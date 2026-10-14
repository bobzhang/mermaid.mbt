///|
/// A node of d3-hierarchy's `hierarchy`, with the box d3's layouts give
/// it.
pub struct HierarchyNode[T] {
  data : T
  /// The distance from the root.
  mut depth : Int32
  /// The distance to the deepest leaf below.
  mut height : Int32
  mut parent : HierarchyNode[T]?
  /// `None` for a leaf: a node is never given an empty list.
  mut children : Array[HierarchyNode[T]]?
  mut value : Double
  mut x0 : Double
  mut y0 : Double
  mut x1 : Double
  mut y1 : Double
}

///|
/// `d3.hierarchy(data, children)`: the tree of nodes below `data`.
pub fn[T] hierarchy(data : T, children : (T) -> Array[T]) -> HierarchyNode[T] {
  let make = (data : T) => {
    data,
    depth: 0,
    height: 0,
    parent: None,
    children: None,
    value: 0.0,
    x0: 0.0,
    y0: 0.0,
    x1: 0.0,
    y1: 0.0,
  }
  let root : HierarchyNode[T] = make(data)
  let nodes = [root]
  while nodes.pop() is Some(node) {
    let below = children(node.data)
    if !below.is_empty() {
      let made = below.map(make)
      node.children = Some(made)
      let mut i = made.length() - 1
      while i >= 0 {
        let child = made[i]
        child.parent = Some(node)
        child.depth = node.depth + 1
        nodes.push(child)
        i -= 1
      }
    }
  }
  // `computeHeight`
  root.each_before(node => {
    let mut height = 0
    let mut current = node
    while true {
      current.height = height
      guard current.parent is Some(parent) else { break }
      height += 1
      guard parent.height < height else { break }
      current = parent
    }
  })
  root
}

///|
/// `node.eachBefore`: every node before its descendants.
pub fn[T] HierarchyNode::each_before(
  self : HierarchyNode[T],
  callback : (HierarchyNode[T]) -> Unit,
) -> Unit {
  let nodes = [self]
  while nodes.pop() is Some(node) {
    callback(node)
    if node.children is Some(children) {
      let mut i = children.length() - 1
      while i >= 0 {
        nodes.push(children[i])
        i -= 1
      }
    }
  }
}

///|
/// `node.eachAfter`: every node after its descendants.
pub fn[T] HierarchyNode::each_after(
  self : HierarchyNode[T],
  callback : (HierarchyNode[T]) -> Unit,
) -> Unit {
  let nodes = [self]
  let next = []
  while nodes.pop() is Some(node) {
    next.push(node)
    if node.children is Some(children) {
      for child in children {
        nodes.push(child)
      }
    }
  }
  while next.pop() is Some(node) {
    callback(node)
  }
}

///|
/// `node.descendants()`: the node and everything below it, level by
/// level.
pub fn[T] HierarchyNode::descendants(
  self : HierarchyNode[T],
) -> Array[HierarchyNode[T]] {
  let out = []
  let mut next = [self]
  while !next.is_empty() {
    let current = next
    next = []
    for node in current {
      out.push(node)
      if node.children is Some(children) {
        for child in children {
          next.push(child)
        }
      }
    }
  }
  out
}

///|
/// `node.leaves()`: the nodes without children, in traversal order.
pub fn[T] HierarchyNode::leaves(
  self : HierarchyNode[T],
) -> Array[HierarchyNode[T]] {
  let leaves = []
  self.each_before(node => if node.children is None { leaves.push(node) })
  leaves
}

///|
/// `node.sum(value)`: every node's value becomes its own (`NaN` counts as
/// nothing) plus those of its children, added last child first.
pub fn[T] HierarchyNode::sum(
  self : HierarchyNode[T],
  value : (T) -> Double,
) -> Unit {
  self.each_after(node => {
    let own = value(node.data)
    let mut sum = if own.is_nan() { 0.0 } else { own }
    if node.children is Some(children) {
      let mut i = children.length() - 1
      while i >= 0 {
        sum += children[i].value
        i -= 1
      }
    }
    node.value = sum
  })
}

///|
/// `node.sort(compare)`: the children of every node, with JavaScript's
/// sort.
pub fn[T] HierarchyNode::sort(
  self : HierarchyNode[T],
  compare : (HierarchyNode[T], HierarchyNode[T]) -> Double,
) -> Unit {
  self.each_before(node => {
    if node.children is Some(children) {
      js_sort(children, compare)
    }
  })
}
