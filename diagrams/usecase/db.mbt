///|
/// What goes wrong while a use case diagram is read or drawn.
pub(all) suberror UsecaseError {
  /// The source is not a use case diagram upstream accepts.
  Invalid(String)
  /// Upstream accepts it; the port cannot reproduce what it makes of it.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// The markers of an association: mermaid's `ARROW_TYPE`.
const SOLID_ARROW : Int32 = 0

///|
const BACK_ARROW : Int32 = 1

///|
const LINE_SOLID : Int32 = 2

///|
const CIRCLE_ARROW : Int32 = 3

///|
const CROSS_ARROW : Int32 = 4

///|
const CIRCLE_ARROW_REVERSED : Int32 = 5

///|
const CROSS_ARROW_REVERSED : Int32 = 6

///|
priv struct Actor {
  id : String
  label : String
  label_type : String
  /// `normal`, `hollow`, `awesome` or `icon`.
  type_ : String
  icon : String?
  business : Bool
  stereotype : String?
  parent_id : String?
  classes : Array[String]
  styles : Array[String]
}

///|
priv struct UseCase {
  id : String
  label : String
  label_type : String
  /// `ellipse` or `rect`.
  shape : String
  business : Bool
  stereotype : String?
  parent_id : String?
  classes : Array[String]
  styles : Array[String]
}

///|
priv struct Boundary {
  id : String
  label : String
  label_type : String
  /// `rect` or `package`.
  mut type_ : String
  mut classes : Array[String]
  styles : Array[String]
}

///|
priv struct Relationship {
  id : String
  explicit_id : Bool
  source : String
  target : String
  /// `association`, `include`, `extend` or `generalization`.
  type_ : String
  arrow_type : Int32
  label : String?
  label_type : String?
  minlen : Int32
  classes : Array[String]
  styles : Array[String]
  mut animate : Bool
  mut animation : String?
}

///|
priv struct Note {
  id : String
  target : String
  label : String
  label_type : String
}

///|
priv struct JsonNode {
  id : String
  value : JsonValue
  classes : Array[String]
  styles : Array[String]
}

///|
/// A parsed use case diagram: mermaid's `usecaseDb` once a model is
/// committed to it.
pub struct UsecaseDb {
  priv config : @config.Config
  priv actors : Map[String, Actor]
  priv use_cases : Map[String, UseCase]
  priv boundaries : Map[String, Boundary]
  priv relationships : Array[Relationship]
  priv notes : Map[String, Note]
  priv json_nodes : Map[String, JsonNode]
  priv class_defs : Map[String, Array[String]]
  priv mut direction : String
  mut acc_title : String
  mut acc_description : String
}

///|
fn UsecaseDb::new(config : @config.Config) -> UsecaseDb {
  {
    config,
    actors: Map([]),
    use_cases: Map([]),
    boundaries: Map([]),
    relationships: [],
    notes: Map([]),
    json_nodes: Map([]),
    class_defs: Map([]),
    direction: "LR",
    acc_title: "",
    acc_description: "",
  }
}
