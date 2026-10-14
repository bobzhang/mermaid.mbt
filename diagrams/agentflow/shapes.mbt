// Agentflow's shape vocabulary and its node kinds: mermaid's
// `agentflow/shapes.ts` and `agentflow/colorSlots.ts`.

///|
/// The author-facing shape names and the shapes they stand for. `round`
/// is a forgiving alias of `rect`, which drawing turns into the default.
let shape_aliases : Map[String, String] = {
  "task": "roundedRect",
  "tool": "subroutine",
  "input": "lean-right",
  "decision": "diamond",
  "refdoc": "lin-doc",
  "action": "hexagon",
  "round": "rect",
}

///|
/// Shapes agentflow removed: a node asking for one is drawn with the
/// default shape, and an error is reported on the console only.
let removed_shapes : Array[String] = [
  "doc", "stadium", "terminal", "circle", "trapezoid", "inv_trapezoid", "inv-trapezoid",
  "doublecircle", "double-circle", "typeDeclaration", "procs", "lean_left", "lean-left",
  "in-out", "cylinder", "ellipse", "odd", "tag-rect", "tagged-rectangle", "delay",
  "half-rounded-rectangle", "lin-rect", "lined-rectangle", "win-pane", "window-pane",
  "curv-trap", "curved-trapezoid",
]

///|
/// The shapes nodes are drawn with; any other falls back to the default.
let allowed_shapes : Array[String] = [
  "roundedRect", "subroutine", "subprocess", "subproc", "framed-rectangle", "lean-right",
  "diamond", "lin-doc", "lined-document", "hexagon", "hex", "connector", "collapsedGroup",
]

///|
const DEFAULT_SHAPE : String = "roundedRect"

///|
/// The shape an alias stands for, or the name itself.
fn resolve_shape_alias(shape : String) -> String {
  shape_aliases.get(shape).unwrap_or(shape)
}

///|
/// The shape a node is finally drawn with: mermaid's
/// `normaliseNodeShapes` for one node that is not a group.
fn normalise_shape(shape : String) -> String {
  if shape is ("squareRect" | "rect") {
    return DEFAULT_SHAPE
  }
  if removed_shapes.contains(shape) || !allowed_shapes.contains(shape) {
    DEFAULT_SHAPE
  } else {
    shape
  }
}

///|
/// The shapes that make a node a tool.
let tool_shapes : Array[String] = [
  "subroutine", "subprocess", "subproc", "framed-rectangle", "tool",
]

///|
/// The palette slot of every node kind, in palette order.
let kind_slots : Array[(String, Int32)] = [
  ("tool", 0),
  ("task", 1),
  ("decision", 2),
  ("input", 3),
  ("refdoc", 4),
  ("connector", 5),
  ("action", 6),
]

///|
/// How many palette slots the node kinds take; containers cycle the
/// slots above them.
let kind_count : Int32 = kind_slots.length()

///|
/// The kind of a node that is not a connector: mermaid's
/// `deriveVertexKind`. Tool-ness comes from the shape as written,
/// the rest from the shape an alias resolves to.
fn vertex_kind(shape : String?) -> String {
  guard shape is Some(shape) else { return "task" }
  if tool_shapes.contains(shape) {
    return "tool"
  }
  match resolve_shape_alias(shape) {
    "hexagon" | "hex" => "action"
    "lean-right" | "lean_right" => "input"
    "lin-doc" | "lined-document" => "refdoc"
    "diamond" => "decision"
    _ => "task"
  }
}

///|
/// How many slots containers cycle through for a palette of the given
/// length: at least one.
fn container_slot_count(palette_length : Int32) -> Int32 {
  (palette_length - kind_count).max(1)
}

///|
/// The palette slot of the `n`th container.
fn container_slot(n : Int32, palette_length : Int32) -> Int32 {
  let slot = kind_count + n % container_slot_count(palette_length)
  if palette_length > 0 {
    slot % palette_length
  } else {
    slot
  }
}
