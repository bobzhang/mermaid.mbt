// Curly braces around a comment.

///|
/// A comment with a curly brace on its left, on its right, or on both
/// sides. The braces are open paths; an invisible outline around brace
/// and text gives the node its box.
fn curly_brace(
  parent : @dom.Element,
  node : Node,
  env : Env,
  handler : String,
) -> @dom.Element raise LayoutError {
  let styles = shape_styles(node)
  let labelled = label_helper(parent, node, node_classes(node), env)
  let box = labelled.bbox
  let neo = node.look == "neo"
  let padding_x = if neo { 18.0 } else { node.padding }
  let padding_y = if neo { 12.0 } else { node.padding }
  // Only the left brace keeps the padding single in the neo look.
  let doubled = neo && handler != "curlyBraceLeft"
  let w = box.width + (if doubled { padding_x * 2.0 } else { padding_x })
  let h = box.height + (if doubled { padding_y * 2.0 } else { padding_y })
  let radius = 5.0.max(h * 0.1)
  // The left brace's arcs are mirrored through the origin, the right
  // brace's are not.
  let arc = (
    cx : Double,
    cy : Double,
    count : Int32,
    start : Double,
    end : Double,
  ) => {
    circle_points(
      cx,
      cy,
      radius,
      count,
      start,
      end,
      mirrored=handler != "curlyBraceRight",
    )
  }
  let left_brace = () => {
    [
      ..arc(w / 2.0, -h / 2.0, 30, -90.0, 0.0),
      { x: -w / 2.0 - radius, y: radius, },
      ..arc(w / 2.0 + radius * 2.0, -radius, 20, -180.0, -270.0),
      ..arc(w / 2.0 + radius * 2.0, radius, 20, -90.0, -180.0),
      { x: -w / 2.0 - radius, y: -h / 2.0, },
      ..arc(w / 2.0, h / 2.0, 20, 0.0, 90.0),
    ]
  }
  // The right brace as the pair draws it, with mirrored arcs.
  let paired_right_brace = () => {
    [
      ..arc(-w / 2.0 + radius + radius / 2.0, -h / 2.0, 20, -90.0, -180.0),
      { x: w / 2.0 - radius / 2.0, y: radius, },
      ..arc(-w / 2.0 - radius / 2.0, -radius, 20, 0.0, 90.0),
      ..arc(-w / 2.0 - radius / 2.0, radius, 20, -90.0, 0.0),
      { x: w / 2.0 - radius / 2.0, y: -radius, },
      ..arc(-w / 2.0 + radius + radius / 2.0, h / 2.0, 30, -180.0, -270.0),
    ]
  }
  let (braces, outline, shift, label_x) = match handler {
    "curlyBraceLeft" =>
      (
        [left_brace()],
        [
          { x: w / 2.0, y: -h / 2.0 - radius, },
          { x: -w / 2.0, y: -h / 2.0 - radius, },
          ..arc(w / 2.0, -h / 2.0, 20, -90.0, 0.0),
          { x: -w / 2.0 - radius, y: -radius, },
          ..arc(w / 2.0 + w * 0.1, -radius, 20, -180.0, -270.0),
          ..arc(w / 2.0 + w * 0.1, radius, 20, -90.0, -180.0),
          { x: -w / 2.0 - radius, y: h / 2.0, },
          ..arc(w / 2.0, h / 2.0, 20, 0.0, 90.0),
          { x: -w / 2.0, y: h / 2.0 + radius, },
          { x: w / 2.0, y: h / 2.0 + radius, },
        ],
        radius,
        -w / 2.0 + radius,
      )
    "curlyBraceRight" => {
      let brace = [
        ..arc(w / 2.0, -h / 2.0, 20, -90.0, 0.0),
        { x: w / 2.0 + radius, y: -radius, },
        ..arc(w / 2.0 + radius * 2.0, -radius, 20, -180.0, -270.0),
        ..arc(w / 2.0 + radius * 2.0, radius, 20, -90.0, -180.0),
        { x: w / 2.0 + radius, y: h / 2.0, },
        ..arc(w / 2.0, h / 2.0, 20, 0.0, 90.0),
      ]
      (
        [brace],
        [
          { x: -w / 2.0, y: -h / 2.0 - radius, },
          { x: w / 2.0, y: -h / 2.0 - radius, },
          ..brace,
          { x: w / 2.0, y: h / 2.0 + radius, },
          { x: -w / 2.0, y: h / 2.0 + radius, },
        ],
        -radius,
        -w / 2.0 + node.padding / 2.0,
      )
    }
    _ =>
      (
        [left_brace(), paired_right_brace()],
        [
          { x: w / 2.0, y: -h / 2.0 - radius, },
          { x: -w / 2.0, y: -h / 2.0 - radius, },
          ..arc(w / 2.0, -h / 2.0, 20, -90.0, 0.0),
          { x: -w / 2.0 - radius, y: -radius, },
          ..arc(w / 2.0 + radius * 2.0, -radius, 20, -180.0, -270.0),
          ..arc(w / 2.0 + radius * 2.0, radius, 20, -90.0, -180.0),
          { x: -w / 2.0 - radius, y: h / 2.0, },
          ..arc(w / 2.0, h / 2.0, 20, 0.0, 90.0),
          { x: -w / 2.0, y: h / 2.0 + radius, },
          { x: w / 2.0 - radius - radius / 2.0, y: h / 2.0 + radius, },
          ..paired_right_brace(),
        ],
        radius - radius / 4.0,
        -w / 2.0 + node.padding / 2.0,
      )
  }
  let options = rough_options(node, env)
  options.fill = "none"
  let group = labelled.shape_svg.insert_first("g")
  let frame = @rough.path(path_from_points(outline), options)
  group.append_child(frame)
  frame.attr("stroke-opacity", "0") |> ignore
  // Each brace goes in front of what is there, so the last comes first.
  for brace in braces {
    // An open path: without the closing `Z`.
    let open_path = path_from_points(brace).replace(old="Z", new="")
    prepend(group, @rough.path(open_path, options))
  }
  group.attr("class", "text") |> ignore
  style_rough_paths(group, node, styles)
  let n = @dom.number
  group.attr("transform", "translate(\{n(shift)}, 0)") |> ignore
  place_label_tight(labelled, label_x, -h / 2.0 + node.padding / 2.0)
  update_node_bounds(node, group)
  node.intersect = Some(point => intersect_polygon(node, outline, point))
  labelled.shape_svg
}
