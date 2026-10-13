///|
/// Protect `#name;` and `#123;` entity codes from the diagram grammars,
/// where `#` and `;` have meanings of their own: they are rewritten with
/// placeholder characters that the serializer turns back into entities.
/// A trailing `;` after a color in `style` and `classDef` lines is dropped
/// first, so that `#f9f;` is not mistaken for an entity.
pub fn encode_entities(text : String) -> String {
  let style = try! @jsregex.Regex::compile("style.*:\\S*#.*;")
  let class_def = try! @jsregex.Regex::compile("classDef.*:\\S*#.*;")
  let entity = try! @jsregex.Regex::compile("#\\w+;")
  let drop_last = (found : @jsregex.Match) => {
    let matched = found.text()
    matched[:matched.length() - 1].to_owned()
  }
  let text = style.replace_all(text, drop_last)
  let text = class_def.replace_all(text, drop_last)
  entity.replace_all(text, found => {
    let matched = found.text()
    let inner = matched[1:matched.length() - 1].to_owned()
    let digits = inner.strip_prefix("+").map(v => v.to_owned()).unwrap_or(inner)
    if digits != "" && digits.iter().all(c => c is ('0'..<='9')) {
      "ﬂ°°" + inner + "¶ß"
    } else {
      "ﬂ°" + inner + "¶ß"
    }
  })
}
