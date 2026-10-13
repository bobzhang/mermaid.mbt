// A runtime for the parsers jison generates. mermaid's grammars are
// compiled by jison into LALR(1) tables and lexer rules; the port takes
// those tables as data (see scripts/gen_jison.py) and interprets them here,
// following the generated JavaScript's `parse` and `lex` step by step.

///|
/// A parser action in a table cell.
priv enum Action {
  Goto(Int32)
  Shift(Int32)
  Reduce(Int32)
  Accept
}

///|
/// What a lexer rule does once it has matched, in order.
pub(all) enum LexOp {
  /// `this.begin(state)` / `this.pushState(state)`
  Push(String)
  /// `this.popState()`
  Pop
  /// `return token`
  Return(String)
  /// Code that is specific to the grammar; the hook with this number runs.
  Custom(Int32)
}

///|
/// What a custom lexer hook asks the lexer to do next.
pub(all) enum HookResult {
  /// Carry on with the rule's remaining operations.
  Continue
  /// Skip the operation that follows the hook (an `if` whose test failed).
  SkipNext
  /// Abandon the rule's remaining operations without producing a token.
  Stop
}

///|
/// A lexer start condition: the rules that apply in it, in priority order.
priv struct Condition {
  rules : Array[Int32]
}

///|
/// The tables of one jison-generated parser.
pub struct Grammar {
  priv symbol_ids : Map[String, Int32]
  /// Which symbols are terminals, for error messages.
  priv terminals : Map[Int32, String]
  /// Left-hand side and length of each production.
  priv productions : Array[(Int32, Int32)]
  priv table : Array[Map[Int32, Action]]
  priv default_actions : Map[Int32, Action]
  priv rules : Array[@jsregex.Regex]
  priv conditions : Map[String, Condition]
  priv lex_ops : Array[Array[LexOp]]
  /// Whether the lexer takes the longest match instead of the first.
  priv flex : Bool
}

///|
/// Build a grammar from the flat tables written by scripts/gen_jison.py.
///
/// - `symbols`: symbol names, indexed by symbol number.
/// - `terminals`: numbers of the terminal symbols.
/// - `productions`: pairs of left-hand side and right-hand side length.
/// - `table`: per state, a count followed by that many triples of symbol,
///   action kind (0 goto, 1 shift, 2 reduce, 3 accept) and operand.
/// - `default_actions`: pairs of state and production to reduce by.
/// - `rules`: lexer patterns with their flags.
/// - `conditions`: per start condition, the rule numbers that apply.
/// - `lex_ops`: per lexer rule, what to do on a match.
pub fn Grammar::new(
  symbols~ : Array[String],
  terminals~ : Array[Int32],
  productions~ : Array[Int32],
  table~ : Array[Int32],
  default_actions~ : Array[Int32],
  rules~ : Array[(String, String)],
  conditions~ : Map[String, Array[Int32]],
  lex_ops~ : Array[Array[LexOp]],
  flex~ : Bool = false,
) -> Grammar {
  let symbol_ids : Map[String, Int32] = Map([])
  for id, name in symbols {
    if name != "" {
      symbol_ids[name] = id
    }
  }
  let terminal_names : Map[Int32, String] = Map([])
  for id in terminals {
    terminal_names[id] = symbols[id]
  }
  let pairs = []
  for i = 0; i + 1 < productions.length(); i = i + 2 {
    pairs.push((productions[i], productions[i + 1]))
  }
  let states : Array[Map[Int32, Action]] = []
  let mut cursor = 0
  while cursor < table.length() {
    let count = table[cursor]
    cursor += 1
    let row : Map[Int32, Action] = Map([])
    for _ in 0..<count {
      let operand = table[cursor + 2]
      row[table[cursor]] = match table[cursor + 1] {
        0 => Goto(operand)
        1 => Shift(operand)
        2 => Reduce(operand)
        _ => Accept
      }
      cursor += 3
    }
    states.push(row)
  }
  let defaults : Map[Int32, Action] = Map([])
  for i = 0; i + 1 < default_actions.length(); i = i + 2 {
    defaults[default_actions[i]] = Reduce(default_actions[i + 1])
  }
  let compiled = rules.map(rule => {
    @jsregex.Regex::compile(rule.0, flags=rule.1) catch {
      // The patterns are generated; one that does not compile is a bug in
      // the regex engine, and never matching is the safest fallback.
      _ => try! @jsregex.Regex::compile("[]")
    }
  })
  let by_name : Map[String, Condition] = Map([])
  for name, indices in conditions {
    by_name[name] = { rules: indices, }
  }
  {
    symbol_ids,
    terminals: terminal_names,
    productions: pairs,
    table: states,
    default_actions: defaults,
    rules: compiled,
    conditions: by_name,
    lex_ops,
    flex,
  }
}

///|
/// The number of the symbol called `name`.
pub fn Grammar::symbol(self : Grammar, name : String) -> Int32? {
  self.symbol_ids.get(name)
}
