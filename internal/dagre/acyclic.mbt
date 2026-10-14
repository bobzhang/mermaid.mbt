// dagre's `acyclic.js`: edges are reversed until no cycle is left, and
// turned back once the layout is done.

///|
fn acyclic_run(g : LayoutGraph) -> Unit raise LayoutError {
  let fas = if g.graph().acyclicer is Some("greedy") {
    greedy_fas(g)
  } else {
    dfs_fas(g)
  }
  for e in fas {
    let label = ed(g, e)
    g.remove_edge(e)
    label.forward_name = e.name
    label.reversed = true
    let name = unique_id("rev")
    graph_op(() => g.set_edge(e.w, e.v, label, name~))
  }
}

///|
/// The edges that close a cycle in a depth-first search of the graph.
fn dfs_fas(g : LayoutGraph) -> Array[@graphlib.Edge] {
  let fas = []
  let stack : Map[String, Unit] = Map([])
  let visited : Map[String, Unit] = Map([])
  fn dfs(v : String) -> Unit {
    if visited.contains(v) {
      return
    }
    visited[v] = ()
    stack[v] = ()
    for e in g.out_edges(v) {
      if stack.contains(e.w) {
        fas.push(e)
      } else {
        dfs(e.w)
      }
    }
    stack.remove(v)
  }

  for v in g.nodes() {
    dfs(v)
  }
  fas
}

///|
fn acyclic_undo(g : LayoutGraph) -> Unit raise LayoutError {
  for e in g.edges() {
    let label = ed(g, e)
    if label.reversed {
      g.remove_edge(e)
      let forward_name = label.forward_name
      label.reversed = false
      label.forward_name = None
      graph_op(() => g.set_edge(e.w, e.v, label, name?=forward_name))
    }
  }
}
