///|
/// What the port cannot reproduce exactly and therefore refuses.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// mermaid's `lineBreakRegex`.
let line_break : @jsregex.Regex = try! @jsregex.Regex::compile(
  "</?br\\s*/?>",
  flags="gi",
)

///|
/// Text between the tags of serialized HTML.
fn escape_html_text(text : String) -> String {
  text
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\u{a0}", new="&nbsp;")
}

///|
/// mermaid's `sanitizeText` as the git graph database calls it, with its
/// own configuration section: that section has no `securityLevel`, so
/// angle brackets and equal signs are always written as entities, and the
/// result goes through DOMPurify.
///
/// DOMPurify returns text without a `<` untouched, which leaves those
/// entities in place: an id `a=b` really is displayed as `a&equals;b`
/// upstream. Only a line break (`<br>`, or mermaid's own `#br#`
/// placeholder) sends the text through the HTML parser, which resolves
/// character references and serializes the tree again.
fn sanitize_text(text : String, html_labels : Bool) -> String raise Unsupported {
  if text == "" {
    return text
  }
  if !html_labels {
    // Nothing is escaped, so any tag reaches the HTML parser as markup.
    if text.contains("<") {
      raise Unsupported(
        "git graph text with markup and htmlLabels off: \{text}",
      )
    }
    return text
  }
  let marked = line_break.replace_all(text, _ => "#br#")
  if !marked.contains("#br#") {
    return text
      .replace_all(old="<", new="&lt;")
      .replace_all(old=">", new="&gt;")
      .replace_all(old="=", new="&equals;")
  }
  // The HTML parser would resolve whatever follows an ampersand against
  // the full table of character references.
  if text.contains("&") {
    raise Unsupported(
      "git graph text with both a line break and an ampersand: \{text}",
    )
  }
  marked
  .split("#br#")
  .map(piece => escape_html_text(piece.to_owned()))
  .join("<br>")
}
