///|
/// A style statement the chart cannot use, or one naming a style that
/// does not exist.
pub(all) suberror QuadrantError {
  QuadrantError(String)
} derive(Eq, Debug)

///|
/// A chart whose rendering depends on something that is not ported.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// How a point is drawn where it departs from the configuration: the
/// styles written after a point, or those of a `classDef`.
priv struct Styles {
  mut radius : Double?
  mut color : String?
  mut stroke_color : String?
  mut stroke_width : String?
}

///|
/// These styles, and those of `other` where these say nothing.
fn Styles::or(self : Styles, other : Styles) -> Styles {
  let pick = (own : String?, theirs : String?) => {
    if own is Some(_) {
      own
    } else {
      theirs
    }
  }
  {
    radius: if self.radius is Some(_) {
      self.radius
    } else {
      other.radius
    },
    color: pick(self.color, other.color),
    stroke_color: pick(self.stroke_color, other.stroke_color),
    stroke_width: pick(self.stroke_width, other.stroke_width),
  }
}

///|
/// A point as written: its position still text, the way the grammar
/// hands it over.
priv struct Point {
  text : String
  class_name : String
  x : String
  y : String
  styles : Styles
}

///|
/// A parsed quadrant chart.
pub struct Quadrant {
  mut title : String
  mut acc_title : String
  mut acc_description : String
  /// The texts of the quadrants, the first being the top right one and
  /// the others following counterclockwise.
  priv quadrant_texts : FixedArray[String]
  priv mut x_axis_left : String
  priv mut x_axis_right : String
  priv mut y_axis_bottom : String
  priv mut y_axis_top : String
  /// Points in the order they are drawn, the last one written first.
  priv points : Array[Point]
  priv classes : Map[String, Styles]
}

///|
fn Quadrant::new() -> Quadrant {
  {
    title: "",
    acc_title: "",
    acc_description: "",
    quadrant_texts: FixedArray::make(4, ""),
    x_axis_left: "",
    x_axis_right: "",
    y_axis_bottom: "",
    y_axis_top: "",
    points: [],
    classes: Map([]),
  }
}

///|
/// The title of the frontmatter, which a `title` statement replaces.
pub fn Quadrant::set_title(
  self : Quadrant,
  title : String,
) -> Unit raise @journeycommon.SanitizeError {
  self.title = @journeycommon.sanitize_text(title)
}

///|
/// Text of the chart as the database stores it: trimmed and sanitized.
fn text_sanitizer(text : String) -> String raise @journeycommon.SanitizeError {
  @journeycommon.sanitize_text(@journeycommon.js_trim(text))
}

///|
let style_separator : @jsregex.Regex = try! @jsregex.Regex::compile("\\s*:\\s*")

///|
let hex_code : @jsregex.Regex = try! @jsregex.Regex::compile(
  "^#?([\\dA-Fa-f]{6}|[\\dA-Fa-f]{3})$",
)

///|
let whole_number : @jsregex.Regex = try! @jsregex.Regex::compile("^\\d+$")

///|
let size_in_pixels : @jsregex.Regex = try! @jsregex.Regex::compile("^\\d+px$")

///|
/// The database's `parseStyles`: `name: value` pairs into the styles of a
/// point or class, each value checked for its kind.
fn parse_styles(styles : Array[String]) -> Styles raise QuadrantError {
  let result = {
    radius: None,
    color: None,
    stroke_color: None,
    stroke_width: None,
  }
  for style in styles {
    let parts = style_separator.split(@journeycommon.js_trim(style))
    let key = parts[0]
    // A style without a colon has no value, which JavaScript tests and
    // prints as the text `undefined`.
    let value = if parts.length() > 1 { parts[1] } else { "undefined" }
    let invalid = (kind : String) => {
      QuadrantError(
        "value for \{key} \{value} is invalid, please use a valid \{kind}",
      )
    }
    match key {
      "radius" => {
        guard whole_number.matches(value) else { raise invalid("number") }
        result.radius = Some(@journeycommon.js_number(value))
      }
      "color" => {
        guard hex_code.matches(value) else { raise invalid("hex code") }
        result.color = Some(value)
      }
      "stroke-color" => {
        guard hex_code.matches(value) else { raise invalid("hex code") }
        result.stroke_color = Some(value)
      }
      "stroke-width" => {
        guard size_in_pixels.matches(value) else {
          raise invalid("number of pixels (eg. 10px)")
        }
        result.stroke_width = Some(value)
      }
      _ => raise QuadrantError("style named \{key} is not supported.")
    }
  }
  result
}

///|
fn Quadrant::add_point(
  self : Quadrant,
  text : String,
  class_name : String,
  x : String,
  y : String,
  styles : Array[String],
) -> Unit raise {
  let styles = parse_styles(styles)
  // Each point goes in front of the ones before it.
  self.points.insert(0, {
    text: text_sanitizer(text),
    class_name,
    x,
    y,
    styles,
  })
}
