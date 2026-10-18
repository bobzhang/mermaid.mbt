///|
test "long markdown paragraphs" {
  // What mermaid's `markdownToHTML` returns for them (marked in Node).
  assert_eq(
    markdown_to_html("a".repeat(20000), true),
    "<p>" + "a".repeat(20000) + "</p>",
  )
  assert_eq(
    markdown_to_html("word ".repeat(4000), true),
    "<p>" + "word ".repeat(4000) + "</p>",
  )
  assert_eq(
    markdown_to_html("a\n".repeat(3000), true),
    "<p>" + "a<br/>".repeat(2999) + "a</p>",
  )
  assert_eq(
    markdown_to_html("**b** c ".repeat(2000), true),
    "<p>" + "<strong>b</strong> c ".repeat(2000) + "</p>",
  )
}

///|
test "a thousand repeated blocks" {
  // mermaid writes every block but a paragraph as its raw text, which is
  // what marked in Node gives for each of these.
  let raw = [
    "> a\n".repeat(1000),
    "    code\n".repeat(1000),
    "- a\n".repeat(1000),
    "1. a\n".repeat(1000),
    "- a\n  b\n".repeat(1000),
    "> a\nb\n".repeat(1000),
    ">".repeat(200) + " a",
    "# h\n".repeat(1000),
    "```\n" + "a\n".repeat(1000) + "```",
    "***\n".repeat(1000),
    "|a|b|\n|-|-|\n" + "|a|b|\n".repeat(1000),
    "<div>\n".repeat(1000),
    "a\n===\n".repeat(1000),
  ]
  for text in raw {
    assert_eq(markdown_to_html(text, true), text)
  }
  // A definition is written once; the repeats define nothing new.
  assert_eq(markdown_to_html("[r]: /x\n".repeat(1000), true), "[r]: /x\n")
}
