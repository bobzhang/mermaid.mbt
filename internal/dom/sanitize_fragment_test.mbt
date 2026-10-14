///|
fn sanitized(text : String) -> String {
  @dom.sanitize_fragment(text) catch {
    _ => "unsupported"
  }
}

///|
test "text without a tag is left alone" {
  inspect(sanitized("a & b > c &lt; d"), content="a & b > c &lt; d")
}

///|
test "unknown elements go, their content stays" {
  // What becomes of generic types written with angle brackets.
  inspect(sanitized("+List<String> names"), content="+List names")
  inspect(sanitized("+Map<String, List<int>> index"), content="+Map&gt; index")
  inspect(sanitized("<<service>>"), content="&lt;&gt;")
  // A tag the text ends in takes the rest of the text with it.
  inspect(sanitized("+tag <unclosed"), content="+tag ")
  // A `>` inside a quoted attribute value does not end the tag.
  inspect(sanitized("<x y=\"a>b\">c"), content="c")
  inspect(sanitized("&copy; <x> &#x41; &quot;"), content="©  A \"")
}

///|
test "character data is escaped once the text is parsed" {
  inspect(sanitized("a < b"), content="a &lt; b")
  inspect(
    sanitized("x <= y && y >= z"),
    content="x &lt;= y &amp;&amp; y &gt;= z",
  )
  inspect(sanitized("&amp; <x> &lt; &#35;"), content="&amp;  &lt; #")
}

///|
test "line breaks and plain formatting stay" {
  inspect(sanitized("x<br/>y<br />z</br><BR >"), content="x<br>y<br>z<br><br>")
  inspect(sanitized("<b>bold</b > label"), content="<b>bold</b> label")
  inspect(sanitized("</>x<1>"), content="x&lt;1&gt;")
  // An element left open is closed where the text ends.
  inspect(sanitized("a <i>b"), content="a <i>b</i>")
}

///|
test "what is not modelled is refused" {
  inspect(sanitized("<a href='x'>link</a>"), content="unsupported")
  inspect(sanitized("<b class='x'>bold</b>"), content="unsupported")
  inspect(sanitized("a <!-- comment --> b"), content="unsupported")
  inspect(sanitized("<i><b>crossed</i></b>"), content="unsupported")
  inspect(sanitized("R&D <x>"), content="unsupported")
  inspect(sanitized("&nope; <x>"), content="unsupported")
}
