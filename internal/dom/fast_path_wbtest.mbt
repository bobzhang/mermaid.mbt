///|
test "Chrome's fast path takes the markup it takes" {
  // Measured in the reference browser: each case follows a span whose
  // `title='&copy=1&amp;'` reads `©=1&` only when the fast path parsed
  // the whole input, through `DOMParser` (body) and `innerHTML` on a
  // `div` and on a `span`.
  let marker = "<span title='&copy=1&amp;'></span>"
  let cases : Array[(String, Bool, Bool, Bool)] = [
    ("", true, true, true),
    ("x", true, true, true),
    ("<em>x</em>", false, false, false),
    ("<img src=x>", false, false, false),
    ("<b>x</b>", true, true, true),
    ("<i>x</i>", true, true, true),
    ("<strong>x</strong>", true, true, true),
    ("<br>", true, true, true),
    ("<br/>", true, true, true),
    ("<br />", true, true, true),
    ("<u>x</u>", false, false, false),
    ("<p>x</p>", true, true, false),
    ("<div>x</div>", true, true, false),
    ("<span><div>x</div></span>", false, false, false),
    ("<p><div>x</div></p>", false, false, false),
    ("<a href='y'>x</a>", true, true, true),
    ("<a><a>x</a></a>", false, false, false),
    ("<ul><li>x</li></ul>", true, true, false),
    ("<ul> <li>x</li> </ul>", true, true, false),
    ("<li>x</li>", true, true, false),
    ("<code>x</code>", false, false, false),
    ("&#x;", true, true, true),
    ("&#;", false, false, false),
    ("&foo;", false, false, false),
    ("&notit;", true, true, true),
    ("a & b", false, false, false),
    ("a &amp b;", true, true, true),
    ("<!-- c -->", false, false, false),
    ("a < b", false, false, false),
    ("a > b", true, true, true),
    ("<span class=a_b>x</span>", true, true, true),
    ("<span class=a.b>x</span>", false, false, false),
    ("<span data-x='1'>x</span>", true, true, true),
    ("<span onclick='1'>x</span>", false, false, false),
    ("<span is='x'>x</span>", false, false, false),
    ("<span a='1' a='2'>x</span>", false, false, false),
    ("<SPAN>x</SPAN>", true, true, true),
    ("<span>x</SPAN >", true, true, true),
    ("<span:x>y</span:x>", false, false, false),
    ("<span x:y='1'>x</span>", false, false, false),
    ("<span x_y='1'>x</span>", false, false, false),
    ("<span x>y</span>", true, true, true),
    ("<span>x", false, false, false),
    ("x</span>", false, false, false),
    ("\r\n", true, true, true),
    ("&#1114112;", false, false, false),
    ("&#128;", true, true, true),
    ("<sup>x</sup>", false, false, false),
    ("<s>x</s>", false, false, false),
    ("<button>x</button>", true, true, true),
    ("<label>x</label>", true, true, true),
    ("<input type=checkbox>", true, true, true),
    ("<select><option>a</option></select>", true, true, true),
    ("<footer>x</footer>", true, true, false),
    ("<ol><li>x<li>y</ol>", false, false, false),
    ("&copy=1 &copyz  &copy;", true, true, true),
    ("&copy=1 &copyz   &copy;", false, false, false),
    ("&xyz=abcdefghijklmnopqrs;", false, false, false),
    ("&a=abcdefghijklmnopqrst;", false, false, false),
  ]
  for entry in cases {
    let (text, body, div, span) = entry
    let html = marker + text
    assert_eq(fast_path(html, "body") is Some(_), body, msg=text)
    assert_eq(fast_path(html, "div") is Some(_), div, msg=text)
    assert_eq(fast_path(html, "span") is Some(_), span, msg=text)
  }
}

///|
test "a value ends at either quote unless the input is long" {
  // Measured in the reference browser through `DOMParser`: with 64 code
  // units or more after the opening quote the value is scanned with SIMD
  // for its own quote only.
  let marker = "<span title='&copy=1&amp;'></span>"
  let pad = "y".repeat(70)
  let cases : Array[(String, Bool)] = [
    ("<span title=\"it's\">x</span>", false),
    ("<span title=\"it's\">x</span>" + pad, true),
    ("<span title='say \"hi\"'>x</span>", false),
    ("<span title='say \"hi\"'>x</span>" + pad, true),
    ("<span title='a\"b'>" + pad + "</span>", true),
  ]
  for entry in cases {
    assert_eq(
      fast_path(marker + entry.0, "body") is Some(_),
      entry.1,
      msg=entry.0,
    )
  }
}

///|
test "markup the fast path takes has its attribute references read as text" {
  // Measured in the reference browser through `innerHTML` on a `div`.
  let cases = [
    (
      "<span title='a&copy=1 &notit; &copy;'>t</span>", "<span title=\"a©=1 ¬it; ©\">t</span>",
    ),
    (
      "<span title='x&copy=1 &copyz &copy;'>x&copy=1 &copyz</span>", "<span title=\"x&amp;copy=1 &amp;copyz ©\">x©=1 ©z</span>",
    ),
    (
      "<span title='x&copy=1'>x&amp;</span>", "<span title=\"x©=1\">x&amp;</span>",
    ),
    ("<span title='x&copy=1'>t</span>", "<span title=\"x&amp;copy=1\">t</span>"),
    ("<b>a &#x; b</b>", "<b>a \u{fffd} b</b>"),
    ("<b>a &#x; b", "<b>a &amp;#x; b</b>"),
  ]
  for entry in cases {
    let div = Element::new("div")
    div.set_inner_html(entry.0)
    assert_eq(div.to_html(), "<div>" + entry.1 + "</div>")
  }
}

///|
test "settle_references spells out what DOMPurify's parse decided" {
  assert_eq(
    settle_references("<span title='a&copy=1 &notit; &copy;'>t</span>"),
    "<span title='a&copy;=1 &not;it; &copy;'>t</span>",
  )
  assert_eq(settle_references("<b>&#x;</b>"), "<b>&#xfffd;</b>")
  // The full parser takes these: nothing to settle.
  assert_eq(
    settle_references("<span title='a&copy=1'>t</span>"),
    "<span title='a&copy=1'>t</span>",
  )
  assert_eq(settle_references("a &#x; b"), "a &#x; b")
}
