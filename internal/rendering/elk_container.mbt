// Containers that lay out their children with an ELK algorithm of their
// own, asked for with `@{ algorithm: ... }`: part of mermaid's
// `layout-algorithms/elk/render.ts`.

///|
/// Padding inside a container with its own algorithm.
const CONTAINER_PADDING : Double = 15.0

///|
const RECTPACKING_CONTAINER_PADDING : Double = 10.0

///|
/// The algorithms a container may ask for.
let container_algorithms : Array[String] = [
  "elk.layered", "elk.box", "elk.rectpacking", "elk.stress", "elk.force", "elk.mrtree",
  "elk.radial", "elk.sporeOverlap",
]

///|
/// The options rectangle packing works with.
fn rectpacking_options() -> Array[(String, Json)] {
  [
    ("spacing.baseValue", 15),
    ("spacing.nodeNode", 15),
    ("elk.aspectRatio", "1.6"),
    ("elk.expandNodes", "true"),
    ("elk.rectpacking.trybox", "true"),
    ("elk.rectpacking.packing.compaction.rowHeightReevaluation", "true"),
    ("elk.rectpacking.packing.compaction.iterations", 10),
    (
      "elk.rectpacking.whiteSpaceElimination.strategy", "EQUAL_BETWEEN_STRUCTURES",
    ),
    ("elk.rectpacking.widthApproximation.strategy", "SCANLINE"),
  ]
}

///|
/// The algorithm a container asks for, if it is one a container may use:
/// mermaid's `resolveContainerAlgorithm`. Another name is ignored, with a
/// warning on the console.
fn container_algorithm(node : Node) -> String? {
  guard node.data is Container(metadata~) &&
    metadata.get("algorithm") is Some(String(algorithm)) &&
    container_algorithms.contains(algorithm) else {
    return None
  }
  Some(algorithm)
}

///|
/// The options of a container laid out on its own with `algorithm`.
fn apply_container_algorithm(
  options : Map[String, Json],
  node : ElkNode,
  algorithm : String,
) -> Unit {
  let n = @dom.number
  let (label_width, label_height) = match node.label_data {
    Some(data) => (data.width, data.height)
    None => (0.0, 0.0)
  }
  let min_width = label_width + 2.0 * node.node.padding
  let pad_top = label_height + CONTAINER_PADDING
  options["nodeSize.constraints"] = "[MINIMUM_SIZE, NODE_LABELS]"
  options["nodeSize.minimum"] = Json::string(
    "(\{n(min_width)}, \{n(pad_top + CONTAINER_PADDING)})",
  )
  options["elk.algorithm"] = Json::string(algorithm)
  options["elk.hierarchyHandling"] = "SEPARATE_CHILDREN"
  options["elk.aspectRatio"] = "2.0"
  options["elk.contentAlignment"] = "H_CENTER V_TOP"
  options["elk.expandNodes"] = "true"
  options["elk.padding"] = Json::string(
    "[top=\{n(pad_top)},left=15,bottom=15,right=15]",
  )
  if algorithm == "elk.rectpacking" {
    let rect_pad_top = label_height + RECTPACKING_CONTAINER_PADDING
    for option in rectpacking_options() {
      options[option.0] = option.1
    }
    options["elk.padding"] = Json::string(
      "[top=\{n(rect_pad_top)},left=10,bottom=10,right=10]",
    )
    options["nodeSize.minimum"] = Json::string(
      "(\{n(min_width)}, \{n(rect_pad_top + RECTPACKING_CONTAINER_PADDING)})",
    )
  }
}

///|
/// A container with its own algorithm that an edge crosses goes back to
/// the diagram's: mermaid's `clearContainerAlgorithmOptions`, followed by
/// the title's minimum size.
fn drop_container_algorithm(node : ElkNode) -> Unit {
  let options = node.layout_options
  guard options.get("elk.hierarchyHandling")
    is Some(String("SEPARATE_CHILDREN")) &&
    container_algorithm(node.node) is Some(_) else {
    return
  }
  let overridden = [
    "nodeSize.constraints", "nodeSize.minimum", "elk.algorithm", "elk.aspectRatio",
    "elk.contentAlignment", "elk.expandNodes", "elk.padding",
  ]
  for option in rectpacking_options() {
    overridden.push(option.0)
  }
  for key in overridden {
    options.remove(key)
  }
  options["spacing.baseValue"] = 24
  options["spacing.nodeNode"] = 50
  if cluster_paints_title(node.node.shape) {
    options["nodeSize.constraints"] = "[MINIMUM_SIZE, NODE_LABELS]"
    options["nodeSize.minimum"] = Json::string(
      "(\{@dom.number(node.title_width())}, 0)",
    )
  }
}
