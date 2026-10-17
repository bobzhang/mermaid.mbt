// The part of cytoscape 3.34.0 the architecture renderer depends on: the
// graph it builds with mermaid's stylesheet, compound node bounds, bounding
// boxes (labels measured on a canvas included) and the endpoints and
// midpoints of straight and segmented edges with manual endpoints.

///|
/// A box: cytoscape's `{x1, y1, x2, y2, w, h}`.
priv struct Box {
  mut x1 : Double
  mut y1 : Double
  mut x2 : Double
  mut y2 : Double
  mut w : Double
  mut h : Double
}

///|
/// `makeBoundingBox`: an empty box.
fn Box::empty() -> Box {
  {
    x1: @double.infinity,
    y1: @double.infinity,
    x2: @double.neg_infinity,
    y2: @double.neg_infinity,
    w: 0.0,
    h: 0.0,
  }
}

///|
/// `updateBounds`: a box without width or height adds nothing.
fn Box::add(
  self : Box,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Unit {
  if x2 - x1 == 0.0 || y2 - y1 == 0.0 {
    return
  }
  // NaN coordinates compare false and leave the box as it is.
  self.x1 = if x1 < self.x1 { x1 } else { self.x1 }
  self.x2 = if x2 > self.x2 { x2 } else { self.x2 }
  self.y1 = if y1 < self.y1 { y1 } else { self.y1 }
  self.y2 = if y2 > self.y2 { y2 } else { self.y2 }
  self.w = self.x2 - self.x1
  self.h = self.y2 - self.y1
}

///|
/// `updateBoundsFromBox`.
fn Box::add_box(self : Box, other : Box) -> Unit {
  self.add(other.x1, other.y1, other.x2, other.y2)
}

///|
/// `expandBoundingBox`.
fn Box::expand(self : Box, padding : Double) -> Unit {
  self.x1 -= padding
  self.x2 += padding
  self.y1 -= padding
  self.y2 += padding
  self.w = self.x2 - self.x1
  self.h = self.y2 - self.y1
}

///|
/// What cytoscape keeps of an infinite edge: `noninf`.
fn noninf(x : Double) -> Double {
  if x == @double.infinity || x == @double.neg_infinity {
    0.0
  } else {
    x
  }
}

///|
/// What kind of node a cytoscape node is: mermaid's classes.
priv enum CyKind {
  /// A service or a junction.
  CyLeaf
  CyGroup
}

///|
/// A node of the cytoscape graph.
priv struct CyNode {
  id : String
  kind : CyKind
  parent : String?
  /// The children in the order they were added.
  children : Array[Int32]
  /// The text of the label (`label: data(label)` of `.node-service`).
  label : String
  /// The position: the centre. A compound node's follows its children.
  mut x : Double
  mut y : Double
  /// A compound node's size around its children, and its padding.
  mut auto_width : Double
  mut auto_height : Double
}

///|
/// A manual endpoint (`source-endpoint`/`target-endpoint`): the numbers
/// as written and whether each is a percentage.
priv struct Endpoint {
  values : (Double, Double)
  percent : (Bool, Bool)
}

///|
/// The endpoint mermaid gives a side: `"0 50%"` for the left one, ...
fn endpoint_of(side : Direction) -> Endpoint {
  match side {
    L => { values: (0.0, 0.5), percent: (false, true), }
    R => { values: (1.0, 0.5), percent: (true, true), }
    T => { values: (0.5, 0.0), percent: (true, false), }
    B => { values: (0.5, 1.0), percent: (true, true), }
  }
}

///|
/// An edge of the cytoscape graph.
priv struct CyEdge {
  id : String
  edge : Edge
  source : Int32
  target : Int32
  /// `curve-style: segments`, for edges that bend.
  segments : Bool
  mut weights : Double
  mut distances : Double
}

///|
/// Where an edge is drawn: what `rscratch` holds.
priv struct EdgeGeometry {
  start_x : Double
  start_y : Double
  end_x : Double
  end_y : Double
  mid_x : Double
  mid_y : Double
  /// The bend of a segmented edge.
  segment : (Double, Double)?
}

///|
/// The cytoscape graph mermaid builds, with what its stylesheet says.
priv struct Cy {
  nodes : Array[CyNode]
  by_id : Map[String, Int32]
  edges : Array[CyEdge]
  icon_size : Double
  font_size : Double
  /// The padding of groups, as written (`${padding}px`).
  padding : Double
}

///|
/// Whether a node is a compound node: a group with something in it.
fn Cy::is_parent(self : Cy, node : CyNode) -> Bool {
  ignore(self)
  !node.children.is_empty()
}

///|
/// The padding of a node: a group's, or none.
fn Cy::node_padding(self : Cy, node : CyNode) -> Double {
  match node.kind {
    CyGroup => self.padding
    _ => 0.0
  }
}

///|
/// `width()`: a compound node's size around its children; a group without
/// any has cytoscape's default size.
fn Cy::width(self : Cy, node : CyNode) -> Double {
  if self.is_parent(node) {
    node.auto_width
  } else {
    match node.kind {
      CyGroup => 30.0
      _ => self.icon_size
    }
  }
}

///|
/// `height()`.
fn Cy::height(self : Cy, node : CyNode) -> Double {
  if self.is_parent(node) {
    node.auto_height
  } else {
    match node.kind {
      CyGroup => 30.0
      _ => self.icon_size
    }
  }
}

///|
/// `outerWidth()`: compound nodes have a border of 1 (the default
/// stylesheet's) and the padding on either side.
fn Cy::outer_width(self : Cy, node : CyNode) -> Double {
  let border = if self.is_parent(node) { 1.0 } else { 0.0 }
  self.width(node) + border + 2.0 * self.node_padding(node)
}

///|
/// `outerHeight()`.
fn Cy::outer_height(self : Cy, node : CyNode) -> Double {
  let border = if self.is_parent(node) { 1.0 } else { 0.0 }
  self.height(node) + border + 2.0 * self.node_padding(node)
}

///|
/// The box of a label below a node, with cytoscape's margin of error; its
/// text measured on a canvas in Helvetica Neue.
fn Cy::node_label_box(self : Cy, node : CyNode) -> Box? raise ArchitectureError {
  guard node.label != "" else { return None }
  let width = canvas_text_width(node.label, self.font_size).ceil()
  let height = self.font_size
  // `text-valign: bottom`, `text-halign: center`.
  let label_x = node.x
  let label_y = node.y + self.height(node) / 2.0 + self.node_padding(node)
  let box = Box::empty()
  box.x1 = label_x - width / 2.0 + -2.0
  box.x2 = label_x + width / 2.0 + 2.0
  box.y1 = label_y + -2.0
  box.y2 = label_y + height + 2.0
  box.w = box.x2 - box.x1
  box.h = box.y2 - box.y1
  Some(box)
}

///|
/// The body of a node: its position, plus or minus half its outer size.
fn Cy::body(self : Cy, node : CyNode) -> Box {
  let half_w = self.outer_width(node) / 2.0
  let half_h = self.outer_height(node) / 2.0
  let box = Box::empty()
  box.add(node.x - half_w, node.y - half_h, node.x + half_w, node.y + half_h)
  box
}

///|
/// `updateCompoundBounds` of a compound node, after those of the compound
/// nodes inside it: the box of the children, labels included, centres it.
fn Cy::update_compound_bounds(
  self : Cy,
  node : CyNode,
) -> Unit raise ArchitectureError {
  guard self.is_parent(node) else { return }
  let box = Box::empty()
  for index in node.children {
    let child = self.nodes[index]
    self.update_compound_bounds(child)
    // The child's body (and label) without overlays, as its cache keeps
    // them: the body widened by 1.
    let body = self.body(child)
    body.expand(1.0)
    box.add_box(body)
    if self.node_label_box(child) is Some(label) {
      box.add_box(label)
    }
  }
  node.auto_width = box.w
  node.auto_height = box.h
  node.x = (-0.0 + box.x1 + box.x2 + 0.0) / 2.0
  node.y = (-0.0 + box.y1 + box.y2 + 0.0) / 2.0
}

///|
/// Every compound node's bounds, from the top.
fn Cy::update_all_compound_bounds(self : Cy) -> Unit raise ArchitectureError {
  for node in self.nodes {
    if node.parent is None {
      self.update_compound_bounds(node)
    }
  }
}

///|
/// The full bounding box of a node, as `boundingBox()` reports it.
fn Cy::node_box(self : Cy, node : CyNode) -> Box raise ArchitectureError {
  let box = self.body(node)
  if self.node_label_box(node) is Some(label) {
    box.add_box(label)
  }
  box.x1 = noninf(box.x1)
  box.y1 = noninf(box.y1)
  box.x2 = noninf(box.x2)
  box.y2 = noninf(box.y2)
  box.w = noninf(box.x2 - box.x1)
  box.h = noninf(box.y2 - box.y1)
  if box.w > 0.0 && box.h > 0.0 {
    box.expand(1.0)
  }
  box
}

///|
/// `manualEndptToPx`: a manual endpoint on a node.
fn Cy::endpoint_px(
  self : Cy,
  node : CyNode,
  endpoint : Endpoint,
) -> (Double, Double) {
  let (a, b) = endpoint.values
  let x = if endpoint.percent.0 { a * self.outer_width(node) } else { a }
  let y = if endpoint.percent.1 { b * self.outer_height(node) } else { b }
  (x + node.x, y + node.y)
}

///|
/// `shortenIntersection` by nothing: the point, as reached from `offset`.
fn shorten(
  intersection : (Double, Double),
  offset : (Double, Double),
) -> (Double, Double) {
  let disp_x = intersection.0 - offset.0
  let disp_y = intersection.1 - offset.1
  let length = (disp_x * disp_x + disp_y * disp_y).sqrt()
  let mut ratio = (length - 0.0) / length
  if ratio < 0.0 {
    ratio = 1.0e-5
  }
  (offset.0 + ratio * disp_x, offset.1 + ratio * disp_y)
}

///|
/// `findEdgeControlPoints` and `findEndpoints` for an edge between two
/// nodes with manual endpoints.
fn Cy::edge_geometry(self : Cy, edge : CyEdge) -> EdgeGeometry {
  let source = self.nodes[edge.source]
  let target = self.nodes[edge.target]
  let source_endpoint = endpoint_of(edge.edge.lhs_dir)
  let target_endpoint = endpoint_of(edge.edge.rhs_dir)
  let source_px = self.endpoint_px(source, source_endpoint)
  let target_px = self.endpoint_px(target, target_endpoint)
  if edge.segments {
    // `findSegmentsPoints` with `edge-distances: endpoints`.
    let (x1, y1) = source_px
    let (x2, y2) = target_px
    let dy = y2 - y1
    let dx = x2 - x1
    let l = (dx * dx + dy * dy).sqrt()
    let inverse_x = -dy / l
    let inverse_y = dx / l
    let w2 = edge.weights
    let w1 = 1.0 - w2
    let d = edge.distances
    let mid_x = x1 * w1 + x2 * w2
    let mid_y = y1 * w1 + y2 * w2
    let segment = (mid_x + inverse_x * d, mid_y + inverse_y * d)
    let (end_x, end_y) = shorten(target_px, segment)
    let (start_x, start_y) = shorten(source_px, segment)
    {
      start_x,
      start_y,
      end_x,
      end_y,
      mid_x: segment.0,
      mid_y: segment.1,
      segment: Some(segment),
    }
  } else {
    // The points the line is shortened towards are the other end's
    // position moved by the raw numbers of its endpoint.
    let (sa, sb) = source_endpoint.values
    let (ta, tb) = target_endpoint.values
    let towards_target = (source.x + sa, source.y + sb)
    let towards_source = (target.x + ta, target.y + tb)
    let (end_x, end_y) = shorten(target_px, towards_target)
    let (start_x, start_y) = shorten(source_px, towards_source)
    {
      start_x,
      start_y,
      end_x,
      end_y,
      mid_x: (start_x + end_x + start_x + end_x) / 4.0,
      mid_y: (start_y + end_y + start_y + end_y) / 4.0,
      segment: None,
    }
  }
}

///|
/// The full bounding box of an edge: its points widened by half its width
/// (3), and its label.
fn Cy::edge_box(self : Cy, edge : CyEdge) -> Box raise ArchitectureError {
  let geometry = self.edge_geometry(edge)
  let half = 1.5
  let box = Box::empty()
  let min3 = (a : Double, b : Double, c : Double) => js_min(js_min(a, b), c)
  let max3 = (a : Double, b : Double, c : Double) => js_max(js_max(a, b), c)
  box.add(
    min3(geometry.start_x, geometry.mid_x, geometry.end_x) - half,
    min3(geometry.start_y, geometry.mid_y, geometry.end_y) - half,
    max3(geometry.start_x, geometry.mid_x, geometry.end_x) + half,
    max3(geometry.start_y, geometry.mid_y, geometry.end_y) + half,
  )
  if geometry.segment is Some(_) {
    // `linePts`: the start, the bend and the end.
    let points = [
      (geometry.start_x, geometry.start_y),
      geometry.segment.unwrap(),
      (geometry.end_x, geometry.end_y),
    ]
    for point in points {
      box.add(point.0 - half, point.1 - half, point.0 + half, point.1 + half)
    }
  }
  if edge.edge.title is Some(label) && label != "" {
    let width = canvas_text_width(label, 16.0).ceil()
    let height = 16.0
    box.add(
      geometry.mid_x - width / 2.0 + -2.0,
      geometry.mid_y - height / 2.0 + -2.0,
      geometry.mid_x + width / 2.0 + 2.0,
      geometry.mid_y + height / 2.0 + 2.0,
    )
  }
  box.x1 = noninf(box.x1)
  box.y1 = noninf(box.y1)
  box.x2 = noninf(box.x2)
  box.y2 = noninf(box.y2)
  box.w = noninf(box.x2 - box.x1)
  box.h = noninf(box.y2 - box.y1)
  if box.w > 0.0 && box.h > 0.0 {
    box.expand(1.0)
  }
  box
}

///|
/// `cy.elements().boundingBox()`: every node and edge.
fn Cy::bounding_box(self : Cy) -> Box raise ArchitectureError {
  self.update_all_compound_bounds()
  let box = Box::empty()
  for node in self.nodes {
    box.add_box(self.node_box(node))
  }
  for edge in self.edges {
    box.add_box(self.edge_box(edge))
  }
  box.x1 = noninf(box.x1)
  box.y1 = noninf(box.y1)
  box.x2 = noninf(box.x2)
  box.y2 = noninf(box.y2)
  box.w = noninf(box.x2 - box.x1)
  box.h = noninf(box.y2 - box.y1)
  box
}

///|
/// `Math.min` of two numbers.
fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a == 0.0 && 1.0 / a < 0.0 {
    a
  } else {
    b
  }
}

///|
/// `Math.max` of two numbers.
fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a == 0.0 && 1.0 / a > 0.0 {
    a
  } else {
    b
  }
}
