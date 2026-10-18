///|
test "how deep block quotes may nest" {
  assert_false(markdown_too_deep(">".repeat(250) + " a"))
  assert_true(markdown_too_deep(">".repeat(251) + " a"))
  // White space between the markers counts them still; text before
  // them does not start a quote.
  assert_true(markdown_too_deep("x\n" + "> ".repeat(251) + "a"))
  assert_false(markdown_too_deep("a " + ">".repeat(3000)))
  assert_false(markdown_too_deep("> a\n".repeat(3000)))
  // Emphasis: at most a thousand delimiters.
  assert_false(markdown_too_deep("*_".repeat(250) + "a" + "_*".repeat(250)))
  assert_true(markdown_too_deep("*_".repeat(251) + "a" + "_*".repeat(251)))
}
