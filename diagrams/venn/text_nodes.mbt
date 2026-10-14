///|
/// `Math.min` of several numbers.
fn js_min_of(values : Array[Double]) -> Double {
  let mut min = @double.infinity
  for value in values {
    min = js_min(min, value)
  }
  min
}

///|
/// Upstream's `renderTextNodes`: the texts of each area in a grid inside
/// the largest circle around the place of the area's label, each in a
/// `<foreignObject>` so that the browser wraps it.
fn draw_text_nodes(
  venn : Venn,
  settings : Settings,
  layout : Solution,
  render_sets : Array[Area],
  dummy_svg : @dom.Element,
  scale : Double,
  styles : Map[String, Map[String, String]],
) -> Unit raise VennError {
  let n = @dom.number
  // The areas of the second layout by their sets; of two with the same
  // sets the later one.
  let layout_by_key : Map[String, Area] = Map([])
  for area in render_sets {
    layout_by_key[sorted_copy(area.sets).join("|")] = area
  }
  let text_group = dummy_svg.append("g").attr("class", "venn-text-nodes")
  let nodes_by_area : Map[String, Array[TextNode]] = Map([])
  for node in venn.text_nodes {
    let key = node.sets.join("|")
    match nodes_by_area.get(key) {
      Some(nodes) => nodes.push(node)
      None => nodes_by_area[key] = [node]
    }
  }
  for key, nodes in nodes_by_area {
    guard layout_by_key.get(key) is Some(area) &&
      layout.text_centres.get(area.key()) is Some(centre) else {
      continue
    }
    let circles = area.sets.map(set => circle_of(layout.circles, set))
    let center_x = centre.x
    let center_y = centre.y
    // The radius of the largest circle around the centre inside the
    // area's circles.
    let min_circle_radius = js_min_of(circles.map(c => c.radius))
    let inner_radius_raw = js_min_of(
      circles.map(c => c.radius - @jsmath.hypot(center_x - c.x, center_y - c.y)),
    )
    let is_finite = (value : Double) => !value.is_nan() && !value.is_inf()
    let mut inner_radius = if is_finite(inner_radius_raw) {
      js_max(0.0, inner_radius_raw)
    } else {
      0.0
    }
    if inner_radius == 0.0 && is_finite(min_circle_radius) {
      inner_radius = min_circle_radius * 0.6
    }
    let area_group = text_group
      .append("g")
      .attr("class", "venn-text-area")
      .attr("font-size", "\{n(40.0 * scale)}px")
    if settings.use_debug_layout {
      area_group
      .append("circle")
      .attr("class", "venn-text-debug-circle")
      .attr("cx", n(center_x))
      .attr("cy", n(center_y))
      .attr("r", n(inner_radius))
      .attr("fill", "none")
      .attr("stroke", "purple")
      .attr("stroke-width", n(1.5 * scale))
      .attr("stroke-dasharray", "\{n(6.0 * scale)} \{n(4.0 * scale)}")
      |> ignore
    }
    let inner_width = js_max(80.0 * scale, inner_radius * 2.0 * 0.95)
    let inner_height = js_max(60.0 * scale, inner_radius * 2.0 * 0.95)
    let has_label = area.label is Some(label) && label != ""
    let label_offset_base = if has_label {
      js_min(32.0 * scale, inner_radius * 0.25)
    } else {
      0.0
    }
    let count = nodes.length().to_double()
    let label_offset = label_offset_base +
      (if nodes.length() <= 2 { 30.0 * scale } else { 0.0 })
    let start_x = center_x - inner_width / 2.0
    let start_y = center_y - inner_height / 2.0 + label_offset
    let cols = js_max(1.0, count.sqrt().ceil())
    let rows = js_max(1.0, (count / cols).ceil())
    let cell_width = inner_width / cols
    let cell_height = inner_height / rows
    for i, node in nodes {
      let col = (i % cols.to_int()).to_double()
      let row = (i.to_double() / cols).floor()
      let x = start_x + cell_width * (col + 0.5)
      let y = start_y + cell_height * (row + 0.5)
      if settings.use_debug_layout {
        area_group
        .append("rect")
        .attr("class", "venn-text-debug-cell")
        .attr("x", n(start_x + cell_width * col))
        .attr("y", n(start_y + cell_height * row))
        .attr("width", n(cell_width))
        .attr("height", n(cell_height))
        .attr("fill", "none")
        .attr("stroke", "teal")
        .attr("stroke-width", n(1.0 * scale))
        .attr("stroke-dasharray", "\{n(4.0 * scale)} \{n(3.0 * scale)}")
        |> ignore
      }
      let box_width = cell_width * 0.9
      let box_height = cell_height * 0.9
      let container = area_group
        .append("foreignObject")
        .attr("class", "venn-text-node-fo")
        .attr("width", n(box_width))
        .attr("height", n(box_height))
        .attr("x", n(x - box_width / 2.0))
        .attr("y", n(y - box_height / 2.0))
        .attr("overflow", "visible")
      let text = container
        .append("span")
        .attr("class", "venn-text-node")
        .attr("xmlns", "http://www.w3.org/1999/xhtml")
        .style("display", "flex")
        .style("width", "100%")
        .style("height", "100%")
        .style("white-space", "normal")
        .style("align-items", "center")
        .style("justify-content", "center")
        .style("text-align", "center")
        .style("overflow-wrap", "normal")
        .style("word-break", "normal")
        .text(node.label.unwrap_or(node.id))
      if style_color(styles.get(node.id), "color") is Some(color) {
        text.style("color", color) |> ignore
      }
    }
  }
}
