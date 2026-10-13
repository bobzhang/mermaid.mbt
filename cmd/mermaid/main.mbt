///|
let usage : String =
  #|usage: mermaid <command> [arguments]
  #|
  #|commands:
  #|  config [site.json]   print the effective configuration as JSON
  #|  measure <cases.json> measure text; cases are {text, size, bold, italic}
  #|

///|
fn read_json(path : String) -> Json raise {
  @json.parse(@fs.read_file_to_string(path))
}

///|
fn main {
  let args = @env.args()
  match args[1:] {
    ["config", .. rest] => {
      let config = try {
        match rest {
          [path, ..] => @config.Config::new(site=read_json(path))
          [] => @config.Config::new()
        }
      } catch {
        error => {
          println("error: \{error}")
          return
        }
      }
      println(Json(config).stringify())
    }
    ["measure", path] => {
      let cases = read_json(path) catch {
        error => {
          println("error: \{error}")
          return
        }
      }
      guard cases is Array(cases) else { return }
      let results : Array[Json] = []
      for item in cases {
        guard item
          is {
            "text": String(text),
            "size": Number(size, ..),
            "bold": bold,
            "italic": italic,
            ..
          } else {
          continue
        }
        let stack = @font.Stack::default(
          bold=bold is True,
          italic=italic is True,
        )
        let box = stack.bbox(text, size)
        results.push({
          "len": stack.advance(text, size),
          "x": box.x,
          "y": box.y,
          "w": box.width,
          "h": box.height,
        })
      }
      println(Json::array(results).stringify())
    }
    _ => println(usage)
  }
}
