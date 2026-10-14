///|
/// How far from the centre of a node its links start: the radius of its
/// circle, or half the diagonal of the square of a pipeline's parent.
fn Scene::link_radius(self : Scene, node : Node) -> Double {
  if node.is_pipeline_parent {
    self.square_size / 2.0.sqrt()
  } else {
    self.settings.node_radius
  }
}

///|
/// The links between nodes: a line from rim to rim, and for those with a
/// label, the label along the middle of the line.
fn Scene::draw_links(self : Scene) -> Unit {
  let n = @dom.number
  let { map, colors, positions, id, .. } = self
  let group = self.root.append("g").attr("class", "wardley-links")
  // Links between nodes that exist, except those from a component of a
  // pipeline to the pipeline's parent.
  let valid : Array[(Link, Position, Position, Node, Node)] = []
  for link in map.links {
    guard positions.get(link.source) is Some(source) &&
      positions.get(link.target) is Some(target) &&
      map.node(link.source) is Some(source_node) &&
      map.node(link.target) is Some(target_node) else {
      continue
    }
    if map.pipelines.search_by(pipeline => pipeline.node_id == link.target)
      is Some(index) &&
      map.pipelines[index].component_ids.contains(link.source) {
      continue
    }
    valid.push((link, source, target, source_node, target_node))
  }
  for entry in valid {
    let (link, source, target, source_node, target_node) = entry
    let line = group
      .append("line")
      .attr(
        "class",
        if link.dashed {
          "wardley-link wardley-link--dashed"
        } else {
          "wardley-link"
        },
      )
    let radius = self.link_radius(source_node)
    let dx = target.x - source.x
    let dy = target.y - source.y
    let distance = (dx * dx + dy * dy).sqrt()
    line
    .attr("x1", n(source.x + dx / distance * radius))
    .attr("y1", n(source.y + dy / distance * radius))
    |> ignore
    let radius = self.link_radius(target_node)
    let dx = source.x - target.x
    let dy = source.y - target.y
    let distance = (dx * dx + dy * dy).sqrt()
    line
    .attr("x2", n(target.x + dx / distance * radius))
    .attr("y2", n(target.y + dy / distance * radius))
    .attr("stroke", colors.link_stroke)
    .attr("stroke-width", "1")
    |> ignore
    if link.dashed {
      line.attr("stroke-dasharray", "6 6") |> ignore
    }
    if link.flow is (Some(Forward) | Some(Bidirectional)) {
      line.attr("marker-end", "url(#link-arrow-end-\{id})") |> ignore
    }
    if link.flow is (Some(Backward) | Some(Bidirectional)) {
      line.attr("marker-start", "url(#link-arrow-start-\{id})") |> ignore
    }
  }
  for entry in valid {
    let (link, source, target, _, _) = entry
    guard link.label is Some(label) && label != "" else { continue }
    let mid_x = (source.x + target.x) / 2.0
    let mid_y = (source.y + target.y) / 2.0
    let dx = target.x - source.x
    let dy = target.y - source.y
    let distance = (dx * dx + dy * dy).sqrt()
    // The label stands 8 units off the line, on its left.
    let offset = 8.0
    let label_x = mid_x + dy / distance * offset
    let label_y = mid_y + -dx / distance * offset
    let mut angle = @jsmath.atan2(dy, dx) * 180.0 / PI
    // Text that would be upside down is turned around.
    if angle > 90.0 || angle < -90.0 {
      angle += 180.0
    }
    group
    .append("text")
    .attr("class", "wardley-link-label")
    .attr("x", n(label_x))
    .attr("y", n(label_y))
    .attr("fill", colors.axis_text)
    .attr("font-size", n(self.settings.label_font_size))
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "middle")
    .attr("transform", "rotate(\{n(angle)} \{n(label_x)} \{n(label_y)})")
    .text(label)
    |> ignore
  }
}

///|
/// The arrows of evolution: from a node to where it is heading, stopping
/// short of the place by the radius of a node and a little more.
fn Scene::draw_trends(self : Scene) -> Unit {
  let n = @dom.number
  let { map, colors, positions, id, .. } = self
  let group = self.root.append("g").attr("class", "wardley-trends")
  for trend in map.trends {
    guard positions.get(trend.node_id) is Some(origin) else { continue }
    let target_x = self.project_x(trend.target_x)
    let target_y = self.project_y(trend.target_y)
    let dx = target_x - origin.x
    let dy = target_y - origin.y
    let distance = (dx * dx + dy * dy).sqrt()
    let shorten_by = self.settings.node_radius + 2.0
    let (x2, y2) = if distance > shorten_by {
      (
        target_x - dx / distance * shorten_by,
        target_y - dy / distance * shorten_by,
      )
    } else {
      (target_x, target_y)
    }
    group
    .append("line")
    .attr("class", "wardley-trend")
    .attr("x1", n(origin.x))
    .attr("y1", n(origin.y))
    .attr("x2", n(x2))
    .attr("y2", n(y2))
    .attr("stroke", colors.evolution_stroke)
    .attr("stroke-width", "1")
    .attr("stroke-dasharray", "4 4")
    .attr("marker-end", "url(#arrow-\{id})")
    |> ignore
  }
}
