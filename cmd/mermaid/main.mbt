///|
let usage : String =
  #|usage: mermaid <command> [arguments]
  #|
  #|commands:
  #|  render <file.mmd> [--id ID] [--config site.json] [--now MS]
  #|         [--viewport WIDTHxHEIGHT]
  #|                         render a diagram to SVG on stdout; --now sets
  #|                         the clock (milliseconds since the epoch) and
  #|                         --viewport the size of the page's viewport
  #|  config [site.json]     print the effective configuration as JSON
  #|  measure <cases.json>   measure text; cases are {text, size, bold, italic},
  #|                         with {x, y, anchor, baseline, scale} for placed SVG text
  #|  regex <cases.json>     match prefixes; cases are {source, flags, input}
  #|  flow-db <file.mmd>...  print each flowchart's parsed database as JSON
  #|  sequence-db <file.mmd>...
  #|                         the same for sequence diagrams
  #|  git-db <file.mmd>...   print each git graph's parsed database as JSON
  #|  c4-db <file.mmd>...    print each C4 diagram's parsed database as JSON
  #|  bbox <cases.json>      print getBBox() of an <svg> around each markup string
  #|  state-db <file.mmd>... print each state diagram's layout data as JSON
  #|  usecase-db <file.mmd>...
  #|                         print each use case diagram's layout data as JSON
  #|  elk-graph <file.mmd> [--config site.json]
  #|                         print the graph a diagram hands to ELK and the
  #|                         layout that came back, one JSON document a line
  #|  mindmap-db <file.mmd>... print each mindmap's tree of nodes as JSON
  #|  cose <graph.json>...   lay out each graph with cose-bilkent and print the
  #|                         positions of the nodes and the points of the edges
  #|  dagre <graphs.json>... lay out graphs with the port of dagre, one JSON
  #|                         document a line (see scripts/dagre_oracle.js)
  #|  dates <cases.json>     evaluate Date operations in the emulated time zone
  #|  time <cases.json>      evaluate dayjs and d3 time operations
  #|  format <cases.json>    format numbers; cases are {specifier, value}
  #|  colors <colors.json>   serialize CSS colors as the CSSOM does
  #|  swimlane <capture.json> [--stages]
  #|                         lay out a capture of scripts/swimlane_capture.py
  #|                         as scripts/swimlane_oracle.js does; with
  #|                         --from SNAPSHOT --run STEP, run one step
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
  let mut now : Double? = None
  let mut page = @diagram.Page::new()
  let number = (value : String) => {
    @string.parse_double(value) catch {
      _ => raise CliError("\{value} is not a number", status=2)
    }
  }
  let mut rest = options
  while true {
    match rest {
      ["--id", value, .. tail] => {
        id = value
        rest = tail
      }
      ["--now", value, .. tail] => {
        now = Some(number(value))
        rest = tail
      }
      ["--viewport", value, .. tail] => {
        guard value.split("x").map(part => part.to_owned()).collect()
          is [width, height] else {
          raise CliError("\{value} is not WIDTHxHEIGHT", status=2)
        }
        page = @diagram.Page::new(
          viewport_width=number(width),
          viewport_height=number(height),
        )
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
  let svg = @lib.render(read_text(path), id~, config=site, now?, page~) catch {
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
      // The font of a page that names none.
      { "family": String("page-default"), .. } => @font.Stack::page_default()
      { "family": String("system-sans-serif"), .. } => @font.Stack::sans_serif()
      { "family": String(family), .. } =>
        @font.Stack::for_family(
          family,
          bold=bold is True,
          italic=italic is True,
        )
      _ => @font.Stack::default(bold=bold is True, italic=italic is True)
    }
    // A case with a position is SVG text placed in a scaled diagram.
    if item is { "x": Number(x, ..), "y": Number(y, ..), .. } {
      let scale = match item {
        { "scale": Number(scale, ..), .. } => scale
        _ => 1.0
      }
      let anchor = match item {
        { "anchor": String(anchor), .. } => anchor
        _ => "start"
      }
      let baseline = match item {
        { "baseline": String(baseline), .. } => baseline
        _ => "auto"
      }
      let box = stack.svg_text_box(
        text,
        size,
        x~,
        y~,
        anchor~,
        baseline=@font.Baseline::from_css(baseline),
        scale~,
      )
      results.push({
        "len": stack.svg_text_length(text, size, scale~),
        "x": box.x,
        "y": box.y,
        "w": box.width,
        "h": box.height,
      })
      continue
    }
    let box = stack.bbox(text, size)
    results.push({
      // Whether every character has a glyph in an embedded face; the
      // measures of other text are approximations.
      "covered": stack.covers(text),
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
fn git_db(paths : ArrayView[String]) -> Unit raise CliError {
  for path in paths {
    let source = read_text(path)
    let line = try {
      let processed = @preprocess.preprocess(source)
      let config = @config.Config::new(
        directive=processed.config,
        diagram_type="gitGraph",
      )
      let graph = @gitgraph.parse(
        @preprocess.encode_entities(processed.code) + "\n",
        config,
      )
      // A frontmatter title applies unless the text has its own.
      if processed.title is Some(title) && graph.title == "" {
        graph.set_title(title)
      }
      graph.dump().stringify()
    } catch {
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
fn c4_db(paths : ArrayView[String]) -> Unit raise CliError {
  for path in paths {
    let source = read_text(path)
    let line = try {
      let processed = @preprocess.preprocess(source)
      let config = @config.Config::new(
        directive=processed.config,
        diagram_type="c4",
      )
      @c4.parse(@preprocess.encode_entities(processed.code) + "\n", config)
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
/// Print the box of an `<svg>` element holding each markup string of a
/// JSON array, as `[x, y, width, height]`, for comparing with `getBBox()`.
fn bboxes(path : String) -> Unit raise CliError {
  guard read_json(path) is Array(cases) else {
    raise CliError("\{path} must hold an array of markup strings", status=2)
  }
  let results : Array[Json] = []
  for item in cases {
    if item is String(markup) {
      let svg = @dom.Element::new("svg")
      svg.set_inner_html(markup)
      let box = svg.bbox()
      results.push([
        Json::number(box.x),
        Json::number(box.y),
        Json::number(box.width),
        Json::number(box.height),
      ])
    }
  }
  println(Json::array(results).stringify())
}

///|
fn elk_graph(path : String, options : ArrayView[String]) -> Unit raise CliError {
  let site = match options {
    ["--config", value, ..] => read_json(value)
    _ => Json::object(Map([]))
  }
  @rendering.trace_elk_graphs()
  let _ = @lib.render(read_text(path), config=site) catch {
    error => raise CliError(Repr(error).to_string(), status=1)
  }
  for pair in @rendering.traced_elk_graphs() {
    println(pair.0)
    println(pair.1.stringify())
  }
}

///|
/// Print the layout data of each use case diagram as one line of JSON.
fn usecase_db(paths : ArrayView[String]) -> Unit raise CliError {
  for path in paths {
    let source = read_text(path)
    let line = try {
      let processed = @preprocess.preprocess(source)
      let config = @config.Config::new(
        directive=processed.config,
        diagram_type="usecase",
      )
      @usecase.parse(@preprocess.encode_entities(processed.code) + "\n", config)
      .dump()
      .stringify()
    } catch {
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
fn state_db(paths : ArrayView[String]) -> Unit raise CliError {
  for path in paths {
    let source = read_text(path)
    let line = try {
      let processed = @preprocess.preprocess(source)
      let config = @config.Config::new(
        directive=processed.config,
        diagram_type="stateDiagram",
      )
      @state.parse(@preprocess.encode_entities(processed.code) + "\n", config)
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
fn sequence_db(paths : ArrayView[String]) -> Unit raise CliError {
  for path in paths {
    let source = read_text(path)
    let line = try {
      let processed = @preprocess.preprocess(source)
      let config = @config.Config::new(
        directive=processed.config,
        diagram_type="sequence",
      )
      @sequence.parse(
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
      ["sequence-db", .. paths] => sequence_db(paths)
      ["git-db", .. paths] => git_db(paths)
      ["c4-db", .. paths] => c4_db(paths)
      ["bbox", path] => bboxes(path)
      ["state-db", .. paths] => state_db(paths)
      ["usecase-db", .. paths] => usecase_db(paths)
      ["elk-graph", path, .. options] => elk_graph(path, options)
      ["cose", .. paths] => cose(paths)
      ["mindmap-db", .. paths] => mindmap_db(paths)
      ["path-length", path] => path_lengths(path)
      ["dagre", .. paths] => dagre(paths)
      ["dates", path] => dates(path)
      ["time", path] => time_cases(path)
      ["format", path] => formats(path)
      ["colors", path] => colors(path)
      ["swimlane", .. options] => swimlane(options)
      _ => println(usage)
    }
  } catch {
    CliError(message, status~) => {
      println("error: \{message}")
      @sys.exit(status)
    }
  }
}
