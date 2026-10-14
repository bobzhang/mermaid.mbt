// The semantic actions of mermaid's `kanban.jison`.

///|
/// What a grammar symbol stands for while parsing.
priv enum Value {
  /// No value: jison's `undefined`.
  Nothing
  /// The text of a token.
  Text(String)
  /// A node as written: its id and the description in its brackets.
  NodeRef(id~ : String, description~ : String)
}

///|
/// `/\n\s*/g`, the line breaks inside a quoted metadata value.
let line_break : @jsregex.Regex = try! @jsregex.Regex::compile(
  "\\n\\s*",
  flags="g",
)

///|
/// The grammar's custom lexer code, by number (see the head of
/// `gen_kanban_grammar.mbt`).
fn lexer_hook(hook : Int32, lexer : @jison.Lexer) -> @jison.HookResult {
  match hook {
    0 => lexer.set_text("")
    2 => lexer.set_text(line_break.replace_all(lexer.text(), _ => "<br/>"))
    _ => ()
  }
  Continue
}

///|
/// jison's `performAction` for kanban.jison: run the semantic action of
/// one production. `None` keeps the default value, that of the first
/// symbol.
fn KanbanDb::reduce(
  self : KanbanDb,
  reduction : @jison.Reduction[Value],
) -> Value? raise KanbanError {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let s = (k : Int32) => {
    match v(k) {
      Text(text) => text
      _ => ""
    }
  }
  let add = (level : Int32, node : Value, shape_data : String?) => {
    if node is NodeRef(id~, description~) {
      self.add_node(level, id, description, shape_data)
    }
  }
  match reduction.production {
    15 => add(s(2).length(), v(1), Some(s(0)))
    16 => add(s(1).length(), v(0), None)
    20 => add(0, v(1), Some(s(0)))
    21 => add(0, v(0), None)
    17 | 22 => self.set_icon(s(0))
    27 => return Some(NodeRef(id=s(1), description=s(1)))
    28 => return Some(NodeRef(id=s(0), description=s(0)))
    29 => return Some(NodeRef(id=s(3), description=s(1)))
    30 => return Some(Text(s(1) + s(0)))
    _ => ()
  }
  None
}

///|
/// Parse kanban diagram source into its database.
pub fn parse(source : String, config : @config.Config) -> KanbanDb raise {
  let db = KanbanDb::new(config)
  kanban_grammar.parse(
    source,
    empty=Nothing,
    token=text => Text(text),
    reduce=reduction => db.reduce(reduction),
    hook=lexer_hook,
  )
  |> ignore
  db
}
