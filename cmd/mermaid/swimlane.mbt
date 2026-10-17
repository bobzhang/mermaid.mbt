///|
/// `swimlane <capture.json> [--stages]` lays out a capture of
/// `scripts/swimlane_capture.py` and prints the layout as
/// `scripts/swimlane_oracle.js` does; `swimlane --from <snapshot.json>
/// --run STEP [--direction D]` runs one step on a snapshot.
fn swimlane(options : ArrayView[String]) -> Unit raise CliError {
  let mut from = None
  let mut step = None
  let mut direction = "TB"
  let mut stages = false
  let mut capture = None
  let mut rest = options
  while true {
    match rest {
      ["--from", value, .. tail] => {
        from = Some(value)
        rest = tail
      }
      ["--run", value, .. tail] => {
        step = Some(value)
        rest = tail
      }
      ["--direction", value, .. tail] => {
        direction = value
        rest = tail
      }
      ["--stages", .. tail] => {
        stages = true
        rest = tail
      }
      [path, .. tail] => {
        capture = Some(path)
        rest = tail
      }
      [] => break
    }
  }
  let plain = (snapshot : Json) => {
    guard snapshot is Object(fields) else { return snapshot }
    Json::object(
      Map([
        ("nodes", fields.get("nodes").unwrap_or(Json::array([]))),
        ("edges", fields.get("edges").unwrap_or(Json::array([]))),
      ]),
    )
  }
  if from is Some(path) {
    guard step is Some(step) else {
      raise CliError("--from needs --run STEP", status=2)
    }
    let layout = @model.Layout::from_snapshot(read_json(path), direction~)
    @swimlane.run_step(layout, step, direction) catch {
      @swimlane.UnknownStep(name) =>
        raise CliError("unknown step \{name}", status=2)
    }
    println(plain(layout.snapshot("step")).stringify())
    return
  }
  guard capture is Some(path) else {
    raise CliError("usage: swimlane <capture.json> [--stages]", status=2)
  }
  let snapshots = []
  let layout = @swimlane.layout_capture(read_json(path), after_step=(
    name,
    layout,
  ) => if stages { snapshots.push(layout.snapshot(name)) }) catch {
    @layering.LayeringError(message) => raise CliError(message, status=1)
    error => raise CliError(error.to_string(), status=1)
  }
  if stages {
    println(Json::object(Map([("stages", Json::array(snapshots))])).stringify())
  } else {
    println(plain(layout.snapshot("final")).stringify())
  }
}
