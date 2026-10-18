// The entry point of the playground (`web/`): diagram text in, SVG out,
// as JSON text so that JavaScript gets either the SVG or the reason.

///|
/// Render `text` with the site configuration `config` (JSON text; blank
/// for none) into an `<svg>` with the id `id`. The result is JSON text:
/// `{"svg": "..."}`, or `{"error": "...", "kind": "..."}` when the diagram
/// cannot be rendered.
pub fn render_svg(text : String, config : String, id : String) -> String {
  let site : Json = if config.trim() is "" {
    Json::object(Map([]))
  } else {
    @json.parse(config) catch {
      _ => return failure("config", "The configuration is not valid JSON.")
    }
  }
  let result : Json = {
    "svg": Json::string(@lib.render(text, id~, config=site)),
  } catch {
    @lib.UnknownDiagram(message) => failure_json("unknown", message)
    @lib.Syntax(message) => failure_json("syntax", message)
    @lib.Config(message) => failure_json("config", message)
    @lib.Unsupported(message) => failure_json("unsupported", message)
    @lib.Render(message) => failure_json("render", message)
  }
  result.stringify()
}

///|
fn failure_json(kind : String, message : String) -> Json {
  { "error": Json::string(message), "kind": Json::string(kind) }
}

///|
fn failure(kind : String, message : String) -> String {
  failure_json(kind, message).stringify()
}
