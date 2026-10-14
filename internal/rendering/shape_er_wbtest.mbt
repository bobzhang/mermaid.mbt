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
