///|
/// d3-sankey's node alignments: which column a node is put in.
pub(all) enum SankeyAlign {
  Left
  Right
  Center
  Justify
} derive(Eq, Debug)

///|
/// d3-sankey refuses graphs with a cycle.
pub(all) suberror SankeyError {
  CircularLink
} derive(Eq, Debug)

///|
/// A node as d3-sankey lays it out. Links are referred to by their index
/// in `SankeyGraph::links`.
pub struct SankeyNode {
  index : Int32
  /// Outgoing links, kept sorted by the position of their targets.
  source_links : Array[Int32]
  /// Incoming links, kept sorted by the position of their sources.
  target_links : Array[Int32]
  mut value : Double
  /// The longest path from a node without incoming links.
  mut depth : Int32
  /// The longest path to a node without outgoing links.
  mut height : Int32
  /// The column.
  mut layer : Int32
  mut x0 : Double
  mut x1 : Double
  mut y0 : Double
  mut y1 : Double
}

///|
/// A link as d3-sankey lays it out; `y0` and `y1` are the centres of its
/// ends on the source and on the target.
pub struct SankeyLink {
  index : Int32
  source : Int32
  target : Int32
  value : Double
  mut width : Double
  mut y0 : Double
  mut y1 : Double
}

///|
pub struct SankeyGraph {
  nodes : Array[SankeyNode]
  links : Array[SankeyLink]
}

///|
/// The settings of a d3-sankey generator.
priv struct SankeyLayout {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
  /// `nodeWidth`
  dx : Double
  /// `nodePadding`
  dy : Double
  /// The padding in use: `dy`, less when a column is too crowded.
  mut py : Double
  align : SankeyAlign
  graph : SankeyGraph
}

///|
/// `Math.pow(0.99, i)` for the six relaxation passes, as Chrome computes
/// them.
let relaxation_alpha : Array[Double] = [
  1.0, 0.99, 0.9801, 0.970299, 0.96059601, 0.9509900498999999,
]

///|
/// Not a number.
let nan : Double = 0.0 / 0.0

///|
/// `Math.min` of two numbers: `NaN` when either is.
fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    nan
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// d3-array's `sum`: zeros and `NaN`s are skipped.
fn d3_sum(values : Iter[Double]) -> Double {
  let mut sum = 0.0
  for value in values {
    if value != 0.0 && !value.is_nan() {
      sum += value
    }
  }
  sum
}

///|
/// Lay out a Sankey diagram: a port of d3-sankey 0.12.3 with its default
/// six relaxation iterations and no custom sorting.
///
/// `links` are `(source, target, value)` with node indices below
/// `node_count`. `extent` is `(x0, y0, x1, y1)`.
pub fn sankey(
  node_count : Int32,
  links : Array[(Int32, Int32, Double)],
  node_width~ : Double = 24.0,
  node_padding~ : Double = 8.0,
  align~ : SankeyAlign = Justify,
  extent~ : (Double, Double, Double, Double) = (0.0, 0.0, 1.0, 1.0),
) -> SankeyGraph raise SankeyError {
  // `computeNodeLinks`
  let nodes : Array[SankeyNode] = Array::makei(node_count, index => {
    index,
    source_links: [],
    target_links: [],
    value: 0.0,
    depth: 0,
    height: 0,
    layer: 0,
    x0: 0.0,
    x1: 0.0,
    y0: 0.0,
    y1: 0.0,
  })
  let graph_links : Array[SankeyLink] = []
  for index, link in links {
    let (source, target, value) = link
    graph_links.push({
      index,
      source,
      target,
      value,
      width: 0.0,
      y0: 0.0,
      y1: 0.0,
    })
    nodes[source].source_links.push(index)
    nodes[target].target_links.push(index)
  }
  let graph = { nodes, links: graph_links, }
  let layout = {
    x0: extent.0,
    y0: extent.1,
    x1: extent.2,
    y1: extent.3,
    dx: node_width,
    dy: node_padding,
    py: node_padding,
    align,
    graph,
  }
  // `computeNodeValues`
  for node in nodes {
    node.value = js_max(
      d3_sum(node.source_links.iter().map(i => graph_links[i].value)),
      d3_sum(node.target_links.iter().map(i => graph_links[i].value)),
    )
  }
  layout.compute_node_depths()
  layout.compute_node_heights()
  layout.compute_node_breadths()
  layout.compute_link_breadths()
  graph
}

///|
/// The nodes reached from `current` over one link, each once, in the
/// order they are first reached.
fn SankeyLayout::step(
  self : SankeyLayout,
  current : Array[Int32],
  forward : Bool,
) -> Array[Int32] {
  let next = []
  let seen = Array::make(self.graph.nodes.length(), false)
  for index in current {
    let node = self.graph.nodes[index]
    let links = if forward { node.source_links } else { node.target_links }
    for link in links {
      let link = self.graph.links[link]
      let other = if forward { link.target } else { link.source }
      if !seen[other] {
        seen[other] = true
        next.push(other)
      }
    }
  }
  next
}

///|
fn SankeyLayout::compute_node_depths(
  self : SankeyLayout,
) -> Unit raise SankeyError {
  let n = self.graph.nodes.length()
  let mut current = Array::makei(n, i => i)
  let mut x = 0
  while !current.is_empty() {
    for index in current {
      self.graph.nodes[index].depth = x
    }
    let next = self.step(current, true)
    x += 1
    if x > n {
      raise CircularLink
    }
    current = next
  }
}

///|
fn SankeyLayout::compute_node_heights(
  self : SankeyLayout,
) -> Unit raise SankeyError {
  let n = self.graph.nodes.length()
  let mut current = Array::makei(n, i => i)
  let mut x = 0
  while !current.is_empty() {
    for index in current {
      self.graph.nodes[index].height = x
    }
    let next = self.step(current, false)
    x += 1
    if x > n {
      raise CircularLink
    }
    current = next
  }
}

///|
/// The column an alignment asks for, before it is clamped. `n` is the
/// number of columns.
fn SankeyLayout::aligned(
  self : SankeyLayout,
  node : SankeyNode,
  n : Int32,
) -> Int32 {
  match self.align {
    Left => node.depth
    Right => n - 1 - node.height
    Justify => if node.source_links.is_empty() { n - 1 } else { node.depth }
    Center =>
      if !node.target_links.is_empty() {
        node.depth
      } else if !node.source_links.is_empty() {
        let mut least = self.graph.nodes[self.graph.links[node.source_links[0]].target].depth
        for link in node.source_links {
          let depth = self.graph.nodes[self.graph.links[link].target].depth
          if depth < least {
            least = depth
          }
        }
        least - 1
      } else {
        0
      }
  }
}

///|
fn SankeyLayout::compute_node_layers(
  self : SankeyLayout,
) -> Array[Array[SankeyNode]] {
  let nodes = self.graph.nodes
  let mut deepest = 0
  for node in nodes {
    if node.depth > deepest {
      deepest = node.depth
    }
  }
  let x = deepest + 1
  let kx = (self.x1 - self.x0 - self.dx) / (x - 1).to_double()
  let columns : Array[Array[SankeyNode]] = Array::makei(x, _ => [])
  for node in nodes {
    let i = self.aligned(node, x)
    let i = if i > x - 1 { x - 1 } else { i }
    let i = if i < 0 { 0 } else { i }
    node.layer = i
    node.x0 = self.x0 + i.to_double() * kx
    node.x1 = node.x0 + self.dx
    columns[i].push(node)
  }
  columns
}

///|
fn SankeyLayout::link(self : SankeyLayout, index : Int32) -> SankeyLink {
  self.graph.links[index]
}

///|
/// `ascendingTargetBreadth`, for the outgoing links of a node.
fn SankeyLayout::sort_source_links(
  self : SankeyLayout,
  node : SankeyNode,
) -> Unit {
  let nodes = self.graph.nodes
  let links = self.graph.links
  js_sort(node.source_links, (a, b) => {
    let by_breadth = nodes[links[a].target].y0 - nodes[links[b].target].y0
    // `||` takes the second operand for zero and for `NaN`.
    if by_breadth != 0.0 && !by_breadth.is_nan() {
      by_breadth
    } else {
      (a - b).to_double()
    }
  })
}

///|
/// `ascendingSourceBreadth`, for the incoming links of a node.
fn SankeyLayout::sort_target_links(
  self : SankeyLayout,
  node : SankeyNode,
) -> Unit {
  let nodes = self.graph.nodes
  let links = self.graph.links
  js_sort(node.target_links, (a, b) => {
    let by_breadth = nodes[links[a].source].y0 - nodes[links[b].source].y0
    if by_breadth != 0.0 && !by_breadth.is_nan() {
      by_breadth
    } else {
      (a - b).to_double()
    }
  })
}

///|
fn SankeyLayout::reorder_links(
  self : SankeyLayout,
  nodes : Array[SankeyNode],
) -> Unit {
  for node in nodes {
    self.sort_source_links(node)
    self.sort_target_links(node)
  }
}

///|
fn SankeyLayout::reorder_node_links(
  self : SankeyLayout,
  node : SankeyNode,
) -> Unit {
  for link in node.target_links {
    self.sort_source_links(self.graph.nodes[self.link(link).source])
  }
  for link in node.source_links {
    self.sort_target_links(self.graph.nodes[self.link(link).target])
  }
}

///|
fn SankeyLayout::initialize_node_breadths(
  self : SankeyLayout,
  columns : Array[Array[SankeyNode]],
) -> Unit {
  // d3-array's `min` skips `NaN`s and is undefined when nothing is left,
  // which then poisons every product.
  let mut ky = nan
  for column in columns {
    let k = (self.y1 - self.y0 - (column.length() - 1).to_double() * self.py) /
      d3_sum(column.iter().map(node => node.value))
    if !k.is_nan() && (ky.is_nan() || ky > k) {
      ky = k
    }
  }
  for nodes in columns {
    let mut y = self.y0
    for node in nodes {
      node.y0 = y
      node.y1 = y + node.value * ky
      y = node.y1 + self.py
      for link in node.source_links {
        let link = self.link(link)
        link.width = link.value * ky
      }
    }
    y = (self.y1 - y + self.py) / (nodes.length() + 1).to_double()
    for i, node in nodes {
      node.y0 += y * (i + 1).to_double()
      node.y1 += y * (i + 1).to_double()
    }
    self.reorder_links(nodes)
  }
}

///|
fn SankeyLayout::compute_node_breadths(self : SankeyLayout) -> Unit {
  let columns = self.compute_node_layers()
  let mut longest = 0
  for column in columns {
    if column.length() > longest {
      longest = column.length()
    }
  }
  self.py = js_min(self.dy, (self.y1 - self.y0) / (longest - 1).to_double())
  self.initialize_node_breadths(columns)
  let iterations = relaxation_alpha.length()
  for i, alpha in relaxation_alpha {
    let beta = js_max(1.0 - alpha, (i + 1).to_double() / iterations.to_double())
    self.relax_right_to_left(columns, alpha, beta)
    self.relax_left_to_right(columns, alpha, beta)
  }
}

///|
fn ascending_breadth(a : SankeyNode, b : SankeyNode) -> Double {
  a.y0 - b.y0
}

///|
fn SankeyLayout::relax_left_to_right(
  self : SankeyLayout,
  columns : Array[Array[SankeyNode]],
  alpha : Double,
  beta : Double,
) -> Unit {
  let nodes = self.graph.nodes
  for i in 1..<columns.length() {
    let column = columns[i]
    for target in column {
      let mut y = 0.0
      let mut w = 0.0
      for link in target.target_links {
        let link = self.link(link)
        let source = nodes[link.source]
        let v = link.value * (target.layer - source.layer).to_double()
        y += self.target_top(source, target) * v
        w += v
      }
      if !(w > 0.0) {
        continue
      }
      let dy = (y / w - target.y0) * alpha
      target.y0 += dy
      target.y1 += dy
      self.reorder_node_links(target)
    }
    js_sort(column, ascending_breadth)
    self.resolve_collisions(column, beta)
  }
}

///|
fn SankeyLayout::relax_right_to_left(
  self : SankeyLayout,
  columns : Array[Array[SankeyNode]],
  alpha : Double,
  beta : Double,
) -> Unit {
  let nodes = self.graph.nodes
  let mut i = columns.length() - 2
  while i >= 0 {
    let column = columns[i]
    for source in column {
      let mut y = 0.0
      let mut w = 0.0
      for link in source.source_links {
        let link = self.link(link)
        let target = nodes[link.target]
        let v = link.value * (target.layer - source.layer).to_double()
        y += self.source_top(source, target) * v
        w += v
      }
      if !(w > 0.0) {
        continue
      }
      let dy = (y / w - source.y0) * alpha
      source.y0 += dy
      source.y1 += dy
      self.reorder_node_links(source)
    }
    js_sort(column, ascending_breadth)
    self.resolve_collisions(column, beta)
    i -= 1
  }
}

///|
fn SankeyLayout::resolve_collisions(
  self : SankeyLayout,
  nodes : Array[SankeyNode],
  alpha : Double,
) -> Unit {
  let i = nodes.length() >> 1
  let subject = nodes[i]
  self.resolve_collisions_bottom_to_top(
    nodes,
    subject.y0 - self.py,
    i - 1,
    alpha,
  )
  self.resolve_collisions_top_to_bottom(
    nodes,
    subject.y1 + self.py,
    i + 1,
    alpha,
  )
  self.resolve_collisions_bottom_to_top(
    nodes,
    self.y1,
    nodes.length() - 1,
    alpha,
  )
  self.resolve_collisions_top_to_bottom(nodes, self.y0, 0, alpha)
}

///|
fn SankeyLayout::resolve_collisions_top_to_bottom(
  self : SankeyLayout,
  nodes : Array[SankeyNode],
  y : Double,
  i : Int32,
  alpha : Double,
) -> Unit {
  let mut y = y
  for i in i..<nodes.length() {
    let node = nodes[i]
    let dy = (y - node.y0) * alpha
    if dy > 1.0e-6 {
      node.y0 += dy
      node.y1 += dy
    }
    y = node.y1 + self.py
  }
}

///|
fn SankeyLayout::resolve_collisions_bottom_to_top(
  self : SankeyLayout,
  nodes : Array[SankeyNode],
  y : Double,
  i : Int32,
  alpha : Double,
) -> Unit {
  let mut y = y
  let mut i = i
  while i >= 0 {
    let node = nodes[i]
    let dy = (node.y1 - y) * alpha
    if dy > 1.0e-6 {
      node.y0 -= dy
      node.y1 -= dy
    }
    y = node.y0 - self.py
    i -= 1
  }
}

///|
/// Where the top of `target` would be if it sat right of `source` with
/// the link between them straight.
fn SankeyLayout::target_top(
  self : SankeyLayout,
  source : SankeyNode,
  target : SankeyNode,
) -> Double {
  let mut y = source.y0 -
    (source.source_links.length() - 1).to_double() * self.py / 2.0
  for link in source.source_links {
    let link = self.link(link)
    if link.target == target.index {
      break
    }
    y += link.width + self.py
  }
  for link in target.target_links {
    let link = self.link(link)
    if link.source == source.index {
      break
    }
    y -= link.width
  }
  y
}

///|
/// Where the top of `source` would be if it sat left of `target` with
/// the link between them straight.
fn SankeyLayout::source_top(
  self : SankeyLayout,
  source : SankeyNode,
  target : SankeyNode,
) -> Double {
  let mut y = target.y0 -
    (target.target_links.length() - 1).to_double() * self.py / 2.0
  for link in target.target_links {
    let link = self.link(link)
    if link.source == source.index {
      break
    }
    y += link.width + self.py
  }
  for link in source.source_links {
    let link = self.link(link)
    if link.target == target.index {
      break
    }
    y -= link.width
  }
  y
}

///|
fn SankeyLayout::compute_link_breadths(self : SankeyLayout) -> Unit {
  for node in self.graph.nodes {
    let mut y0 = node.y0
    let mut y1 = y0
    for link in node.source_links {
      let link = self.link(link)
      link.y0 = y0 + link.width / 2.0
      y0 += link.width
    }
    for link in node.target_links {
      let link = self.link(link)
      link.y1 = y1 + link.width / 2.0
      y1 += link.width
    }
  }
}

///|
/// d3-sankey's `sankeyLinkHorizontal()` applied to `link`: a cubic curve
/// from the right side of the source to the left side of the target.
pub fn SankeyGraph::link_horizontal(
  self : SankeyGraph,
  link : SankeyLink,
) -> String {
  let x0 = self.nodes[link.source].x1
  let x1 = self.nodes[link.target].x0
  let middle = (x0 + x1) / 2.0
  let n = number
  "M\{n(x0)},\{n(link.y0)}C\{n(middle)},\{n(link.y0)},\{n(middle)},\{n(link.y1)},\{n(x1)},\{n(link.y1)}"
}
