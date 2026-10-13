// Byte-for-byte comparison against upstream mermaid.
//
// Every `testdata/<type>/<name>.mmd` has a `<name>.svg` beside it, rendered
// by mermaid itself in the reference browser (see scripts/oracle.py and
// scripts/compare.py). The port must produce exactly that text.

///|
/// Render every fixture under `testdata/<directory>` and return the names
/// of those whose output differs from the reference.
fn mismatches(directory : String) -> Array[String] raise {
  let root = "testdata/\{directory}"
  let failed = []
  let names = @fs.read_dir(root).to_owned()
  names.sort()
  let mut count = 0
  for name in names {
    guard name.strip_suffix(".mmd") is Some(stem) else { continue }
    let source = @fs.read_file_to_string("\{root}/\{name}")
    count += 1
    // A fixture upstream rejects has an `.error` file instead of an SVG.
    if !@fs.path_exists("\{root}/\{stem}.svg") {
      try @mermaid.render(source) catch {
        _ => ()
      } noraise {
        _ => failed.push("\{stem}: expected an error")
      }
      continue
    }
    let expected = @fs.read_file_to_string("\{root}/\{stem}.svg")
    let actual = @mermaid.render(source) catch {
      error => {
        failed.push("\{stem}: \{Repr(error)}")
        continue
      }
    }
    if actual != expected {
      failed.push(stem.to_owned())
    }
  }
  if count == 0 {
    fail("no fixtures in \{root}")
  }
  failed
}

///|
test "pie" {
  json_inspect(mismatches("pie"), content=[])
}
