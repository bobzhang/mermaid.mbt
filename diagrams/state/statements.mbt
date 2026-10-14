// What the grammar builds: mermaid's `Stmt` objects. The parser hands the
// database a document of them, and the database rewrites them in place
// before reading states and transitions out of them.

///|
/// The `description` of a statement: missing, a text, or a title with a
/// description after it.
priv enum Description {
  Missing
  One(String)
  Many(Array[String])
}

///|
/// Whether JavaScript takes the description for true.
fn Description::is_set(self : Description) -> Bool {
  match self {
    Missing => false
    One(text) => text != ""
    Many(_) => true
  }
}

///|
fn Description::copy(self : Description) -> Description {
  match self {
    Many(items) => Many(items.copy())
    other => other
  }
}

///|
/// A note attached to a state.
priv struct Note {
  /// `left of` or `right of`.
  position : String
  text : String
}

///|
/// One statement of a document.
priv struct Stmt {
  /// `state`, `relation`, `classDef`, `style`, `applyClass`, `dir`,
  /// `click`, or empty for a statement the grammar leaves as bare text.
  kind : String
  mut id : String
  /// `default`, `fork`, `join`, `choice` or `divider`; a note names none.
  state_type : String?
  mut description : Description
  /// The statements between the braces of a composite state.
  mut doc : Array[Stmt]?
  note : Note?
  /// Set on `[*]`: whether it starts or ends its document.
  mut start : Bool?
  /// The class after `:::`.
  classes : Array[String]
  /// The two ends of a relation, or the state a click is bound to.
  state1 : Stmt?
  state2 : Stmt?
  /// The styles of a `classDef` or `style`, the class of a `class`, the
  /// direction of a `direction`, the address of a `click`.
  value : String
  tooltip : String
}

///|
fn Stmt::new(
  kind : String,
  id~ : String = "",
  state_type? : String,
  description~ : Description = Missing,
  doc? : Array[Stmt],
  note? : Note,
  classes~ : Array[String] = [],
  state1? : Stmt,
  state2? : Stmt,
  value~ : String = "",
  tooltip~ : String = "",
) -> Stmt {
  {
    kind,
    id,
    state_type,
    description,
    doc,
    note,
    start: None,
    classes,
    state1,
    state2,
    value,
    tooltip,
  }
}

///|
/// A deep copy: upstream's `JSON.parse(JSON.stringify(o))`.
fn Stmt::clone(self : Stmt) -> Stmt {
  {
    ..self,
    description: self.description.copy(),
    doc: self.doc.map(clone_doc),
    classes: self.classes.copy(),
    state1: self.state1.map(Stmt::clone),
    state2: self.state2.map(Stmt::clone),
  }
}

///|
fn clone_doc(doc : Array[Stmt]) -> Array[Stmt] {
  doc.map(Stmt::clone)
}

///|
/// JavaScript's `String.prototype.trim`.
fn trim(text : String) -> String {
  text.trim(chars=" \t\n\r\u{0B}\u{0C}\u{A0}\u{FEFF}").to_owned()
}
