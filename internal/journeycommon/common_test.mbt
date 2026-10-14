///|
test "text without markup is not touched by the sanitizer" {
  inspect(@journeycommon.sanitize_text("A & B > C"), content="A & B > C")
  inspect(@journeycommon.sanitize_text(""), content="")
}

///|
test "markup is serialized back the way an HTML parser would" {
  inspect(
    @journeycommon.sanitize_text("A & <B>bold</b> <i>it<br/>alic > x"),
    content="A &amp; <b>bold</b> <i>it<br>alic &gt; x</i>",
  )
  // A `<` before anything but a name is text.
  inspect(@journeycommon.sanitize_text("1 < 2 <b>"), content="1 &lt; 2 <b></b>")
}

///|
test "markup the port cannot reproduce is refused" {
  let refused = (text : String) => {
    try @journeycommon.sanitize_text(text) catch {
      @journeycommon.SanitizeError(_) => true
    } noraise {
      _ => false
    }
  }
  inspect(refused("<script>x</script>"), content="true")
  inspect(refused("<b class=\"x\">y</b>"), content="true")
  inspect(refused("<b>&amp;</b>"), content="true")
  inspect(refused("<b><i>x</b></i>"), content="true")
}

///|
test "accessibility text" {
  inspect(@journeycommon.acc_title("  \t title "), content="title ")
  inspect(
    @journeycommon.acc_description("one\n   two\n\n three"),
    content="one\ntwo\nthree",
  )
}

///|
test "Number() of a string" {
  let number = (text : String) => @journeycommon.js_number(text).to_string()
  inspect(number(" 5 "), content="5")
  inspect(number(""), content="0")
  inspect(number("\u{a0}\n"), content="0")
  inspect(number("3.5"), content="3.5")
  inspect(number(".5"), content="0.5")
  inspect(number("5."), content="5")
  inspect(number("-2"), content="-2")
  inspect(number("+1e2"), content="100")
  inspect(number("0x10"), content="16")
  inspect(number("0b101"), content="5")
  inspect(number("0o17"), content="15")
  inspect(number("-0x10"), content="NaN")
  inspect(number("Infinity"), content="Infinity")
  inspect(number("-Infinity"), content="-Infinity")
  inspect(number("infinity"), content="NaN")
  inspect(number("abc"), content="NaN")
  inspect(number("1_0"), content="NaN")
  inspect(number("1e"), content="NaN")
  inspect(number("."), content="NaN")
  inspect(number("5 5"), content="NaN")
}

///|
test "trim removes what JavaScript calls white space" {
  inspect(@journeycommon.js_trim("\u{feff}\u{a0} a b\u{3000}\n"), content="a b")
}

///|
test "the theme's font" {
  let theme = @theme.Theme::from_variables({
    "fontFamily": "\"Recursive Variable\", arial, sans-serif",
    "fontSize": "14px",
  })
  // Recursive is not installed in the reference environment; Arial is
  // what text is set in.
  inspect(
    @journeycommon.theme_font(theme).advance("timeline", 16.0),
    content="55.140625",
  )
  inspect(@journeycommon.theme_font_size(theme), content="14")
  let unknown = @theme.Theme::from_variables({
    "fontFamily": "Georgia, arial",
    "fontSize": 20,
  })
  let refused = try @journeycommon.theme_font(unknown) catch {
    @journeycommon.MeasureError(_) => true
  } noraise {
    _ => false
  }
  inspect(refused, content="true")
  // A bare number is no length for a stylesheet: the page's size stays.
  inspect(@journeycommon.theme_font_size(unknown), content="16")
}

///|
test "glyphs outside the embedded faces" {
  let font = @font.Stack::default()
  let refused = (text : String) => {
    try @journeycommon.require_glyphs(font, text) catch {
      @journeycommon.MeasureError(_) => true
    } noraise {
      _ => false
    }
  }
  inspect(refused("plain\ttext é"), content="false")
  inspect(refused("日本語"), content="true")
}
