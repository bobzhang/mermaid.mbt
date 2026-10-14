// What the layout does before the nodes are measured:
// `prepareSwimlaneLayout`.

///|
/// Put every node outside a lane into a lane of its own and turn the
/// labels of edges into nodes: `prepareSwimlaneLayout`.
pub fn prepare(layout : @model.Layout) -> Unit {
  ignore(layout)
  abort("prepareSwimlaneLayout is not ported yet")
}

///|
/// Rank the nodes, order them and place them: `sugiyamaLayout` and
/// `writeBackToLayoutData`.
fn rank_and_place(layout : @model.Layout, direction : String) -> Unit {
  ignore(layout)
  ignore(direction)
  abort("sugiyamaLayout is not ported yet")
}
