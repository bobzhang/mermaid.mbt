// cytoscape-fcose 2.2.0's spectral layout (`spectralLayout`, with the
// greedy sampling of its defaults) and the auxiliary functions it uses on
// the cytoscape graph: where the layout starts when it is randomized.

///|
/// A node of the cytoscape graph, as the spectral layout sees it.
pub(all) struct SpectralNode {
  id : String
  parent : Int32?
  /// The children, in the order they were added.
  children : Array[Int32]
  /// The position (the centre), `width()`, `height()` and `outerWidth()`.
  x : Double
  y : Double
  width : Double
  height : Double
  outer_width : Double
  /// The edges at the node (`connectedEdges()`), in the order they were
  /// added, as indices of `SpectralGraph.edges`.
  edges : Array[Int32]
}

///|
/// The cytoscape graph: its nodes in the order of `cy.nodes()`, and its
/// edges as pairs of node indices.
pub(all) struct SpectralGraph {
  nodes : Array[SpectralNode]
  edges : Array[(Int32, Int32)]
}

///|
/// Where the spectral layout puts the centres of the leaves.
pub(all) struct SpectralResult {
  /// The leaves (and the dummy nodes that join components) by id.
  indexes : Map[String, Int32]
  x : Array[Double]
  y : Array[Double]
}

///|
/// mermaid's `withSeededRandom` as the layout's `Math.random`, shared by
/// the spectral layout and the spring embedder of one run.
pub struct SeededRandom {
  priv random : Random
}

///|
pub fn SeededRandom::new(seed : UInt32) -> SeededRandom {
  { random: { state: seed, }, }
}

///|
fn SpectralGraph::is_parent(self : SpectralGraph, index : Int32) -> Bool {
  !self.nodes[index].children.is_empty()
}

///|
/// `descendants()`: children, each followed by its own descendants.
fn SpectralGraph::descendants(
  self : SpectralGraph,
  index : Int32,
) -> Array[Int32] {
  let out = []
  fn add(children : Array[Int32]) -> Unit {
    for child in children {
      out.push(child)
      add(self.nodes[child].children)
    }
  }

  add(self.nodes[index].children)
  out
}

///|
/// `neighborhood().nodes()`: the other ends of the node's edges, once each.
fn SpectralGraph::neighbors(
  self : SpectralGraph,
  index : Int32,
) -> Array[Int32] {
  let out = []
  for edge in self.nodes[index].edges {
    let (source, target) = self.edges[edge]
    let other = if source == index { target } else { source }
    if !out.contains(other) {
      out.push(other)
    }
  }
  out
}

///|
/// `getTopMostNodes`: the nodes without an ancestor among them.
fn SpectralGraph::top_most(
  self : SpectralGraph,
  nodes : Array[Int32],
) -> Array[Int32] {
  nodes.filter(node => {
    let mut parent = self.nodes[node].parent
    while parent is Some(p) {
      if nodes.contains(p) {
        return false
      }
      parent = self.nodes[p].parent
    }
    true
  })
}

///|
/// `connectComponents`: the components of the top-most nodes, breadth
/// first; when there are several, the node of least degree of each is
/// joined to a new dummy node.
fn SpectralGraph::connect_components(
  self : SpectralGraph,
  top_most : Array[Int32],
  dummies : Map[String, Array[Int32]],
) -> Unit {
  let mut top = top_most
  let visited = Array::make(self.nodes.length(), false)
  let mut visited_top = []
  let mut is_connected = false
  let mut count = 1
  let to_dummy = []
  while !is_connected {
    let current = top[0]
    let queue = [current]
    queue.append(self.descendants(current))
    visited_top.push(current)
    for node in queue {
      visited[node] = true
    }
    let mut next = 0
    while next < queue.length() {
      let node = queue[next]
      next += 1
      for neighbor in self.neighbors(node) {
        // The top-most ancestor of the neighbour (or itself).
        let mut candidate = Some(neighbor)
        let mut found = None
        while candidate is Some(c) {
          if top.contains(c) {
            found = Some(c)
            break
          }
          candidate = self.nodes[c].parent
        }
        guard found is Some(top_node) && !visited[top_node] else { continue }
        let inside = [top_node]
        inside.append(self.descendants(top_node))
        for n in inside {
          queue.push(n)
          visited[n] = true
          if top.contains(n) {
            visited_top.push(n)
          }
        }
      }
    }
    if visited_top.length() == top.length() {
      is_connected = true
    }
    if !is_connected || count > 1 {
      let mut min_node = visited_top[0]
      let mut min_degree = self.nodes[min_node].edges.length()
      for node in visited_top {
        if self.nodes[node].edges.length() < min_degree {
          min_degree = self.nodes[node].edges.length()
          min_node = node
        }
      }
      to_dummy.push(min_node)
      let done = visited_top
      top = top.filter(node => !done.contains(node))
      visited_top = []
      count += 1
    }
  }
  if !to_dummy.is_empty() {
    dummies["dummy\{dummies.length() + 1}"] = to_dummy
  }
}

///|
/// `spectralLayout` with greedy sampling of 25 samples and a power
/// iteration tolerance of 1e-7.
pub fn spectral_layout(
  graph : SpectralGraph,
  random : SeededRandom,
  node_separation : Double,
) -> SpectralResult {
  let random = random.random
  let all = Array::makei(graph.nodes.length(), i => i)
  let parents = all.filter(i => graph.is_parent(i))
  let dummies : Map[String, Array[Int32]] = Map([])
  graph.connect_components(graph.top_most(all), dummies)
  for parent in parents {
    graph.connect_components(graph.top_most(graph.descendants(parent)), dummies)
  }
  let indexes : Map[String, Int32] = Map([])
  for i in all {
    if !graph.is_parent(i) {
      indexes[graph.nodes[i].id] = indexes.length()
    }
  }
  for key, _ in dummies {
    indexes[key] = indexes.length()
  }
  let neighborhoods : Array[Array[String]] = Array::makei(indexes.length(), _ => {
    []
  })
  // A compound node stands for the leaf inside it with the fewest edges.
  let representative : Map[Int32, String] = Map([])
  for parent in parents {
    let mut children = graph.nodes[parent].children
    while !children.iter().any(c => !graph.is_parent(c)) {
      children = graph.nodes[children[0]].children
    }
    let childless = children.filter(c => !graph.is_parent(c))
    let mut index = 0
    let mut min = graph.nodes[childless[0]].edges.length()
    for i, child in childless {
      if graph.nodes[child].edges.length() < min {
        min = graph.nodes[child].edges.length()
        index = i
      }
    }
    representative[parent] = graph.nodes[childless[index]].id
  }
  let id_of = (node : Int32) => {
    if graph.is_parent(node) {
      representative[node]
    } else {
      graph.nodes[node].id
    }
  }
  for node in all {
    let own = indexes.get(id_of(node)).unwrap_or(-1)
    for neighbor in graph.neighbors(node) {
      neighborhoods[own].push(id_of(neighbor))
    }
  }
  for key, members in dummies {
    let own = indexes[key]
    for joined in members {
      let id = id_of(joined)
      neighborhoods[own].push(id)
      neighborhoods[indexes[id]].push(key)
    }
  }
  let node_size = indexes.length()
  if node_size <= 2 {
    // The first leaf where it is; a second one an `idealEdgeLength` away,
    // which is a function here: the sum is a string, and the position
    // `NaN` once a number is taken from it.
    let ids = indexes.keys().collect()
    let first = graph.nodes[all
      .search_by(i => graph.nodes[i].id == ids[0])
      .unwrap()]
    let x = [first.x]
    let y = [first.y]
    if node_size == 2 {
      x.push(@double.not_a_number)
      y.push(first.y)
    }
    return { indexes, x, y, }
  }
  let sample_size = if node_size < 25 { node_size } else { 25 }
  let infinity = 1.0e8
  let c = Array::makei(node_size, _ => {
    Array::make(sample_size, @double.not_a_number)
  })
  let samples = Array::make(sample_size, 0)
  let min_distances = Array::make(node_size, infinity)
  // `BFS` with greedy sampling: the next sample is the node farthest from
  // all samples so far.
  let bfs = (pivot : Int32, column : Int32) => {
    let distance = Array::make(node_size, infinity)
    let path = [pivot]
    distance[pivot] = 0.0
    let mut front = 0
    while front < path.length() {
      let current = path[front]
      front += 1
      for id in neighborhoods[current] {
        let temp = indexes[id]
        if distance[temp] == infinity {
          distance[temp] = distance[current] + 1.0
          path.push(temp)
        }
      }
      c[current][column] = distance[current] * node_separation
    }
    let mut max_dist = 0.0
    let mut max_ind = 1
    for i in 0..<node_size {
      if c[i][column] < min_distances[i] {
        min_distances[i] = c[i][column]
      }
    }
    for i in 0..<node_size {
      if min_distances[i] > max_dist {
        max_dist = min_distances[i]
        max_ind = i
      }
    }
    max_ind
  }
  let mut sample = (random.next() * node_size.to_double()).floor().to_int()
  for i in 0..<sample_size {
    samples[i] = sample
    sample = bfs(sample, i)
  }
  for i in 0..<node_size {
    for j in 0..<sample_size {
      c[i][j] *= c[i][j]
    }
  }
  let phi = Array::makei(sample_size, i => {
    Array::makei(sample_size, j => c[samples[j]][i])
  })
  // `sample`: the regularized pseudo-inverse of the samples' block.
  let decomposition = svd(phi)
  let a_q = decomposition.s
  let max_s = a_q[0] * a_q[0] * a_q[0]
  let sig = Array::makei(sample_size, i => {
    Array::makei(sample_size, j => {
      if i == j {
        a_q[i] / (a_q[i] * a_q[i] + max_s / (a_q[i] * a_q[i]))
      } else {
        0.0
      }
    })
  })
  let inv = mult_mat(mult_mat(decomposition.v, sig), transpose(decomposition.u))
  // `powerIteration`: the two leading eigenvectors.
  let small = 1.0e-9
  let pi_tol = 1.0e-7
  let mut y1 = []
  let mut y2 = []
  for _ in 0..<node_size {
    y1.push(random.next())
    y2.push(random.next())
  }
  y1 = normalize(y1)
  y2 = normalize(y2)
  let mut previous = small
  let mut theta1 = 0.0
  let mut v1 = []
  while true {
    v1 = y1.copy()
    y1 = mult_gamma(mult_l(mult_gamma(v1), c, inv))
    theta1 = dot_product(v1, y1)
    y1 = normalize(y1)
    let current = dot_product(v1, y1)
    let temp = (current / previous).abs()
    if temp <= 1.0 + pi_tol && temp >= 1.0 {
      break
    }
    previous = current
  }
  v1 = y1.copy()
  previous = small
  let mut theta2 = 0.0
  let mut v2 = []
  while true {
    v2 = y2.copy()
    v2 = minus_op(v2, mult_cons(v1, dot_product(v1, v2)))
    y2 = mult_gamma(mult_l(mult_gamma(v2), c, inv))
    theta2 = dot_product(v2, y2)
    y2 = normalize(y2)
    let current = dot_product(v2, y2)
    let temp = (current / previous).abs()
    if temp <= 1.0 + pi_tol && temp >= 1.0 {
      break
    }
    previous = current
  }
  v2 = y2.copy()
  {
    indexes,
    x: mult_cons(v1, theta1.abs().sqrt()),
    y: mult_cons(v2, theta2.abs().sqrt()),
  }
}
