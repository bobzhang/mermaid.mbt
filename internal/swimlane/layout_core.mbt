// The swimlane layout: `swimlanes/index.ts` and `swimlanes/layoutCore.ts`.

///|
/// Lay out a prepared and measured layout: `runSwimlaneLayoutCore`.
/// `after_step` sees the layout after each step, by the names of
/// `scripts/swimlane_oracle.js --stages`. Returns the direction.
pub fn run_core(
  layout : @model.Layout,
  after_step? : (String) -> Unit,
) -> String {
  let after = (name : String) => if after_step is Some(f) { f(name) }
  let direction = layout_direction(layout)
  rank_and_place(layout, direction)
  for edge in layout.edges {
    edge.points = None
  }
  after("sugiyama")
  route(layout, direction)
  after("route")
  post_process(layout, direction, after_step=after)
  direction
}

///|
/// The diagram's direction; top to bottom by default:
/// `getSwimlaneDirection`.
pub fn layout_direction(layout : @model.Layout) -> String {
  layout.direction.unwrap_or("TB")
}
