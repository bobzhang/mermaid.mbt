// The label of a C4 element: mermaid's `c4LabelHelper`.

///|
/// The gap between two sections of the label.
const SECTION_GAP : Double = 3.0

///|
/// A label never wraps narrower than this.
const MIN_WRAP_WIDTH : Double = 32.0

///|
/// The environment one section of a C4 label is measured in: the diagram's
/// stylesheet makes the name bold and sets the type and description lines
/// in smaller text.
fn section_env(env : Env, css_class : String) -> Env {
  // An `em` is a multiple of the inherited size, which the browser holds
  // in single precision.
  let inherited = Float::from_double(env.font_size).to_double()
  match css_class {
    "c4-name" => { ..env, bold: true, }
    "c4-type" => { ..env, font_size: inherited * 0.75, }
    _ => { ..env, font_size: inherited * 0.82, }
  }
}

///|
/// mermaid's `c4LabelHelper`: a label of stacked sections (name, type,
/// description lines), each SVG text of its own so that the stylesheet
/// can set each in its own type. Stands in for `label_helper` on nodes
/// that carry a stereotype.
fn c4_label_helper(
  parent : @dom.Element,
  node : Node,
  classes : String,
  env : Env,
) -> Labelled raise LayoutError {
  let shape_svg = parent
    .append("g")
    .attr("class", classes)
    .attr("id", node.dom_id)
  let label = shape_svg
    .append("g")
    .attr("class", "label")
    .attr("style", node.label_style)
  let sections : Array[(String, String)] = [(node.label, "c4-name")]
  // The stylesheet sets the label in the font of the element's type.
  let env = match node.data {
    C4(stereotype~, font_family~, font_size~, bold~) => {
      sections.push((stereotype, "c4-type"))
      { ..env, font_family, font_size, bold, italic: false, }
    }
    _ => env
  }
  for line in node.description {
    sections.push((line, "c4-descr"))
  }
  let wrap_width = match node.width {
    Some(width) if width != 0.0 && !width.is_nan() =>
      (width - 2.0 * node.padding).max(MIN_WRAP_WIDTH)
    _ => env.config.number("flowchart.wrappingWidth").unwrap_or(200.0)
  }
  // `c4.wrap` is the diagram's own switch, on unless configured off.
  let width = if env.config.get("c4.wrap") is Null || env.config.flag("c4.wrap") {
    Some(wrap_width)
  } else {
    None
  }
  let rendered : Array[(@dom.Element, @dom.Rect)] = []
  for section in sections {
    guard section.0 != "" else { continue }
    let element = label.append("g").attr("class", section.1)
    let section_env = section_env(env, section.1)
    // Lines are broken while every word still carries the weight
    // attribute `createText` writes, which overrides whatever weight the
    // stylesheet gives the label: the breaks are those of regular text.
    let text = create_svg_label(
      element,
      section.0,
      { ..section_env, bold: false, },
      width?,
      style=node.label_style,
      anchor_middle=true,
    )
    // Each line is centred in its section; the lines sit at x = 0.
    for tspan in text.element.child_elements() {
      tspan.attr("text-anchor", "middle") |> ignore
      // Without the presentation attributes, weight and style come from
      // the stylesheet.
      for word in tspan.child_elements() {
        word.remove_attr("font-weight").remove_attr("font-style") |> ignore
      }
    }
    text.element.set_text_box(text_box(text.lines, section_env, true))
    rendered.push((element, element.bbox()))
  }
  let total_width = rendered.fold(init=0.0, (widest, section) => {
    widest.max(section.1.width)
  })
  let n = @dom.number
  let mut y = 0.0
  for section in rendered {
    let (element, box) = section
    element.attr(
      "transform",
      "translate(\{n(total_width / 2.0 - box.x - box.width / 2.0)}, \{n(y - box.y)})",
    )
    |> ignore
    y += box.height + SECTION_GAP
  }
  let total_height = if rendered.is_empty() { 0.0 } else { y - SECTION_GAP }
  label.insert_first("rect") |> ignore
  label.attr(
    "transform",
    "translate(\{n(-total_width / 2.0)}, \{n(-total_height / 2.0)})",
  )
  |> ignore
  let box = label.bbox()
  // The box is an `SVGRect`, without `left` and `top`: shapes that place
  // the label subtract where it starts, which is the origin give or take
  // what the transforms lose in single precision.
  {
    shape_svg,
    label,
    bbox: { width: box.width, height: box.height, },
    offset_x: box.x,
    offset_y: box.y,
  }
}
