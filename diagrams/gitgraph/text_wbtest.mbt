// Expected values are what upstream's sanitizer and Chrome's text layout
// produce for the same input.

///|
fn sanitized(text : String) -> String {
  sanitize_text(text, true) catch {
    Unsupported(_) => "unsupported"
  }
}

///|
test "sanitizeText of the git graph database" {
  // Without a line break the entities stay as written.
  inspect(sanitized("a<b>c=d&e"), content="a&lt;b&gt;c&equals;d&e")
  // With one, the HTML parser resolves them and serializes again.
  inspect(sanitized("a<br/>b=c"), content="a<br>b=c")
  inspect(sanitized("a & b<BR >c < d"), content="a &amp; b<br>c &lt; d")
  inspect(sanitized("a #br# b"), content="a <br> b")
  // Sanitizing twice, as `branch` does, changes nothing more.
  inspect(sanitized(sanitized("x & y<br>z")), content="x &amp; y<br>z")
  inspect(sanitized("&copy;<br>"), content="unsupported")
}

///|
fn common(text : String) -> String {
  sanitize_common(text) catch {
    Unsupported(_) => "unsupported"
  }
}

///|
test "sanitizeText of titles" {
  inspect(common("a > b & c"), content="a > b & c")
  inspect(common("a < b & c"), content="a &lt; b &amp; c")
  inspect(
    common("x <b>bold <i>it</i></b> > y"),
    content="x <b>bold <i>it</i></b> &gt; y",
  )
  inspect(common("a <e> b"), content="unsupported")
  inspect(common("<b>open"), content="unsupported")
  inspect(common("a < b &amp; c"), content="unsupported")
}

///|
test "font sizes" {
  let size = (value : Json) => {
    css_font_size("fontSize", value, 16.0) catch {
      Unsupported(_) => -1.0
    }
  }
  inspect(size("10px"), content="10")
  inspect(size("12.5px"), content="12.5")
  inspect(size("150%"), content="24")
  inspect(size("0.5em"), content="8")
  inspect(size("9pt"), content="12")
  // A bare number is not a length; the inherited size stays.
  inspect(size(20), content="16")
  inspect(size("20"), content="16")
  inspect(size("large"), content="-1")
  // CSS numbers; a negative size is invalid, and inherits.
  inspect(size("+14px"), content="14")
  inspect(size("-16px"), content="16")
  inspect(size("-1.4e1px"), content="16")
  // Zero is a length with a unit or without.
  inspect(size("0"), content="0")
  inspect(size("0px"), content="0")
}

///|
test "font weights" {
  inspect(is_bold_weight("normal"), content="false")
  inspect(is_bold_weight("bold"), content="true")
  inspect(is_bold_weight(500), content="false")
  inspect(is_bold_weight(600), content="true")
}

///|
test "white space in SVG text" {
  inspect(collapse_spaces("  a   b \n c\t"), content="a b c")
  inspect(collapse_spaces("   "), content="")
}
