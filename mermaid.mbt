///|
/// Why a diagram could not be rendered.
pub(all) suberror MermaidError {
  /// No diagram type matches the text.
  UnknownDiagram(String)
  /// The diagram text is not valid for its type.
  Syntax(String)
  /// The frontmatter or configuration is invalid.
  Config(String)
  /// The diagram type is recognized but not ported yet.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// Diagrams longer than this are refused unless `maxTextSize` says
/// otherwise.
const MAX_TEXT_LENGTH : Double = 50000.0

///|
/// What a diagram contributes to the rendering pipeline once parsed.
priv struct Parsed {
  styles : String
  acc_title : String
  acc_description : String
  /// Classes defined in the diagram text, which become stylesheet rules.
  classes : Array[StyleClass]
  draw : (@diagram.Context) -> Unit raise MermaidError
}

///|
/// `id` is the id of the `<svg>` element, for the stylesheets that address
/// definitions inside it.
fn parse_diagram(
  diagram_type : String,
  code : String,
  config : @config.Config,
  title : String?,
  id : String,
) -> Parsed raise MermaidError {
  match diagram_type {
    "pie" => {
      let pie = @pie.parse(code) catch {
        @langium.ParseError(message~, ..) => raise Syntax(message)
      }
      // A frontmatter title applies unless the diagram body has its own.
      let pie = match title {
        Some(title) if pie.title == "" => pie.with_title(title)
        _ => pie
      }
      {
        styles: @pie.styles(config.theme()),
        acc_title: pie.acc_title,
        acc_description: pie.acc_description,
        classes: [],
        draw: context => @pie.draw(pie, context),
      }
    }
    "info" => {
      @info.parse(code) catch {
        @langium.ParseError(message~, ..) => raise Syntax(message)
      }
      {
        styles: "",
        acc_title: "",
        acc_description: "",
        classes: [],
        draw: context => @info.draw(context),
      }
    }
    "packet" => {
      let packet = @packet.parse(code, config) catch {
        @langium.ParseError(message~, ..) => raise Syntax(message)
      }
      let packet = match title {
        Some(title) if packet.title == "" => packet.with_title(title)
        _ => packet
      }
      {
        styles: @packet.styles(config.theme()),
        acc_title: packet.acc_title,
        acc_description: packet.acc_description,
        classes: [],
        draw: context => @packet.draw(packet, context),
      }
    }
    "flowchart-v2" | "flowchart-elk" => {
      let db = @flowchart.parse(code, config) catch {
        @jison.ParseError(message~, ..) => raise Syntax(message)
        @flowchart.FlowError(message) => raise Syntax(message)
        error => raise Syntax(error.to_string())
      }
      if title is Some(title) && db.title == "" {
        db.set_title(title)
      }
      {
        styles: @flowchart.styles(
          config.theme(),
          config.text("theme").unwrap_or(""),
          config.text("look").unwrap_or(""),
        ),
        acc_title: db.acc_title,
        acc_description: db.acc_description,
        classes: db.classes
        .values()
        .map(c => { id: c.id, styles: c.styles, text_styles: c.text_styles, })
        .collect(),
        draw: context => {
          @flowchart.draw(db, context, diagram_type~) catch {
            @rendering.LayoutError(message) => raise Unsupported(message)
          }
        },
      }
    }
    "gitGraph" => {
      let graph = @gitgraph.parse(code, config) catch {
        @langium.ParseError(message~, ..) => raise Syntax(message)
        @gitgraph.GitError(message) => raise Syntax(message)
        @gitgraph.Unsupported(message) => raise Unsupported(message)
        error => raise Syntax(error.to_string())
      }
      if title is Some(title) && graph.title == "" {
        graph.set_title(title) catch {
          @gitgraph.Unsupported(message) => raise Unsupported(message)
        }
      }
      {
        styles: @gitgraph.styles(config, "#" + id),
        acc_title: graph.acc_title,
        acc_description: graph.acc_description,
        classes: [],
        draw: context => {
          @gitgraph.draw(graph, context) catch {
            @gitgraph.GitError(message) => raise Syntax(message)
            @gitgraph.Unsupported(message) => raise Unsupported(message)
            error => raise Syntax(error.to_string())
          }
        },
      }
    }
    "journey" => {
      let journey = @journey.parse(code) catch {
        @jison.ParseError(message~, ..) => raise Syntax(message)
        @journeycommon.SanitizeError(message) => raise Unsupported(message)
        error => raise Syntax(error.to_string())
      }
      if title is Some(title) && journey.title == "" {
        journey.set_title(title)
      }
      {
        styles: @journey.styles(config.theme()),
        acc_title: journey.acc_title,
        acc_description: journey.acc_description,
        classes: [],
        draw: context => {
          @journey.draw(journey, context) catch {
            @journey.JourneyError(message) => raise Unsupported(message)
            @journeycommon.MeasureError(message) => raise Unsupported(message)
            error => raise Unsupported(error.to_string())
          }
        },
      }
    }
    "er" => {
      let db = @er.parse(code, config) catch {
        @jison.ParseError(message~, ..) => raise Syntax(message)
        error => raise Syntax(error.to_string())
      }
      if title is Some(title) {
        db.set_title(title)
      }
      {
        styles: @er.styles(config),
        acc_title: db.acc_title,
        acc_description: db.acc_description,
        // The renderer reports no classes, so none become stylesheet rules.
        classes: [],
        draw: context => {
          @er.draw(db, context) catch {
            @rendering.LayoutError(message) => raise Unsupported(message)
          }
        },
      }
    }
    "requirement" => {
      let db = @requirement.parse(code, config) catch {
        @jison.ParseError(message~, ..) => raise Syntax(message)
        error => raise Syntax(error.to_string())
      }
      if title is Some(title) {
        db.set_title(title)
      }
      {
        styles: @requirement.styles(config),
        acc_title: db.acc_title,
        acc_description: db.acc_description,
        // The renderer reports no classes, so none become stylesheet rules.
        classes: [],
        draw: context => {
          @requirement.draw(db, context) catch {
            @rendering.LayoutError(message) => raise Unsupported(message)
          }
        },
      }
    }
    "stateDiagram" => {
      let db = @state.parse(code, config) catch {
        @jison.ParseError(message~, ..) => raise Syntax(message)
        @state.StateError(message) => raise Syntax(message)
        error => raise Syntax(error.to_string())
      }
      if title is Some(title) {
        db.set_title(title) catch {
          @state.StateError(message) => raise Syntax(message)
        }
      }
      {
        styles: @state.styles(
          config.theme(),
          config.text("theme").unwrap_or(""),
          config.text("look").unwrap_or(""),
          "#" + id,
        ),
        acc_title: db.acc_title,
        acc_description: db.acc_description,
        classes: db.classes
        .values()
        .map(c => { id: c.id, styles: c.styles, text_styles: c.text_styles, })
        .collect(),
        draw: context => {
          @state.draw(db, context) catch {
            @rendering.LayoutError(message) => raise Unsupported(message)
          }
        },
      }
    }
    "timeline" => {
      let timeline = @timeline.parse(code) catch {
        @jison.ParseError(message~, ..) => raise Syntax(message)
        @journeycommon.SanitizeError(message) => raise Unsupported(message)
        @timeline.TimelineError(message) => raise Syntax(message)
        error => raise Syntax(error.to_string())
      }
      // The timeline's database exposes neither `setDiagramTitle` nor the
      // accessibility getters to the renderer, so a frontmatter title and
      // `accTitle`/`accDescr` leave no trace in the output.
      {
        styles: @timeline.styles(
          config.theme(),
          config.text("theme").unwrap_or(""),
          id,
        ),
        acc_title: "",
        acc_description: "",
        classes: [],
        draw: context => {
          @timeline.draw(timeline, context) catch {
            @timeline.TimelineError(message) => raise Unsupported(message)
            @journeycommon.MeasureError(message) => raise Unsupported(message)
            error => raise Unsupported(error.to_string())
          }
        },
      }
    }
    other => raise Unsupported(other)
  }
}

///|
/// Render diagram text to SVG.
///
/// - `id` becomes the id of the `<svg>` element and the prefix of the ids
///   inside it, as with `mermaid.render(id, text)`.
/// - `config` is the site configuration, as passed to
///   `mermaid.initialize`. The diagram's own frontmatter and directives are
///   layered on top.
///
/// The output is byte for byte what mermaid produces in the reference
/// browser, for the diagram types and features ported so far.
pub fn render(
  text : String,
  id~ : String = "mermaid-svg",
  config~ : Json = Json::object(Map([])),
) -> String raise MermaidError {
  let processed = @preprocess.preprocess(text) catch {
    @preprocess.UnknownDiagramError(message) => raise UnknownDiagram(message)
    error => raise Config(error.to_string())
  }
  let diagram_type = @preprocess.detect_type(processed.code) catch {
    @preprocess.UnknownDiagramError(message) => raise UnknownDiagram(message)
  }
  let config = @config.Config::new(
    site=config,
    directive=processed.config,
    diagram_type~,
  ) catch {
    @config.InvalidColor(color) =>
      raise Config("Unsupported color format: \"\{color}\"")
  }
  let max_length = config.number("maxTextSize").unwrap_or(MAX_TEXT_LENGTH)
  if processed.code.length().to_double() > max_length {
    raise Syntax("Maximum text size in diagram exceeded")
  }
  let svg = @dom.Element::new("svg")
    .attr("id", id)
    .attr("width", "100%")
    .attr("xmlns", "http://www.w3.org/2000/svg")
  let first_child = svg.append("g")
  // Entity codes are shielded from the grammars, as in Diagram.fromText.
  let parsed = parse_diagram(
    diagram_type,
    @preprocess.encode_entities(processed.code) + "\n",
    config,
    processed.title,
    id,
  )
  let style = @dom.Element::new("style").text(
    compiled_styles(id, parsed.styles, config, parsed.classes),
  )
  svg.insert_before(style, first_child)
  (parsed.draw)(@diagram.Context::new(id, config, svg))
  // Accessibility: the diagram type, then its title and description.
  svg
  .attr("role", "graphics-document document")
  .attr("aria-roledescription", diagram_type)
  |> ignore
  if parsed.acc_description != "" {
    let desc_id = "chart-desc-\{id}"
    svg.attr("aria-describedby", desc_id) |> ignore
    svg.insert_first("desc").attr("id", desc_id).text(parsed.acc_description)
    |> ignore
  }
  if parsed.acc_title != "" {
    let title_id = "chart-title-\{id}"
    svg.attr("aria-labelledby", title_id) |> ignore
    svg.insert_first("title").attr("id", title_id).text(parsed.acc_title)
    |> ignore
  }
  svg.to_html()
}
