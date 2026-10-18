///|
/// What goes wrong while a class diagram is read or drawn.
pub(all) suberror ClassError {
  /// The source is not a class diagram upstream accepts.
  Invalid(String)
  /// Upstream accepts it; the port cannot reproduce what it makes of it.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// mermaid's `sanitizeText`: the text as DOMPurify hands it back, which
/// differs from what went in only when there is a `<` in it.
fn sanitize_text(text : String) -> String raise ClassError {
  @dom.sanitize_fragment(text) catch {
    _ => raise Unsupported("class diagram text with markup: \{text}")
  }
}

///|
/// mermaid's `formatUrl`: outside the loose security level a link goes
/// through `sanitizeUrl`, which blanks scripting schemes and spells web
/// addresses as the browser's URL parser does.
fn format_url(
  link : String,
  config : @config.Config,
) -> String raise ClassError {
  let url = js_trim(link)
  if url == "" || config.text("securityLevel") is Some("loose") {
    return url
  }
  @sanitizeurl.sanitize_url(url) catch {
    @sanitizeurl.Unsupported(message) => raise Unsupported(message)
  }
}
