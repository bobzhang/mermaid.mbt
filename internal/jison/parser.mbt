///|
/// What a reduction sees: the values of the production's right-hand side
/// and the state of the lexer.
pub struct Reduction[V] {
  /// The production's number, the `yystate` of jison's `performAction`.
  production : Int32
  /// `$1` to `$n`.
  values : ArrayView[V]
  /// The text of the token shifted last, jison's `yytext`.
  text : String
  /// The line of the token shifted last, counting from one.
  line : Int32
}

///|
/// Parse `input` with `grammar`.
///
/// - `token` turns the text of a shifted token into a semantic value.
/// - `reduce` is jison's `performAction`: it returns the value of the
///   production, or `None` for the default, the value of its first symbol.
/// - `hook` runs the grammar's custom lexer code.
/// - `empty` is the value of an empty production with no action.
///
/// Returns the value of the start symbol.
pub fn[V] Grammar::parse(
  self : Grammar,
  input : String,
  empty~ : V,
  token~ : (String) -> V,
  reduce~ : (Reduction[V]) -> V? raise,
  hook~ : (Int32, Lexer) -> HookResult = (_, _) => Continue,
) -> V raise {
  let lexer : Lexer = {
    grammar: self,
    input,
    position: 0,
    done: false,
    yytext: "",
    yylineno: 0,
    states: ["INITIAL"],
    failure: None,
  }
  let states = [0]
  let values : Array[V] = [empty]
  let mut symbol : Int32? = None
  let mut text = ""
  let mut line = 1
  while true {
    let state = states[states.length() - 1]
    let action = match self.default_actions.get(state) {
      Some(action) => Some(action)
      None => {
        let lookahead = match symbol {
          Some(lookahead) => lookahead
          None => {
            let lookahead = lexer.lex(hook)
            symbol = Some(lookahead)
            lookahead
          }
        }
        self.table[state].get(lookahead)
      }
    }
    match action {
      Some(Shift(next)) => {
        values.push(token(lexer.yytext))
        states.push(next)
        symbol = None
        text = lexer.yytext
        line = lexer.line()
      }
      Some(Reduce(production)) => {
        let (lhs, length) = self.productions[production]
        let base = values.length() - length
        let default = if length > 0 { values[base] } else { empty }
        let value = reduce({ production, values: values[base:], text, line, }).unwrap_or(
          default,
        )
        states.truncate(states.length() - length)
        values.truncate(base)
        values.push(value)
        guard self.table[states[states.length() - 1]].get(lhs)
          is Some(Goto(next)) else {
          raise ParseError(message="Parser table has no goto", line~)
        }
        states.push(next)
      }
      Some(Accept) => return values[values.length() - 1]
      Some(Goto(_)) | None => {
        let lookahead = symbol.unwrap_or(EOF)
        let expected = []
        for id, _ in self.table[state] {
          if id > 2 && self.terminals.get(id) is Some(name) {
            expected.push("'\{name}'")
          }
        }
        let got = self.terminals.get(lookahead).unwrap_or(lookahead.to_string())
        let line = lexer.line()
        let message = "Parse error on line \{line}:\n\{lexer.show_position()}\nExpecting \{expected.join(", ")}, got '\{got}'"
        raise ParseError(message~, line~)
      }
    }
  }
  empty
}
