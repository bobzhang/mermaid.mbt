///|
/// Print the natural size of the image in each `data:` URL of a JSON
/// array, as `scripts/check_images.py` compares it with Chrome's:
/// `WIDTHxHEIGHT`, `undecodable`, or `unknown` when the port does not know.
fn image_sizes(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of data: URLs", status=2)
  }
  let results : Array[Json] = []
  for item in cases {
    guard item is String(url) else { continue }
    let result = match @image.data_url_size(url) {
      Some(Size(width, height)) => "\{width}x\{height}"
      Some(Undecodable) => "undecodable"
      Some(Unknown(_)) | None => "unknown"
    }
    results.push(Json::string(result))
  }
  println(Json::array(results).stringify())
}
