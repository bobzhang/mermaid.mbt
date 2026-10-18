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
