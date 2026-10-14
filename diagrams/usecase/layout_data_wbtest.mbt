///|
test "element ids keep word characters and dashes" {
  inspect(safe_id("Check out!"), content="Check_out")
  inspect(safe_id("__a--b__"), content="a--b")
  inspect(safe_id("!!"), content="element")
}

///|
test "JSON tables list one row per leaf" {
  let value = parse_json_object(
    "{\"b\": 1, \"a\": [1, {\"c\": null}], \"e\": {}, \"s\": [\"x\", true], \"b\": 2.50}",
  ) catch {
    _ => abort("valid JSON")
  }
  inspect(
    flatten_json_rows(value)
    .map(row => "\{row.key}|\{row.accessible_key}|\{row.value}")
    .join("; "),
    content="b|b|2.5; a[0]|a[0]|1; a[1].c|a[1].c|null; e|e|{}; s|s|x; |s|true",
  )
}
