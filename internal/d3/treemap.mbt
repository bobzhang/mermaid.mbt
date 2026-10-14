///|
/// The settings of d3-hierarchy's `treemap()` layout with the squarify
/// tiling. The paddings are asked of every node that has children.
pub(all) struct TreemapLayout[T] {
  width : Double
  height : Double
  padding_inner : (HierarchyNode[T]) -> Double
  padding_top : (HierarchyNode[T]) -> Double
  padding_right : (HierarchyNode[T]) -> Double
  padding_bottom : (HierarchyNode[T]) -> Double
  padding_left : (HierarchyNode[T]) -> Double
  /// Whether boxes are rounded to whole numbers at the end.
  round : Bool
}

///|
/// The golden ratio, squarify's target aspect ratio.
let phi : Double = (1.0 + 5.0.sqrt()) / 2.0

///|
/// A row of squarify: nodes laid side by side.
priv struct Row[T] {
  value : Double
  children : ArrayView[HierarchyNode[T]]
}

///|
/// `treemapDice`: the nodes share the width in proportion to their
/// values.
fn[T] dice(
  row : Row[T],
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  // `parent.value && (x1 - x0) / parent.value`
  let k = if row.value == 0.0 || row.value.is_nan() {
    row.value
  } else {
    (x1 - x0) / row.value
  }
  let mut x0 = x0
  for node in row.children {
    node.y0 = y0
    node.y1 = y1
    node.x0 = x0
    x0 += node.value * k
    node.x1 = x0
  }
}

///|
/// `treemapSlice`: the nodes share the height in proportion to their
/// values.
fn[T] slice(
  row : Row[T],
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  let k = if row.value == 0.0 || row.value.is_nan() {
    row.value
  } else {
    (y1 - y0) / row.value
  }
  let mut y0 = y0
  for node in row.children {
    node.x0 = x0
    node.x1 = x1
    node.y0 = y0
    y0 += node.value * k
    node.y1 = y0
  }
}

///|
/// `squarifyRatio`: fill the box with rows of children whose aspect
/// ratios stay as close to `ratio` as a greedy choice allows.
fn[T] squarify(
  ratio : Double,
  parent : HierarchyNode[T],
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  guard parent.children is Some(nodes) else { return }
  let n = nodes.length()
  let truthy = (value : Double) => value != 0.0 && !value.is_nan()
  let mut x0 = x0
  let mut y0 = y0
  let mut i0 = 0
  let mut i1 = 0
  let mut value = parent.value
  while i0 < n {
    let dx = x1 - x0
    let dy = y1 - y0
    // Find the next non-empty node.
    let mut sum_value = nodes[i1].value
    i1 += 1
    while !truthy(sum_value) && i1 < n {
      sum_value = nodes[i1].value
      i1 += 1
    }
    let mut min_value = sum_value
    let mut max_value = sum_value
    let alpha = js_max(dy / dx, dx / dy) / (value * ratio)
    let mut beta = sum_value * sum_value * alpha
    let mut min_ratio = js_max(max_value / beta, beta / min_value)
    // Keep adding nodes while the aspect ratio maintains or improves.
    while i1 < n {
      let node_value = nodes[i1].value
      sum_value += node_value
      if node_value < min_value {
        min_value = node_value
      }
      if node_value > max_value {
        max_value = node_value
      }
      beta = sum_value * sum_value * alpha
      let new_ratio = js_max(max_value / beta, beta / min_value)
      if new_ratio > min_ratio {
        sum_value -= node_value
        break
      }
      min_ratio = new_ratio
      i1 += 1
    }
    // Position and record the row orientation.
    let row = { value: sum_value, children: nodes[i0:i1], }
    if dx < dy {
      let top = y0
      let bottom = if truthy(value) {
        y0 += dy * sum_value / value
        y0
      } else {
        y1
      }
      dice(row, x0, top, x1, bottom)
    } else {
      let left = x0
      let right = if truthy(value) {
        x0 += dx * sum_value / value
        x0
      } else {
        x1
      }
      slice(row, left, y0, right, y1)
    }
    value -= sum_value
    i0 = i1
  }
}

///|
/// `treemap()(root)`: give every node of the tree its box. The values
/// must have been computed with `sum`.
pub fn[T] TreemapLayout::layout(
  self : TreemapLayout[T],
  root : HierarchyNode[T],
) -> Unit {
  root.x0 = 0.0
  root.y0 = 0.0
  root.x1 = self.width
  root.y1 = self.height
  // Half the inner padding of the parent, by depth.
  let padding_stack = [0.0]
  root.each_before(node => {
    let mut p = padding_stack[node.depth]
    let mut x0 = node.x0 + p
    let mut y0 = node.y0 + p
    let mut x1 = node.x1 - p
    let mut y1 = node.y1 - p
    if x1 < x0 {
      x0 = (x0 + x1) / 2.0
      x1 = x0
    }
    if y1 < y0 {
      y0 = (y0 + y1) / 2.0
      y1 = y0
    }
    node.x0 = x0
    node.y0 = y0
    node.x1 = x1
    node.y1 = y1
    if node.children is Some(_) {
      p = (self.padding_inner)(node) / 2.0
      if padding_stack.length() > node.depth + 1 {
        padding_stack[node.depth + 1] = p
      } else {
        padding_stack.push(p)
      }
      x0 += (self.padding_left)(node) - p
      y0 += (self.padding_top)(node) - p
      x1 -= (self.padding_right)(node) - p
      y1 -= (self.padding_bottom)(node) - p
      if x1 < x0 {
        x0 = (x0 + x1) / 2.0
        x1 = x0
      }
      if y1 < y0 {
        y0 = (y0 + y1) / 2.0
        y1 = y0
      }
      squarify(phi, node, x0, y0, x1, y1)
    }
  })
  if self.round {
    root.each_before(node => {
      node.x0 = js_round(node.x0)
      node.y0 = js_round(node.y0)
      node.x1 = js_round(node.x1)
      node.y1 = js_round(node.y1)
    })
  }
}
