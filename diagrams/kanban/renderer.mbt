// Drawing a kanban board: mermaid's `kanbanRenderer.ts`.

///|
/// The gap the board keeps between cards and around them.
const PADDING : Double = 10.0

///|
/// `conf.kanban.sectionWidth || 200`: the width of a column.
fn section_width(config : @config.Config) -> Double raise KanbanError {
  match config.get("kanban.sectionWidth") {
    Null | False => 200.0
    Number(width, ..) =>
      if width == 0.0 || width.is_nan() {
        200.0
      } else if width > 0.0 {
        width
      } else {
        // The browser refuses the sizes that follow from it.
        raise Unsupported("a negative kanban.sectionWidth")
      }
    String("") => 200.0
    // Upstream computes with whatever it is given.
    _ => raise Unsupported("a kanban.sectionWidth that is no number")
  }
}

///|
/// The padding around the board and whether the `<svg>` scales with its
/// container. Upstream asks the mind map's configuration for both.
fn viewbox_options(config : @config.Config) -> (Double, Bool) raise KanbanError {
  let padding = match config.get("mindmap.padding") {
    Null => config.number("kanban.padding").unwrap_or(8.0)
    Number(padding, ..) => padding
    _ => raise Unsupported("a mindmap.padding that is no number")
  }
  let use_max_width = match config.get("mindmap.useMaxWidth") {
    Null => config.get("kanban.useMaxWidth") is (True | Null)
    True => true
    False => false
    _ => raise Unsupported("a mindmap.useMaxWidth that is no boolean")
  }
  (padding, use_max_width)
}

///|
/// Whether text in `family`, a CSS list of font families, can be measured
/// as the reference browser would: the first family installed there has
/// to be one of the embedded ones. A family not known either way may or
/// may not be installed, and would be measured in a stand-in; no family
/// at all leaves the text in the font of the page.
fn is_measurable_family(family : String) -> Bool {
  for name in family.split(",") {
    match name.trim(chars=" \t\n\"';").to_owned().to_lower() {
      // The font of the redux themes, which the reference machine lacks.
      "recursive variable" => continue
      "trebuchet ms" | "verdana" | "arial" => return true
      _ => return false
    }
  }
  false
}

///|
/// Elements of an HTML label whose text the measuring lays out as the
/// browser does: those that change the face, line breaks, paragraphs.
/// Any other element starts text the browser rounds on its own, if it
/// does not change its size or face as well.
let plain_elements : Array[String] = ["b", "strong", "i", "em", "br", "p"]

///|
/// Refuse text that cannot be measured as the browser does: characters
/// the embedded fonts do not have, which the browser draws from fonts of
/// the system, and, in HTML labels, elements the measuring does not know
/// (`sub`, `code`, `u`, ...).
fn check_text(
  text : String,
  html : Bool,
  stacks : Array[@font.Stack],
) -> Unit raise KanbanError {
  // The text as it is shown: references resolved, markup apart.
  let holder = @dom.Element::new("div")
  holder.set_inner_html(@dom.placeholders_to_references(text))
  let shown = holder.text_content()
  for stack in stacks {
    guard stack.covers(shown) else {
      raise Unsupported("text the embedded fonts do not cover: \{shown}")
    }
  }
  guard html else {
    check_markdown_text(@dom.placeholders_to_references(text))
    return
  }
  fn visit(element : @dom.Element) raise KanbanError {
    for child in element.children() {
      guard child is Element(child) else { continue }
      // An element with attributes may be styled by them.
      guard plain_elements.contains(child.tag) &&
        child.to_html().has_prefix("<\{child.tag}>") else {
        raise Unsupported("<\{child.tag}> in a label")
      }
      visit(child)
    }
  }
  visit(holder)
}

///|
/// A label as the label helpers sanitize it before it becomes markup:
/// `sanitizeText(decodeEntities(text))`. Where the sanitizer has to parse
/// the text, which it does when there is a tag in it, the character
/// references come back resolved, before markdown sees the text: `#35;`
/// at the start of a line is then a heading.
fn label_text(text : String) -> String raise KanbanError {
  guard text.contains("<") else { return text }
  let text = @dom.placeholders_to_references(text)
  @dom.sanitize_fragment(text) catch {
    _ => raise Unsupported("kanban text with markup: \{text}")
  }
}

///|
/// Whether a line of markdown may start a block other than a paragraph
/// (a heading, a list, a quote, code), which text labels take over as
/// written, white space and line breaks included.
fn starts_block(line : String) -> Bool {
  let indent = line.length() - line.trim_start(chars=" ").length()
  if indent >= 4 || line.contains("\t") {
    return true
  }
  let chars = line.trim_start(chars=" ").to_array()
  guard chars is [first, ..] else { return false }
  let after = (i : Int32) => i >= chars.length() || chars[i] is (' ' | '\t')
  match first {
    '#' | '>' => true
    // A fence.
    '`' => line.contains("```")
    '-' | '*' | '+' | '_' => {
      // A bullet, or a thematic break.
      if after(1) {
        return true
      }
      chars.iter().all(c => c == first || c == ' ') &&
      chars.iter().filter(c => c == first).count() >= 3
    }
    '0'..<='9' => {
      let mut i = 0
      while i < chars.length() && chars[i] is ('0'..<='9') {
        i += 1
      }
      i < chars.length() && chars[i] is ('.' | ')') && after(i + 1)
    }
    _ => false
  }
}

///|
/// `x@y.z`, which marked links as an e-mail address.
let email_pattern : @jsregex.Regex = try! @jsregex.Regex::compile(
  "[A-Za-z0-9._+-]@[A-Za-z0-9_-]+\\.[A-Za-z0-9]",
)

///|
/// `<br>` in its forms, where markdown text labels break lines.
let break_pattern : @jsregex.Regex = try! @jsregex.Regex::compile(
  "<br\\s*/?>",
  flags="gi",
)

///|
/// Refuse markdown that text labels draw from tokens the port's markdown
/// does not make: blocks other than paragraphs, and the inline links and
/// strike-through of GitHub's flavour, which text labels leave out.
fn check_markdown_text(text : String) -> Unit raise KanbanError {
  let text = break_pattern.replace_all(text, _ => "\n")
  let refuse = () => {
    Unsupported("markdown the port's text labels do not read: \{text}")
  }
  if text.contains("~") ||
    text.contains("://") ||
    text.contains("www.") ||
    text.contains("  \n") ||
    email_pattern.exec(text) is Some(_) {
    raise refuse()
  }
  // A block as the last line comes out as marked has it; one with lines
  // after it does not, and code keeps white space SVG text collapses.
  let lines = text.split("\n").map(line => line.to_owned()).collect()
  for index, line in lines {
    if starts_block(line) &&
      (
        index < lines.length() - 1 ||
        line.has_prefix("    ") ||
        line.contains("\t")
      ) {
      raise refuse()
    }
  }
}

///|
/// Refuse a board whose text the port cannot measure exactly.
fn check_measurable(
  db : KanbanDb,
  data : Array[LayoutNode],
  context : @diagram.Context,
) -> Unit raise KanbanError {
  let family = context.theme().text("fontFamily")
  if !is_measurable_family(family) {
    raise Unsupported("measuring text in the font family \{family}")
  }
  // Sizes in pixels are what the labels are measured at; a number alone
  // is dropped by the browser and leaves its default size, which is that
  // of the labels too.
  match context.theme().get("fontSize") {
    Number(_, ..) => ()
    String(size) if size.has_suffix("px") &&
      size[:size.length() - 2].iter().all(c => c is ('0'..<='9' | '.')) => ()
    size => raise Unsupported("the font size \{size.stringify()}")
  }
  let stacks = [
    context.font(),
    context.font(bold=true),
    context.font(italic=true),
    context.font(bold=true, italic=true),
  ]
  let config = context.config
  // Titles of cards follow the root `htmlLabels`; the other labels take
  // the flowchart's into account.
  let html_titles = match config.get("htmlLabels") {
    Null => true
    value => @config.evaluate(value)
  }
  let html_labels = match config.get("htmlLabels") {
    Null =>
      match config.get("flowchart.htmlLabels") {
        Null => true
        value => @config.evaluate(value)
      }
    value => @config.evaluate(value)
  }
  for entry in data {
    if entry.is_group {
      check_text(entry.label, html_labels, stacks)
      continue
    }
    // The text of a card is sanitized once more on its way to its label.
    let item = entry.node
    check_text(label_text(entry.label), html_titles, stacks)
    for text in [item.ticket.unwrap_or(""), item.assigned.unwrap_or("")] {
      check_text(label_text(db.sanitize_text(text)), html_labels, stacks)
    }
  }
}

///|
/// Draw the board into the context's `<svg>` element: mermaid's `draw`.
/// Columns stand side by side, each as tall as its cards need.
pub fn draw(db : KanbanDb, context : @diagram.Context) -> Unit raise {
  let config = context.config
  let svg = context.svg
  let data = db.data()
  check_measurable(db, data, context)
  let painter = @rendering.Painter::new(
    config,
    diagram_type="kanban",
    diagram_id=context.id,
  )
  let sections_element = svg.append("g").attr("class", "sections")
  let items_element = svg.append("g").attr("class", "items")
  let width = section_width(config)
  let look = config.text("look").unwrap_or("classic")
  // Draw the columns first, at a height they are given for now.
  let sections = []
  let mut max_label_height = 25.0
  for entry in data {
    guard entry.is_group else { continue }
    let count = (sections.length() + 1).to_double()
    let node = @rendering.Node::new(
      id=entry.node.id,
      label=entry.label,
      label_type="markdown",
      padding=0.0,
      // The classes of a node are not handed on, and so are `undefined`.
      css_classes="undefined section-\{sections.length() + 1}",
      dom_id="\{context.id}-\{entry.node.id}",
      look~,
      is_group=true,
      shape="kanbanSection",
      rx=5.0,
      ry=5.0,
    ).placed(
      x=width * count + (count - 1.0) * PADDING / 2.0,
      y=0.0,
      width~,
      height=width * 3.0,
      label_style="",
    )
    let element = painter.insert_cluster(sections_element, node)
    if node.label_box is Some((_, height)) {
      max_label_height = max_label_height.max(height)
    }
    sections.push((node, element))
  }
  // Then the cards of each column, one below the other. A card is first
  // drawn to learn its size.
  let n = @dom.number
  // The node of every item, kept from one column to the next: an item of
  // sections that share an id is drawn in each, carrying over what the
  // first drawing left on it.
  let item_nodes : Array[@rendering.Node?] = data.map(_ => None)
  for section in sections {
    let (section_node, section_element) = section
    let top = -width * 3.0 / 2.0 + max_label_height
    let mut y = top
    for index, entry in data {
      guard entry.node.parent_id == Some(section_node.id) else { continue }
      if entry.is_group {
        raise Invalid("Groups within groups are not allowed in Kanban diagrams")
      }
      let item = entry.node
      let node = match item_nodes[index] {
        Some(node) =>
          node.placed(
            x=section_node.x,
            y=node.y,
            width=width - 1.5 * PADDING,
            height?=node.height,
            label_style=node.label_style,
          )
        None =>
          @rendering.Node::new(
            id=item.id,
            parent_id=section_node.id,
            label=label_text(entry.label),
            label_type="markdown",
            padding=0.0,
            css_styles=["text-align: left"],
            css_classes="undefined",
            dom_id="\{context.id}-\{item.id}",
            // Items have no look.
            look="",
            shape="kanbanItem",
            data=KanbanItem(
              ticket=item.ticket.unwrap_or(""),
              ticket_text=label_text(
                db.sanitize_text(item.ticket.unwrap_or("")),
              ),
              assigned=label_text(db.sanitize_text(item.assigned.unwrap_or(""))),
              priority=item.priority,
              icon=item.icon is Some(icon) && icon != "",
            ),
            rx=5.0,
            ry=5.0,
          ).placed(
            x=section_node.x,
            y=0.0,
            width=width - 1.5 * PADDING,
            label_style="",
          )
      }
      item_nodes[index] = Some(node)
      let element = painter.insert_node(items_element, node)
      element.remove_attr("data-look") |> ignore
      let box = element.bbox()
      let item_y = y + box.height / 2.0
      element.attr("transform", "translate(\{n(node.x)}, \{n(item_y)})")
      |> ignore
      y = item_y + box.height / 2.0 + PADDING / 2.0
    }
    // `cluster.select('rect')`: the frame is the first one.
    if section_element.descendants(["rect"]) is [rect, ..] {
      let height = (y - top + 3.0 * PADDING).max(50.0) +
        (max_label_height - 25.0)
      rect.attr_number("height", height) |> ignore
    }
  }
  // `setupGraphViewbox`
  let (padding, use_max_width) = viewbox_options(config)
  let bounds = svg.bbox()
  @diagram.configure_svg_size(
    svg,
    bounds.height + padding * 2.0,
    bounds.width + padding * 2.0,
    use_max_width,
  )
  svg.attr(
    "viewBox",
    "\{n(bounds.x - padding)} \{n(bounds.y - padding)} \{n(bounds.width + 2.0 * padding)} \{n(bounds.height + 2.0 * padding)}",
  )
  |> ignore
}
