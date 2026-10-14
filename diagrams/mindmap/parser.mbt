// The mindmap parser: the jison grammar of `mindmap.jison` with its
// semantic actions.

///|
/// The value of a grammar symbol: the text of a token, or a node with the
/// text inside and around its brackets.
priv enum Value {
  Text(String)
  Node(id~ : String, descr~ : String, type_~ : NodeType)
}

///|
fn Value::text(self : Value) -> String {
  match self {
    Text(text) => text
    Node(id~, ..) => id
  }
}

///|
/// jison's `performAction` for mindmap.jison: run the semantic action of
/// one production. `None` keeps the default value, that of the first
/// symbol.
fn MindmapDb::reduce(
  self : MindmapDb,
  reduction : @jison.Reduction[Value],
) -> Value? raise MindmapError {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let add = (level : Int32, node : Value) => {
    guard node is Node(id~, descr~, type_~) else { return }
    self.add_node(level, id, descr, type_)
  }
  match reduction.production {
    // SPACELIST node: the indentation is the length of the white space.
    15 => {
      add(v(1).text().length(), v(0))
      None
    }
    16 => {
      self.decorate_node(icon=v(0).text())
      None
    }
    17 | 21 => {
      self.decorate_node(class=v(0).text())
      None
    }
    19 => {
      add(0, v(0))
      None
    }
    20 => {
      self.decorate_node(icon=v(0).text())
      None
    }
    // NODE_DSTART NODE_DESCR NODE_DEND
    25 =>
      Some(
        Node(
          id=v(1).text(),
          descr=v(1).text(),
          type_=node_type(v(2).text(), v(0).text()),
        ),
      )
    // NODE_ID
    26 => Some(Node(id=v(0).text(), descr=v(0).text(), type_=Default))
    // NODE_ID NODE_DSTART NODE_DESCR NODE_DEND
    27 =>
      Some(
        Node(
          id=v(3).text(),
          descr=v(1).text(),
          type_=node_type(v(2).text(), v(0).text()),
        ),
      )
    _ => None
  }
}

///|
/// Read a mindmap: `source` is the diagram text after preprocessing.
pub fn parse(
  source : String,
  config : @config.Config,
) -> MindmapDb raise MindmapError {
  let db = MindmapDb::new(config)
  let _ = mindmap_grammar.parse(
    source,
    empty=Text(""),
    token=text => Text(text),
    reduce=reduction => db.reduce(reduction),
  ) catch {
    @jison.ParseError(message~, ..) => raise Invalid(message)
    Invalid(message) => raise Invalid(message)
    Unsupported(message) => raise Unsupported(message)
    error => raise Invalid(error.to_string())
  }
  db
}
