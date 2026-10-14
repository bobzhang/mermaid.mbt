///|
let usage : String =
  #|usage: mermaid <command> [arguments]
  #|
  #|commands:
  #|  render <file.mmd> [--id ID] [--config site.json]
  #|                         render a diagram to SVG on stdout
  #|  config [site.json]     print the effective configuration as JSON
  #|  measure <cases.json>   measure text; cases are {text, size, bold, italic}
  #|  regex <cases.json>     match prefixes; cases are {source, flags, input}
  #|  flow-db <file.mmd>...  print each flowchart's parsed database as JSON
  #|  dates <cases.json>     evaluate Date operations in the emulated time zone
  #|

///|
/// A command-line failure: the message to print and the exit status.
suberror CliError {
  CliError(String, status~ : Int32)
}

///|
fn read_text(path : String) -> String raise CliError {
  @fs.read_file_to_string(path) catch {
    _ => raise CliError("cannot read \{path}", status=2)
  }
}

///|
fn read_json(path : String) -> Json raise CliError {
  @json.parse(read_text(path)) catch {
    _ => raise CliError("\{path} is not valid JSON", status=2)
  }
}

///|
fn render(path : String, options : ArrayView[String]) -> Unit raise CliError {
  let mut id = "mermaid-svg"
  let mut site : Json = Json::object(Map([]))
  let mut rest = options
  while true {
    match rest {
      ["--id", value, .. tail] => {
        id = value
        rest = tail
      }
      ["--config", value, .. tail] => {
        site = read_json(value)
        rest = tail
      }
      [] => break
      [other, ..] => raise CliError("unknown option \{other}", status=2)
    }
  }
  let svg = @lib.render(read_text(path), id~, config=site) catch {
    error => raise CliError(Repr(error).to_string(), status=1)
  }
  println(svg)
}

///|
fn print_config(arguments : ArrayView[String]) -> Unit raise CliError {
  let site = match arguments {
    [path, ..] => read_json(path)
    [] => Json::object(Map([]))
  }
  let config = @config.Config::new(site~) catch {
    error => raise CliError(Repr(error).to_string(), status=1)
  }
  println(Json(config).stringify())
}

///|
fn measure(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of cases", status=2)
  }
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
    let stack = match item {
      { "family": String(family), .. } =>
        @font.Stack::for_family(
          family,
          bold=bold is True,
          italic=italic is True,
        )
      _ => @font.Stack::default(bold=bold is True, italic=italic is True)
    }
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

///|
fn regex(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of cases", status=2)
  }
  let results : Array[Json] = []
  for item in cases {
    guard item
      is {
        "source": String(source),
        "flags": String(flags),
        "input": String(input),
        ..
      } else {
      continue
    }
    let compiled = @jsregex.Regex::compile(source, flags~) catch {
      error => {
        results.push({ "error": Repr(error).to_string() })
        continue
      }
    }
    results.push(
      match compiled.match_prefix(input) {
        Some(found) => Json::string(found.text())
        None => Json::null()
      },
    )
  }
  println(Json::array(results).stringify())
}

///|
/// Print the length of each path in a JSON array of path data, for
/// comparing with `getTotalLength()`.
fn path_lengths(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of path data", status=2)
  }
  let results : Array[Json] = []
  for item in cases {
    if item is String(data) {
      results.push(Json::number(@dom.path_length(data)))
    }
  }
  println(Json::array(results).stringify())
}

///|
fn flow_db(paths : ArrayView[String]) -> Unit raise CliError {
  for path in paths {
    let source = read_text(path)
    let line = try {
      let processed = @preprocess.preprocess(source)
      let config = @config.Config::new(
        directive=processed.config,
        diagram_type="flowchart-v2",
      )
      @flowchart.parse(
        @preprocess.encode_entities(processed.code) + "\n",
        config,
      )
      .dump()
      .stringify()
    } catch {
      @jison.ParseError(message~, ..) => {
        let report : Json = { "error": message }
        report.stringify()
      }
      error => {
        let report : Json = { "error": Repr(error).to_string() }
        report.stringify()
      }
    } noraise {
      text => text
    }
    println(line)
  }
}

///|
fn main {
  let arguments = @env.args()
  try {
    match arguments[1:] {
      ["render", path, .. options] => render(path, options)
      ["config", .. rest] => print_config(rest)
      ["measure", path] => measure(path)
      ["regex", path] => regex(path)
      ["flow-db", .. paths] => flow_db(paths)
      ["path-length", path] => path_lengths(path)
      ["dates", path] => dates(path)
      _ => println(usage)
    }
  } catch {
    CliError(message, status~) => {
      println("error: \{message}")
      @sys.exit(status)
    }
  }
}
