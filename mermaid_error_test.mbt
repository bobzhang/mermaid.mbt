///|
/// How a failure reads to people.
test "MermaidError shows its kind and message" {
  let message = (text : String, config : Json) => {
    try @mermaid.render(text, config~) catch {
      error => error.to_string()
    } noraise {
      _ => "rendered"
    }
  }
  inspect(
    message("hello", {}),
    content="unknown diagram: No diagram type detected matching given configuration for text: hello",
  )
  inspect(
    message("pie\n\"a\": 1\n", { "securityLevel": "sandbox" }),
    content="not supported: the sandbox security level",
  )
  inspect(
    @mermaid.Syntax("Parse error on line 1"),
    content="syntax error: Parse error on line 1",
  )
  inspect(
    @mermaid.Config("Unsupported color format: \"x\""),
    content="invalid configuration: Unsupported color format: \"x\"",
  )
  inspect(
    @mermaid.Render("the image cannot be decoded"),
    content="cannot render: the image cannot be decoded",
  )
}
