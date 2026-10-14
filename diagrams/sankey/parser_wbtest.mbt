///|
test "only the ends of the text are trimmed, and blank lines dropped" {
  inspect(
    prepare_text_for_parsing("  sankey-beta \r\n\r\n a , b,1 \n\n\nb,c,2\n \n"),
    content=(
      #|sankey-beta 
      #| a , b,1 
      #|b,c,2
    ),
  )
}

///|
test "fields are trimmed and doubled quotes unescaped" {
  let config = @config.Config::new()
  let sankey = parse(
    "sankey-beta\n\"a, \"\"b\"\"\", c ,1.5\nc,d,x\n\"a, \"\"b\"\"\",d,2\n", config,
  )
  json_inspect(sankey.nodes, content=["a, \"b\"", "c", "d"])
  inspect(sankey.links.length(), content="3")
  json_inspect(sankey.links[0], content=[0, 1, 1.5])
  json_inspect(sankey.links[2], content=[0, 2, 2])
}

///|
test "syntax errors are worded like jison's" {
  let config = @config.Config::new()
  let message = try {
    parse("sankey-beta\na,b\n", config) |> ignore
    ""
  } catch {
    @jison.ParseError(message~, ..) => message
    _ => "another error"
  }
  inspect(
    message,
    content=(
      #|Parse error on line 2:
      #|sankey-betaa,b
      #|--------------^
      #|Expecting 'COMMA', got 'EOF'
    ),
  )
}
