///|
/// The nodes: per node a group holding, from back to front, the disc of
/// its sourcing strategy, its own circle or square, the bar that marks
/// inertia, and its label.
fn Scene::draw_nodes(self : Scene) -> Unit {
  let n = @dom.number
  let { map, colors, positions, square_size, .. } = self
  let radius = self.settings.node_radius
  let nodes = self.root.append("g").attr("class", "wardley-nodes")
  // The market symbol: three small circles on the corners of a triangle.
  let small_radius = radius * 0.7
  let triangle_radius = radius * 1.2
  let cos30 = @jsmath.cos(PI / 6.0)
  let sin30 = @jsmath.sin(PI / 6.0)
  for node in map.nodes {
    guard positions.get(node.id) is Some(position) else { continue }
    let { x, y, } = position
    let group = nodes
      .append("g")
      .attr(
        "class",
        if node.class_name == "" {
          "wardley-node"
        } else {
          "wardley-node wardley-node--\{node.class_name}"
        },
      )
    let overlay = (class_name : String, fill : String, stroke : String) => {
      group
      .append("circle")
      .attr("class", class_name)
      .attr("cx", n(x))
      .attr("cy", n(y))
      .attr("r", n(radius * 2.0))
      .attr("fill", fill)
      .attr("stroke", stroke)
      .attr("stroke-width", "1")
      |> ignore
    }
    let market = node.source_strategy == Some("market")
    match node.source_strategy {
      Some("outsource") =>
        overlay("wardley-outsource-overlay", "#666", colors.component_stroke)
      Some("buy") =>
        overlay("wardley-buy-overlay", "#ccc", colors.component_stroke)
      Some("build") => overlay("wardley-build-overlay", "#eee", "#000")
      Some("market") =>
        overlay("wardley-market-overlay", "white", colors.component_stroke)
      _ => ()
    }
    if !node.is_pipeline_parent && !market && node.class_name != "anchor" {
      group
      .append("circle")
      .attr("cx", n(x))
      .attr("cy", n(y))
      .attr("r", n(radius))
      .attr("fill", colors.component_fill)
      .attr("stroke", colors.component_stroke)
      .attr("stroke-width", "1")
      |> ignore
    }
    if market {
      let top = (x, y - triangle_radius)
      let left = (x - triangle_radius * cos30, y + triangle_radius * sin30)
      let right = (x + triangle_radius * cos30, y + triangle_radius * sin30)
      // The sides of the triangle first, so that the circles cover
      // their ends.
      for side in [(top, left), (left, right), (right, top)] {
        let (from, to) = side
        group
        .append("line")
        .attr("class", "wardley-market-line")
        .attr("x1", n(from.0))
        .attr("y1", n(from.1))
        .attr("x2", n(to.0))
        .attr("y2", n(to.1))
        .attr("stroke", colors.component_stroke)
        .attr("stroke-width", "1")
        |> ignore
      }
      for corner in [top, left, right] {
        group
        .append("circle")
        .attr("class", "wardley-market-dot")
        .attr("cx", n(corner.0))
        .attr("cy", n(corner.1))
        .attr("r", n(small_radius))
        .attr("fill", "white")
        .attr("stroke", colors.component_stroke)
        .attr("stroke-width", "2")
        |> ignore
      }
    }
    if node.is_pipeline_parent {
      group
      .append("rect")
      .attr("x", n(x - square_size / 2.0))
      .attr("y", n(y - square_size / 2.0))
      .attr("width", n(square_size))
      .attr("height", n(square_size))
      .attr("fill", colors.component_fill)
      .attr("stroke", colors.component_stroke)
      .attr("stroke-width", "1")
      |> ignore
    }
    if node.inertia {
      // A thick bar to the right of the node, further out when the node
      // has the disc of a sourcing strategy around it.
      let mut offset = if node.is_pipeline_parent {
        square_size / 2.0 + 15.0
      } else {
        radius + 15.0
      }
      if node.source_strategy is Some(_) {
        offset += radius + 10.0
      }
      let line_height = if node.is_pipeline_parent {
        square_size
      } else {
        radius * 2.0
      }
      group
      .append("line")
      .attr("class", "wardley-inertia")
      .attr("x1", n(x + offset))
      .attr("y1", n(y - line_height / 2.0))
      .attr("x2", n(x + offset))
      .attr("y2", n(y + line_height / 2.0))
      .attr("stroke", colors.component_stroke)
      .attr("stroke-width", "6")
      |> ignore
    }
    let anchor = node.class_name == "anchor"
    // An anchor's label is centred on its place; any other label goes up
    // and to the right, further when a strategy's disc is in the way.
    let label_x = if anchor {
      match node.label_offset_x {
        Some(offset) => x + offset
        None => x
      }
    } else {
      let mut default_offset = self.settings.node_label_offset
      if node.source_strategy is Some(_) && node.label_offset_x is None {
        default_offset += 10.0
      }
      x + node.label_offset_x.unwrap_or(default_offset)
    }
    let label_y = if anchor {
      match node.label_offset_y {
        Some(offset) => y + offset
        None => y - 3.0
      }
    } else {
      let mut default_offset = -self.settings.node_label_offset
      if node.source_strategy is Some(_) && node.label_offset_y is None {
        default_offset -= 10.0
      }
      y + node.label_offset_y.unwrap_or(default_offset)
    }
    group
    .append("text")
    .attr("x", n(label_x))
    .attr("y", n(label_y))
    .attr("class", "wardley-node-label")
    .attr(
      "fill",
      if node.class_name == "evolved" {
        colors.evolution_stroke
      } else if anchor {
        "#000"
      } else {
        colors.component_label
      },
    )
    .attr("font-size", n(self.settings.label_font_size))
    .attr("font-weight", if anchor { "bold" } else { "normal" })
    .attr("text-anchor", if anchor { "middle" } else { "start" })
    .attr("dominant-baseline", if anchor { "middle" } else { "auto" })
    .text(node.label)
    |> ignore
  }
}
