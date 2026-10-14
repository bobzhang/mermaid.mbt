///|
test "the first token type that matches wins, unless a longer alternative does" {
  let types = [
    @langium.keyword_token("axis", longer_alt=["ID"]),
    @langium.keyword_token(","),
    @langium.terminal_token("NUMBER", "[0-9]+"),
    @langium.terminal_token("ID", "\\w+"),
    @langium.terminal_token("WS", "\\s+", hidden=true),
  ]
  let kinds = (input : String) => {
    @langium.tokenize(input, types).map(token => "\{token.kind}:\{token.text}")
  }
  json_inspect(kinds("axis a, axisb"), content=[
    "axis:axis", "ID:a", ",:,", "ID:axisb",
  ])
  // `1a` is a number and an identifier: NUMBER comes first.
  json_inspect(kinds("1a"), content=["NUMBER:1", "ID:a"])
  let message = try {
    kinds("a ? b") |> ignore
    ""
  } catch {
    @langium.ParseError(message~, ..) => message
  }
  inspect(
    message,
    content=(
      #|unexpected character: ->?<- at offset: 2
    ),
  )
}
