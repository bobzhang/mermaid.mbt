// The box of a requirement or an element in a requirement diagram:
// mermaid's `shapes/requirementBox.ts`.

///|
/// One text of the box in a group of its own, centred on `y_offset`:
/// requirementBox's `addText`. Returns the group with the translation it
/// was given, and the height of the text; nothing for an empty text.
fn requirement_add_text(
  shape_svg : @dom.Element,
  text : String,
  y_offset : Double,
  style : String,
  start_aligned : Bool,
  env : Env,
) -> (@dom.Element, Double, Double, Double)? {
  if text == "" {
    return None
  }
  let label = shape_svg.append("g").attr("class", "label").attr("style", style)
  // Room for error when the text is split into lines.
  let width = calculate_text_width(text, env.config) + 50.0
  let n = @dom.number
  let place = (box_width : Double, box_height : Double) => {
    let x = -box_width / 2.0
    let y = -box_height / 2.0 + y_offset
    label.attr("transform", "translate(\{n(x)},\{n(y)})") |> ignore
    Some((label, x, y, box_height))
  }
  if env.html_labels {
    let (fo, box) = create_html_label(
      label,
      text,
      env,
      width~,
      classes="markdown-node-label",
      style~,
      markdown=true,
    )
    if start_aligned && fo.child_elements() is [div, ..] {
      div.style("text-align", "left") |> ignore
    }
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    return place(box.width, box.height)
  }
  let svg_label = create_svg_label(
    label,
    text,
    env,
    width~,
    style~,
    markdown=true,
    anchor_middle=false,
  )
  // The words of the first line take the style, and the anchor; the box is
  // read after that. A size in the style applies to the whole text.
  let font = label_font(style)
  if svg_label.element.child_elements() is [first, ..] {
    if style != "" {
      for word in first.child_elements() {
        word.attr("style", style) |> ignore
      }
    }
    if start_aligned {
      first.attr("text-anchor", "start") |> ignore
      for word in first.child_elements() {
        word.attr("text-anchor", "start") |> ignore
      }
    }
  }
  let sized_env = match font.size {
    Some(size) => { ..env, font_size: size, }
    None => env
  }
  let box = text_box(svg_label.lines, sized_env, false, restyle=(line, run) => {
    if line == 0 {
      { ..run, bold: run.bold || font.bold, italic: run.italic || font.italic, }
    } else {
      run
    }
  })
  svg_label.element.set_text_box(box)
  // Six more in height, so that it comes close to the HTML labels; the
  // box of SVG text holds single-precision numbers.
  let height = Float::from_double(box.height + 6.0).to_double()
  place(box.width, height)
}

///|
/// A requirement or an element: its kind and name over what is known
/// about it.
fn requirement_box(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  if node.look == "handDrawn" {
    raise LayoutError("The hand-drawn look is not supported yet.")
  }
  let styles = shape_styles(node)
  let padding = 20.0
  let gap = 20.0
  let config = env.config
  // `config.htmlLabels ?? true`, read for its truth.
  let html_labels = !(config.get("htmlLabels")
    is (False | String("") | Number(0.0, ..)))
  let env = { ..env, html_labels, }
  let start_aligned = config.text("layout") == Some("elk")
  let shape_svg = parent
    .append("g")
    .attr("class", node_classes(node))
    .attr("id", node.dom_id)
  let labels : Array[(@dom.Element, Double, Double)] = []
  // Add a text and return its height.
  let add = (text : String, y : Double, style : String, start : Bool) => {
    match requirement_add_text(shape_svg, text, y, style, start, env) {
      Some((label, x, y, height)) => {
        labels.push((label, x, y))
        height
      }
      None => 0.0
    }
  }
  let labelled = (title : String, value : String) => {
    if value == "" {
      ""
    } else {
      "\{title}: \{value}"
    }
  }
  let label_style = node.label_style
  let name_style = label_style + "; font-weight: bold;"
  let (type_height, name_height, body_height) = match node.data {
    Requirement(name~, type_~, requirement_id~, text~, risk~, verify_method~) => {
      let type_height = add("&lt;&lt;\{type_}&gt;&gt;", 0.0, label_style, false)
      let name_height = add(name, type_height, name_style, false)
      let mut y = type_height + name_height + gap
      y += add(labelled("ID", requirement_id), y, label_style, start_aligned)
      y += add(labelled("Text", text), y, label_style, start_aligned)
      y += add(labelled("Risk", risk), y, label_style, start_aligned)
      add(
        labelled("Verification", verify_method),
        y,
        label_style,
        start_aligned,
      )
      |> ignore
      (type_height, name_height, y)
    }
    RequirementElement(name~, type_~, doc_ref~) => {
      let type_height = add("&lt;&lt;Element&gt;&gt;", 0.0, label_style, false)
      let name_height = add(name, type_height, name_style, false)
      let mut y = type_height + name_height + gap
      y += add(labelled("Type", type_), y, label_style, start_aligned)
      add(labelled("Doc Ref", doc_ref), y, label_style, start_aligned) |> ignore
      (type_height, name_height, y)
    }
    _ => raise LayoutError("A requirement box needs a requirement to draw.")
  }
  let content = shape_svg.bbox()
  let total_width = content.width + padding
  let total_height = content.height + padding
  let x = -total_width / 2.0
  let y = -total_height / 2.0
  let outline = @rough.rectangle(
    x,
    y,
    total_width,
    total_height,
    rough_options(node, env),
  )
  prepend(shape_svg, outline)
  outline
  .attr("class", "basic label-container outer-path")
  .attr("style", styles.node_styles)
  |> ignore
  let palette = match config.theme().get("borderColorArray") {
    Array(palette) => palette.length()
    _ => 0
  }
  if palette > 0 {
    shape_svg.attr(
      "data-color-id",
      "color-\{node.color_index.unwrap_or(0) % palette}",
    )
    |> ignore
  }
  // The labels move with the rectangle now that it is centred; all but
  // the kind and the name go to its left side.
  let n = @dom.number
  for index, label in labels {
    let (element, translate_x, translate_y) = label
    let new_y = translate_y - total_height / 2.0
    let new_x = if index < 2 { translate_x } else { x + padding / 2.0 }
    element.attr("transform", "translate(\{n(new_x)}, \{n(new_y + padding)})")
    |> ignore
  }
  // A line under the name when there is a body.
  if body_height > type_height + name_height + gap {
    let line_y = y + type_height + name_height + gap
    let line = if node.look == "neo" {
      @rough.polygon(
        [
          (x, line_y),
          (x + total_width, line_y),
          (x + total_width, line_y + 0.001),
          (x, line_y + 0.001),
        ],
        rough_options(node, env),
      )
    } else {
      @rough.line(x, line_y, x + total_width, line_y, rough_options(node, env))
    }
    shape_svg.append_child(line)
    line.attr("class", "divider") |> ignore
  }
  update_node_bounds(node, outline)
  node.intersect = Some(point => {
    intersect_rect(
      node.x,
      node.y,
      node.width.unwrap_or(0.0),
      node.height.unwrap_or(0.0),
      point,
    )
  })
  if styles.node_styles != "" &&
    (config.theme().flag("requirementEdgeLabelBackground") || palette > 0) {
    for path in shape_svg.descendants(["path"]) {
      path.attr("style", styles.node_styles) |> ignore
    }
  }
  shape_svg
}
