// A chevrotain lexer and parser, driven by what chevrotain itself worked
// out: `scripts/gen_chevrotain.py` reads the token types, the grammar and
// the lookahead sequences of every choice out of the mermaid bundle.

///|
/// A syntax or lexical error.
pub(all) suberror ParseError {
  ParseError(message~ : String, offset~ : Int32)
} derive(Eq, Debug)

///|
/// How a token type is recognized.
pub(all) enum Pattern {
  /// A JavaScript regular expression: source and flags.
  Regex(String, String)
  /// A function, ported by hand and reached through the `custom` hook of
  /// `Grammar::tokenize`.
  Custom
  /// Nothing: the type is a category other types belong to.
  Category
}

///|
/// A token type as declared with chevrotain's `createToken`.
pub(all) struct TokenType {
  name : String
  pattern : Pattern
  /// Whether matches are dropped (`group: Lexer.SKIPPED`).
  skipped : Bool
  /// Types tried after this one matched, the first longer match winning.
  longer_alt : Array[String]
  push_mode : String?
  pop_mode : Bool
  /// The other types that satisfy a request for this one: those that have
  /// it among their categories, directly or not.
  matched_by : Array[String]
}

///|
pub fn TokenType::new(
  name : String,
  pattern : Pattern,
  skipped~ : Bool = false,
  longer_alt~ : Array[String] = [],
  push_mode? : String,
  pop_mode~ : Bool = false,
  matched_by~ : Array[String] = [],
) -> TokenType {
  { name, pattern, skipped, longer_alt, push_mode, pop_mode, matched_by, }
}

///|
/// A piece of a rule. Choices carry the token sequences chevrotain tests
/// to make them, and their occurrence index, which names them to
/// predicates.
pub(all) enum Production {
  /// `CONSUME`: a token of a type, filed in the syntax tree under the
  /// type's name.
  Terminal(String)
  /// `SUBRULE`
  NonTerminal(String)
  /// `OPTION`: entered when the input starts with one of the sequences.
  Option(Int32, Array[Array[String]], Array[Production])
  /// `MANY`
  Repetition(Int32, Array[Array[String]], Array[Production])
  /// `AT_LEAST_ONE`
  RepetitionMandatory(Int32, Array[Array[String]], Array[Production])
  /// `OR`: the first alternative one of whose sequences the input starts
  /// with.
  Alternation(Int32, Array[(Array[Array[String]], Array[Production])])
}

///|
priv struct CompiledToken {
  name : String
  regex : @jsregex.Regex?
  custom : Bool
  skipped : Bool
  longer_alt : Array[Int32]
  push_mode : String?
  pop_mode : Bool
}

///|
/// A production with names resolved.
priv enum Step {
  Consume(Int32, String)
  Call(Int32)
  Maybe(String, Array[Array[Int32]], Array[Step])
  Many(String, Array[Array[Int32]], Array[Step])
  AtLeastOne(String, Array[Array[Int32]], Array[Step])
  Choose(Array[(String, Array[Array[Int32]], Array[Step])])
}

///|
/// The lexer and parser of one language.
pub struct Grammar {
  priv tokens : Array[CompiledToken]
  priv token_index : Map[String, Int32]
  /// `accepts[expected][actual]`: whether a token of type `actual`
  /// satisfies a request for `expected`.
  priv accepts : Array[Array[Bool]]
  priv modes : Map[String, Array[Int32]]
  priv default_mode : String
  priv rule_names : Array[String]
  priv rules : Array[Array[Step]]
  priv eof : Int32
}

///|
/// The type of the token that stands for the end of the input.
const EOF_NAME : String = "EOF"

///|
fn compile_steps(
  rule : String,
  productions : Array[Production],
  token_index : Map[String, Int32],
  rule_index : Map[String, Int32],
) -> Array[Step] {
  let paths = (paths : Array[Array[String]]) => {
    paths.map(path => path.map(name => token_index[name]))
  }
  let steps = (body : Array[Production]) => {
    compile_steps(rule, body, token_index, rule_index)
  }
  productions.map(production => {
    match production {
      Terminal(name) => Consume(token_index[name], name)
      NonTerminal(name) => Call(rule_index[name])
      Option(idx, sequences, body) =>
        Maybe("\{rule}:Option\{idx}", paths(sequences), steps(body))
      Repetition(idx, sequences, body) =>
        Many("\{rule}:Repetition\{idx}", paths(sequences), steps(body))
      RepetitionMandatory(idx, sequences, body) =>
        AtLeastOne(
          "\{rule}:RepetitionMandatory\{idx}",
          paths(sequences),
          steps(body),
        )
      Alternation(idx, alternatives) =>
        Choose(
          alternatives.mapi((index, alternative) => {
            (
              "\{rule}:Alternation\{idx}:\{index}",
              paths(alternative.0),
              steps(alternative.1),
            )
          }),
        )
    }
  })
}

///|
/// Put a language together. `modes` lists the token types of each lexer
/// mode in the order they are tried; `rules` are the parser's rules, the
/// first one being where parsing starts.
pub fn Grammar::new(
  tokens~ : Array[TokenType],
  modes~ : Map[String, Array[String]],
  default_mode~ : String,
  rules~ : Array[(String, Array[Production])],
) -> Grammar {
  let token_index : Map[String, Int32] = Map([])
  for index, token in tokens {
    token_index[token.name] = index
  }
  let eof = match token_index.get(EOF_NAME) {
    Some(index) => index
    None => {
      token_index[EOF_NAME] = tokens.length()
      tokens.length()
    }
  }
  let count = token_index.length()
  let accepts = Array::makei(count, expected => {
    Array::makei(count, actual => expected == actual)
  })
  for index, token in tokens {
    for name in token.matched_by {
      accepts[index][token_index[name]] = true
    }
  }
  let compiled = tokens.map(token => {
    let regex = match token.pattern {
      Regex(source, flags) =>
        Some(
          @jsregex.Regex::compile(source, flags~) catch {
            RegexError(message) => abort("token \{token.name}: \{message}")
          },
        )
      _ => None
    }
    {
      name: token.name,
      regex,
      custom: token.pattern is Custom,
      skipped: token.skipped,
      longer_alt: token.longer_alt.map(name => token_index[name]),
      push_mode: token.push_mode,
      pop_mode: token.pop_mode,
    }
  })
  let rule_index : Map[String, Int32] = Map([])
  for index, rule in rules {
    rule_index[rule.0] = index
  }
  {
    tokens: compiled,
    token_index,
    accepts,
    modes: Map::from_iter(
      modes
      .iter()
      .map(entry => (entry.0, entry.1.map(name => token_index[name]))),
    ),
    default_mode,
    rule_names: rules.map(rule => rule.0),
    rules: rules.map(rule => {
      compile_steps(rule.0, rule.1, token_index, rule_index)
    }),
    eof,
  }
}
