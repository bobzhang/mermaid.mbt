///|
/// A small language: `let x = 1`, keywords taking precedence over names
/// unless the name is longer, with `NUMBER` and `NAME` both words.
let tiny : @chevrotain.Grammar = @chevrotain.Grammar::new(
  tokens=[
    @chevrotain.TokenType::new("WORD", Category, matched_by=["NAME", "LET"]),
    @chevrotain.TokenType::new("WS", Regex("[ ]+", ""), skipped=true),
    @chevrotain.TokenType::new("LET", Regex("let", ""), longer_alt=["NAME"]),
    @chevrotain.TokenType::new("NAME", Regex("[a-z]+", "")),
    @chevrotain.TokenType::new("EQ", Regex("=", "")),
    @chevrotain.TokenType::new("NUMBER", Regex("[0-9]+", "")),
  ],
  modes={ "main": ["WS", "LET", "NAME", "EQ", "NUMBER"] },
  default_mode="main",
  rules=[
    (
      "start",
      [
        Terminal("LET"),
        Terminal("NAME"),
        Option(0, [["EQ"]], [Terminal("EQ"), NonTerminal("value")]),
      ],
    ),
    (
      "value",
      [
        Alternation(0, [
          ([["NUMBER"]], [Terminal("NUMBER")]),
          ([["NAME"], ["LET"]], [Terminal("WORD")]),
        ]),
      ],
    ),
  ],
)

///|
test "longer alternatives and skipped tokens" {
  let tokens = tiny.tokenize("let letter = 12")
  inspect(
    tokens.map(token => "\{token.name}:\{token.image}@\{token.start}").join(" "),
    content="LET:let@0 NAME:letter@4 EQ:=@11 NUMBER:12@13",
  )
}

///|
test "tokens are filed under the type asked for" {
  let tree = tiny.parse(tiny.tokenize("let x = let"))
  let value = tree.nodes("value")[0]
  inspect(
    value.tokens("WORD").map(token => token.image).join(","),
    content="let",
  )
  inspect(tree.all_tokens().length(), content="4")
}

///|
test "left-over input and gates are errors" {
  let failed = (text : String, gate : (String, @chevrotain.Parser) -> Bool) => {
    try {
      tiny.parse(tiny.tokenize(text), gate~) |> ignore
      false
    } catch {
      _ => true
    }
  }
  inspect(failed("let x 1", (_, _) => true), content="true")
  inspect(failed("let x = 1", (_, _) => true), content="false")
  inspect(
    failed("let x = 1", (key, _) => key != "start:Option0"),
    content="true",
  )
}
