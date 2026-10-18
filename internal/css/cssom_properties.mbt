// The properties whose values the port parses and serializes as Blink
// does. A property Chrome does not know is dropped, as it drops it; one it
// knows that is not listed here makes the style sheet unported.

///|
/// The grammar of a property's value.
priv enum Grammar {
  /// A numeric value, or one of the keywords.
  Numeric(NumericKind, Array[String])
  /// One of the keywords.
  Keywords(Array[String])
  /// `<color>`.
  ColorValue
  /// `fill` and `stroke`: `none`, a color, a URL with a fallback.
  Paint
  /// `none` or a URL (the markers).
  UrlOrNone
  /// `<number> | <percentage>`, the percentage written as a number.
  Opacity
  FontFamily
  /// `normal`, `bold`, `bolder`, `lighter` or a number from 1 to 1000.
  FontWeight
  Transform
  DashArray
  /// One to four values of a longhand per side, written as briefly as
  /// they read.
  Sides(Grammar)
  /// `border` and its sides: a width, a style and a color, in any order.
  Border
  /// `display`: a keyword, or an outer and an inner display type.
  Display(Array[String])
}

///|
fn kind(
  length~ : Bool = true,
  percentage~ : Bool = true,
  number~ : Bool = false,
  negative~ : Bool = true,
  angle~ : Bool = false,
  integer~ : Bool = false,
) -> NumericKind {
  {
    length,
    percentage,
    angle,
    number,
    zero_length: length && !number,
    negative,
    integer,
  }
}

///|
let line_styles : Array[String] = [
  "none", "hidden", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset",
  "outset",
]

///|
let line_width : Grammar = Numeric(kind(percentage=false, negative=false), [
  "thin", "medium", "thick",
])

///|
let size_keywords : Array[String] = [
  "auto", "min-content", "max-content", "fit-content", "-webkit-fit-content", "-webkit-min-content",
  "-webkit-max-content", "-webkit-fill-available", "stretch",
]

///|
/// The longhands of the shorthands the port reads, and of those Blink
/// writes in place of all their longhands.
let shorthands : Map[String, Array[String]] = {
  let sides = (prefix : String, suffix : String) => {
    ["top", "right", "bottom", "left"].map(side => "\{prefix}\{side}\{suffix}")
  }
  Map([
    ("margin", sides("margin-", "")),
    ("padding", sides("padding-", "")),
    ("inset", sides("", "")),
    ("border-width", sides("border-", "-width")),
    ("border-style", sides("border-", "-style")),
    ("border-color", sides("border-", "-color")),
    ("border-top", ["border-top-width", "border-top-style", "border-top-color"]),
    (
      "border-right",
      ["border-right-width", "border-right-style", "border-right-color"],
    ),
    (
      "border-bottom",
      ["border-bottom-width", "border-bottom-style", "border-bottom-color"],
    ),
    (
      "border-left",
      ["border-left-width", "border-left-style", "border-left-color"],
    ),
    (
      "border",
      [
        ..sides("border-", "-width"),
        ..sides("border-", "-style"),
        ..sides("border-", "-color"),
        "border-image-source",
        "border-image-slice",
        "border-image-width",
        "border-image-outset",
        "border-image-repeat",
      ],
    ),
    ("overflow", ["overflow-x", "overflow-y"]),
    ("marker", ["marker-start", "marker-mid", "marker-end"]),
    ("gap", ["row-gap", "column-gap"]),
    ("outline", ["outline-color", "outline-style", "outline-width"]),
    ("flex", ["flex-grow", "flex-shrink", "flex-basis"]),
    ("flex-flow", ["flex-direction", "flex-wrap"]),
    (
      "text-decoration",
      [
        "text-decoration-line", "text-decoration-thickness", "text-decoration-style",
        "text-decoration-color",
      ],
    ),
    ("white-space", ["white-space-collapse", "text-wrap-mode"]),
    ("text-wrap", ["text-wrap-mode", "text-wrap-style"]),
  ])
}

///|
/// The grammars of the properties the port reads.
let property_grammars : Map[String, Grammar] = {
  let svg_length = Numeric(kind(number=true), [])
  let svg_size = Numeric(kind(number=true, negative=false), [])
  let svg_radius = Numeric(kind(number=true, negative=false), ["auto"])
  let size = Numeric(kind(negative=false), size_keywords)
  let offset = Numeric(kind(), ["auto"])
  let margin = Numeric(kind(), ["auto"])
  let padding = Numeric(kind(negative=false), [])
  let opacity = Opacity
  let grammars : Map[String, Grammar] = Map([
    ("x", svg_length),
    ("y", svg_length),
    ("cx", svg_length),
    ("cy", svg_length),
    ("r", svg_size),
    ("rx", svg_radius),
    ("ry", svg_radius),
    ("stroke-width", svg_size),
    ("stroke-dashoffset", svg_length),
    (
      "stroke-miterlimit",
      Numeric(
        kind(length=false, percentage=false, number=true, negative=false),
        [],
      ),
    ),
    ("width", size),
    ("height", size),
    ("min-width", size),
    ("min-height", size),
    ("max-width", Numeric(kind(negative=false), ["none", ..size_keywords[1:]])),
    ("max-height", Numeric(kind(negative=false), ["none", ..size_keywords[1:]])),
    ("top", offset),
    ("right", offset),
    ("bottom", offset),
    ("left", offset),
    ("margin-top", margin),
    ("margin-right", margin),
    ("margin-bottom", margin),
    ("margin-left", margin),
    ("padding-top", padding),
    ("padding-right", padding),
    ("padding-bottom", padding),
    ("padding-left", padding),
    ("margin", Sides(margin)),
    ("padding", Sides(padding)),
    ("inset", Sides(offset)),
    (
      "font-size",
      Numeric(kind(negative=false), [
        "xx-small", "x-small", "small", "medium", "large", "x-large", "xx-large",
        "xxx-large", "larger", "smaller", "math", "-webkit-xxx-large",
      ]),
    ),
    ("line-height", Numeric(kind(number=true, negative=false), ["normal"])),
    ("letter-spacing", Numeric(kind(), ["normal"])),
    ("word-spacing", Numeric(kind(), ["normal"])),
    ("text-indent", Numeric(kind(), [])),
    (
      "vertical-align",
      Numeric(kind(), [
        "baseline", "sub", "super", "text-top", "text-bottom", "middle", "top", "bottom",
        "-webkit-baseline-middle",
      ]),
    ),
    ("outline-offset", Numeric(kind(percentage=false), [])),
    ("border-top-width", line_width),
    ("border-right-width", line_width),
    ("border-bottom-width", line_width),
    ("border-left-width", line_width),
    ("outline-width", line_width),
    ("border-width", Sides(line_width)),
    ("border-top-style", Keywords(line_styles)),
    ("border-right-style", Keywords(line_styles)),
    ("border-bottom-style", Keywords(line_styles)),
    ("border-left-style", Keywords(line_styles)),
    ("border-style", Sides(Keywords(line_styles))),
    ("border-top-color", ColorValue),
    ("border-right-color", ColorValue),
    ("border-bottom-color", ColorValue),
    ("border-left-color", ColorValue),
    ("border-color", Sides(ColorValue)),
    ("border", Border),
    ("border-top", Border),
    ("border-right", Border),
    ("border-bottom", Border),
    ("border-left", Border),
    ("opacity", opacity),
    ("fill-opacity", opacity),
    ("stroke-opacity", opacity),
    ("stop-opacity", opacity),
    ("flood-opacity", opacity),
    (
      "z-index",
      Numeric(kind(length=false, percentage=false, number=true, integer=true), [
        "auto",
      ]),
    ),
    (
      "order",
      Numeric(kind(length=false, percentage=false, number=true, integer=true), []),
    ),
    (
      "flex-grow",
      Numeric(
        kind(length=false, percentage=false, number=true, negative=false),
        [],
      ),
    ),
    (
      "flex-shrink",
      Numeric(
        kind(length=false, percentage=false, number=true, negative=false),
        [],
      ),
    ),
    ("color", ColorValue),
    ("background-color", ColorValue),
    ("stop-color", ColorValue),
    ("flood-color", ColorValue),
    ("lighting-color", ColorValue),
    ("outline-color", ColorValue),
    ("caret-color", ColorValue),
    ("column-rule-color", ColorValue),
    ("text-decoration-color", ColorValue),
    ("fill", Paint),
    ("stroke", Paint),
    ("marker-start", UrlOrNone),
    ("marker-mid", UrlOrNone),
    ("marker-end", UrlOrNone),
    ("font-family", FontFamily),
    ("font-weight", FontWeight),
    ("font-style", Keywords(["normal", "italic", "oblique"])),
    ("transform", Transform),
    ("stroke-dasharray", DashArray),
    ("visibility", Keywords(["visible", "hidden", "collapse"])),
    (
      "display",
      Display([
        "none", "inline", "block", "list-item", "inline-block", "table", "inline-table",
        "table-row-group", "table-header-group", "table-footer-group", "table-row",
        "table-column-group", "table-column", "table-cell", "table-caption", "flex",
        "inline-flex", "grid", "inline-grid", "contents", "flow-root", "-webkit-box",
        "-webkit-inline-box", "-webkit-flex", "-webkit-inline-flex", "math", "ruby",
        "ruby-text",
      ]),
    ),
    ("text-anchor", Keywords(["start", "middle", "end"])),
    (
      "dominant-baseline",
      Keywords([
        "auto", "alphabetic", "ideographic", "middle", "central", "mathematical",
        "hanging", "text-bottom", "text-top",
      ]),
    ),
    (
      "alignment-baseline",
      Keywords([
        "auto", "baseline", "alphabetic", "ideographic", "middle", "central", "mathematical",
        "before-edge", "text-before-edge", "after-edge", "text-after-edge", "hanging",
      ]),
    ),
    ("stroke-linecap", Keywords(["butt", "round", "square"])),
    ("stroke-linejoin", Keywords(["miter", "round", "bevel"])),
    ("fill-rule", Keywords(["nonzero", "evenodd"])),
    ("clip-rule", Keywords(["nonzero", "evenodd"])),
    (
      "text-transform",
      Keywords(["none", "capitalize", "uppercase", "lowercase", "math-auto"]),
    ),
    (
      "text-align",
      Keywords([
        "left", "right", "center", "justify", "start", "end", "match-parent", "-webkit-left",
        "-webkit-right", "-webkit-center",
      ]),
    ),
    (
      "cursor",
      Keywords([
        "auto", "default", "none", "context-menu", "help", "pointer", "progress",
        "wait", "cell", "crosshair", "text", "vertical-text", "alias", "copy", "move",
        "no-drop", "not-allowed", "grab", "grabbing", "all-scroll", "col-resize",
        "row-resize", "n-resize", "e-resize", "s-resize", "w-resize", "ne-resize",
        "nw-resize", "se-resize", "sw-resize", "ew-resize", "ns-resize", "nesw-resize",
        "nwse-resize", "zoom-in", "zoom-out", "-webkit-grab", "-webkit-grabbing",
        "-webkit-zoom-in", "-webkit-zoom-out",
      ]),
    ),
    (
      "pointer-events",
      Keywords([
        "auto", "none", "visiblepainted", "visiblefill", "visiblestroke", "visible",
        "painted", "fill", "stroke", "all", "bounding-box",
      ]),
    ),
    (
      "position",
      Keywords(["static", "relative", "absolute", "fixed", "sticky"]),
    ),
    ("box-sizing", Keywords(["content-box", "border-box"])),
    (
      "shape-rendering",
      Keywords(["auto", "optimizespeed", "crispedges", "geometricprecision"]),
    ),
    (
      "text-rendering",
      Keywords([
        "auto", "optimizespeed", "optimizelegibility", "geometricprecision",
      ]),
    ),
    (
      "mix-blend-mode",
      Keywords([
        "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge",
        "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue",
        "saturation", "color", "luminosity", "plus-lighter",
      ]),
    ),
    ("direction", Keywords(["ltr", "rtl"])),
    ("vector-effect", Keywords(["none", "non-scaling-stroke"])),
    ("float", Keywords(["left", "right", "none", "inline-start", "inline-end"])),
    (
      "clear",
      Keywords(["none", "left", "right", "both", "inline-start", "inline-end"]),
    ),
    ("text-overflow", Keywords(["clip", "ellipsis"])),
    (
      "overflow-x",
      Keywords(["visible", "hidden", "clip", "scroll", "auto", "overlay"]),
    ),
    (
      "overflow-y",
      Keywords(["visible", "hidden", "clip", "scroll", "auto", "overlay"]),
    ),
    ("isolation", Keywords(["auto", "isolate"])),
  ])
  grammars
}

///|
/// A component that is a keyword of the list, in lower case.
fn keyword(item : Component, keywords : Array[String]) -> String? {
  match item {
    Preserved(Ident(word), _) => {
      let word = ascii_lower(word)
      if keywords.contains(word) {
        Some(word)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// The values of a list separated by white space.
fn spaced_values(items : Array[Component]) -> Array[Component] {
  items.filter(item => !item.is_whitespace())
}

///|
/// One value of a grammar that takes a single component, serialized.
fn single_value(
  grammar : Grammar,
  item : Component,
  source : Tokens,
) -> String raise CssomError {
  match grammar {
    Numeric(kind, keywords) =>
      match keyword(item, keywords) {
        Some(word) => word
        None => numeric(item, kind)
      }
    Keywords(keywords) =>
      match keyword(item, keywords) {
        Some(word) => word
        None => raise Invalid
      }
    ColorValue => color_value(item, source)
    Opacity =>
      match item {
        Preserved(Percentage(value), _) => number_text(value / 100.0)
        Func(_, _, _, _) =>
          numeric(item, kind(length=false, percentage=true, number=true))
        _ => numeric(item, kind(length=false, percentage=false, number=true))
      }
    FontWeight =>
      match keyword(item, ["normal", "bold", "bolder", "lighter"]) {
        Some(word) => word
        None =>
          match item {
            Preserved(Number(value, _, _), _) if value >= 1.0 && value <= 1000.0 =>
              number_text(value)
            Func(_, _, _, _) =>
              numeric(item, kind(length=false, percentage=false, number=true))
            _ => raise Invalid
          }
      }
    UrlOrNone =>
      match keyword(item, ["none"]) {
        Some(word) => word
        None => url_value(item)
      }
    _ => raise Invalid
  }
}

///|
/// A URL component, serialized.
fn url_value(item : Component) -> String raise CssomError {
  match item {
    Preserved(Url(url), _) => serialize_url(url)
    Func(name, arguments, _, _) if ascii_lower(name) == "url" =>
      match trim_components(arguments[:]) {
        [Preserved(Str(url), _)] => serialize_url(url)
        _ => raise Invalid
      }
    _ => raise Invalid
  }
}

///|
/// A declaration's value as Blink serializes it for `grammar`.
fn property_value(
  grammar : Grammar,
  items : Array[Component],
  source : Tokens,
) -> String raise CssomError {
  let values = spaced_values(items)
  match grammar {
    Numeric(_) | Keywords(_) | ColorValue | Opacity | FontWeight | UrlOrNone =>
      match values {
        [item] => single_value(grammar, item, source)
        _ => raise Invalid
      }
    Paint => paint_value(values, source)
    FontFamily => font_family_value(items)
    Transform => transform_value(values)
    DashArray => dash_array_value(items)
    Sides(side) => {
      guard values.length() is (1 | 2 | 3 | 4) else { raise Invalid }
      let parts = values.map(item => single_value(side, item, source))
      let top = parts[0]
      let right = parts.get(1).unwrap_or(top)
      let bottom = parts.get(2).unwrap_or(top)
      let left = parts.get(3).unwrap_or(right)
      if left != right {
        "\{top} \{right} \{bottom} \{left}"
      } else if bottom != top {
        "\{top} \{right} \{bottom}"
      } else if right != top {
        "\{top} \{right}"
      } else {
        top
      }
    }
    Border => border_value(values, source)
    Display(keywords) => display_value(values, keywords)
  }
}

///|
/// `display`, the two-keyword forms written as the keyword they amount
/// to.
fn display_value(
  values : Array[Component],
  keywords : Array[String],
) -> String raise CssomError {
  let words = []
  for item in values {
    guard item is Preserved(Ident(word), _) else { raise Invalid }
    words.push(ascii_lower(word))
  }
  match words {
    ["flow"] => "block"
    [word] if keywords.contains(word) => word
    [first, second] => {
      let (outer, inner) = if first is ("block" | "inline") {
        (first, second)
      } else {
        (second, first)
      }
      match (outer, inner) {
        ("block", "flow") => "block"
        ("inline", "flow") => "inline"
        ("block", "flow-root") => "flow-root"
        ("inline", "flow-root") => "inline-block"
        ("block", "flex" | "grid" | "table") => inner
        ("inline", "flex" | "grid" | "table") => "inline-\{inner}"
        _ => raise Unported("display: \{words.join(" ")}")
      }
    }
    [_, _, ..] => raise Unported("display: \{words.join(" ")}")
    _ => raise Invalid
  }
}

///|
fn paint_value(
  values : Array[Component],
  source : Tokens,
) -> String raise CssomError {
  match values {
    [item] =>
      match keyword(item, ["none", "context-fill", "context-stroke"]) {
        Some(word) => word
        None =>
          match item {
            Preserved(Url(_), _) => url_value(item)
            Func(name, _, _, _) if ascii_lower(name) == "url" => url_value(item)
            _ => color_value(item, source)
          }
      }
    [url, fallback] => {
      let url = url_value(url)
      let fallback = match keyword(fallback, ["none"]) {
        Some(word) => word
        None => color_value(fallback, source)
      }
      "\{url} \{fallback}"
    }
    _ => raise Invalid
  }
}

///|
/// Generic font families, which are keywords.
let generic_families : Array[String] = [
  "serif", "sans-serif", "cursive", "fantasy", "monospace", "system-ui", "math",
  "emoji", "fangsong", "ui-serif", "ui-sans-serif", "ui-monospace", "ui-rounded",
  "-webkit-body", "-webkit-pictograph",
]

///|
/// Whether a family name reads as one identifier, which Blink then
/// writes unquoted.
fn is_single_identifier(name : String) -> Bool {
  let tokens = tokenize(name).tokens
  tokens is [Ident(value)] && value == name
}

///|
fn font_family_value(items : Array[Component]) -> String raise CssomError {
  let families = []
  for part in split_commas(items[:]) {
    let part = trim_components(part[:])
    let name = match part {
      [Preserved(Str(name), _)] =>
        if is_single_identifier(name) &&
          !generic_families.contains(ascii_lower(name)) &&
          !(ascii_lower(name)
          is ("inherit"
          | "initial"
          | "unset"
          | "default"
          | "revert"
          | "revert-layer")) {
          name
        } else {
          serialize_string(name)
        }
      [Preserved(Ident(word), _)] if generic_families.contains(
          ascii_lower(word),
        ) => ascii_lower(word)
      [Preserved(Ident(word), _)] if ascii_lower(word)
        is ("inherit"
        | "initial"
        | "unset"
        | "default"
        | "revert"
        | "revert-layer") => raise Invalid
      _ => {
        let words = []
        for item in part {
          match item {
            Preserved(Ident(word), _) => words.push(word)
            Preserved(Whitespace, _) => ()
            _ => raise Invalid
          }
        }
        guard !words.is_empty() else { raise Invalid }
        let name = words.join(" ")
        if words.length() == 1 {
          serialize_identifier(name)
        } else {
          serialize_string(name)
        }
      }
    }
    families.push(name)
  }
  families.join(", ")
}

///|
/// The canonical names of transform functions, by their lower-case names,
/// and what their arguments are.
let transform_functions : Map[String, (String, Int32, Int32, NumericKind)] = {
  let length = kind(percentage=false)
  let lp = kind()
  let number = kind(length=false, percentage=false, number=true)
  let angle = kind(length=false, percentage=false, angle=true)
  Map([
    ("matrix", ("matrix", 6, 6, number)),
    ("translate", ("translate", 1, 2, lp)),
    ("translatex", ("translateX", 1, 1, lp)),
    ("translatey", ("translateY", 1, 1, lp)),
    ("translatez", ("translateZ", 1, 1, length)),
    ("scale", ("scale", 1, 2, number)),
    ("scalex", ("scaleX", 1, 1, number)),
    ("scaley", ("scaleY", 1, 1, number)),
    ("rotate", ("rotate", 1, 1, angle)),
    ("skew", ("skew", 1, 2, angle)),
    ("skewx", ("skewX", 1, 1, angle)),
    ("skewy", ("skewY", 1, 1, angle)),
  ])
}

///|
fn transform_value(values : Array[Component]) -> String raise CssomError {
  if values is [item] && keyword(item, ["none"]) is Some(word) {
    return word
  }
  guard !values.is_empty() else { raise Invalid }
  let functions = []
  for item in values {
    guard item is Func(name, arguments, _, _) else { raise Invalid }
    let lower = ascii_lower(name)
    guard transform_functions.get(lower) is Some((canonical, least, most, kind)) else {
      if lower
        is ("matrix3d"
        | "translate3d"
        | "scale3d"
        | "scalez"
        | "rotate3d"
        | "rotatex"
        | "rotatey"
        | "rotatez"
        | "perspective") {
        raise Unported("the transform \{lower}()")
      }
      raise Invalid
    }
    let parts = split_commas(arguments[:]).map(part => trim_components(part[:]))
    guard parts.length() >= least &&
      parts.length() <= most &&
      parts.iter().all(part => part.length() == 1) else {
      raise Invalid
    }
    let serialized = parts.map(part => {
      let item = part[0]
      match (canonical, item) {
        // An angle of 0 may be written without a unit.
        ("rotate" | "skew" | "skewX" | "skewY", Preserved(Number(0.0, _, _), _)) =>
          "0deg"
        ("scale" | "scaleX" | "scaleY", Preserved(Percentage(value), _)) =>
          number_text(value / 100.0)
        _ => numeric(item, kind)
      }
    })
    functions.push("\{canonical}(\{serialized.join(", ")})")
  }
  functions.join(" ")
}

///|
fn dash_array_value(items : Array[Component]) -> String raise CssomError {
  if spaced_values(items) is [item] && keyword(item, ["none"]) is Some(word) {
    return word
  }
  // Commas and white space both separate the values, but no empty one.
  let values = []
  let mut expecting = true
  for item in items {
    match item {
      Preserved(Whitespace, _) => ()
      Preserved(Comma, _) => {
        guard !expecting else { raise Invalid }
        expecting = true
      }
      _ => {
        values.push(numeric(item, kind(number=true, negative=false)))
        expecting = false
      }
    }
  }
  guard !expecting && !values.is_empty() else { raise Invalid }
  values.join(", ")
}

///|
/// `border`: the width, style and color given, in that order, without
/// those at their initial values (`medium`, `none`, `currentcolor`).
fn border_value(
  values : Array[Component],
  source : Tokens,
) -> String raise CssomError {
  guard values.length() is (1 | 2 | 3) else { raise Invalid }
  let mut width = None
  let mut style = None
  let mut color = None
  for item in values {
    let as_width = if width is None {
      Some(single_value(line_width, item, source)) catch {
        _ => None
      }
    } else {
      None
    }
    if as_width is Some(text) {
      width = Some(text)
    } else if style is None && keyword(item, line_styles) is Some(word) {
      style = Some(word)
    } else if color is None {
      color = Some(color_value(item, source))
    } else {
      raise Invalid
    }
  }
  let parts = []
  if width is Some(text) && text != "medium" {
    parts.push(text)
  }
  if style is Some(text) && text != "none" {
    parts.push(text)
  }
  if color is Some(text) && text != "currentcolor" {
    parts.push(text)
  }
  // All at their initial values, Blink writes the longhands instead.
  guard !parts.is_empty() else {
    raise Unported("a border at its initial values")
  }
  parts.join(" ")
}
