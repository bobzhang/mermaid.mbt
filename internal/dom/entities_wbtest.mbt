///|
test "a reference's name stops before a character outside the basic plane" {
  // Both halves of 😀 and 𠮷 stay after the reference, or after the `&`
  // that starts none.
  assert_eq(resolve_references("&😀"), "&😀")
  assert_eq(resolve_references("&copy;𠮷"), "©𠮷")
  assert_eq(resolve_references("&copy😀"), "©😀")
  assert_eq(resolve_references("&copy😀", in_attribute=true), "©😀")
  assert_eq(resolve_references("&amp😀x;"), "&😀x;")
}

///|
test "markup with references before characters outside the basic plane" {
  // Measured in the reference browser through `innerHTML` on a `div`.
  let cases = [
    ("&😀", "&amp;😀"),
    ("&copy;𠮷", "©𠮷"),
    ("<b title='&copy😀'>&copy😀</b>", "<b title=\"©😀\">©😀</b>"),
    ("<b title='&copy😀x;'>t</b>", "<b title=\"©😀x;\">t</b>"),
    (
      "<b title='a&copy𠮷'>t</b><em></em>", "<b title=\"a©𠮷\">t</b><em></em>",
    ),
  ]
  for entry in cases {
    let div = Element::new("div")
    div.set_inner_html(entry.0)
    assert_eq(div.to_html(), "<div>" + entry.1 + "</div>")
  }
}
