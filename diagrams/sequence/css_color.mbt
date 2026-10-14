// `box` takes an optional color before its title, and upstream tells the
// two apart by asking the browser: `CSS.supports('color', word)`. This is
// that question, for the values the grammar can hand over: a single word or
// an `rgb()`/`hsl()` function.

///|
/// Color keywords: the named colors, the system colors, and the keywords
/// every property accepts.
let color_keywords : Array[String] = [
  "aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige", "bisque",
  "black", "blanchedalmond", "blue", "blueviolet", "brown", "burlywood", "cadetblue",
  "chartreuse", "chocolate", "coral", "cornflowerblue", "cornsilk", "crimson", "cyan",
  "darkblue", "darkcyan", "darkgoldenrod", "darkgray", "darkgreen", "darkgrey", "darkkhaki",
  "darkmagenta", "darkolivegreen", "darkorange", "darkorchid", "darkred", "darksalmon",
  "darkseagreen", "darkslateblue", "darkslategray", "darkslategrey", "darkturquoise",
  "darkviolet", "deeppink", "deepskyblue", "dimgray", "dimgrey", "dodgerblue", "firebrick",
  "floralwhite", "forestgreen", "fuchsia", "gainsboro", "ghostwhite", "gold", "goldenrod",
  "gray", "green", "greenyellow", "grey", "honeydew", "hotpink", "indianred", "indigo",
  "ivory", "khaki", "lavender", "lavenderblush", "lawngreen", "lemonchiffon", "lightblue",
  "lightcoral", "lightcyan", "lightgoldenrodyellow", "lightgray", "lightgreen", "lightgrey",
  "lightpink", "lightsalmon", "lightseagreen", "lightskyblue", "lightslategray",
  "lightslategrey", "lightsteelblue", "lightyellow", "lime", "limegreen", "linen",
  "magenta", "maroon", "mediumaquamarine", "mediumblue", "mediumorchid", "mediumpurple",
  "mediumseagreen", "mediumslateblue", "mediumspringgreen", "mediumturquoise", "mediumvioletred",
  "midnightblue", "mintcream", "mistyrose", "moccasin", "navajowhite", "navy", "oldlace",
  "olive", "olivedrab", "orange", "orangered", "orchid", "palegoldenrod", "palegreen",
  "paleturquoise", "palevioletred", "papayawhip", "peachpuff", "peru", "pink", "plum",
  "powderblue", "purple", "rebeccapurple", "red", "rosybrown", "royalblue", "saddlebrown",
  "salmon", "sandybrown", "seagreen", "seashell", "sienna", "silver", "skyblue",
  "slateblue", "slategray", "slategrey", "snow", "springgreen", "steelblue", "tan",
  "teal", "thistle", "tomato", "turquoise", "violet", "wheat", "white", "whitesmoke",
  "yellow", "yellowgreen", "transparent", "currentcolor",
  // System colors, current and deprecated.
   "accentcolor", "accentcolortext", "activetext", "buttonborder", "buttonface",
  "buttontext", "canvas", "canvastext", "field", "fieldtext", "graytext", "highlight",
  "highlighttext", "linktext", "mark", "marktext", "selecteditem", "selecteditemtext",
  "visitedtext", "activeborder", "activecaption", "appworkspace", "background", "buttonhighlight",
  "buttonshadow", "captiontext", "inactiveborder", "inactivecaption", "inactivecaptiontext",
  "infobackground", "infotext", "menu", "menutext", "scrollbar", "threeddarkshadow",
  "threedface", "threedhighlight", "threedlightshadow", "threedshadow", "window",
  "windowframe", "windowtext",
  // CSS-wide keywords.
   "inherit", "initial", "unset", "revert", "revert-layer",
]

///|
/// What one argument of a color function is.
priv enum ColorArgument {
  Number
  Percentage
  Angle
  Nothing
} derive(Eq)

///|
/// Classify one argument of a color function: a number, optionally with a
/// unit, or the keyword `none`.
fn color_argument(text : StringView) -> ColorArgument? {
  if text == "none" {
    return Some(Nothing)
  }
  let chars = text.to_array()
  let mut i = 0
  if i < chars.length() && (chars[i] == '+' || chars[i] == '-') {
    i += 1
  }
  let mut digits = 0
  while i < chars.length() && chars[i] is ('0'..<='9') {
    i += 1
    digits += 1
  }
  if i + 1 < chars.length() && chars[i] == '.' && chars[i + 1] is ('0'..<='9') {
    i += 1
    while i < chars.length() && chars[i] is ('0'..<='9') {
      i += 1
      digits += 1
    }
  }
  guard digits > 0 else { return None }
  // An exponent needs digits of its own, else `e` starts a unit.
  if i < chars.length() && chars[i] == 'e' {
    let mut j = i + 1
    if j < chars.length() && (chars[j] == '+' || chars[j] == '-') {
      j += 1
    }
    if j < chars.length() && chars[j] is ('0'..<='9') {
      while j < chars.length() && chars[j] is ('0'..<='9') {
        j += 1
      }
      i = j
    }
  }
  match String::from_array(chars[i:]) {
    "" => Some(Number)
    "%" => Some(Percentage)
    "deg" | "rad" | "grad" | "turn" => Some(Angle)
    _ => None
  }
}

///|
/// Whether the arguments of `rgb()` or `hsl()` form a color, in either the
/// comma-separated or the space-separated syntax.
fn is_color_function(hsl : Bool, arguments : String) -> Bool {
  let is_alpha = (argument : ColorArgument?) => {
    argument is Some(Number | Percentage)
  }
  let words = (text : StringView) => {
    text
    .split(" ")
    .filter(word => !word.is_empty())
    .map(color_argument)
    .collect()
  }
  if arguments.contains(",") {
    // The legacy syntax: no `none`, and one kind of channel throughout.
    let parts = arguments
      .split(",")
      .map(part => color_argument(part.trim(chars=" \t\n")))
      .collect()
    guard parts.length() is (3 | 4) else { return false }
    guard parts.length() == 3 || is_alpha(parts[3]) else { return false }
    return match (parts[0], parts[1], parts[2]) {
      (Some(Number | Angle), Some(Percentage), Some(Percentage)) if hsl => true
      (Some(Number), Some(Number), Some(Number)) if !hsl => true
      (Some(Percentage), Some(Percentage), Some(Percentage)) if !hsl => true
      _ => false
    }
  }
  let (channels, alpha) = match arguments.find("/") {
    Some(slash) => {
      let alpha = words(arguments[slash + 1:])
      guard alpha.length() == 1 &&
        (is_alpha(alpha[0]) || alpha[0] == Some(Nothing)) else {
        return false
      }
      (words(arguments[:slash]), true)
    }
    None => (words(arguments[:]), false)
  }
  ignore(alpha)
  guard channels.length() == 3 else { return false }
  for index, channel in channels {
    let fits = match channel {
      Some(Number | Nothing) => true
      Some(Percentage) => !(hsl && index == 0)
      Some(Angle) => hsl && index == 0
      None => false
    }
    guard fits else { return false }
  }
  true
}

///|
/// `CSS.supports('color', value)` for a keyword or an `rgb()`/`hsl()`
/// function. Other notations cannot reach here through the grammar.
fn css_supports_color(value : String) -> Bool {
  let value = value.trim(chars=" \t\n").to_owned().to_lower()
  if color_keywords.contains(value) {
    return true
  }
  for name in ["rgba(", "rgb(", "hsla(", "hsl("] {
    if value.strip_prefix(name) is Some(rest) &&
      rest.strip_suffix(")") is Some(arguments) {
      return !arguments.contains("(") &&
        !arguments.contains(")") &&
        is_color_function(
          name.has_prefix("hsl"),
          arguments.to_owned().replace_all(old="\t", new=" "),
        )
    }
  }
  false
}
