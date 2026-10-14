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
/// Draw the board into the context's `<svg>` element: mermaid's `draw`.
/// Columns stand side by side, each as tall as its cards need.
pub fn draw(db : KanbanDb, context : @diagram.Context) -> Unit raise {
  let config = context.config
  let svg = context.svg
  let data = db.data()
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
  for section in sections {
    let (section_node, section_element) = section
    let top = -width * 3.0 / 2.0 + max_label_height
    let mut y = top
    for entry in data {
      guard entry.node.parent_id == Some(section_node.id) else { continue }
      if entry.is_group {
        raise Invalid("Groups within groups are not allowed in Kanban diagrams")
      }
      let item = entry.node
      let node = @rendering.Node::new(
        id=item.id,
        parent_id=section_node.id,
        label=entry.label,
        label_type="markdown",
        padding=0.0,
        css_styles=["text-align: left"],
        css_classes="undefined",
        dom_id="\{context.id}-\{item.id}",
        // Items have no look.
        look="",
        shape="kanbanItem",
        data=KanbanItem(
          ticket=db.sanitize_text(item.ticket.unwrap_or("")),
          assigned=db.sanitize_text(item.assigned.unwrap_or("")),
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
