///|
test "markup the port follows the sanitizer through" {
  let plain = [
    "a < b > c <= d", "one<br/>two<BR >three", "<b>bold</b> and <i>italic</i>", "unclosed <b>bold",
    "stray </i> end", "1 <2",
  ]
  for text in plain {
    assert_true(only_plain_markup(text))
  }
  // Attributes, unknown elements and comments may be rewritten or removed.
  let other = [
    "<span style='color:red'>x</span>", "<a href='https://x.test'>x</a>", "<unknown>x</unknown>",
    "<script>alert(1)</script>", "<!-- comment -->", "</ 3", "<b", "<br",
  ]
  for text in other {
    assert_false(only_plain_markup(text))
  }
}

///|
test "sanitized text is the HTML parsed and written again" {
  let config = @config.Config::new(diagram_type="c4")
  inspect(
    sanitize_text("a < b > c<br/>d &amp; <b>e", config, "a test"),
    content="a &lt; b &gt; c<br>d &amp; <b>e</b>",
  )
  // Without a `<` nothing is parsed, references included.
  inspect(
    sanitize_text("a > b &quot;c&quot;", config, "a test"),
    content="a > b &quot;c&quot;",
  )
}
