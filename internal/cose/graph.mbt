// The graph the layout works on: layout-base's `RectangleD`, `LNode` and
// `LEdge` with the fields of their force-directed subclasses, for a graph
// without compound nodes.

///|
/// A rectangle by its top left corner: `RectangleD`.
priv struct Rect {
  mut x : Double
  mut y : Double
  width : Double
  height : Double
}

///|
fn Rect::right(self : Rect) -> Double {
  self.x + self.width
}

///|
fn Rect::bottom(self : Rect) -> Double {
  self.y + self.height
}

///|
fn Rect::center_x(self : Rect) -> Double {
  self.x + self.width / 2.0
}

///|
fn Rect::center_y(self : Rect) -> Double {
  self.y + self.height / 2.0
}

///|
/// Whether the rectangles touch or overlap.
fn Rect::intersects(self : Rect, other : Rect) -> Bool {
  !(self.right() < other.x ||
  self.bottom() < other.y ||
  other.right() < self.x ||
  other.bottom() < self.y)
}

///|
/// A node: `CoSENode`.
priv struct LNode {
  /// The position among the nodes of the graph.
  index : Int32
  rect : Rect
  /// The incident edges in the order they were added.
  edges : Array[LEdge]
  mut estimated_size : Double
  mut spring_force_x : Double
  mut spring_force_y : Double
  mut repulsion_force_x : Double
  mut repulsion_force_y : Double
  mut gravitation_force_x : Double
  mut gravitation_force_y : Double
  /// The cells of the repulsion grid the node covers.
  mut start_x : Int32
  mut finish_x : Int32
  mut start_y : Int32
  mut finish_y : Int32
  /// The nodes close enough to repel this one, as of the last time the
  /// grid was rebuilt.
  mut surrounding : Array[LNode]
}

///|
/// An edge: `CoSEEdge`.
priv struct LEdge {
  source : LNode
  target : LNode
  mut ideal_length : Double
  /// The vector between the points where the line between the centres
  /// leaves the two rectangles, and its length.
  mut length_x : Double
  mut length_y : Double
  mut length : Double
  mut is_overlapping_source_and_target : Bool
}

///|
fn LNode::new(index : Int32, width : Double, height : Double) -> LNode {
  // cytoscape-cose-bilkent's `processChildrenList`: the node is centred on
  // the position cytoscape has for it, which is the origin for every node
  // mermaid adds.
  {
    index,
    rect: { x: 0.0 - width / 2.0, y: 0.0 - height / 2.0, width, height, },
    edges: [],
    estimated_size: integer_min,
    spring_force_x: 0.0,
    spring_force_y: 0.0,
    repulsion_force_x: 0.0,
    repulsion_force_y: 0.0,
    gravitation_force_x: 0.0,
    gravitation_force_y: 0.0,
    start_x: 0,
    finish_x: 0,
    start_y: 0,
    finish_y: 0,
    surrounding: [],
  }
}

///|
fn LNode::center_x(self : LNode) -> Double {
  self.rect.center_x()
}

///|
fn LNode::center_y(self : LNode) -> Double {
  self.rect.center_y()
}

///|
fn LNode::set_center(self : LNode, cx : Double, cy : Double) -> Unit {
  self.rect.x = cx - self.rect.width / 2.0
  self.rect.y = cy - self.rect.height / 2.0
}

///|
fn LNode::diagonal(self : LNode) -> Double {
  (self.rect.width * self.rect.width + self.rect.height * self.rect.height).sqrt()
}

///|
/// `LEdge.getOtherEnd`.
fn LEdge::other_end(self : LEdge, node : LNode) -> LNode {
  if physical_equal(self.source, node) {
    self.target
  } else {
    self.source
  }
}

///|
/// `LNode.getEdgesBetween`: the edges that join the node with `other`.
fn LNode::edges_between(self : LNode, other : LNode) -> Array[LEdge] {
  self.edges.filter(edge => {
    physical_equal(edge.target, other) || physical_equal(edge.source, other)
  })
}

///|
/// A shift of the plane: `Transform` with its extents left at 1, which
/// is all the layout uses. `inverseTransformPoint` takes a point from
/// device to world coordinates.
priv struct Transform {
  world_org_x : Double
  world_org_y : Double
  device_org_x : Double
  device_org_y : Double
}

///|
/// `LNode.transform`: move the node's corner from device to world
/// coordinates.
fn LNode::transform(self : LNode, trans : Transform) -> Unit {
  let mut left = self.rect.x
  if left > world_boundary {
    left = world_boundary
  } else if left < -world_boundary {
    left = -world_boundary
  }
  let mut top = self.rect.y
  if top > world_boundary {
    top = world_boundary
  } else if top < -world_boundary {
    top = -world_boundary
  }
  self.rect.x = trans.inverse_x(left)
  self.rect.y = trans.inverse_y(top)
}

///|
fn Transform::inverse_x(self : Transform, x : Double) -> Double {
  self.world_org_x + (x - self.device_org_x) * 1.0 / 1.0
}

///|
fn Transform::inverse_y(self : Transform, y : Double) -> Double {
  self.world_org_y + (y - self.device_org_y) * 1.0 / 1.0
}

///|
/// `LGraph.calculateBounds`: the bounding rectangle of `nodes`.
fn calculate_bounds(nodes : Array[LNode]) -> Rect {
  let mut left = integer_max
  let mut right = -integer_max
  let mut top = integer_max
  let mut bottom = -integer_max
  for node in nodes {
    let node_left = node.rect.x
    let node_right = node.rect.right()
    let node_top = node.rect.y
    let node_bottom = node.rect.bottom()
    if left > node_left {
      left = node_left
    }
    if right < node_right {
      right = node_right
    }
    if top > node_top {
      top = node_top
    }
    if bottom < node_bottom {
      bottom = node_bottom
    }
  }
  { x: left, y: top, width: right - left, height: bottom - top, }
}
