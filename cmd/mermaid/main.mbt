///|
let usage : String =
  #|usage: mermaid <command> [arguments]
  #|
  #|commands:
  #|  config [site.json]   print the effective configuration as JSON
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
    _ => println(usage)
  }
}
