///|
/// Print the `cssText` of the rules of each style sheet in a JSON array
/// of texts, as `scripts/check_cssom.py` compares them with Chrome's; a
/// style sheet the port does not read gives `"unported: <what>"`.
fn style_sheets(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of style sheets", status=2)
  }
  let results : Array[Json] = []
  for item in cases {
    guard item is String(text) else { continue }
    let result = try @css.serialize_style_sheet(text) catch {
      CssUnsupported(what) => Json::string("unported: \{what}")
    } noraise {
      rules => Json::array(rules.map(rule => Json::string(rule)))
    }
    results.push(result)
  }
  println(Json::array(results).stringify())
}
