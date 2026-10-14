///|
/// Format numbers with d3-format, for comparing with upstream: every case
/// is `{specifier, value}`, and the result its text or `{error}`.
fn formats(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of cases", status=2)
  }
  let results : Array[Json] = []
  for item in cases {
    guard item is { "specifier": String(specifier), "value": value, .. } else {
      continue
    }
    let value = match value {
      Number(value, ..) => value
      String("Infinity") => @double.infinity
      String("-Infinity") => @double.neg_infinity
      String("-0") => -0.0
      _ => @double.not_a_number
    }
    let format = @d3.format(specifier) catch {
      @d3.InvalidFormat(message) => {
        results.push({ "error": message })
        continue
      }
    }
    results.push(Json::string(format.apply(value)))
  }
  println(Json::array(results).stringify())
}
