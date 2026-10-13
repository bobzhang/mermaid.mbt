///|
/// Parse a CSS color: hex, `rgb()`/`rgba()`, `hsl()`/`hsla()` or a keyword.
pub fn Channels::parse(color : String) -> Channels raise ColorError {
  if parse_hex(color, color) is Some(c) {
    return c
  }
  if parse_rgb(color) is Some(c) {
    return c
  }
  if parse_hsl(color) is Some(c) {
    return c
  }
  if keyword_hex(color.to_lower()) is Some(hex) &&
    parse_hex(hex, hex) is Some(c) {
    return c
  }
  raise Unsupported(color)
}

///|
fn hex_digit(c : Char) -> Int32? {
  match c {
    '0'..<='9' => Some(c.to_int() - '0')
    'a'..<='f' => Some(c.to_int() - 'a' + 10)
    'A'..<='F' => Some(c.to_int() - 'A' + 10)
    _ => None
  }
}

///|
/// `#rgb`, `#rgba`, `#rrggbb` and `#rrggbbaa`.
fn parse_hex(color : StringView, source : String) -> Channels? {
  guard color is ['#', .. digits] else { return None }
  let values = []
  for c in digits {
    guard hex_digit(c) is Some(d) else { return None }
    values.push(d)
  }
  let channel = fn(i : Int32) -> Double {
    if values.length() <= 4 {
      (values[i] * 17).to_double()
    } else {
      (values[2 * i] * 16 + values[2 * i + 1]).to_double()
    }
  }
  match values.length() {
    3 | 6 =>
      Some(Channels::from_rgb(channel(0), channel(1), channel(2), 1.0, source~))
    4 | 8 =>
      Some(
        Channels::from_rgb(
          channel(0),
          channel(1),
          channel(2),
          channel(3) / 255.0,
          source~,
        ),
      )
    _ => None
  }
}

///|
/// One numeric argument of a color function, with its unit suffix.
priv struct Argument {
  value : Double
  unit : String
}

///|
/// Split the arguments of `name(...)`, which may be separated by commas,
/// whitespace, or (before the alpha) a slash. Returns `None` when the text is
/// not a call to one of `names` or an argument is not a number.
fn parse_function(color : String, names : Array[String]) -> Array[Argument]? {
  let lower = color.to_lower()
  let mut body : StringView? = None
  for name in names {
    if lower.strip_prefix(name + "(") is Some(rest) &&
      rest.strip_suffix(")") is Some(inner) {
      body = Some(inner)
      break
    }
  }
  guard body is Some(body) else { return None }
  let arguments = []
  let token = StringBuilder()
  let flush = fn() -> Bool {
    if token.is_empty() {
      return true
    }
    let text = token.to_string()
    token.reset()
    match parse_argument(text) {
      Some(argument) => {
        arguments.push(argument)
        true
      }
      None => false
    }
  }
  for c in body {
    match c {
      ' ' | '\t' | '\n' | ',' | '/' => if !flush() { return None }
      _ => token.write_char(c)
    }
  }
  guard flush() else { return None }
  Some(arguments)
}

///|
fn parse_argument(text : String) -> Argument? {
  let text = text.strip_prefix("+").map(v => v.to_owned()).unwrap_or(text)
  let mut end = text.length()
  while end > 0 &&
        !(text.get_char(end - 1) is Some('0'..<='9') ||
        text.get_char(end - 1) is Some('.')) {
    end -= 1
  }
  guard end > 0 else { return None }
  let value = @string.parse_double(text[:end]) catch { _ => return None }
  Some({ value, unit: text[end:].to_owned(), })
}

///|
fn parse_rgb(color : String) -> Channels? {
  guard parse_function(color, ["rgba", "rgb"]) is Some(arguments) else {
    return None
  }
  guard arguments.length() is (3 | 4) else { return None }
  let channel = fn(argument : Argument) -> Double? {
    match argument.unit {
      "" => Some(clamp_rgb(argument.value))
      "%" => Some(clamp_rgb(argument.value * 2.55))
      _ => None
    }
  }
  guard channel(arguments[0]) is Some(r) &&
    channel(arguments[1]) is Some(g) &&
    channel(arguments[2]) is Some(b) else {
    return None
  }
  guard parse_alpha(arguments) is Some(a) else { return None }
  Some(Channels::from_rgb(r, g, b, a, source=color))
}

///|
fn parse_alpha(arguments : Array[Argument]) -> Double? {
  guard arguments.get(3) is Some(alpha) else { return Some(1.0) }
  match alpha.unit {
    "" => Some(clamp_alpha(alpha.value))
    "%" => Some(clamp_alpha(alpha.value / 100.0))
    _ => None
  }
}

///|
fn parse_hsl(color : String) -> Channels? {
  guard parse_function(color, ["hsla", "hsl"]) is Some(arguments) else {
    return None
  }
  guard arguments.length() is (3 | 4) else { return None }
  let hue = arguments[0]
  let h = match hue.unit {
    "" | "deg" => clamp_hue(hue.value)
    "grad" => clamp_hue(hue.value * 0.9)
    "rad" => clamp_hue(hue.value * 180.0 / @math.PI)
    "turn" => clamp_hue(hue.value * 360.0)
    _ => return None
  }
  guard arguments[1].unit == "%" && arguments[2].unit == "%" else {
    return None
  }
  guard parse_alpha(arguments) is Some(a) else { return None }
  Some(
    Channels::from_hsl(
      h,
      clamp_percent(arguments[1].value),
      clamp_percent(arguments[2].value),
      a,
      source=color,
    ),
  )
}
