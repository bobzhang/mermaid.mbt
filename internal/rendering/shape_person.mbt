///|
/// A person, as in C4 model notation: a circular head above a body with
/// round corners.
fn person(parent : @dom.Element, node : Node, env : Env) -> @dom.Element {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let padding = node.padding
  let w = (box.width + padding * 2.0).max(node.width.unwrap_or(0.0)).max(100.0)
  // Proportions of the c4model.com person: the head's radius is 0.23 of
  // the body's width and overlaps the body by 0.27 of itself; the body's
  // corners are 0.177 of the width. A body widened by a long label keeps
  // a head of a person's size.
  let head_radius = (w * 0.23).max(16.0).min(56.0)
  let overlap = head_radius * 0.27
  let body_height = (box.height + padding * 2.0).max(
    match node.height {
      Some(height) if height != 0.0 => height - (2.0 * head_radius - overlap)
      _ => 0.0
    },
  )
  let body_radius = (w * 0.177).min(body_height * 0.45)
  let total_height = body_height + 2.0 * head_radius - overlap
  let top = -total_height / 2.0
  let body_top = top + 2.0 * head_radius - overlap
  let group = labelled.shape_svg
    .insert_first("g")
    .attr("class", "basic label-container")
  if hand_drawn(node) {
    sketch_person(
      group, node, env, w, body_top, body_height, body_radius, top, head_radius,
    )
  } else {
    // The body first, the head on top of it so that the whole circle shows.
    group
    .append("rect")
    .attr_number("x", -w / 2.0)
    .attr_number("y", body_top)
    .attr_number("width", w)
    .attr_number("height", body_height)
    .attr_number("rx", body_radius)
    .attr_number("ry", body_radius)
    .attr("style", styles.node_styles)
    |> ignore
    group
    .append("circle")
    .attr("cx", "0")
    .attr_number("cy", top + head_radius)
    .attr_number("r", head_radius)
    .attr("style", styles.node_styles)
    |> ignore
  }
  update_node_bounds(node, group)
  let body_centre = body_top + body_height / 2.0
  place_label(labelled, -(box.width / 2.0), body_centre - box.height / 2.0)
  // Edges meet the silhouette: the arc of the head that shows, joined to
  // the outline of the body.
  let head_centre = top + head_radius
  let pi = 3.141592653589793
  let phi = @jsmath.asin(((body_top - head_centre) / head_radius).min(1.0)) *
    180.0 /
    pi
  let outline = [
    ..circle_points(0.0, -head_centre, head_radius, 24, 180.0 + phi, -phi),
    ..circle_points(
      -(-w / 2.0 + body_radius),
      -(body_top + body_radius),
      body_radius,
      12,
      90.0,
      0.0,
    ),
    ..circle_points(
      -(-w / 2.0 + body_radius),
      -(total_height / 2.0 - body_radius),
      body_radius,
      12,
      360.0,
      270.0,
    ),
    ..circle_points(
      -(w / 2.0 - body_radius),
      -(total_height / 2.0 - body_radius),
      body_radius,
      12,
      270.0,
      180.0,
    ),
    ..circle_points(
      -(w / 2.0 - body_radius),
      -(body_top + body_radius),
      body_radius,
      12,
      180.0,
      90.0,
    ),
  ]
  node.intersect = Some(point => intersect_polygon(node, outline, point))
  labelled.shape_svg
}
