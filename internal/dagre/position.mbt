// dagre's `position/index.js`.

///|
fn position(g : LayoutGraph) -> Unit raise LayoutError {
  let g = as_non_compound_graph(g)
  position_y(g)
  for v, x in position_x(g) {
    nd(g, v).x = x
  }
}

///|
/// Every rank is as high as its highest node, and `ranksep` from the
/// next.
fn position_y(g : LayoutGraph) -> Unit raise LayoutError {
  let layering = build_layer_matrix(g)
  let rank_sep = g.graph().ranksep
  let mut prev_y = 0.0
  for layer in layering {
    let heights = []
    for v in layer {
      heights.push(nd(g, v).height)
    }
    // The height of a rank without a node is undefined, and every
    // coordinate from there on not a number.
    let max_height = lodash_max(heights).unwrap_or(@double.not_a_number)
    for v in layer {
      nd(g, v).y = prev_y + max_height / 2.0
    }
    prev_y = prev_y + (max_height + rank_sep)
  }
}
