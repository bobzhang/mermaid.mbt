// The class of a class diagram: mermaid's `shapes/classBox.ts` with the
// text helper of `diagrams/class/shapeUtil.ts`.

///|
/// One text of a class box in a group of its own, moved up by half its
/// first line and down by `y_offset`: shapeUtil's `addText`. Returns the
/// height of the text.
fn class_add_text(
  parent : @dom.Element,
  text : String,
  env : Env,
  html : Bool,
  y_offset : Double,
  style : String,
) -> Double raise LayoutError {
  let label = parent.append("g").attr("class", "label").attr("style", style)
  // The backslash that keeps markdown from reading a visibility marker
  // as markup only matters to HTML labels.
  let text = if !html && text.has_prefix("\\") {
    text[1:].to_owned()
  } else {
    text
  }
  if text.contains("$$") {
    raise LayoutError("KaTeX in class diagrams is not supported yet.")
  }
  // Upstream sanitizes the text here, which rewrites anything that has
  // markup in it.
  if @dom.placeholders_to_references(text).contains("<") {
    raise LayoutError("class diagram text with markup: \{text}")
  }
  let width = calculate_text_width(text, env.config) + 50.0
  let n = @dom.number
  let bold = style == "font-weight: bolder"
  let (height, lines) = if html {
    let face = label_font(style)
    let (fo, box) = create_html_label(
      label,
      text,
      { ..env, bold: bold || face.bold, italic: face.italic, },
      width~,
      classes="markdown-node-label",
      markdown=true,
    )
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    (box.height, fo.descendants(["br"]).length() + 1)
  } else {
    let svg_label = create_svg_label(
      label,
      text,
      env,
      width~,
      markdown=true,
      anchor_middle=false,
      sanitize=false,
    )
    let element = svg_label.element
    let mut box = svg_label.text_box
    if bold {
      // The title is bold through its group once its spans stop saying
      // otherwise. A member in italics stays upright: its spans keep
      // their own style.
      for tspan in element.descendants(["tspan"]) {
        tspan.attr("font-weight", "") |> ignore
      }
      box = text_box(svg_label.lines, env, false, restyle=(_, run) => {
        ..run,
        bold: true,
      })
      element.set_text_box(box)
    }
    (box.height, svg_label.lines.length())
  }
  label.attr(
    "transform",
    "translate(0,\{n(-height / (2.0 * lines.to_double()) + y_offset)})",
  )
  |> ignore
  height
}

///|
/// The second number of a `translate(x, y)` as upstream reads it back
/// from the attribute; a transform without a comma has none.
fn translate_y(element : @dom.Element) -> Double {
  guard element.get_attr("transform") is Some(transform) &&
    transform.find(",") is Some(comma) else {
    return 0.0
  }
  let rest = transform[comma + 1:]
  let end = rest.find(")").unwrap_or(rest.length())
  @string.parse_double(rest[:end].trim().to_owned()) catch {
    _ => 0.0
  }
}

///|
/// `value || 0`
fn or_zero(value : Double) -> Double {
  if value.is_nan() || value == 0.0 {
    0.0
  } else {
    value
  }
}

///|
/// A class: annotation and title over its members and its methods, in a
/// box with a divider between the sections.
fn class_box(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  guard node.data is ClassBox(text~, annotations~, members~, methods~) else {
    raise LayoutError("A class box needs a class to draw.")
  }
  if node.look == "handDrawn" {
    raise LayoutError("The hand-drawn look is not supported yet.")
  }
  let config = env.config
  let theme = config.theme()
  let padding = config.number("class.padding").unwrap_or(12.0)
  let gap = padding
  // `evaluate(config.htmlLabels)`, where unset means HTML.
  let html = match config.get("htmlLabels") {
    Null => true
    value => @config.evaluate(value)
  }
  let text_padding = if html { 0.0 } else { 3.0 }
  let n = @dom.number
  // The text helper.
  let shape_svg = parent
    .append("g")
    .attr("class", node_classes(node))
    .attr("id", node.dom_id)
  let annotation_group = shape_svg
    .append("g")
    .attr("class", "annotation-group text")
  let mut annotation_height = 0.0
  if annotations is [annotation, ..] {
    class_add_text(annotation_group, "«\{annotation}»", env, html, 0.0, "")
    |> ignore
    annotation_height = annotation_group.bbox().height
  }
  let label_group = shape_svg.append("g").attr("class", "label-group text")
  class_add_text(label_group, text, env, html, 0.0, "font-weight: bolder")
  |> ignore
  let label_box = label_group.bbox()
  let label_height = label_box.height
  let section = (class_name : String, lines : Array[ClassBoxMember]) => {
    let group = shape_svg.append("g").attr("class", class_name)
    let mut y_offset = 0.0
    for line in lines {
      let height = class_add_text(
        group,
        line.text,
        env,
        html,
        y_offset,
        line.style,
      )
      y_offset += height + text_padding
    }
    group
  }
  let members_group = section("members-group text", members)
  let mut members_height = members_group.bbox().height
  if members_height <= 0.0 {
    members_height = gap / 2.0
  }
  let methods_group = section("methods-group text", methods)
  annotation_group.attr(
    "transform",
    "translate(\{n(-annotation_group.bbox().width / 2.0)})",
  )
  |> ignore
  label_group.attr(
    "transform",
    "translate(\{n(-label_box.width / 2.0)}, \{n(annotation_height)})",
  )
  |> ignore
  members_group.attr(
    "transform",
    "translate(0, \{n(annotation_height + label_height + gap * 2.0)})",
  )
  |> ignore
  methods_group.attr(
    "transform",
    "translate(0, \{n(annotation_height + label_height + (if members_height != 0.0 { members_height + gap * 4.0 } else { gap * 2.0 }))})",
  )
  |> ignore
  let text_bounds = shape_svg.bbox()
  // The box.
  if node.color_index is Some(index) &&
    config.text("theme") is Some("redux-color" | "redux-dark-color") &&
    theme.get("borderColorArray") is Array(palette) &&
    !palette.is_empty() {
    shape_svg.attr("data-color-id", "color-\{index % palette.length()}")
    |> ignore
  }
  let styles = node.css_styles.join(";")
  let empty = members.is_empty() && methods.is_empty()
  let extra_box = empty && !config.flag("class.hideEmptyMembersBox")
  let w = node.width.unwrap_or(0.0).max(text_bounds.width)
  let mut h = node.height.unwrap_or(0.0).max(text_bounds.height)
  let taller = node.height.unwrap_or(0.0) > text_bounds.height
  if empty {
    h += gap
  } else if methods.is_empty() {
    h += gap * 2.0
  }
  let x = -w / 2.0
  let y = -h / 2.0
  // How far the title sits above where it would in a box with sections.
  let lift = if extra_box {
    padding
  } else if empty {
    -padding / 2.0
  } else {
    0.0
  }
  let extra_height = if taller {
    padding * 2.0
  } else if extra_box {
    padding * 2.0
  } else if empty {
    -padding
  } else {
    0.0
  }
  let rect = @rough.rectangle(
    x - padding,
    y - padding - lift,
    w + 2.0 * padding,
    h + 2.0 * padding + extra_height,
    rough_options(node, env),
  )
  prepend(shape_svg, rect)
  rect.attr("class", "basic label-container outer-path") |> ignore
  let rect_box = rect.bbox()
  let trim = if extra_box { padding / 2.0 } else { 0.0 }
  let annotation_height = or_zero(annotation_group.bbox().height - trim)
  let label_height = or_zero(label_group.bbox().height - trim)
  let members_height = or_zero(members_group.bbox().height - trim)
  // Half way between the title and the bottom, for a box made taller.
  let methods_area = (
      annotation_height + label_height + y + padding - (y - padding - lift)
    ) /
    2.0
  let hide_empty = empty && config.flag("class.hideEmptyMembersBox")
  for group in [annotation_group, label_group, members_group, methods_group] {
    let class_name = group.get_attr("class").unwrap_or("")
    let old_y = translate_y(group)
    let mut new_y = old_y + y + padding - lift
    if class_name.contains("methods-group") {
      let members_height = members_height.max(gap / 2.0)
      new_y = if taller {
        methods_area.max(
          annotation_height +
          label_height +
          members_height +
          y +
          gap * 2.0 +
          padding,
        ) +
        gap * 2.0
      } else {
        annotation_height +
        label_height +
        members_height +
        y +
        gap * 4.0 +
        padding
      }
    }
    if hide_empty {
      new_y = if annotations.is_empty() { old_y } else { old_y - gap }
    }
    if !html {
      // Upstream's correction for text labels.
      new_y -= 4.0
    }
    let new_x = if class_name.contains("label-group") ||
      class_name.contains("annotation-group") {
      or_zero(-group.bbox().width / 2.0)
    } else {
      x
    }
    group.attr("transform", "translate(\{n(new_x)}, \{n(new_y)})") |> ignore
  }
  // The dividers: lines that rise by a thousandth, so that their box has
  // a height for a gradient stroke to fill.
  let divider_class = if node.look == "neo" && !theme.flag("useGradient") {
    "divider neo-line"
  } else {
    "divider"
  }
  let divider = (line_y : Double) => {
    let line = @rough.line(
      rect_box.x,
      line_y,
      rect_box.x + rect_box.width,
      line_y + 0.001,
      rough_options(node, env),
    )
    shape_svg.append_child(line)
    line.attr("class", divider_class).attr("style", styles) |> ignore
  }
  if !empty || extra_box {
    divider(annotation_height + label_height + y + padding)
    let second = annotation_height +
      label_height +
      members_height +
      y +
      gap * 2.0 +
      padding
    divider(if taller { methods_area.max(second) } else { second })
  }
  for path in shape_svg.descendants(["path"]) {
    path.attr("style", styles) |> ignore
  }
  for span in shape_svg.descendants(["span"]) {
    span.attr("style", styles) |> ignore
  }
  if !html && style_color(styles) is Some(color) {
    // Text takes its colour as a fill.
    for tspan in shape_svg.descendants(["tspan"]) {
      tspan.attr("style", color) |> ignore
    }
  }
  update_node_bounds(node, rect)
  node.intersect = Some(node_intersect_rect(node))
  shape_svg
}

///|
/// The `color` declaration of a style text as a `fill` declaration:
/// what `/color\s*:\s*([^;]*)/` matches, with `color` replaced.
fn style_color(styles : String) -> String? {
  let mut from = 0
  while styles[from:].find("color") is Some(found) {
    let start = from + found
    let rest = styles[start + 5:]
    let value = rest.trim_start(chars=" \t\n\r")
    if value.has_prefix(":") {
      let end = rest.find(";").unwrap_or(rest.length())
      return Some("fill" + rest[:end].to_owned())
    }
    from = start + 5
  }
  None
}
