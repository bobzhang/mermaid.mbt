///|
test "generic types: pairs of tildes become brackets" {
  inspect(parse_generic_types("List~string~"), content="List<string>")
  inspect(
    parse_generic_types("Array~Array~string~~"),
    content="Array<Array<string>>",
  )
  // A pair split by a comma belongs together.
  inspect(parse_generic_types("Map~K, V~"), content="Map<K, V>")
  // A single tilde, or an odd one in front, stays.
  inspect(parse_generic_types("a~b"), content="a~b")
  inspect(parse_generic_types("~a~b~"), content="~a<b>")
  inspect(parse_generic_types("plain, text"), content="plain, text")
}

///|
test "text widths in the page's font" {
  // What mermaid's `calculateTextWidth` returns in the reference browser
  // with the default configuration: Times at 16px, rounded.
  let config = @config.Config::new(diagram_type="er")
  inspect(calculate_text_width("ORDER", config), content="54")
  inspect(calculate_text_width("the name", config), content="58")
  inspect(calculate_text_width("", config), content="0")
  // "fi" is one glyph.
  inspect(calculate_text_width("office", config), content="36")
}
