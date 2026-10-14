///|
/// A row of an entity in an ER diagram.
pub(all) struct EntityAttribute {
  type_ : String
  name : String
  keys : Array[String]
  comment : String
}

///|
/// A line of a class box: its text as markdown, and the style its
/// classifier asks for.
pub(all) struct ClassBoxMember {
  text : String
  style : String
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
  /// A class of a class diagram: its title and what its box lists.
  ClassBox(
    text~ : String,
    annotations~ : Array[String],
    members~ : Array[ClassBoxMember],
    methods~ : Array[ClassBoxMember]
  )
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
  /// An item of a kanban board: its ticket, as given and as its label
  /// shows it, and whom it is assigned to, empty when it has none; its
  /// priority, if any; and whether it has an icon, which only gives its
  /// title a background.
  KanbanItem(
    ticket~ : String,
    ticket_text~ : String,
    assigned~ : String,
    priority~ : String?,
    icon~ : Bool
  )
  /// A container of an agentflow, expanded or collapsed, with its
  /// `@{ ... }` metadata: `algorithm` picks the layout of its children,
  /// `containerType` the look of the collapsed node.
  Container(metadata~ : Map[String, Json])
}
