// The shapes of use case diagrams: mermaid's `usecaseActor*.ts`,
// `usecaseEllipse.ts`, `usecaseBusiness.ts` and `usecaseJsonTable.ts`.

///|
/// The type a stylesheet sets a label in: a CSS `font-family` list, a
/// size in pixels and whether the weight is bold.
pub(all) struct UsecaseFont {
  family : String
  size : Double
  bold : Bool
}

///|
/// Whether node labels are HTML, as `labelHelper` decides it.
fn node_html_labels(env : Env) -> Bool {
  match env.config.get("htmlLabels") {
    Null => true
    value => @config.evaluate(value)
  }
}

///|
/// The environment the label of a use case diagram node is measured in:
/// the stylesheet sets HTML labels (`.nodeLabel`) of actors and use cases
/// in a type of their own.
fn usecase_label_env(node : Node, env : Env) -> Env {
  match node.data {
    Usecase(font=Some(font), ..) if node_html_labels(env) =>
      {
        ..env,
        font_family: font.family,
        font_size: font.size,
        bold: font.bold,
      }
    _ => env
  }
}

///|
/// A label inserted into a shape: its group, its box, and where the box
/// starts (`bbox.x - bbox.left`, zero for HTML labels).
priv struct InsertedLabel {
  label : @dom.Element
  bbox : LabelBox
  offset_x : Double
  offset_y : Double
}

///|
/// A label of its own in a shape: mermaid's `insertLabel`. The text is
/// markdown, and wraps at `width` or the flowchart's wrapping width.
fn insert_label(
  parent : @dom.Element,
  text : String,
  env : Env,
  width? : Double,
  style~ : String = "",
  center_label~ : Bool = false,
) -> InsertedLabel {
  let label = parent.append("g").attr("class", "label").attr("style", style)
  let width = match width {
    Some(width) if width != 0.0 && !width.is_nan() => width
    _ => env.config.number("flowchart.wrappingWidth").unwrap_or(200.0)
  }
  let n = @dom.number
  let (box, offset_x, offset_y) = if node_html_labels(env) {
    let (fo, box) = create_html_label(
      label,
      text,
      env,
      width~,
      style~,
      markdown=true,
    )
    fo.attr_number("width", box.width).attr_number("height", box.height)
    |> ignore
    label.attr(
      "transform",
      "translate(\{n(-box.width / 2.0)}, \{n(-box.height / 2.0)})",
    )
    |> ignore
    (box, 0.0, 0.0)
  } else {
    let text = create_svg_label(
      label,
      text,
      env,
      width~,
      style~,
      markdown=true,
      anchor_middle=false,
    )
    let box : LabelBox = {
      width: text.text_box.width,
      height: text.text_box.height,
    }
    label.attr("transform", "translate(0, \{n(-box.height / 2.0)})") |> ignore
    (box, text.text_box.x, text.text_box.y)
  }
  if center_label {
    label.attr(
      "transform",
      "translate(\{n(-box.width / 2.0)}, \{n(-box.height / 2.0)})",
    )
    |> ignore
  }
  label.insert_first("rect") |> ignore
  { label, bbox: box, offset_x, offset_y, }
}

///|
/// Centre a label's box on `x`, `y`: the `positionLabel` of the use case
/// shapes.
fn position_usecase_label(
  label : @dom.Element,
  box : LabelBox,
  offset_x : Double,
  offset_y : Double,
  x : Double,
  y : Double,
) -> Unit {
  let n = @dom.number
  label.attr(
    "transform",
    "translate(\{n(x - box.width / 2.0 - offset_x)},\{n(y - box.height / 2.0 - offset_y)})",
  )
  |> ignore
}

///|
/// The class an actor's glyph group carries for each variant.
fn actor_variant_class(variant : String) -> String {
  match variant {
    "normal" => "usecase-actor-shape usecase-actor-normal"
    "hollow" => "usecase-actor-hollow"
    "awesome" => "usecase-actor-awesome"
    _ => "usecase-actor-icon"
  }
}

///|
/// The slash across the head of a business actor, as path data:
/// `businessMarkerPathForCircle`.
fn business_marker_for_circle(center_y : Double, radius : Double) -> String {
  let angle = 3.141592653589793 / 3.0
  let offset_ratio = 0.6
  let center_offset = radius * offset_ratio
  // `ratio ** 2`, which is the product for a square.
  let half_chord = radius * (1.0 - offset_ratio * offset_ratio).sqrt()
  let direction_x = @jsmath.cos(angle)
  let direction_y = -@jsmath.sin(angle)
  let center_x = center_offset * -direction_y
  let marker_center_y = center_y + center_offset * direction_x
  let delta_x = half_chord * direction_x
  let delta_y = half_chord * direction_y
  let n = @dom.number
  "M \{n(center_x - delta_x)} \{n(marker_center_y - delta_y)} L \{n(center_x + delta_x)} \{n(marker_center_y + delta_y)}"
}

///|
fn business_marker_path(variant : String) -> String {
  match variant {
    "normal" => business_marker_for_circle(-24.0, 12.0)
    "hollow" => business_marker_for_circle(-23.0, 9.0)
    "awesome" => business_marker_for_circle(-21.0, 13.0)
    _ => "M 12 -8 L 26 -26"
  }
}

///|
const STICK_FIGURE_PATH : String = "M 0 -12 C 6.627 -12 12 -17.373 12 -24 C 12 -30.627 6.627 -36 0 -36 C -6.627 -36 -12 -30.627 -12 -24 C -12 -17.373 -6.627 -12 0 -12 Z M 0 -12 V 8 M -17 -5 H 17 M 0 8 L -15 28 M 0 8 L 15 28"

///|
const AWESOME_SILHOUETTE_PATH : String = "M 0 -34 C 7.18 -34 13 -28.18 13 -21 C 13 -13.82 7.18 -8 0 -8 C -7.18 -8 -13 -13.82 -13 -21 C -13 -28.18 -7.18 -34 0 -34 Z M -24 25 C -24 7 -14 -3 0 -3 C 14 -3 24 7 24 25 C 24 28 21 30 18 30 H -18 C -21 30 -24 28 -24 25 Z"

///|
const HOLLOW_BODY_PATH : String = "M -22 -10 H 22 V 0 H 6 L 22 17 L 13 28 L 0 13 L -13 28 L -22 17 L -6 0 H -22 Z"

///|
/// The figure of an actor, drawn into its glyph group.
fn draw_actor_glyph(group : @dom.Element, variant : String) -> Unit {
  match variant {
    "normal" =>
      group
      .append("path")
      .attr("class", "usecase-actor-stick")
      .attr("d", STICK_FIGURE_PATH)
      |> ignore
    "awesome" =>
      group
      .append("path")
      .attr("class", "usecase-actor-awesome-silhouette")
      .attr("d", AWESOME_SILHOUETTE_PATH)
      |> ignore
    "hollow" => {
      group
      .append("circle")
      .attr("class", "usecase-actor-hollow-head")
      .attr("cx", "0")
      .attr("cy", "-23")
      .attr("r", "9")
      .attr("fill", "none")
      |> ignore
      group
      .append("path")
      .attr("class", "usecase-actor-hollow-body")
      .attr("d", HOLLOW_BODY_PATH)
      .attr("fill", "none")
      |> ignore
    }
    _ => {
      group
      .append("rect")
      .attr("class", "usecase-actor-icon-frame")
      .attr("x", "-26")
      .attr("y", "-28")
      .attr("width", "52")
      .attr("height", "52")
      .attr("rx", "4")
      .attr("ry", "4")
      |> ignore
      // No icon pack is registered: every name draws the unknown icon, an
      // `<svg>` 42 pixels square, whose box is its viewport.
      let icon = group
        .append("g")
        .attr("class", "usecase-actor-icon-symbol usecase-actor-icon-fallback")
        .attr("aria-hidden", "true")
      let symbol = icon
        .append("g")
        .append("svg")
        .attr("xmlns", "http://www.w3.org/2000/svg")
        .attr("width", "42")
        .attr("height", "42")
        .attr("viewBox", "0 0 80 80")
        .append("g")
      symbol
      .append("rect")
      .attr("width", "80")
      .attr("height", "80")
      .attr("style", "fill: #087ebf; stroke-width: 0px;")
      |> ignore
      symbol
      .append("text")
      .attr("transform", "translate(21.16 64.67)")
      .attr(
        "style", "fill: #fff; font-family: ArialMT, Arial; font-size: 67.75px;",
      )
      .append("tspan")
      .attr("x", "0")
      .attr("y", "0")
      .text("?")
      |> ignore
      icon.attr("transform", "translate(-21,-23)") |> ignore
    }
  }
}

///|
/// An actor: a figure with its label below and the stereotype, if any,
/// between them. Mermaid's `renderUsecaseActor`.
fn usecase_actor(
  parent : @dom.Element,
  node : Node,
  env : Env,
  variant : String,
) -> @dom.Element raise LayoutError {
  guard node.data is Usecase(business~, stereotype~, ..) else {
    raise LayoutError("An actor without its data.")
  }
  let styles = shape_styles(node)
  // SVG text is measured before its group gets the class the stylesheet
  // sets the actor's type for: in the diagram's type.
  let labelled = label_helper(
    parent,
    node,
    node_classes(node) + "usecase-actor-variant usecase-actor-\{variant}",
    env,
  )
  let shape_svg = labelled.shape_svg
  if node.label != "" {
    shape_svg.attr("role", "img").attr("aria-label", node.label) |> ignore
  }
  labelled.label.attr("class", "label actor-label usecase-actor-label")
  |> ignore
  stamp_color_slot(shape_svg, node.color_index, env)
  // The stereotype is measured in the actor's type as HTML, and in the
  // diagram's as SVG text.
  let stereotype_label = match stereotype {
    Some(text) => {
      let inserted = insert_label(
        shape_svg,
        "«\{text}»",
        env,
        width?=node.wrapping_width,
        style=styles.label_styles,
        center_label=true,
      )
      inserted.label.attr("class", "label usecase-stereotype") |> ignore
      Some(inserted)
    }
    None => None
  }
  let actor_group = shape_svg
    .append("g")
    .attr("class", "usecase-actor-glyph \{actor_variant_class(variant)}")
  if styles.node_styles != "" {
    actor_group.attr("style", styles.node_styles) |> ignore
  }
  draw_actor_glyph(actor_group, variant)
  if business {
    actor_group
    .append("path")
    .attr("class", "usecase-business-marker usecase-actor-business-marker")
    .attr("d", business_marker_path(variant))
    .attr("fill", "none")
    .attr(
      "style", "stroke: inherit !important; stroke-width: inherit !important",
    )
    |> ignore
  }
  let label_box = labelled.bbox
  let padding = node.padding
  let figure_width = 56.0
  let figure_height = 72.0
  let label_gap = 8.0
  let stereotype_height = match stereotype_label {
    Some(inserted) => inserted.bbox.height
    None => 0.0
  }
  let content_height = figure_height +
    label_gap +
    label_box.height +
    (if stereotype_label is Some(_) { stereotype_height + 2.0 } else { 0.0 })
  let stereotype_width = match stereotype_label {
    Some(inserted) => inserted.bbox.width
    None => 0.0
  }
  let total_width = figure_width.max(label_box.width).max(stereotype_width) +
    padding * 2.0
  let total_height = content_height + padding * 2.0
  let content_top = -content_height / 2.0
  let n = @dom.number
  actor_group.attr(
    "transform",
    "translate(0,\{n(content_top + figure_height / 2.0)})",
  )
  |> ignore
  let mut next_label_center = content_top + figure_height + label_gap
  if stereotype_label is Some(inserted) {
    next_label_center += stereotype_height / 2.0
    position_usecase_label(
      inserted.label,
      inserted.bbox,
      inserted.offset_x,
      inserted.offset_y,
      0.0,
      next_label_center,
    )
    next_label_center += stereotype_height / 2.0 + 2.0
  }
  position_usecase_label(
    labelled.label,
    label_box,
    labelled.offset_x,
    labelled.offset_y,
    0.0,
    next_label_center + label_box.height / 2.0,
  )
  let outline = shape_svg
    .insert_first("rect")
    .attr("class", "usecase-actor-outline")
    .attr_number("x", -total_width / 2.0)
    .attr_number("y", -total_height / 2.0)
    .attr_number("width", total_width)
    .attr_number("height", total_height)
    .attr("opacity", "0")
    .attr("aria-hidden", "true")
  update_node_bounds(node, outline)
  node.intersect = Some(node_intersect_rect(node))
  shape_svg
}

///|
/// A use case: an ellipse around its label.
fn usecase_ellipse(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  stamp_color_slot(labelled.shape_svg, node.color_index, env)
  let padding = node.padding / 2.0
  let radius_x = labelled.bbox.width / 2.0 + padding * 2.0
  let radius_y = labelled.bbox.height / 2.0 + padding * 2.0
  let ellipse = labelled.shape_svg
    .insert_first("ellipse")
    .attr("class", "basic label-container")
    .attr("style", styles.node_styles)
    .attr_number("rx", radius_x)
    .attr_number("ry", radius_y)
    .attr("cx", "0")
    .attr("cy", "0")
  update_node_bounds(node, ellipse)
  node.intersect = Some(point => {
    intersect_ellipse(node, radius_x, radius_y, point)
  })
  labelled.shape_svg
}

///|
/// A business use case: an ellipse with a slash on its right, the
/// stereotype, if any, above the label.
fn usecase_business(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let stereotype = match node.data {
    Usecase(stereotype~, ..) => stereotype
    _ => None
  }
  let styles = shape_styles(node)
  let labelled = label_helper(
    parent,
    node,
    node_classes(node) + "usecase-business-shape",
    env,
  )
  labelled.label.attr("class", "label usecase-label") |> ignore
  let shape_svg = labelled.shape_svg
  stamp_color_slot(shape_svg, node.color_index, env)
  let stereotype_label = match stereotype {
    Some(text) => {
      let inserted = insert_label(
        shape_svg,
        "«\{text}»",
        env,
        width?=node.wrapping_width,
        style=styles.label_styles,
        center_label=true,
      )
      inserted.label.attr("class", "label usecase-stereotype") |> ignore
      Some(inserted)
    }
    None => None
  }
  let label_box = labelled.bbox
  let (stereotype_width, stereotype_height, gap) = match stereotype_label {
    Some(inserted) => (inserted.bbox.width, inserted.bbox.height, 2.0)
    None => (0.0, 0.0, 0.0)
  }
  let label_height = label_box.height + stereotype_height + gap
  let label_width = label_box.width.max(stereotype_width)
  let padding = node.padding / 2.0
  let radius_x = label_width / 2.0 + padding * 2.0
  let radius_y = label_height / 2.0 + padding * 2.0
  let marker_inset = (padding / 5.0).max(1.0).min(padding / 2.0)
  let marker_start_x = label_width / 2.0 + marker_inset
  let marker_end_x = radius_x - marker_inset
  let normalized_start_x = marker_start_x / radius_x
  let normalized_end_x = marker_end_x / radius_x
  let marker_start_y = radius_y *
    0.0.max(1.0 - normalized_start_x * normalized_start_x).sqrt()
  let marker_end_y = -radius_y *
    0.0.max(1.0 - normalized_end_x * normalized_end_x).sqrt()
  if stereotype_label is Some(inserted) {
    position_usecase_label(
      inserted.label,
      inserted.bbox,
      inserted.offset_x,
      inserted.offset_y,
      0.0,
      -label_height / 2.0 + inserted.bbox.height / 2.0,
    )
  }
  position_usecase_label(
    labelled.label,
    label_box,
    labelled.offset_x,
    labelled.offset_y,
    0.0,
    label_height / 2.0 - label_box.height / 2.0,
  )
  let ellipse = shape_svg
    .insert_first("ellipse")
    .attr("class", "basic label-container usecase-business-ellipse")
    .attr("style", styles.node_styles)
    .attr_number("rx", radius_x)
    .attr_number("ry", radius_y)
    .attr("cx", "0")
    .attr("cy", "0")
  let n = @dom.number
  let marker = shape_svg
    .append("path")
    .attr("class", "usecase-business-marker")
    .attr(
      "d",
      "M \{n(marker_start_x)} \{n(marker_start_y)} L \{n(marker_end_x)} \{n(marker_end_y)}",
    )
    .attr("fill", "none")
  if styles.node_styles != "" {
    marker.attr("style", styles.node_styles) |> ignore
  }
  if node.label != "" {
    shape_svg.attr("role", "img").attr("aria-label", node.label) |> ignore
  }
  update_node_bounds(node, ellipse)
  node.intersect = Some(point => {
    intersect_ellipse(node, radius_x, radius_y, point)
  })
  shape_svg
}

///|
/// A JSON object as a table: its id as the title, then a row of key and
/// value for every leaf.
fn usecase_json_table(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element {
  let rows = match node.data {
    Usecase(rows~, ..) => rows
    _ => []
  }
  let cell_padding_x = 8.0
  let cell_padding_y = 4.0
  let styles = shape_styles(node)
  let styles_map = styles_map([..node.css_compiled_styles, ..node.css_styles])
  let labelled = label_helper(
    parent,
    node,
    node_classes(node) + "usecase-json-table",
    env,
  )
  let shape_svg = labelled.shape_svg
  shape_svg.attr("role", "img") |> ignore
  labelled.label.attr("class", "label usecase-json-title") |> ignore
  let table_group = shape_svg
    .append("g")
    .attr("class", "usecase-json-table-grid")
  let measured = rows.map(row => {
    let key = insert_label(
      table_group,
      row.0,
      env,
      style=styles.label_styles,
      center_label=true,
    )
    let value = insert_label(
      table_group,
      row.1,
      env,
      style=styles.label_styles,
      center_label=true,
    )
    key.label.attr("class", "label usecase-json-key") |> ignore
    value.label.attr("class", "label usecase-json-value") |> ignore
    (key, value)
  })
  let key_width = measured.fold(init=0.0, (widest, row) => {
      widest.max(row.0.bbox.width)
    }) +
    cell_padding_x * 2.0
  let measured_value_width = measured.fold(init=0.0, (widest, row) => {
      widest.max(row.1.bbox.width)
    }) +
    cell_padding_x * 2.0
  let title_box = labelled.bbox
  let title_width = title_box.width + cell_padding_x * 2.0
  let inner_width = title_width.max(key_width + measured_value_width)
  let value_width = measured_value_width +
    0.0.max(inner_width - key_width - measured_value_width)
  let title_height = title_box.height + cell_padding_y * 2.0
  let row_heights = measured.map(row => {
    row.0.bbox.height.max(row.1.bbox.height) + cell_padding_y * 2.0
  })
  let inner_height = title_height +
    row_heights.fold(init=0.0, (sum, height) => sum + height)
  let border_width = match styles_map.get("stroke-width") {
    Some(value) => numeric_stroke_width(value)
    None => 1.0
  }
  let total_width = inner_width + border_width * 2.0
  let total_height = inner_height + border_width * 2.0
  let left = -inner_width / 2.0
  let top = -inner_height / 2.0
  let insert_cell = (
    container : @dom.Element,
    class_name : String,
    x : Double,
    y : Double,
    width : Double,
    height : Double,
  ) => {
    container
    .insert_first("rect")
    .attr("class", class_name)
    .attr_number("x", x)
    .attr_number("y", y)
    .attr_number("width", width)
    .attr_number("height", height)
    .attr("style", styles.node_styles)
  }
  let outer_border = insert_cell(
    shape_svg,
    "label-container usecase-json-border",
    -total_width / 2.0,
    -total_height / 2.0,
    total_width,
    total_height,
  )
  insert_cell(
    table_group, "usecase-json-cell usecase-json-title-cell", left, top, inner_width,
    title_height,
  )
  |> ignore
  table_group.append_child(labelled.label)
  position_usecase_label(
    labelled.label,
    title_box,
    labelled.offset_x,
    labelled.offset_y,
    0.0,
    top + title_height / 2.0,
  )
  let n = @dom.number
  let mut row_top = top + title_height
  for index, row in measured {
    let (key, value) = row
    let row_height = row_heights[index]
    let row_group = table_group
      .append("g")
      .attr("class", "usecase-json-row")
      .attr("data-row-index", index.to_string())
      .attr("transform", "translate(0,\{n(row_top)})")
    insert_cell(
      row_group, "usecase-json-cell usecase-json-key-cell", left, 0.0, key_width,
      row_height,
    )
    |> ignore
    insert_cell(
      row_group,
      "usecase-json-cell usecase-json-value-cell",
      left + key_width,
      0.0,
      value_width,
      row_height,
    )
    |> ignore
    row_group.append_child(key.label)
    row_group.append_child(value.label)
    position_usecase_label(
      key.label,
      key.bbox,
      key.offset_x,
      key.offset_y,
      left + key_width / 2.0,
      row_height / 2.0,
    )
    position_usecase_label(
      value.label,
      value.bbox,
      value.offset_x,
      value.offset_y,
      left + key_width + value_width / 2.0,
      row_height / 2.0,
    )
    row_top += row_height
  }
  update_node_bounds(node, outer_border)
  node.intersect = Some(node_intersect_rect(node))
  shape_svg
}

///|
/// `Number.parseFloat` of a stroke width, if it is a usable one:
/// `numericStrokeWidth`.
fn numeric_stroke_width(value : String) -> Double {
  let text = value.trim_start(chars=" \t\n\r").to_owned()
  let mut end = 0
  let mut seen_dot = false
  let mut seen_digit = false
  for c in text {
    if c is ('0'..<='9') {
      seen_digit = true
    } else if c == '.' && !seen_dot {
      seen_dot = true
    } else if c is ('+' | '-') && end == 0 {
      ()
    } else {
      break
    }
    end += 1
  }
  guard seen_digit else { return 1.0 }
  let parsed = @string.parse_double(text[:end].to_owned()) catch { _ => 1.0 }
  if parsed >= 0.0 && !parsed.is_inf() {
    parsed
  } else {
    1.0
  }
}

///|
/// Draw a node of a use case diagram.
fn usecase_shape(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  match node.shape {
    "usecaseActor" => usecase_actor(parent, node, env, "normal")
    "usecaseActorHollow" => usecase_actor(parent, node, env, "hollow")
    "usecaseActorAwesome" => usecase_actor(parent, node, env, "awesome")
    "usecaseActorIcon" => usecase_actor(parent, node, env, "icon")
    "usecaseBusiness" => usecase_business(parent, node, env)
    "usecaseJsonTable" => usecase_json_table(parent, node, env)
    _ => usecase_ellipse(parent, node, env)
  }
}
