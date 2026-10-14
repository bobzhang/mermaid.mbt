// The entity of an ER diagram: mermaid's `shapes/erBox.ts`.

///|
/// mermaid's `parseGenericTypes`: pairs of tildes become angle brackets,
/// outermost first, within each stretch between commas.
fn parse_generic_types(input : String) -> String {
  // `input.split(/(,)/)`: the commas are pieces of their own.
  let sets = []
  for index, piece in input.split(",").collect() {
    if index > 0 {
      sets.push(",")
    }
    sets.push(piece.to_owned())
  }
  let count = (text : String) => text.iter().filter(c => c == '~').count()
  let process = (set : String) => {
    let tildes = count(set)
    if tildes <= 1 {
      return set
    }
    let starting = tildes % 2 != 0 && set.has_prefix("~")
    let chars = if starting {
      set[1:].to_owned().to_array()
    } else {
      set.to_array()
    }
    while true {
      let first = chars.search('~')
      let mut last = None
      for index, c in chars {
        if c == '~' {
          last = Some(index)
        }
      }
      guard first is Some(first) && last is Some(last) && first != last else {
        break
      }
      chars[first] = '<'
      chars[last] = '>'
    }
    (if starting { "~" } else { "" }) + String::from_array(chars)
  }
  let output = []
  let mut i = 0
  while i < sets.length() {
    let mut set = sets[i]
    // "~K, V~" was split in three; such pieces belong together.
    if set == "," &&
      i > 0 &&
      i + 1 < sets.length() &&
      count(sets[i - 1]) == 1 &&
      count(sets[i + 1]) == 1 {
      set = sets[i - 1] + "," + sets[i + 1]
      i += 1
      output.pop() |> ignore
    }
    output.push(process(set))
    i += 1
  }
  output.join("")
}

///|
/// How an entity's texts are drawn. The shape reads the root `htmlLabels`
/// setting on its own, in three ways that agree unless it is set oddly.
priv struct ErLabels {
  /// `config.htmlLabels`, where unset means HTML.
  html : Bool
  /// `evaluate(config.htmlLabels)`
  measured_as_html : Bool
  /// `!config.htmlLabels`
  unset_or_off : Bool
}

///|
fn ErLabels::new(config : @config.Config) -> ErLabels {
  let value = config.get("htmlLabels")
  let falsy = value is (Null | False | String("") | Number(0.0, ..))
  {
    html: value is Null || !falsy,
    // An unset option reads `undefined`, which evaluates to true.
    measured_as_html: value is Null || @config.evaluate(value),
    unset_or_off: falsy,
  }
}

///|
/// One text of an entity in a group of its own, translated down by
/// `translate_y`: erBox's `addText`. Returns the size of the text.
fn er_add_text(
  shape_svg : @dom.Element,
  text : String,
  env : Env,
  labels : ErLabels,
  translate_y : Double,
  class_name : String,
  style : String,
) -> LabelBox {
  let label = shape_svg
    .append("g")
    .attr("class", "label \{class_name}")
    .attr("transform", "translate(0, \{@dom.number(translate_y)})")
    .attr("style", style)
  // Generic types: the brackets go through the label code as entities.
  let generic = parse_generic_types(text)
  let text = if generic != text {
    generic.replace_all(old="<", new="&lt;").replace_all(old=">", new="&gt;")
  } else {
    text
  }
  let flatten = text.contains("&lt;") || text.contains("&gt;")
  let width = calculate_text_width(text, env.config) + 100.0
  if labels.html {
    let (fo, box) = create_html_label(
      label,
      text,
      env,
      width~,
      style~,
      markdown=true,
    )
    guard fo.child_elements() is [div, ..] else { return box }
    if flatten {
      // Upstream undoes the entities by assigning the text of the `div`,
      // which leaves it holding nothing but that text.
      div.text(div.text_content()) |> ignore
    }
    if labels.measured_as_html {
      div.style("text-align", "start") |> ignore
      fo.attr_number("width", box.width).attr_number("height", box.height)
      |> ignore
    }
    return box
  }
  let env = env.styled(style, faces=false)
  let svg_label = create_svg_label(
    label,
    text,
    env,
    width~,
    style~,
    markdown=true,
    anchor_middle=false,
    sanitize=false,
  )
  let mut box = svg_label.text_box
  guard svg_label.group.descendants(["text"]) is [element, ..] else {
    return { width: box.width, height: box.height, }
  }
  // Upstream appends what the label code returned, the text, to the
  // group, which takes it out of the group it was created in.
  label.append_child(element)
  if flatten && element.child_elements() is [first, ..] {
    // The same assignment turns the first line into a single run of text.
    let content = first.text_content()
    first.text(content) |> ignore
    let lines = svg_label.lines.mapi((index, line) => {
      if index == 0 {
        [{ content, kind: "normal", }]
      } else {
        line
      }
    })
    box = text_box(lines, env, false)
    element.set_text_box(box)
  }
  { width: box.width, height: box.height, }
}

///|
/// A line as a polygon with next to no thickness: erBox's `lineToPolygon`.
fn line_to_polygon(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Array[(Double, Double)] {
  let half = 0.0001 / 2.0
  if x1 == x2 {
    [(x1 - half, y1), (x1 + half, y1), (x2 + half, y2), (x2 - half, y2)]
  } else {
    [(x1, y1 - half), (x1, y1 + half), (x2, y2 + half), (x2, y2 - half)]
  }
}

///|
/// The slot of an entity in the palette of the color themes.
fn er_color_slot(element : @dom.Element, node : Node, env : Env) -> Unit {
  guard env.config.text("theme") is Some("redux-color" | "redux-dark-color") else {
    return
  }
  let slots = match env.config.theme().get("borderColorArray") {
    Array(palette) => palette.length()
    _ => 0
  }
  let slot = if slots == 0 {
    "NaN"
  } else {
    (node.color_index.unwrap_or(0) % slots).to_string()
  }
  element.attr("data-color-id", "color-\{slot}") |> ignore
}

///|
/// An entity: its name over a table of its attributes, or a plain
/// rectangle when it has none.
fn er_box(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  guard node.data is Entity(alias_name~, attributes~) else {
    raise LayoutError("An entity box needs an entity to draw.")
  }
  if node.look == "handDrawn" {
    raise LayoutError("The hand-drawn look is not supported yet.")
  }
  if alias_name != "" {
    node.label = alias_name
  }
  let config = env.config
  let theme = config.theme()
  let labels = ErLabels::new(config)
  let mut padding = config.number("er.diagramPadding").unwrap_or(10.0)
  let mut text_padding = config.number("er.entityPadding").unwrap_or(6.0)
  let n = @dom.number
  if attributes.is_empty() && node.label != "" {
    if calculate_text_width(node.label, config) + padding * 2.0 <
      config.number("er.minEntityWidth").unwrap_or(0.0) {
      node.width = config.number("er.minEntityWidth")
    }
    let shape_svg = draw_rect(
      parent,
      node,
      env,
      label_padding_x=padding,
      label_padding_y=padding * 1.5,
      // `node.useHtmlLabels || evaluate(config.htmlLabels)`
      html_labels=!labels.unset_or_off || labels.measured_as_html,
    )
    er_color_slot(shape_svg, node, env)
    if !labels.measured_as_html && shape_svg.descendants(["text"]) is [text, ..] {
      // Text labels are not centred by the rectangle; the shape does it.
      text.attr("transform", "translate(\{n(-text.bbox().width / 2.0)}, 0)")
      |> ignore
    }
    return shape_svg
  }
  if labels.unset_or_off {
    padding = padding * 1.25
    text_padding = text_padding * 1.25
  }
  let styles = node_styles(node)
  let shape_svg = parent
    .append("g")
    .attr("class", node_classes(node))
    .attr("id", node.dom_id)
  let add = (text : String, y : Double, class_name : String) => {
    er_add_text(
      shape_svg,
      text,
      env,
      labels,
      y,
      class_name,
      styles.label_styles,
    )
  }
  let name_box = add(node.label, 0.0, "name")
  // Upstream adds the padding to the measured box itself, and the box of
  // SVG text holds single-precision numbers.
  let name_height = if labels.measured_as_html {
    name_box.height + text_padding
  } else {
    Float::from_double(name_box.height + text_padding).to_double()
  }
  let mut y_offset = 0.0
  let rows : Array[(Double, Double)] = []
  let mut max_type_width = 0.0
  let mut max_name_width = 0.0
  let mut max_keys_width = 0.0
  let mut max_comment_width = 0.0
  for attribute in attributes {
    let type_box = add(attribute.type_, y_offset, "attribute-type")
    max_type_width = max_type_width.max(type_box.width + padding)
    let attribute_name_box = add(attribute.name, y_offset, "attribute-name")
    max_name_width = max_name_width.max(attribute_name_box.width + padding)
    let keys_box = add(attribute.keys.join(","), y_offset, "attribute-keys")
    max_keys_width = max_keys_width.max(keys_box.width + padding)
    let comment_box = add(attribute.comment, y_offset, "attribute-comment")
    max_comment_width = max_comment_width.max(comment_box.width + padding)
    let row_height = type_box.height
      .max(attribute_name_box.height)
      .max(keys_box.height)
      .max(comment_box.height) +
      text_padding
    rows.push((y_offset, row_height))
    y_offset += row_height
  }
  let mut sections = 4.0
  let keys_present = max_keys_width > padding
  if !keys_present {
    max_keys_width = 0.0
    sections -= 1.0
  }
  let comment_present = max_comment_width > padding
  if !comment_present {
    max_comment_width = 0.0
    sections -= 1.0
  }
  let shape_box = shape_svg.bbox()
  // A name wider than the columns widens every column.
  let difference = name_box.width +
    padding * 2.0 -
    (max_type_width + max_name_width + max_keys_width + max_comment_width)
  if difference > 0.0 {
    max_type_width += difference / sections
    max_name_width += difference / sections
    if max_keys_width > 0.0 {
      max_keys_width += difference / sections
    }
    if max_comment_width > 0.0 {
      max_comment_width += difference / sections
    }
  }
  let max_width = max_type_width +
    max_name_width +
    max_keys_width +
    max_comment_width
  let rows_height = rows.fold(init=0.0, (sum, row) => sum + row.1)
  let w = (shape_box.width + padding * 2.0)
    .max(node.width.unwrap_or(0.0))
    .max(max_width)
  let h = (rows_height + name_height).max(node.height.unwrap_or(0.0))
  let x = -w / 2.0
  let y = -h / 2.0
  // Move every text but the name into its cell. Upstream reads the
  // offsets back from the transforms it wrote.
  for index, label in shape_svg.child_elements() {
    guard index > 0 else { continue }
    let class_name = label.get_attr("class").unwrap_or("")
    let translate_x = if class_name.contains("attribute-name") {
      max_type_width
    } else if class_name.contains("attribute-keys") {
      max_type_width + max_name_width
    } else if class_name.contains("attribute-comment") {
      max_type_width + max_name_width + max_keys_width
    } else {
      0.0
    }
    // The four texts of row r come after the name.
    let translate_y = rows[(index - 1) / 4].0
    label.attr(
      "transform",
      "translate(\{n(x + padding / 2.0 + translate_x)}, \{n(translate_y + y + name_height + text_padding / 2.0)})",
    )
    |> ignore
  }
  guard shape_svg.child_elements() is [name_label, ..] else {
    raise LayoutError("The entity has no name label.")
  }
  name_label.attr(
    "transform",
    "translate(\{n(-name_box.width / 2.0)}, \{n(y + text_padding / 2.0)})",
  )
  |> ignore
  er_color_slot(shape_svg, node, env)
  let css_styles = node.css_styles.join("")
  let outline = @rough.rectangle(x, y, w, h, rough_options(node, env))
  shape_svg.insert_before(outline, name_label)
  outline.attr("class", "outer-path").attr("style", css_styles) |> ignore
  let color = (name : String) => {
    match theme.get(name) {
      String(color) => color
      _ => ""
    }
  }
  for index, row in rows {
    let even = (index + 1) % 2 == 0 && row.0 != 0.0
    let options = rough_options(node, env)
    options.fill = color(if even { "rowEven" } else { "rowOdd" })
    options.stroke = color("nodeBorder")
    let rect = @rough.rectangle(x, name_height + y + row.0, w, row.1, options)
    shape_svg.insert_before(rect, name_label)
    rect
    .attr("style", css_styles)
    .attr("class", if even { "row-rect-even" } else { "row-rect-odd" })
    |> ignore
  }
  let divider = (x1 : Double, y1 : Double, x2 : Double, y2 : Double) => {
    let line = @rough.polygon(
      line_to_polygon(x1, y1, x2, y2),
      rough_options(node, env),
    )
    shape_svg.append_child(line)
    line.attr("class", "divider") |> ignore
  }
  divider(x, name_height + y, w + x, name_height + y)
  divider(max_type_width + x, name_height + y, max_type_width + x, h + y)
  if keys_present {
    let at = max_type_width + max_name_width + x
    divider(at, name_height + y, at, h + y)
  }
  if comment_present {
    let at = max_type_width + max_name_width + max_keys_width + x
    divider(at, name_height + y, at, h + y)
  }
  divider(x, name_height + y, w + x, name_height + y)
  update_node_bounds(node, outline)
  if styles.node_styles != "" {
    let paths = shape_svg.descendants(["path"])
    if config.text("theme")
      is Some("redux" | "redux-dark" | "redux-color" | "redux-dark-color") {
      for path in paths {
        path.attr("style", styles.node_styles) |> ignore
      }
    } else {
      let strokes = []
      for style in styles.node_styles.split(";") {
        if style.contains("stroke") {
          strokes.push(style.to_owned())
        }
      }
      for path in paths {
        path.attr("style", strokes.join("; ")) |> ignore
      }
      for group in shape_svg.child_elements() {
        if group.get_attr("class") == Some("row-rect-even") {
          for path in group.descendants(["path"]) {
            path.attr("style", styles.node_styles) |> ignore
          }
        }
      }
    }
  }
  node.intersect = Some(point => {
    intersect_rect(
      node.x,
      node.y,
      node.width.unwrap_or(0.0),
      node.height.unwrap_or(0.0),
      point,
    )
  })
  shape_svg
}
