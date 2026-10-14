///|
/// A semantic value of the grammar: the text of a token, a statement, or
/// the statements of a document.
priv enum Value {
  Null
  Text(String)
  Statement(Stmt)
  Document(Array[Stmt])
}

///|
fn Value::text(self : Value) -> String {
  match self {
    Text(text) => text
    _ => ""
  }
}

///|
/// mermaid's `trimColon`.
fn trim_colon(text : String) -> String {
  match text.strip_prefix(":") {
    Some(rest) => trim(rest.to_owned())
    None => trim(text)
  }
}

///|
/// The text of a token without its last `count` characters, trimmed.
fn without_suffix(text : String, count : Int32) -> String {
  let end = text.length() - count
  if end <= 0 {
    ""
  } else {
    trim(text[:end].to_owned())
  }
}

///|
/// The grammar's `processId`: an id ends where a `%%` comment starts, and
/// the comment goes back to the input. An id that is all comment is not an
/// id.
fn process_id(lexer : @jison.Lexer) -> @jison.HookResult {
  let text = lexer.text()
  match text.find("%%") {
    Some(0) => Stop
    Some(index) => {
      lexer.unput(text.length() - index)
      Continue
    }
    None => Continue
  }
}

///|
/// The grammar's custom lexer code; the numbers are those listed at the
/// top of gen_state_grammar.mbt.
fn lexer_hook(hook : Int32, lexer : @jison.Lexer) -> @jison.HookResult {
  match hook {
    0 | 1 | 3 | 4 => lexer.set_text(without_suffix(lexer.text(), 8))
    2 | 5 => lexer.set_text(without_suffix(lexer.text(), 10))
    6 | 8 | 9 | 12 => return process_id(lexer)
    7 =>
      lexer.fail(
        "Error: State name must be a single word. Found: \"\{trim(lexer.text())}\"",
      )
    10 => {
      let text = lexer.text()
      lexer.set_text(
        if text.length() <= 2 {
          ""
        } else {
          trim(text[2:].to_owned())
        },
      )
    }
    11 => lexer.set_text(without_suffix(lexer.text(), 8))
    13 => lexer.set_text(trim(lexer.text()))
    _ => ()
  }
  Continue
}

///|
/// jison's `performAction` for stateDiagram.jison: the semantic action of
/// one production. `None` keeps the default value, that of the first
/// symbol.
fn StateDb::reduce(
  self : StateDb,
  reduction : @jison.Reduction[Value],
) -> Value? {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let state = (id : Value, state_type : String) => {
    Some(Statement(Stmt::new("state", id=id.text(), state_type~)))
  }
  let id_statement = (id : Value, classes : Array[String]) => {
    Some(
      Statement(
        Stmt::new(
          "state",
          id=trim(id.text()),
          state_type="default",
          description=One(""),
          classes~,
        ),
      ),
    )
  }
  let direction = (value : String) => Some(Statement(Stmt::new("dir", value~)))
  match reduction.production {
    3 => {
      if v(0) is Document(doc) {
        self.root_doc = doc
      }
      Some(v(0))
    }
    4 => Some(Document([]))
    5 => {
      guard v(1) is Document(doc) else { return None }
      match v(0) {
        Text("nl") => ()
        Statement(statement) => doc.push(statement)
        // A statement the grammar gives no object is kept as it is.
        _ => doc.push(Stmt::new(""))
      }
      None
    }
    6 | 7 | 12 => Some(v(0))
    8 => Some(Text("nl"))
    13 => {
      if v(1) is Statement(statement) {
        statement.description = One(trim_colon(v(0).text()))
      }
      Some(v(1))
    }
    14 =>
      match (v(2), v(0)) {
        (Statement(state1), Statement(state2)) =>
          Some(Statement(Stmt::new("relation", state1~, state2~)))
        _ => None
      }
    15 =>
      match (v(3), v(1)) {
        (Statement(state1), Statement(state2)) =>
          Some(
            Statement(
              Stmt::new(
                "relation",
                state1~,
                state2~,
                description=One(trim_colon(v(0).text())),
              ),
            ),
          )
        _ => None
      }
    19 =>
      match v(1) {
        Document(doc) =>
          Some(
            Statement(
              Stmt::new(
                "state",
                id=v(3).text(),
                state_type="default",
                description=One(""),
                doc~,
              ),
            ),
          )
        _ => None
      }
    20 => {
      let id = v(0).text()
      let description = trim(v(2).text())
      // `"long" as id: more` titles the state and describes it.
      let (id, description) = match id.find(":") {
        Some(_) => {
          let parts = id.split(":").map(part => part.to_owned()).collect()
          (parts[0], Description::Many([description, parts[1]]))
        }
        None => (id, One(description))
      }
      Some(
        Statement(Stmt::new("state", id~, state_type="default", description~)),
      )
    }
    21 =>
      match v(1) {
        Document(doc) =>
          Some(
            Statement(
              Stmt::new(
                "state",
                id=v(3).text(),
                state_type="default",
                description=One(v(5).text()),
                doc~,
              ),
            ),
          )
        _ => None
      }
    22 => state(v(0), "fork")
    23 => state(v(0), "join")
    24 => state(v(0), "choice")
    25 => {
      self.divider_count += 1
      Some(
        Statement(
          Stmt::new(
            "state",
            id="divider-id-\{self.divider_count}",
            state_type="divider",
          ),
        ),
      )
    }
    26 =>
      Some(
        Statement(
          Stmt::new("state", id=trim(v(1).text()), note={
            position: trim(v(2).text()),
            text: trim(v(0).text()),
          }),
        ),
      )
    29 => {
      let title = trim(v(0).text())
      self.acc_title = title.trim_start(chars=" \t\n\r").to_owned()
      Some(Text(title))
    }
    30 | 31 => {
      let description = trim(v(0).text())
      let indent = try! @jsregex.Regex::compile("\\n\\s+")
      self.acc_description = indent.replace_all(description, _ => "\n")
      Some(Text(description))
    }
    32 =>
      match v(3) {
        Statement(target) =>
          Some(
            Statement(
              Stmt::new(
                "click",
                state1=target,
                value=v(2).text(),
                tooltip=v(1).text(),
              ),
            ),
          )
        _ => None
      }
    33 =>
      match v(3) {
        Statement(target) =>
          Some(Statement(Stmt::new("click", state1=target, value=v(1).text())))
        _ => None
      }
    34 | 35 =>
      Some(
        Statement(
          Stmt::new("classDef", id=trim(v(1).text()), value=trim(v(0).text())),
        ),
      )
    36 =>
      Some(
        Statement(
          Stmt::new("style", id=trim(v(1).text()), value=trim(v(0).text())),
        ),
      )
    37 =>
      Some(
        Statement(
          Stmt::new("applyClass", id=trim(v(1).text()), value=trim(v(0).text())),
        ),
      )
    38 => direction("TB")
    39 => direction("BT")
    40 => direction("RL")
    41 => direction("LR")
    44 | 45 => id_statement(v(0), [])
    46 | 47 => id_statement(v(2), [trim(v(0).text())])
    _ => None
  }
}

///|
/// Parse state diagram source into its database.
pub fn parse(source : String, config : @config.Config) -> StateDb raise {
  let db = StateDb::new(config)
  statediagram_grammar.parse(
    source,
    empty=Null,
    token=text => Text(text),
    reduce=reduction => db.reduce(reduction),
    hook=lexer_hook,
  )
  |> ignore
  db.set_root_doc()
  db
}
