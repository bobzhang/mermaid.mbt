///|
/// What goes wrong while a class diagram is read or drawn.
pub(all) suberror ClassError {
  /// The source is not a class diagram upstream accepts.
  Invalid(String)
  /// Upstream accepts it; the port cannot reproduce what it makes of it.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// mermaid's `sanitizeText`. Text without a `<` comes back from DOMPurify
/// as it went in. Anything else is parsed as HTML there, which drops
/// unknown elements and rewrites character data, and is refused here.
fn sanitize_text(text : String) -> String raise ClassError {
  if text.contains("<") {
    raise Unsupported("class diagram text with markup: \{text}")
  }
  text
}

///|
/// mermaid's `formatUrl`: outside the loose security level a link is
/// sanitized; a `javascript:` URL becomes `about:blank`.
fn format_url(link : String, config : @config.Config) -> String {
  let url = js_trim(link)
  if url == "" {
    return url
  }
  if config.text("securityLevel") is Some("loose") {
    return url
  }
  // Like @braintree/sanitize-url: script-capable schemes are refused.
  let stripped = try! @jsregex.Regex::compile("[\\u0000-\\u0020]")
  let compact = stripped.replace_all(url.to_lower(), _ => "")
  for scheme in ["javascript:", "data:", "vbscript:"] {
    if compact.has_prefix(scheme) {
      return "about:blank"
    }
  }
  // The URL comes back normalized: a bare origin gains its root path.
  let origin = try! @jsregex.Regex::compile("^https?://[^/?#]+$", flags="i")
  if origin.matches(url) {
    url + "/"
  } else {
    url
  }
}
