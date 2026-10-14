///|
/// Why a Wardley map cannot be rendered.
pub(all) suberror WardleyError {
  /// The map is invalid, with upstream's message.
  Invalid(String)
  /// What the port cannot reproduce exactly and therefore refuses.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// A point of the map: anchors, components and the components of
/// pipelines. `x` (evolution) and `y` (visibility) are percentages.
pub struct Node {
  id : String
  mut label : String
  mut x : Double
  mut y : Double
  /// `anchor`, `component` or `pipeline-component`.
  mut class_name : String
  mut label_offset_x : Double?
  mut label_offset_y : Double?
  mut in_pipeline : Bool
  mut is_pipeline_parent : Bool
  mut inertia : Bool
  /// `build`, `buy`, `outsource` or `market`.
  mut source_strategy : String?
} derive(Debug)

///|
/// Which ends of a link carry an arrow head.
pub(all) enum Flow {
  Forward
  Backward
  Bidirectional
} derive(Eq, Debug)

///|
/// A dependency between two nodes, by id.
pub struct Link {
  source : String
  target : String
  dashed : Bool
  label : String?
  flow : Flow?
} derive(Debug)

///|
/// Where a node is evolving to.
pub struct Trend {
  node_id : String
  mut target_x : Double
  mut target_y : Double
} derive(Debug)

///|
/// A pipeline: the node it hangs from and its components, by id.
pub struct Pipeline {
  node_id : String
  mut component_ids : Array[String]
} derive(Debug)

///|
/// A numbered mark on the map, explained in the annotations box.
pub struct Annotation {
  number : Double
  x : Double
  y : Double
  text : String
} derive(Debug)

///|
/// Free text, an accelerator or a deaccelerator at a point of the map.
pub struct Placed {
  text : String
  x : Double
  y : Double
} derive(Debug)

///|
/// A parsed Wardley map: what upstream's `WardleyBuilder` holds.
pub struct Wardley {
  nodes : Array[Node]
  priv node_index : Map[String, Node]
  links : Array[Link]
  trends : Array[Trend]
  pipelines : Array[Pipeline]
  annotations : Array[Annotation]
  notes : Array[Placed]
  accelerators : Array[Placed]
  deaccelerators : Array[Placed]
  mut annotations_box : (Double, Double)?
  /// The names of the evolution stages; the default ones when empty.
  mut stages : Array[String]
  /// Where each stage ends, as a fraction of the axis.
  mut stage_boundaries : Array[Double]?
  mut size : (Double, Double)?
  mut title : String
  mut acc_title : String
  mut acc_description : String
}

///|
fn Wardley::new() -> Wardley {
  {
    nodes: [],
    node_index: Map([]),
    links: [],
    trends: [],
    pipelines: [],
    annotations: [],
    notes: [],
    accelerators: [],
    deaccelerators: [],
    annotations_box: None,
    stages: [],
    stage_boundaries: None,
    size: None,
    title: "",
    acc_title: "",
    acc_description: "",
  }
}

///|
/// Give the map a title, as its frontmatter does.
pub fn Wardley::set_title(self : Wardley, title : String) -> Unit {
  self.title = title
}

///|
/// The node with this id.
pub fn Wardley::node(self : Wardley, id : String) -> Node? {
  self.node_index.get(id)
}

///|
/// `WardleyBuilder.addNode`: a node declared again keeps its place among
/// the nodes and its part in pipelines; its position, label, inertia and
/// strategy are replaced, and its label offsets when new ones are given.
fn Wardley::add_node(
  self : Wardley,
  id : String,
  label : String,
  x : Double,
  y : Double,
  class_name : String,
  label_offset_x~ : Double? = None,
  label_offset_y~ : Double? = None,
  inertia~ : Bool = false,
  source_strategy~ : String? = None,
) -> Unit {
  match self.node_index.get(id) {
    Some(node) => {
      node.label = label
      node.x = x
      node.y = y
      node.class_name = class_name
      if label_offset_x is Some(_) {
        node.label_offset_x = label_offset_x
      }
      if label_offset_y is Some(_) {
        node.label_offset_y = label_offset_y
      }
      node.inertia = inertia
      node.source_strategy = source_strategy
    }
    None => {
      let node : Node = {
        id,
        label,
        x,
        y,
        class_name,
        label_offset_x,
        label_offset_y,
        in_pipeline: false,
        is_pipeline_parent: false,
        inertia,
        source_strategy,
      }
      self.nodes.push(node)
      self.node_index[id] = node
    }
  }
}

///|
/// `WardleyBuilder.resolveNodeId`: the name of a node, or failing that
/// the label of one — which is how the components of a pipeline, whose
/// ids are made up, are linked to.
fn Wardley::resolve_node_id(self : Wardley, name : String) -> String {
  if self.node_index.contains(name) {
    return name
  }
  for node in self.nodes {
    if node.label == name {
      return node.id
    }
  }
  name
}

///|
/// `WardleyBuilder.startPipeline`: a pipeline declared again starts over,
/// in the place of the first.
fn Wardley::start_pipeline(self : Wardley, node_id : String) -> Unit {
  match self.pipelines.search_by(pipeline => pipeline.node_id == node_id) {
    Some(index) => self.pipelines[index].component_ids = []
    None => self.pipelines.push({ node_id, component_ids: [], })
  }
  if self.node_index.get(node_id) is Some(node) {
    node.is_pipeline_parent = true
  }
}

///|
/// `WardleyBuilder.addPipelineComponent`
fn Wardley::add_pipeline_component(
  self : Wardley,
  pipeline_node_id : String,
  component_id : String,
) -> Unit {
  if self.pipelines.search_by(pipeline => pipeline.node_id == pipeline_node_id)
    is Some(index) {
    self.pipelines[index].component_ids.push(component_id)
  }
  if self.node_index.get(component_id) is Some(node) {
    node.in_pipeline = true
  }
}

///|
/// `WardleyBuilder.addTrend`: one trend per node, the last one given.
fn Wardley::add_trend(
  self : Wardley,
  node_id : String,
  target_x : Double,
  target_y : Double,
) -> Unit {
  match self.trends.search_by(trend => trend.node_id == node_id) {
    Some(index) => {
      self.trends[index].target_x = target_x
      self.trends[index].target_y = target_y
    }
    None => self.trends.push({ node_id, target_x, target_y, })
  }
}
