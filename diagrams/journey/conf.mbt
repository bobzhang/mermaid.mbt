///|
/// Why a journey could not be drawn exactly as upstream draws it.
pub(all) suberror JourneyError {
  JourneyError(String)
} derive(Eq, Debug)

///|
/// The `journey` section of the configuration, read once.
priv struct Conf {
  use_max_width : Bool
  diagram_margin_x : Double
  diagram_margin_y : Double
  left_margin : Double
  max_label_width : Double
  width : Double
  height : Double
  box_text_margin : Double
  task_margin : Double
  /// The size of task and section text: what multiplies line offsets, and
  /// the `font-size` declaration it becomes (absent when CSS rejects it).
  task_font_size : Double
  task_font_size_css : String?
  task_font_family : String
  text_placement : String
  actor_colours : Array[String]
  section_fills : Array[String]
  section_colours : Array[String]
  title_color : Json
  title_font_family : Json
  title_font_size : Json
}

///|
fn Conf::new(config : @config.Config) -> Conf raise JourneyError {
  let number = (name : String) => {
    match config.get("journey.\{name}") {
      Number(n, ..) => n
      _ => raise JourneyError("journey.\{name} must be a number")
    }
  }
  let colours = (name : String) => {
    guard config.get("journey.\{name}") is Array(items) else {
      raise JourneyError("journey.\{name} must be a list of colours")
    }
    items.map(item => {
      match item {
        String(colour) => colour
        _ => raise JourneyError("journey.\{name} must be a list of colours")
      }
    })
  }
  // A number is a length in pixels, in arithmetic and in CSS alike. A
  // string is `NaN` in the arithmetic unless it spells a number.
  let (task_font_size, task_font_size_css) = match
    config.get("journey.taskFontSize") {
    Number(n, ..) =>
      (n, if n >= 0.0 { Some(@dom.number(n) + "px") } else { None })
    String(text) => (js_number(text), css_font_size(text))
    _ => raise JourneyError("journey.taskFontSize must be a number")
  }
  let task_font_family = match config.get("journey.taskFontFamily") {
    String(family) => css_font_family(family)
    _ => raise JourneyError("journey.taskFontFamily must be a string")
  }
  {
    use_max_width: config.flag("journey.useMaxWidth"),
    diagram_margin_x: number("diagramMarginX"),
    diagram_margin_y: number("diagramMarginY"),
    left_margin: number("leftMargin"),
    max_label_width: number("maxLabelWidth"),
    width: number("width"),
    height: number("height"),
    box_text_margin: match config.get("journey.boxTextMargin") {
      Null => 5.0
      _ => number("boxTextMargin")
    },
    task_margin: number("taskMargin"),
    task_font_size,
    task_font_size_css,
    task_font_family,
    text_placement: config.text("journey.textPlacement").unwrap_or(""),
    actor_colours: colours("actorColours"),
    section_fills: colours("sectionFills"),
    section_colours: colours("sectionColours"),
    title_color: config.get("journey.titleColor"),
    title_font_family: config.get("journey.titleFontFamily"),
    title_font_size: config.get("journey.titleFontSize"),
  }
}

///|
/// A `font-size` value as the CSSOM serializes it once set through
/// `style.setProperty`. SVG elements parse their inline style in quirks
/// mode, where a bare number is a length in pixels. Only plain lengths
/// are understood here.
fn css_font_size(text : String) -> String? raise JourneyError {
  let text = text.trim(chars=" \t\n\r\u{0c}").to_owned()
  let units = ["px", "em", "rem", "ex", "pt", "pc", "cm", "mm", "in", "%"]
  let mut value = text
  let mut unit = "px"
  for candidate in units {
    if text.to_lower().has_suffix(candidate) &&
      !(candidate == "em" && text.to_lower().has_suffix("rem")) {
      value = text[:text.length() - candidate.length()].to_owned()
      unit = candidate
      break
    }
  }
  // Signs, exponents and anything else CSS reads differently from
  // JavaScript are left alone.
  let plain = value != "" &&
    value.iter().all(c => c is ('0'..<='9' | '.')) &&
    value.iter().filter(c => c == '.').count() <= 1 &&
    !value.has_suffix(".")
  if !plain {
    raise JourneyError("journey.taskFontSize \{text} is not a plain length")
  }
  Some(@dom.number(js_number(value)) + unit)
}

///|
/// A `font-family` list as the CSSOM serializes it: names separated by
/// `, `, a quoted name in double quotes, a name of plain identifiers as
/// written.
fn css_font_family(text : String) -> String raise JourneyError {
  let families = []
  for part in text.split(",") {
    let name = part.trim(chars=" \t\n\r\u{0c}").to_owned()
    let unsupported = () => {
      JourneyError("journey.taskFontFamily \{text} is not a plain list")
    }
    if name.length() >= 2 &&
      (
        (name.has_prefix("\"") && name.has_suffix("\"")) ||
        (name.has_prefix("'") && name.has_suffix("'"))
      ) {
      let inner = name[1:name.length() - 1].to_owned()
      if inner.contains("\"") || inner.contains("'") || inner.contains("\\") {
        raise unsupported()
      }
      families.push("\"\{inner}\"")
    } else {
      // An unquoted name is a run of identifiers; several of them
      // serialize as one quoted name.
      let words = []
      for word in name.split(" ") {
        if word.is_empty() {
          continue
        }
        let word = word.to_owned()
        let first = if word.has_prefix("-") {
          word[1:].to_owned()
        } else {
          word
        }
        let is_start = (c : Char) => {
          c is ('a'..<='z' | 'A'..<='Z' | '_') || c.to_int() >= 0x80
        }
        let ok = first != "" &&
          is_start(first.get_char(0).unwrap()) &&
          word.iter().all(c => is_start(c) || c is ('0'..<='9' | '-'))
        if !ok {
          raise unsupported()
        }
        words.push(word)
      }
      match words {
        [] => raise unsupported()
        [word] => {
          // Generic families are keywords, which serialize in lower case.
          let lower = word.to_lower()
          let generic = [
            "serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui",
            "math", "ui-serif", "ui-sans-serif", "ui-monospace", "ui-rounded",
          ]
          let wide = [
            "inherit", "initial", "unset", "revert", "revert-layer", "default",
          ]
          if wide.contains(lower) {
            raise unsupported()
          }
          families.push(if generic.contains(lower) { lower } else { word })
        }
        words => families.push("\"" + words.join(" ") + "\"")
      }
    }
  }
  families.join(", ")
}
