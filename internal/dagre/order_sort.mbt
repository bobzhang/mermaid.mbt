// dagre's `order/barycenter.js`, `order/resolve-conflicts.js`,
// `order/sort.js` and `order/sort-subgraph.js`: one layer is sorted by the
// barycenters of its nodes' neighbours in the fixed layer next to it,
// compound nodes as a whole and within the constraints between them.

///|
/// A node to sort, or several that have to stay together: `vs` in order,
/// the position `i` they had, and the weighted mean position of their
/// neighbours if they have any.
priv struct SortEntry {
  mut vs : Array[String]
  mut i : Int32
  mut barycenter : Double?
  mut weight : Double?
  // While conflicts are resolved.
  mut indegree : Int32
  ins : Array[SortEntry]
  out : Array[SortEntry]
  mut merged : Bool
}

///|
/// The barycenter of a node of the movable layer.
priv struct Barycenter {
  v : String
  mut barycenter : Double?
  mut weight : Double?
}

///|
fn order_in_layer(g : LayerGraph, v : String) -> Double raise LayoutError {
  match g.node(v) {
    Some(Leaf(label)) =>
      match label.order {
        Some(order) => order.to_double()
        // A position that is undefined is not a number.
        None => @double.not_a_number
      }
    _ => raise LayoutError("the node \{v} has no place in its layer")
  }
}

///|
fn barycenter(
  g : LayerGraph,
  movable : Array[String],
) -> Array[Barycenter] raise LayoutError {
  let result = []
  for v in movable {
    let in_v = g.in_edges(v)
    if in_v.is_empty() {
      result.push({ v, barycenter: None, weight: None, })
    } else {
      let mut sum = 0.0
      let mut weight = 0.0
      for e in in_v {
        let edge = ed(g, e)
        sum = sum + edge * order_in_layer(g, e.v)
        weight = weight + edge
      }
      result.push({ v, barycenter: Some(sum / weight), weight: Some(weight), })
    }
  }
  result
}

///|
/// Given a list of entries with a barycenter each and a constraint graph,
/// merges the entries that violate a constraint into one that keeps them
/// in the order the constraint asks for.
fn resolve_conflicts(
  entries : Array[Barycenter],
  cg : ConstraintGraph,
) -> Array[SortEntry] {
  let mapped : @graphlib.JsObject[SortEntry] = @graphlib.JsObject::new()
  for i, entry in entries {
    mapped.set(entry.v, {
      vs: [entry.v],
      i,
      barycenter: entry.barycenter,
      weight: if entry.barycenter is Some(_) {
        entry.weight
      } else {
        None
      },
      indegree: 0,
      ins: [],
      out: [],
      merged: false,
    })
  }
  for e in cg.edges() {
    if mapped.get(e.v) is Some(entry_v) && mapped.get(e.w) is Some(entry_w) {
      entry_w.indegree += 1
      entry_v.out.push(entry_w)
    }
  }
  let source_set = mapped.values().filter(entry => entry.indegree == 0)
  do_resolve_conflicts(source_set)
}

///|
fn do_resolve_conflicts(source_set : Array[SortEntry]) -> Array[SortEntry] {
  let entries = []
  while source_set.pop() is Some(entry) {
    entries.push(entry)
    entry.ins.rev_in_place()
    for u_entry in entry.ins {
      if u_entry.merged {
        continue
      }
      let merge = match (u_entry.barycenter, entry.barycenter) {
        (Some(u), Some(v)) => u >= v
        _ => true
      }
      if merge {
        merge_entries(entry, u_entry)
      }
    }
    for w_entry in entry.out {
      w_entry.ins.push(entry)
      w_entry.indegree -= 1
      if w_entry.indegree == 0 {
        source_set.push(w_entry)
      }
    }
  }
  entries.filter(entry => !entry.merged)
}

///|
fn merge_entries(target : SortEntry, source : SortEntry) -> Unit {
  let mut sum = 0.0
  let mut weight = 0.0
  if target.weight is Some(target_weight) && truthy(target_weight) {
    sum = sum +
      target.barycenter.unwrap_or(@double.not_a_number) * target_weight
    weight = weight + target_weight
  }
  if source.weight is Some(source_weight) && truthy(source_weight) {
    sum = sum +
      source.barycenter.unwrap_or(@double.not_a_number) * source_weight
    weight = weight + source_weight
  }
  target.vs = source.vs + target.vs
  target.barycenter = Some(sum / weight)
  target.weight = Some(weight)
  target.i = if source.i < target.i { source.i } else { target.i }
  source.merged = true
}

///|
/// A sorted layer, or part of one, and the barycenter of the whole.
priv struct Sorted {
  mut vs : Array[String]
  mut barycenter : Double?
  mut weight : Double
}

///|
fn sort_entries(entries : Array[SortEntry], bias_right : Bool) -> Sorted {
  let sortable = entries.filter(entry => entry.barycenter is Some(_))
  let unsortable = sort_by(entries.filter(entry => entry.barycenter is None), entry => {
    -entry.i.to_double()
  })
  let vs : Array[Array[String]] = []
  let mut sum = 0.0
  let mut weight = 0.0
  let mut vs_index = 0
  js_sort(sortable, (entry_v, entry_w) => {
    let v = entry_v.barycenter.unwrap_or(@double.not_a_number)
    let w = entry_w.barycenter.unwrap_or(@double.not_a_number)
    if v < w {
      -1
    } else if v > w {
      1
    } else if !bias_right {
      entry_v.i - entry_w.i
    } else {
      entry_w.i - entry_v.i
    }
  })
  vs_index = consume_unsortable(vs, unsortable, vs_index)
  for entry in sortable {
    vs_index += entry.vs.length()
    vs.push(entry.vs)
    let entry_weight = entry.weight.unwrap_or(@double.not_a_number)
    sum = sum + entry.barycenter.unwrap_or(@double.not_a_number) * entry_weight
    weight = weight + entry_weight
    vs_index = consume_unsortable(vs, unsortable, vs_index)
  }
  let result = { vs: vs.flatten(), barycenter: None, weight: 0.0, }
  if truthy(weight) {
    result.barycenter = Some(sum / weight)
    result.weight = weight
  }
  result
}

///|
fn consume_unsortable(
  vs : Array[Array[String]],
  unsortable : Array[SortEntry],
  index : Int32,
) -> Int32 {
  let mut index = index
  while unsortable.last() is Some(last) && last.i <= index {
    unsortable.pop() |> ignore
    vs.push(last.vs)
    index += 1
  }
  index
}

///|
fn sort_subgraph(
  g : LayerGraph,
  v : String,
  cg : ConstraintGraph,
  bias_right : Bool,
) -> Sorted raise LayoutError {
  let mut movable = g.children(v)
  let borders = match g.node(v) {
    Some(Group(bl, br)) if bl != "" => Some((bl, br))
    _ => None
  }
  let subgraphs : Map[String, Sorted] = Map([])
  if borders is Some((bl, br)) {
    movable = movable.filter(w => w != bl && w != br)
  }
  let barycenters = barycenter(g, movable)
  for entry in barycenters {
    if !g.children(entry.v).is_empty() {
      let subgraph_result = sort_subgraph(g, entry.v, cg, bias_right)
      subgraphs[entry.v] = subgraph_result
      if subgraph_result.barycenter is Some(other) {
        // `mergeBarycenters`
        match entry.barycenter {
          Some(own) => {
            let own_weight = entry.weight.unwrap_or(@double.not_a_number)
            entry.barycenter = Some(
              (own * own_weight + other * subgraph_result.weight) /
              (own_weight + subgraph_result.weight),
            )
            entry.weight = Some(own_weight + subgraph_result.weight)
          }
          None => {
            entry.barycenter = Some(other)
            entry.weight = Some(subgraph_result.weight)
          }
        }
      }
    }
  }
  let entries = resolve_conflicts(barycenters, cg)
  // `expandSubgraphs`
  for entry in entries {
    let expanded = []
    for w in entry.vs {
      match subgraphs.get(w) {
        Some(subgraph) => expanded.append(subgraph.vs)
        None => expanded.push(w)
      }
    }
    entry.vs = expanded
  }
  let result = sort_entries(entries, bias_right)
  if borders is Some((bl, br)) {
    result.vs = [bl, ..result.vs, br]
    if g.predecessors(bl) is [bl_pred, ..] {
      guard g.predecessors(br) is [br_pred, ..] else {
        raise LayoutError("the border node \{br} has no predecessor")
      }
      let bl_order = order_in_layer(g, bl_pred)
      let br_order = order_in_layer(g, br_pred)
      let barycenter = result.barycenter.unwrap_or(0.0)
      let weight = if result.barycenter is Some(_) {
        result.weight
      } else {
        0.0
      }
      result.barycenter = Some(
        (barycenter * weight + bl_order + br_order) / (weight + 2.0),
      )
      result.weight = weight + 2.0
    }
  }
  result
}
