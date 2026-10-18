// Colors in declarations: keywords in lower case, everything else
// resolved to `rgb()` or `rgba()` (the conversion is `@dom`'s, checked
// against Chrome by `cmd/mermaid colors`).

///|
/// The named colors of CSS Color 4, `transparent` and `currentcolor`.
let named_colors : Set[String] = Set::from_array([
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
  "windowframe", "windowtext", "-webkit-link", "-webkit-focus-ring-color", "-webkit-activelink",
  "-internal-quirk-inherit",
])

///|
/// The arguments of a legacy or modern `rgb()`/`hsl()`: whether they are
/// well formed. Legacy: three or four comma-separated values (rgb's three
/// all numbers or all percentages); modern: three space-separated values
/// and an optional `/ alpha`.
fn color_function_arguments(
  hsl : Bool,
  arguments : Array[Component],
) -> Bool raise CssomError {
  let items = trim_components(arguments[:])
  let is_number = (item : Component) => item is Preserved(Number(_, _, _), _)
  let is_percentage = (item : Component) => item is Preserved(Percentage(_), _)
  let is_hue = (item : Component) => {
    match item {
      Preserved(Number(_, _, _), _) => true
      Preserved(Dimension(_, _, unit, _), _) =>
        angle_units.contains(ascii_lower(unit))
      _ => false
    }
  }
  let is_alpha = (item : Component) => is_number(item) || is_percentage(item)
  for item in items {
    match item {
      Preserved(Ident(word), _) if ascii_lower(word) is ("none" | "from") =>
        raise Unported("this color syntax")
      Func(_, _, _, _) => raise Unported("functions in colors")
      _ => ()
    }
  }
  if items.iter().any(item => item is Preserved(Comma, _)) {
    let parts = split_commas(items[:]).map(part => trim_components(part[:]))
    guard parts.iter().all(part => part.length() == 1) &&
      parts.length() is (3 | 4) else {
      return false
    }
    let values = parts.map(part => part[0])
    let channels_ok = if hsl {
      is_hue(values[0]) && is_percentage(values[1]) && is_percentage(values[2])
    } else {
      values[:3].iter().all(is_number) || values[:3].iter().all(is_percentage)
    }
    channels_ok && (values.length() == 3 || is_alpha(values[3]))
  } else {
    let values = items.filter(item => !item.is_whitespace())
    let (channels, alpha) = match values {
      [a, b, c] => ([a, b, c], None)
      [a, b, c, Preserved(Delim('/'), _), alpha] => ([a, b, c], Some(alpha))
      _ => return false
    }
    let channels_ok = if hsl {
      is_hue(channels[0]) &&
      (is_percentage(channels[1]) || is_number(channels[1])) &&
      (is_percentage(channels[2]) || is_number(channels[2]))
    } else {
      channels.iter().all(item => is_number(item) || is_percentage(item))
    }
    channels_ok && alpha.map(is_alpha).unwrap_or(true)
  }
}

///|
/// A color, serialized.
fn color_value(item : Component, source : Tokens) -> String raise CssomError {
  match item {
    Preserved(Ident(name), _) => {
      let name = ascii_lower(name)
      guard named_colors.contains(name) else { raise Invalid }
      name
    }
    Preserved(Hash(digits, _), _) => {
      guard digits.length() is (3 | 4 | 6 | 8) &&
        digits.iter().all(c => c is ('0'..<='9' | 'a'..<='f' | 'A'..<='F')) else {
        raise Invalid
      }
      resolved_color("#" + digits)
    }
    Func(name, arguments, first, last) => {
      let name = ascii_lower(name)
      match name {
        "rgb" | "rgba" | "hsl" | "hsla" => {
          guard color_function_arguments(name.has_prefix("hsl"), arguments) else {
            raise Invalid
          }
          resolved_color(source.source(first, last))
        }
        "hwb"
        | "lab"
        | "lch"
        | "oklab"
        | "oklch"
        | "color"
        | "color-mix"
        | "light-dark"
        | "contrast-color"
        | "-webkit-gradient" => raise Unported("\{name}() colors")
        _ => raise Invalid
      }
    }
    _ => raise Invalid
  }
}

///|
/// A color resolved to `rgb()` or `rgba()`.
fn resolved_color(text : String) -> String raise CssomError {
  let serialized = @dom.serialize_declarations("fill:" + text)
  guard serialized.strip_prefix("fill: ") is Some(rest) &&
    rest.strip_suffix(";") is Some(color) &&
    color.has_prefix("rgb") else {
    raise Unported("the color \{text}")
  }
  color.to_owned()
}
