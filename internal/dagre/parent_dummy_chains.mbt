// dagre's `parent-dummy-chains.js`: the dummy nodes of an edge are nested
// in the compound nodes the edge passes through, so that it leaves and
// enters them through their borders.

///|
fn parent_dummy_chains(g : LayoutGraph) -> Unit raise LayoutError {
  let postorder_nums = dummy_postorder(g)
  for start in g.graph().dummy_chains {
    let mut v = start
    let mut node = nd(g, v)
    guard node.edge_obj is Some(edge_obj) else {
      raise LayoutError("the dummy node \{v} stands for no edge")
    }
    let (path, lca) = find_path(g, postorder_nums, edge_obj.v, edge_obj.w)
    let mut path_idx = 0
    let mut path_v : String? = path.get(path_idx).unwrap_or(None)
    let mut ascending = true
    while v != edge_obj.w {
      node = nd(g, v)
      let rank = rank_of(g, v)
      if ascending {
        while true {
          path_v = path.get(path_idx).unwrap_or(None)
          guard path_v != lca else { break }
          guard path_v is Some(group) else {
            raise LayoutError("the path of \{v} leaves the graph")
          }
          // A comparison with a rank that is undefined is false.
          guard nd(g, group).max_rank is Some(max) && max < rank else { break }
          path_idx += 1
        }
        if path_v == lca {
          ascending = false
        }
      }
      if !ascending {
        while path_idx < path.length() - 1 {
          path_v = path[path_idx + 1]
          guard path_v is Some(group) else {
            raise LayoutError("the path of \{v} leaves the graph")
          }
          guard nd(g, group).min_rank is Some(min) && min <= rank else { break }
          path_idx += 1
        }
        path_v = path.get(path_idx).unwrap_or(None)
      }
      let (child, parent) = (v, path_v)
      graph_op(() => g.set_parent(child, parent?))
      guard g.successors(v) is [next, ..] else {
        raise LayoutError("the dummy node \{v} leads nowhere")
      }
      v = next
    }
    ignore(node)
  }
}

///|
/// Find a path from v to w through the lowest common ancestor (LCA).
/// Return the full path and the LCA.
fn find_path(
  g : LayoutGraph,
  postorder_nums : Map[String, (Int32, Int32)],
  v : String,
  w : String,
) -> (Array[String?], String?) raise LayoutError {
  let num = (v : String) => {
    match postorder_nums.get(v) {
      Some(pair) => pair
      None => raise LayoutError("the node \{v} is not in the graph")
    }
  }
  let v_path : Array[String?] = []
  let w_path : Array[String?] = []
  let low = if num(v).0 < num(w).0 { num(v).0 } else { num(w).0 }
  let lim = if num(v).1 > num(w).1 { num(v).1 } else { num(w).1 }
  // Traverse up from v to find the LCA.
  let mut parent : String? = Some(v)
  while true {
    parent = match parent {
      Some(current) => g.parent(current)
      None => None
    }
    v_path.push(parent)
    guard parent is Some(current) && current != "" else { break }
    guard num(current).0 > low || lim > num(current).1 else { break }
  }
  let lca = parent
  // Traverse from w to LCA.
  parent = Some(w)
  while true {
    parent = match parent {
      Some(current) => g.parent(current)
      None => None
    }
    guard parent != lca else { break }
    guard parent is Some(_) else {
      raise LayoutError("the node \{w} is not under the common ancestor")
    }
    w_path.push(parent)
  }
  w_path.rev_in_place()
  v_path.append(w_path)
  (v_path, lca)
}

///|
/// The interval of postorder numbers under every node of the nesting
/// tree: `low` and `lim`.
fn dummy_postorder(g : LayoutGraph) -> Map[String, (Int32, Int32)] {
  let result = Map([])
  let mut lim = 0
  fn dfs(v : String) -> Unit {
    let low = lim
    for child in g.children(v) {
      dfs(child)
    }
    result[v] = (low, lim)
    lim += 1
  }

  for v in g.top_children() {
    dfs(v)
  }
  result
}
