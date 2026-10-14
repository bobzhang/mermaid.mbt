// Running the layout on a capture of upstream's input
// (`scripts/swimlane_capture.py`), for `cmd/mermaid swimlane`.

///|
/// Prepare the layout a capture holds, size its nodes as the browser
/// measured them and lay it out; `after_step` sees each step, starting
/// with `prepare`.
pub fn layout_capture(
  capture : Json,
  after_step? : (String, @model.Layout) -> Unit,
) -> @model.Layout raise @layering.LayeringError {
  let data = match capture {
    Object(fields) => fields.get("data").unwrap_or(Json::null())
    _ => Json::null()
  }
  let layout = @model.Layout::from_capture(data)
  let after = (name : String) => if after_step is Some(f) { f(name, layout) }
  @layering.prepare(layout)
  let sizes = @model.capture_sizes(capture)
  for node in layout.nodes {
    if !node.is_group && sizes.get(node.id) is Some((width, height)) {
      node.width = Some(width)
      node.height = Some(height)
    }
  }
  after("prepare")
  run_core(layout, after_step=after) |> ignore
  layout
}
