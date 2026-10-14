// A window on the layout engine for debugging: the graphs handed to ELK
// and what came back, so that a layout that differs from mermaid's can be
// pinned on the graph or on the engine (`cmd/mermaid elk-graph`).

///|
/// The graphs laid out since tracing was switched on: the input as JSON
/// text, taken before the engine writes positions into it, and the result.
let traced : Ref[Array[(String, Json)]?] = Ref(None)

///|
/// Start recording every graph handed to ELK.
pub fn trace_elk_graphs() -> Unit {
  traced.val = Some([])
}

///|
/// The graphs recorded so far, each with its layout.
pub fn traced_elk_graphs() -> Array[(String, Json)] {
  traced.val.unwrap_or([])
}

///|
/// The graph as text when tracing is on.
fn traced_input(input : Json) -> String? {
  match traced.val {
    Some(_) => Some(input.stringify())
    None => None
  }
}

///|
fn trace_graph(input : String?, result : Json) -> Unit {
  if traced.val is Some(log) && input is Some(input) {
    log.push((input, result))
  }
}
