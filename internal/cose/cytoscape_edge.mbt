// What cytoscape's renderer reports for an edge, which is where mermaid's
// cose-bilkent layout takes the route of an edge from
// (`edge._private.rscratch`). Mermaid styles no node, so every node is
// cytoscape's default one whatever its size in the diagram: an ellipse 30
// wide and high. The only edge between two nodes is drawn straight.

///|
/// Half the `width` and `height` of cytoscape's default node style.
let default_node_radius : Double = 30.0 / 2.0

///|
/// cytoscape's `intersectLineEllipse`: where the line from `(x, y)` to
/// the centre of a default node enters the node. `None` when the point is
/// inside it.
fn intersect_line_ellipse(
  x : Double,
  y : Double,
  center_x : Double,
  center_y : Double,
) -> (Double, Double)? {
  let mut disp_x = center_x - x
  let mut disp_y = center_y - y
  disp_x = disp_x / default_node_radius
  disp_y = disp_y / default_node_radius
  let len = (disp_x * disp_x + disp_y * disp_y).sqrt()
  let new_length = len - 1.0
  if new_length < 0.0 {
    return None
  }
  let len_proportion = new_length / len
  Some(
    ((center_x - x) * len_proportion + x, (center_y - y) * len_proportion + y),
  )
}

///|
/// cytoscape's `shortenIntersection` by nothing, as for an edge without
/// arrows: the point is rebuilt from `offset`, which is not always the
/// identity in floating point.
fn shorten_intersection(
  intersection : (Double, Double),
  offset : (Double, Double),
) -> (Double, Double) {
  let disp_x = intersection.0 - offset.0
  let disp_y = intersection.1 - offset.1
  let length = (disp_x * disp_x + disp_y * disp_y).sqrt()
  let mut len_ratio = (length - 0.0) / length
  if len_ratio < 0.0 {
    len_ratio = 1.0e-5
  }
  (offset.0 + len_ratio * disp_x, offset.1 + len_ratio * disp_y)
}

///|
/// The start, middle and end of the straight edge between two nodes
/// centred on `source` and `target`: cytoscape's `findEndpoints` and
/// `storeAllpts` for an edge of type "straight". `None` when the nodes
/// overlap as cytoscape sees them (the centres less than 15 apart); it
/// then reports no usable points.
pub fn straight_edge(
  source : (Double, Double),
  target : (Double, Double),
) -> Array[(Double, Double)]? {
  guard intersect_line_ellipse(source.0, source.1, target.0, target.1)
    is Some(at_target) else {
    return None
  }
  let end = shorten_intersection(at_target, source)
  guard intersect_line_ellipse(target.0, target.1, source.0, source.1)
    is Some(at_source) else {
    return None
  }
  let start = shorten_intersection(at_source, target)
  // The arrow ends coincide with the ends of the line.
  let mid = (
    (start.0 + end.0 + start.0 + end.0) / 4.0,
    (start.1 + end.1 + start.1 + end.1) / 4.0,
  )
  Some([start, mid, end])
}
