// SVG: the natural size Blink gives an SVG image, from the `width`,
// `height`, `viewBox` and `preserveAspectRatio` attributes of the root
// `<svg>` element (never from its style), fitted to the default object size
// of 300 by 150 where they leave it open:
//
// - both lengths: that size;
// - one length: the other from the view box's proportions, else the
//   default's (150 high, or 300 wide);
// - neither: the view box's proportions fitted inside 300 by 150, else
//   300 by 150;
// - `preserveAspectRatio="none"` without both lengths: 300 by 150.
//
// Percentages leave a length open; the result is rounded to whole pixels.

///|
const SVG_NAMESPACE : String = "http://www.w3.org/2000/svg"

///|
/// The default object size of replaced elements.
const DEFAULT_WIDTH : Float = 300.0

///|
const DEFAULT_HEIGHT : Float = 150.0

///|
/// The font size of an image's document.
const DEFAULT_FONT_SIZE : Float = 16.0

///|
/// The largest size Blink reports: lengths are layout units, whose range
/// ends a little below 2^25.
const LARGEST_SIZE : Int32 = 33554428

///|
fn svg_size(data : Bytes) -> Decoded {
  let root = parse_xml(data) catch {
    Malformed => return Undecodable
    Unevaluated(reason) => return Unknown("an SVG image where \{reason}")
  }
  guard root.namespace_uri == Some(SVG_NAMESPACE) && root.local_name == "svg" else {
    return Undecodable
  }
  let attributes = root.attributes
  // The font size of the root, which font-relative lengths refer to:
  // the default of 16 pixels, or that of its `font-size` attribute in
  // absolute units, as long as no style sets it.
  let font_size = if root.has_style_element ||
    attributes.get("style").unwrap_or("").to_lower().find("font") is Some(_) {
    None
  } else {
    match attributes.get("font-size") {
      None => Some(DEFAULT_FONT_SIZE)
      Some(text) if text.trim().has_prefix("-") => None
      Some(text) =>
        match svg_length(text, None) {
          Pixels(size) => Some(size)
          _ => None
        }
    }
  }
  let length = (name : String) => {
    match attributes.get(name) {
      Some(text) => svg_length(text, font_size)
      None => Open
    }
  }
  let width = match length("width") {
    Pixels(value) => Some(value)
    Open => None
    Unevaluated(reason) => return Unknown("an SVG image whose \{reason}")
  }
  let height = match length("height") {
    Pixels(value) => Some(value)
    Open => None
    Unevaluated(reason) => return Unknown("an SVG image whose \{reason}")
  }
  let unstretched = !(attributes.get("preserveAspectRatio").unwrap_or("")
    |> aligns_to_none)
  let ratio = if unstretched {
    attributes.get("viewBox").bind(view_box_ratio)
  } else {
    None
  }
  let (width, height) = match (width, height) {
    (Some(width), Some(height)) => (width, height)
    _ if !unstretched => (DEFAULT_WIDTH, DEFAULT_HEIGHT)
    (Some(width), None) =>
      match ratio {
        Some((x, y)) => (width, width * y / x)
        None => (width, DEFAULT_HEIGHT)
      }
    (None, Some(height)) =>
      match ratio {
        Some((x, y)) => (height * x / y, height)
        None => (DEFAULT_WIDTH, height)
      }
    (None, None) =>
      match ratio {
        Some((x, y)) =>
          if x * DEFAULT_HEIGHT > DEFAULT_WIDTH * y {
            (DEFAULT_WIDTH, DEFAULT_WIDTH * y / x)
          } else {
            (DEFAULT_HEIGHT * x / y, DEFAULT_HEIGHT)
          }
        None => (DEFAULT_WIDTH, DEFAULT_HEIGHT)
      }
  }
  Size(whole_pixels(width), whole_pixels(height))
}

///|
/// A size rounded to whole pixels, halves up, within Blink's range.
fn whole_pixels(size : Float) -> Int32 {
  let rounded = (size.to_double() + 0.5).floor()
  if rounded >= LARGEST_SIZE.to_double() {
    LARGEST_SIZE
  } else {
    rounded.to_int()
  }
}

///|
/// SVG's white space.
fn is_svg_space(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\r')
}

///|
/// Whether a `preserveAspectRatio` value parses, as Blink parses it, to
/// the alignment `none`: an alignment, then optionally `meet` or `slice`,
/// between white space; anything else is the default, `xMidYMid meet`.
fn aligns_to_none(value : String) -> Bool {
  let words = value
    .split(" ")
    .flat_map(word => word.split("\t"))
    .flat_map(word => word.split("\n"))
    .flat_map(word => word.split("\r"))
    .filter(word => word != "")
    .map(word => word.to_owned())
    .collect()
  match words {
    ["none"] | ["none", "meet" | "slice"] => true
    _ => false
  }
}

///|
/// The proportions of a `viewBox` value (`min-x min-y width height`,
/// numbers separated by white space and at most one comma each), when it
/// parses and has an area; a negative width or height makes it invalid.
fn view_box_ratio(value : String) -> (Float, Float)? {
  let chars = value.to_array()
  let mut at = 0
  let skip_space = () => {
    while chars.get(at) is Some(c) && is_svg_space(c) {
      at += 1
    }
  }
  let numbers = []
  skip_space()
  for i in 0..<4 {
    guard svg_number(chars, at) is Some((number, next)) else { return None }
    numbers.push(number)
    at = next
    skip_space()
    if i < 3 && chars.get(at) == Some(',') {
      at += 1
      skip_space()
    }
  }
  guard at == chars.length() else { return None }
  let width = Float::from_double(numbers[2])
  let height = Float::from_double(numbers[3])
  guard width > 0.0 && height > 0.0 else { return None }
  Some((width, height))
}

///|
/// A number in SVG's syntax at `at`: its value and where it ends.
fn svg_number(chars : Array[Char], at : Int32) -> (Double, Int32)? {
  let mut end = at
  if chars.get(end) is Some('+' | '-') {
    end += 1
  }
  let digits = (from : Int32) => {
    let mut to = from
    while chars.get(to) is Some('0'..<='9') {
      to += 1
    }
    to
  }
  let integer_end = digits(end)
  let mut has_digits = integer_end > end
  end = integer_end
  if chars.get(end) == Some('.') {
    let fraction_end = digits(end + 1)
    guard fraction_end > end + 1 else { return None }
    has_digits = true
    end = fraction_end
  }
  guard has_digits else { return None }
  // An exponent, unless the `e` starts a unit (`em`, `ex`).
  if chars.get(end) is Some('e' | 'E') {
    let mut exponent = end + 1
    if chars.get(exponent) is Some('+' | '-') {
      exponent += 1
    }
    let exponent_end = digits(exponent)
    if exponent_end > exponent {
      end = exponent_end
    }
  }
  let text = String::from_array(chars[at:end])
  let text = if text.has_prefix(".") ||
    text.has_prefix("-.") ||
    text.has_prefix("+.") {
    text.replace(old=".", new="0.")
  } else {
    text
  }
  // Beyond the range of doubles: infinite, or zero.
  let value = @string.parse_double(text) catch {
    _ =>
      if text.find("e-") is Some(_) || text.find("E-") is Some(_) {
        0.0
      } else if text.has_prefix("-") {
        -@double.infinity
      } else {
        @double.infinity
      }
  }
  Some((value, end))
}
