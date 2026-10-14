///|
/// Resolve colors the way the CSSOM serializes them (`rgb(r, g, b)`), for
/// comparing with what the reference browser reads back from
/// `element.style.fill`: the input is a JSON array of CSS colors, the
/// output one of their serializations.
fn colors(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of colors", status=2)
  }
  let results : Array[Json] = []
  for item in cases {
    guard item is String(color) else { continue }
    let serialized = @dom.serialize_declarations("fill:" + color)
    results.push(
      match serialized.strip_prefix("fill: ") {
        Some(rest) =>
          Json::string(rest.strip_suffix(";").unwrap_or(rest).to_owned())
        None => Json::null()
      },
    )
  }
  println(Json::array(results).stringify())
}
