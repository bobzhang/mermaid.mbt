// dagre's `position/bk.js`: horizontal coordinates by the algorithm of
// Brandes and Köpf, "Fast and Simple Horizontal Coordinate Assignment".
// Four alignments are computed (up or down, left or right), moved to the
// narrowest one, and every node takes the mean of its two middle
// positions.

///|
/// The pairs of nodes whose alignment would let a long edge cross another:
/// each pair under the smaller of its names.
type Conflicts = Map[String, Map[String, Unit]]

///|
/// Marks all edges in the graph with a type-1 conflict: a non-inner
/// segment that crosses an inner segment, one whose ends are both dummy
/// nodes.
fn find_type1_conflicts(
  g : LayoutGraph,
  layering : Array[Array[String]],
  conflicts : Conflicts,
) -> Unit raise LayoutError {
  for index in 1..<layering.length() {
    let prev_layer = layering[index - 1]
    let layer = layering[index]
    // The last visited node in the previous layer that is incident on an
    // inner segment, and the next position to scan for crossings.
    let mut k0 = 0
    let mut scan_pos = 0
    let prev_layer_length = prev_layer.length()
    let last_node = layer.last()
    for i, v in layer {
      let w = find_other_inner_segment_node(g, v)
      let k1 = match w {
        Some(w) => order_of(g, w)
        None => prev_layer_length
      }
      if w is Some(_) || Some(v) == last_node {
        for j in scan_pos..<(i + 1) {
          let scan_node = layer[j]
          for u in g.predecessors(scan_node) {
            let u_label = nd(g, u)
            let u_pos = order_of(g, u)
            if (u_pos < k0 || k1 < u_pos) &&
              !(u_label.dummy is Some(_) && nd(g, scan_node).dummy is Some(_)) {
              add_conflict(conflicts, u, scan_node)
            }
          }
        }
        scan_pos = i + 1
        k0 = k1
      }
    }
  }
}

///|
fn find_type2_conflicts(
  g : LayoutGraph,
  layering : Array[Array[String]],
  conflicts : Conflicts,
) -> Unit raise LayoutError {
  // A border that is undefined compares false with every position.
  fn scan(
    south : Array[String],
    south_pos : Int32,
    south_end : Int32,
    prev_north_border : Int32?,
    next_north_border : Int32,
  ) -> Unit raise LayoutError {
    for i in south_pos..<south_end {
      let v = south[i]
      if nd(g, v).dummy is Some(_) {
        for u in g.predecessors(v) {
          let u_node = nd(g, u)
          guard u_node.dummy is Some(_) && u_node.order is Some(order) else {
            continue
          }
          if (prev_north_border is Some(border) && order < border) ||
            order > next_north_border {
            add_conflict(conflicts, u, v)
          }
        }
      }
    }
  }

  for index in 1..<layering.length() {
    let north = layering[index - 1]
    let south = layering[index]
    let mut prev_north_pos = -1
    let mut next_north_pos : Int32? = None
    let mut south_pos = 0
    for south_lookahead, v in south {
      if nd(g, v).dummy is Some("border") {
        if g.predecessors(v) is [first, ..] {
          let next = order_of(g, first)
          next_north_pos = Some(next)
          scan(south, south_pos, south_lookahead, Some(prev_north_pos), next)
          south_pos = south_lookahead
          prev_north_pos = next
        }
      }
      scan(south, south_pos, south.length(), next_north_pos, north.length())
    }
  }
}

///|
fn find_other_inner_segment_node(
  g : LayoutGraph,
  v : String,
) -> String? raise LayoutError {
  if nd(g, v).dummy is Some(_) {
    for u in g.predecessors(v) {
      if nd(g, u).dummy is Some(_) {
        return Some(u)
      }
    }
  }
  None
}

///|
fn add_conflict(conflicts : Conflicts, v : String, w : String) -> Unit {
  let (v, w) = if @graphlib.compare_strings(v, w) > 0 { (w, v) } else { (v, w) }
  match conflicts.get(v) {
    Some(conflicts_v) => conflicts_v[w] = ()
    None => {
      let conflicts_v : Map[String, Unit] = Map([])
      conflicts_v[w] = ()
      conflicts[v] = conflicts_v
    }
  }
}

///|
fn has_conflict(conflicts : Conflicts, v : String, w : String) -> Bool {
  let (v, w) = if @graphlib.compare_strings(v, w) > 0 { (w, v) } else { (v, w) }
  conflicts.get(v) is Some(conflicts_v) && conflicts_v.contains(w)
}

///|
/// Try to align nodes into vertical "blocks" where possible. This
/// algorithm attempts to align a node with one of its median neighbors. If
/// the edge connecting a neighbor is a type-1 conflict then we ignore that
/// possibility. If a previous node has already formed a block with a node
/// after the node we're trying to form a block with, we also ignore that
/// possibility - our blocks would be split in that scenario.
fn vertical_alignment(
  layering : Array[Array[String]],
  conflicts : Conflicts,
  neighbor_fn : (String) -> Array[String],
) -> (Map[String, String], Map[String, String]) {
  let root : Map[String, String] = Map([])
  let align : @graphlib.JsObject[String] = @graphlib.JsObject::new()
  let pos : Map[String, Int32] = Map([])
  // We cache the position here based on the layering because the graph and
  // layering may be out of sync. The layering matrix is manipulated to
  // generate different extreme alignments.
  for layer in layering {
    for order, v in layer {
      root[v] = v
      align.set(v, v)
      pos[v] = order
    }
  }
  for layer in layering {
    let mut prev_idx = -1
    for v in layer {
      let ws = neighbor_fn(v)
      if !ws.is_empty() {
        let ws = sort_by(ws, w => {
          match pos.get(w) {
            Some(pos) => pos.to_double()
            None => @double.not_a_number
          }
        })
        let mp = (ws.length() - 1).to_double() / 2.0
        let il = mp.ceil().to_int()
        for i = mp.floor().to_int(); i <= il; i = i + 1 {
          let w = ws[i]
          guard pos.get(w) is Some(pos_w) else { continue }
          if align.get(v) == Some(v) &&
            prev_idx < pos_w &&
            !has_conflict(conflicts, v, w) {
            align.set(w, v)
            let root_w = root.get(w).unwrap_or(w)
            root[v] = root_w
            align.set(v, root_w)
            prev_idx = pos_w
          }
        }
      }
    }
  }
  // The alignment in the order its keys have as the properties of a
  // JavaScript object.
  let aligned : Map[String, String] = Map([])
  for v in align.keys() {
    if align.get(v) is Some(w) {
      aligned[v] = w
    }
  }
  (root, aligned)
}

///|
type BlockGraph = @graphlib.Graph[Unit, Unit, Double]

///|
fn horizontal_compaction(
  g : LayoutGraph,
  layering : Array[Array[String]],
  root : Map[String, String],
  align : Map[String, String],
  reverse_sep : Bool,
) -> Map[String, Double] raise LayoutError {
  // This portion of the algorithm differs from BK due to a number of
  // problems. Instead of their algorithm we construct a new block graph
  // and do two sweeps. The first sweep places blocks with the smallest
  // possible coordinates. The second sweep removes unused space by moving
  // blocks to the greatest coordinates without violating separation.
  let xs : Map[String, Double] = Map([])
  let block_g = build_block_graph(g, layering, root, reverse_sep)
  let border_type = if reverse_sep { "borderLeft" } else { "borderRight" }
  let x_of = (v : String) => xs.get(v).unwrap_or(@double.not_a_number)
  let iterate = (first_pass : Bool) => {
    let stack = block_g.nodes()
    let visited : Map[String, Unit] = Map([])
    // `while (elem)`: an empty name ends the walk.
    while stack.pop() is Some(elem) && elem != "" {
      if visited.contains(elem) {
        if first_pass {
          // First pass, assign smallest coordinates.
          let mut acc = 0.0
          for e in block_g.in_edges(elem) {
            acc = js_max(acc, x_of(e.v) + ed(block_g, e))
          }
          xs[elem] = acc
        } else {
          // Second pass, assign greatest coordinates.
          let mut min = @double.infinity
          for e in block_g.out_edges(elem) {
            min = js_min(min, x_of(e.w) - ed(block_g, e))
          }
          let node = nd(g, elem)
          if min != @double.infinity && node.border_type != Some(border_type) {
            xs[elem] = js_max(x_of(elem), min)
          }
        }
      } else {
        visited[elem] = ()
        stack.push(elem)
        stack.append(
          if first_pass {
            block_g.predecessors(elem)
          } else {
            block_g.successors(elem)
          },
        )
      }
    }
  }
  iterate(true)
  iterate(false)
  // Assign x coordinates to all nodes.
  for _, v in align {
    xs[v] = x_of(root.get(v).unwrap_or(v))
  }
  xs
}

///|
fn build_block_graph(
  g : LayoutGraph,
  layering : Array[Array[String]],
  root : Map[String, String],
  reverse_sep : Bool,
) -> BlockGraph raise LayoutError {
  let block_graph : BlockGraph = @graphlib.Graph::new((), default_node=_ => ())
  let graph_label = g.graph()
  for layer in layering {
    let mut u : String? = None
    for v in layer {
      let v_root = root.get(v).unwrap_or(v)
      block_graph.ensure_node(v_root)
      if u is Some(u) && u != "" {
        let u_root = root.get(u).unwrap_or(u)
        let prev_max = block_graph.edge_between(u_root, v_root).unwrap_or(0.0)
        let prev_max = if truthy(prev_max) { prev_max } else { 0.0 }
        let separation = sep(
          g,
          graph_label.nodesep,
          graph_label.edgesep,
          reverse_sep,
          v,
          u,
        )
        graph_op(() => {
          block_graph.set_edge(u_root, v_root, js_max(separation, prev_max))
        })
      }
      u = Some(v)
    }
  }
  block_graph
}

///|
/// Returns the alignment that has the smallest width of the given
/// alignments.
fn find_smallest_width_alignment(
  g : LayoutGraph,
  xss : Array[Map[String, Double]],
) -> Int32? raise LayoutError {
  let mut best : (Int32, Double)? = None
  for index, xs in xss {
    let mut max = @double.neg_infinity
    let mut min = @double.infinity
    for v, x in xs {
      let half_width = nd(g, v).width / 2.0
      max = js_max(x + half_width, max)
      min = js_min(x - half_width, min)
    }
    let width = max - min
    match best {
      None => if !width.is_nan() { best = Some((index, width)) }
      Some((_, current)) => if width < current { best = Some((index, width)) }
    }
  }
  best.map(pair => pair.0)
}

///|
/// Align the coordinates of each of the layout alignments such that
/// left-biased alignments have their minimum coordinate at the same point
/// as the minimum coordinate of the smallest width alignment and
/// right-biased alignments have their maximum coordinate at the same point
/// as the maximum coordinate of the smallest width alignment.
///
/// The alignments are in the order `ul`, `ur`, `dl`, `dr`.
fn align_coordinates(
  xss : Array[Map[String, Double]],
  align_to : Int32?,
) -> Unit {
  let align_to_vals = match align_to {
    Some(index) => xss[index].values().collect()
    None => []
  }
  let align_to_min = lodash_min(align_to_vals)
  let align_to_max = lodash_max(align_to_vals)
  for index in 0..<4 {
    if align_to == Some(index) {
      continue
    }
    let xs = xss[index]
    let xs_vals = xs.values().collect()
    // An extreme of nothing is undefined, and the difference not a number.
    let delta = if index % 2 == 0 {
      match (align_to_min, lodash_min(xs_vals)) {
        (Some(a), Some(b)) => a - b
        _ => @double.not_a_number
      }
    } else {
      match (align_to_max, lodash_max(xs_vals)) {
        (Some(a), Some(b)) => a - b
        _ => @double.not_a_number
      }
    }
    if truthy(delta) {
      let moved : Map[String, Double] = Map([])
      for v, x in xs {
        moved[v] = x + delta
      }
      xss[index] = moved
    }
  }
}

///|
fn balance(
  xss : Array[Map[String, Double]],
  align : String?,
) -> Map[String, Double] raise LayoutError {
  let result : Map[String, Double] = Map([])
  let at = (index : Int32, v : String) => {
    xss[index].get(v).unwrap_or(@double.not_a_number)
  }
  for v, _ in xss[0] {
    result[v] = match align {
      Some(align) if align != "" =>
        match align.to_lower() {
          "ul" => at(0, v)
          "ur" => at(1, v)
          "dl" => at(2, v)
          "dr" => at(3, v)
          other => raise LayoutError("there is no alignment \{other}")
        }
      _ => {
        let xs = sort_by([at(0, v), at(1, v), at(2, v), at(3, v)], x => x)
        (xs[1] + xs[2]) / 2.0
      }
    }
  }
  result
}

///|
fn position_x(g : LayoutGraph) -> Map[String, Double] raise LayoutError {
  let layering = build_layer_matrix(g)
  let conflicts : Conflicts = Map([])
  find_type1_conflicts(g, layering, conflicts)
  find_type2_conflicts(g, layering, conflicts)
  let xss : Array[Map[String, Double]] = []
  for vert in ["u", "d"] {
    let mut adjusted_layering = if vert == "u" {
      layering
    } else {
      layering.rev()
    }
    for horiz in ["l", "r"] {
      if horiz == "r" {
        adjusted_layering = adjusted_layering.map(inner => inner.rev())
      }
      let neighbor_fn = if vert == "u" {
        (v : String) => g.predecessors(v)
      } else {
        (v : String) => g.successors(v)
      }
      let (root, align) = vertical_alignment(
        adjusted_layering, conflicts, neighbor_fn,
      )
      let mut xs = horizontal_compaction(
        g,
        adjusted_layering,
        root,
        align,
        horiz == "r",
      )
      if horiz == "r" {
        let negated : Map[String, Double] = Map([])
        for v, x in xs {
          negated[v] = -x
        }
        xs = negated
      }
      xss.push(xs)
    }
  }
  let smallest_width = find_smallest_width_alignment(g, xss)
  align_coordinates(xss, smallest_width)
  balance(xss, g.graph().align)
}

///|
/// How far apart the centres of two neighbours `w` and `v` of a layer
/// have to be.
fn sep(
  g : LayoutGraph,
  node_sep : Double,
  edge_sep : Double,
  reverse_sep : Bool,
  v : String,
  w : String,
) -> Double raise LayoutError {
  let v_label = nd(g, v)
  let w_label = nd(g, w)
  let mut sum = 0.0
  let mut delta = 0.0
  sum = sum + v_label.width / 2.0
  if v_label.labelpos is Some(labelpos) {
    match labelpos.to_lower() {
      "l" => delta = -v_label.width / 2.0
      "r" => delta = v_label.width / 2.0
      _ => ()
    }
  }
  if truthy(delta) {
    sum = sum + (if reverse_sep { delta } else { -delta })
  }
  delta = 0.0
  sum = sum + (if v_label.dummy is Some(_) { edge_sep } else { node_sep }) / 2.0
  sum = sum + (if w_label.dummy is Some(_) { edge_sep } else { node_sep }) / 2.0
  sum = sum + w_label.width / 2.0
  if w_label.labelpos is Some(labelpos) {
    match labelpos.to_lower() {
      "l" => delta = w_label.width / 2.0
      "r" => delta = -w_label.width / 2.0
      _ => ()
    }
  }
  if truthy(delta) {
    sum = sum + (if reverse_sep { delta } else { -delta })
  }
  sum
}
