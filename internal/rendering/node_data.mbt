///|
/// A row of an entity in an ER diagram.
pub(all) struct EntityAttribute {
  type_ : String
  name : String
  keys : Array[String]
  comment : String
}

///|
/// What the shapes of one diagram type draw besides the node's label.
pub(all) enum NodeData {
  /// Nothing more.
  Plain
  /// An entity of an ER diagram: the name it is shown under, if not its
  /// own, and its rows.
  Entity(alias_name~ : String, attributes~ : Array[EntityAttribute])
  /// A requirement of a requirement diagram, with the words it shows.
  Requirement(
    name~ : String,
    type_~ : String,
    requirement_id~ : String,
    text~ : String,
    risk~ : String,
    verify_method~ : String
  )
  /// An element of a requirement diagram.
  RequirementElement(name~ : String, type_~ : String, doc_ref~ : String)
}
