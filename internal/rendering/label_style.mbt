// The inline styles of a label that change how its text measures: weight,
// slant, size and family. They are written on the label's element, so the
// browser lays the text out with them.

///|
/// The number at the start of a CSS length and the unit after it.
fn css_length(value : String) -> (Double, String)? {
  let mut end = 0
  for c in value {
    guard c is ('0'..<='9' | '.' | '-' | '+') else { break }
    end += 1
  }
  guard end > 0 else { return None }
  let number = @string.parse_double(value[:end].to_owned()) catch {
    _ => return None
  }
  Some((number, value[end:].trim().to_owned()))
}

///|
/// The environment text is measured in under the declarations of `style`,
/// such as `color:#fff !important;font-weight:bold !important`. SVG text
/// names weight and slant on every `<tspan>`, so there only size and
/// family reach the text: `faces` is false.
fn Env::styled(self : Env, style : String, faces~ : Bool = true) -> Env {
  if !style.contains("font") {
    return self
  }
  let mut env = self
  for declaration in style.split(";") {
    guard declaration.find(":") is Some(colon) else { continue }
    let name = declaration[:colon].trim().to_owned().to_lower()
    let value = declaration[colon + 1:]
      .to_owned()
      .replace_all(old="!important", new="")
      .trim()
      .to_owned()
    match name {
      "font-weight" if faces => {
        let bold = match value.to_lower() {
          "bold" | "bolder" => true
          "normal" | "lighter" => false
          other =>
            match css_length(other) {
              Some((weight, "")) => weight >= 600.0
              _ => env.bold
            }
        }
        env = { ..env, bold, }
      }
      "font-style" if faces => {
        let italic = match value.to_lower() {
          "italic" => true
          "normal" => false
          other => other.has_prefix("oblique")
        }
        env = { ..env, italic, }
      }
      "font-size" =>
        match css_length(value) {
          Some((size, "px")) => env = { ..env, font_size: size, }
          // Relative sizes compound over the elements the style is
          // written on, which differ from label to label; not modelled.
          _ => ()
        }
      "font-family" => env = { ..env, font_family: value, }
      _ => ()
    }
  }
  env
}
