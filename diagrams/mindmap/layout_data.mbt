// What the mindmap hands to the unified renderer: `getData` of
// `mindmapDb.ts` with the per-shape settings of `mindmapRenderer.ts`.

///|
/// `getShapeFromType`: the shape that draws a kind of node. The redux
/// themes draw a node without brackets as a rounded box.
fn shape_of(type_ : NodeType, theme_name : String) -> String {
  match type_ {
    Circle => "mindmapCircle"
    Rect => "rect"
    RoundedRect => "rounded"
    Cloud => "cloud"
    Bang => "bang"
    Hexagon => "hexagon"
    Default =>
      if theme_name.to_lower().contains("redux") {
        "rounded"
      } else {
        "defaultMindmapNode"
      }
  }
}

///|
/// `flattenNodes`: the nodes in the order of the source, as the renderer
/// takes them.
fn MindmapDb::flatten_nodes(
  self : MindmapDb,
  node : MindmapNode,
  out : Array[@rendering.Node],
) -> Unit {
  let config = self.config
  let classes = ["mindmap-node"]
  if node.is_root {
    classes.push("section-root")
    classes.push("section--1")
  } else if node.section is Some(section) {
    classes.push("section-\{section}")
  }
  if node.class is Some(class) {
    classes.push(class)
  }
  let shape = shape_of(node.type_, config.text("theme").unwrap_or(""))
  // `mindmapRenderer.ts` adjusts some shapes before they are drawn.
  let (padding, width, height) = match shape {
    "rounded" => (15.0, 0.0, 0.0)
    "rect" => (10.0, 0.0, 0.0)
    "hexagon" => (node.padding, 0.0, 0.0)
    _ => (node.padding, node.width, 0.0)
  }
  let id = node.id.to_string()
  let node_data = @rendering.Node::new(
    id~,
    dom_id="node_\{id}",
    label=node.descr,
    label_type="markdown",
    padding~,
    css_classes=classes.join(" "),
    look=config.text("look").unwrap_or("classic"),
    shape~,
    center_label=true,
    icon?=node.icon,
  )
  out.push(node_data.placed(x=0.0, y=0.0, width~, height~, label_style=""))
  for child in node.children {
    self.flatten_nodes(child, out)
  }
}

///|
/// `generateEdges`: an edge from every node to each of its children,
/// classed by the child's section and the parent's depth.
fn MindmapDb::generate_edges(
  self : MindmapDb,
  node : MindmapNode,
  out : Array[@rendering.Edge],
) -> Unit {
  for child in node.children {
    let mut classes = "edge"
    if child.section is Some(section) {
      classes += " section-edge-\{section}"
    }
    classes += " edge-depth-\{node.level + 1}"
    let edge = @rendering.Edge::new(
      id="edge_\{node.id}_\{child.id}",
      start=node.id.to_string(),
      end=child.id.to_string(),
      thickness="normal",
      classes~,
      // The edge has no style; upstream writes `undefined` where it puts
      // the style into the path's.
      style=["undefined"],
      look=self.config.text("look").unwrap_or("classic"),
      curve="basis",
    )
    out.push(edge)
    self.generate_edges(child, out)
  }
}

///|
/// `getData`: the nodes and edges of the mindmap for the renderer.
pub fn MindmapDb::layout_data(
  self : MindmapDb,
) -> (Array[@rendering.Node], Array[@rendering.Edge]) {
  guard self.root() is Some(root) else { return ([], []) }
  assign_sections(
    root,
    None,
    0,
    self.config.text("mindmap.colorBy") == Some("depth"),
  )
  let nodes = []
  let edges = []
  self.flatten_nodes(root, nodes)
  self.generate_edges(root, edges)
  (nodes, edges)
}
