// Expected values are what the reference browser answers; see the probes
// in the comments.

///|
test "CSS.supports('color', value) for box colors" {
  let supported = [
    "Aqua", "transparent", "rgb(33,66,99)", "rgba(33,66,99,0.5)", "rgb(33 66 99)",
    "rgb(33 66 99 / 50%)", "rgb(10%,20%,30%)", "rgb(10% 20 30)", "hsl(120,50%,50%)",
    "hsl(120deg 50% 50%)", "hsl(120 50 50)", "hsla(120,50%,50%,.3)", "rgb(none 1 2)",
    "inherit", "Canvas", "rgb( 1 , 2 , 3 )", "rgb(1e2,2,3)", "rgb(1.5,2,3)", "rgb(1,2,3,50%)",
    "rgb(1 2 3 / none)", "hsl(1turn,50%,50%)", "RGB(1,2,3)", "currentColor", "rgb(1 2 3/0.5)",
    "hsl(120 50% 50)", "hsl(none none none)", "ThreeDFace", "rgb(1% 2 none / 5)",
  ]
  let refused = [
    "rgb(1,2)", "rgb(1,2,3,4,5)", "rgb(10%,20,30)", "hsl(120,50,50)", "rgb(none,1,2)",
    "foo", "hsl(50% 50% 50%)", "rgb(1 2 3 4)", "rgb(1,2,3 / 0.5)", "rgb(1 2,3)",
    "rgb(+1 -2 3.)", "rgb(1 2 3.)", "rgb()", "", "rgb(1deg 2 3)", "hsl(1,2%,3%,none)",
    "rgb (1,2,3)",
  ]
  debug_inspect(
    supported.filter(color => !css_supports_color(color)),
    content="[]",
  )
  debug_inspect(refused.filter(css_supports_color), content="[]")
}

///|
test "a box line starts with its color when the browser knows it" {
  json_inspect(parse_box_data("Aqua Group Description"), content={
    "color": "Aqua",
    "text": "Group Description",
  })
  json_inspect(parse_box_data("rgb(33,66,99)"), content={
    "color": "rgb(33,66,99)",
  })
  // Not a color: the whole line is the title.
  json_inspect(parse_box_data("Another Group"), content={
    "color": "transparent",
    "text": "Another Group",
  })
  json_inspect(parse_box_data("transparent Aqua"), content={
    "color": "transparent",
    "text": "Aqua",
  })
  json_inspect(parse_box_data("Purple wrap:Alice & John"), content={
    "color": "Purple",
    "text": "Alice & John",
    "wrap": true,
  })
}

///|
test "wrap prefixes" {
  debug_inspect(
    extract_wrap("wrap: hello "),
    content=(
      #|("hello", Some(true))
    ),
  )
  debug_inspect(
    extract_wrap(":nowrap:hello"),
    content=(
      #|("hello", Some(false))
    ),
  )
  debug_inspect(
    extract_wrap("wrapped: hello"),
    content=(
      #|("wrapped: hello", None)
    ),
  )
}

///|
test "text is measured in the standard font unless the family is valid CSS" {
  // mermaid's default family ends in a semicolon, which the CSSOM
  // refuses, so the browser's standard font (Times) is measured. The
  // sans-serif measure only wins when it is larger in every respect, and
  // at 16px both are 18 high.
  let default_font : TextFont = {
    family: Some("\"trebuchet ms\", verdana, arial, sans-serif;"),
    size: Json::number(16),
    weight: Json::number(400),
  }
  let dims = text_dimensions("Hello John, how are you?", default_font)
  debug_inspect((dims.width, dims.height), content="(164, 18)")
  let two_lines = text_dimensions("Hello<br/>John, how are you?", default_font)
  debug_inspect(
    (two_lines.width, two_lines.height),
    content=(
      #|(124, 36)
    ),
  )
  // An empty line is measured as a zero-width space: no width, full height.
  let gap = text_dimensions("a<br><br>b", default_font)
  debug_inspect((gap.width, gap.height), content="(8, 54)")
  let verdana : TextFont = { ..default_font, family: Some("verdana"), }
  let dims = text_dimensions("Hello John, how are you?", verdana)
  debug_inspect(
    (dims.width, dims.height),
    content=(
      #|(202, 19)
    ),
  )
  inspect(text_dimensions("", default_font).width, content="0")
}

///|
test "labels wrap at word boundaries, long words are hyphenated" {
  let font : TextFont = {
    family: Some("\"trebuchet ms\", verdana, arial, sans-serif;"),
    size: Json::number(16),
    weight: Json::number(400),
  }
  inspect(
    wrap_label(
      "This is a long message that should be wrapped because it is wide", 130, font,
    ),
    content=(
      #|This is a long<br/>message that should<br/>be wrapped because<br/>it is wide
    ),
  )
  inspect(
    wrap_label(
      "Pneumonoultramicroscopicsilicovolcanoconiosis is long", 130, font,
    ),
    content=(
      #|Pneumonoultramicro-<br/>scopicsilicovolcanoc-<br/>oniosis is long
    ),
  )
  // Existing breaks are respected as they are.
  inspect(
    wrap_label("one<br/>two three four five six seven", 50, font),
    content="one<br/>two three four five six seven",
  )
}

///|
test "font properties as the CSSOM keeps them" {
  debug_inspect(
    serialize_font_family("verdana,arial"),
    content=(
      #|Some("verdana, arial")
    ),
  )
  debug_inspect(
    serialize_font_family("'Open Sans',  ARIAL , Sans-Serif"),
    content=(
      #|Some("\"Open Sans\", ARIAL, sans-serif")
    ),
  )
  debug_inspect(
    serialize_font_family("courier new"),
    content=(
      #|Some("\"courier new\"")
    ),
  )
  debug_inspect(
    serialize_font_family("\"trebuchet ms\", verdana, arial, sans-serif;"),
    content="None",
  )
  debug_inspect(serialize_font_family("a,"), content="None")
  debug_inspect(serialize_font_family("12px"), content="None")
  debug_inspect(
    serialize_font_weight(Json::string("BOLD")),
    content=(
      #|Some("bold")
    ),
  )
  debug_inspect(
    serialize_font_weight(Json::number(400)),
    content=(
      #|Some("400")
    ),
  )
  debug_inspect(serialize_font_weight(Json::number(1001)), content="None")
  debug_inspect(serialize_font_weight(Json::string("heavy")), content="None")
}

///|
test "links are sanitized and web addresses normalized" {
  inspect(sanitize_url("https://x.example"), content="https://x.example/")
  inspect(
    sanitize_url("HTTPS://X.Example/Path"),
    content="https://x.example/Path",
  )
  inspect(
    sanitize_url("https://x.example/a/../b/./c"),
    content="https://x.example/b/c",
  )
  inspect(
    sanitize_url("https://x.example/?q=a b&c='d'"),
    content="https://x.example/?q=a%20b&c=%27d%27",
  )
  inspect(
    sanitize_url("https://x.example/{a}|b^c`d"),
    content="https://x.example/%7Ba%7D%7Cb%5Ec%60d",
  )
  inspect(
    sanitize_url("https://x.example/caf\u{e9}"),
    content="https://x.example/caf%C3%A9",
  )
  inspect(
    sanitize_url("https://x.example/%7Efoo"),
    content="https://x.example/~foo",
  )
  inspect(sanitize_url("https:x.example"), content="https://x.example/")
  // An address with a second colon is taken as it is.
  inspect(
    sanitize_url("https://x.example:8080/a"),
    content="https://x.example:8080/a",
  )
  inspect(sanitize_url("javascript:alert(1)"), content="about:blank")
  inspect(sanitize_url("  jav&#x09;ascript:alert(1)"), content="about:blank")
  inspect(sanitize_url(""), content="about:blank")
  inspect(sanitize_url("./relative"), content="./relative")
  inspect(
    sanitize_url("mailto:someone@example.com"),
    content="mailto:someone@example.com",
  )
}
