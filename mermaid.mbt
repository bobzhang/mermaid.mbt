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
  draw : (@diagram.Context) -> Unit
}

///|
fn parse_diagram(
  diagram_type : String,
  code : String,
  config : @config.Config,
  title : String?,
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
        draw: context => @pie.draw(pie, context),
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
  let parsed = parse_diagram(
    diagram_type,
    processed.code,
    config,
    processed.title,
  )
  let style = @dom.Element::new("style").text(
    compiled_styles(id, parsed.styles, config),
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
