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
  /// A block of a block diagram, which draws every block twice: once to
  /// measure it and once `positioned`, at the size its grid gives it.
  /// `directions` are those a block arrow points in, `style` the inline
  /// style of the outline of a composite or an arrow, `class_rules` the
  /// declarations of the block's classes in the order of their rules in
  /// the stylesheet.
  Block(
    positioned~ : Bool,
    directions~ : Array[String],
    width_in_columns~ : Double,
    style~ : String,
    class_rules~ : Array[String]
  )
  /// An element of a C4 diagram, whose label is stacked sections: its
  /// name, the `stereotype` (a type line such as `[Container: Node.js]`)
  /// and the node's description lines. The diagram's stylesheet sets the
  /// label in a font of its own: a CSS `font-family` list, a size in
  /// pixels, and whether the weight is bold.
  C4(
    stereotype~ : String,
    font_family~ : String,
    font_size~ : Double,
    bold~ : Bool
  )
}
