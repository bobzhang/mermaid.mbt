// Text sizes as upstream's `calculateTextDimensions` measures them, and
// the wrapping built on them.

///|
/// mermaid's `lineBreakRegex`.
let line_break : @jsregex.Regex = try! @jsregex.Regex::compile(
  "</?br\\s*/?>",
  flags="gi",
)

///|
/// `text.split(lineBreakRegex)`: only `<br>` tags break lines; a literal
/// newline stays in the line, where SVG shows it as a space.
fn split_breaks(text : String) -> Array[String] {
  line_break.split(text)
}

///|
/// Text as SVG lays it out without `xml:space="preserve"`: line breaks
/// and tabs are spaces, runs of spaces collapse, and the spaces at both
/// ends go.
fn collapse_spaces(text : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  let mut started = false
  for c in text {
    if c is (' ' | '\t' | '\n' | '\r') {
      pending = started
    } else {
      if pending {
        out.write_char(' ')
        pending = false
      }
      out.write_char(c)
      started = true
    }
  }
  out.to_string()
}

///|
/// JavaScript's `Math.round`.
fn js_round(value : Double) -> Double {
  (value + 0.5).floor()
}

///|
/// mermaid's `calculateTextDimensions`: the width and height of `text`, a
/// line per `<br>`, as SVG text in `font`, each line's box rounded.
///
/// Upstream measures in `sans-serif` and in the font's family and keeps
/// the latter unless the former is larger in every respect. In the
/// reference browser `sans-serif` is Helvetica, which is also what the
/// default families of the configuration come down to. The port measures
/// a family list whose first installed family it embeds.
fn text_dimensions(text : String, font : Font) -> (Double, Double) raise {
  if text == "" {
    return (0.0, 0.0)
  }
  // The generic family is measured as well, in the same weight.
  guard measurable_family(font.family, font.weight) &&
    measurable_family("sans-serif", font.weight) else {
    raise Unsupported(
      "C4: text in the font family \{font.family} at weight \{font.weight}",
    )
  }
  let bold = is_bold(font.weight)
  // Width, height and the height of the tallest line.
  let measure = (family : String) => {
    let stack = @font.Stack::for_family(family, bold~)
    let mut width = 0.0
    let mut height = 0.0
    let mut line_height = 0.0
    for line in split_breaks(text) {
      // An empty line is measured as a zero-width space: no width, the
      // height of the font.
      let collapsed = collapse_spaces(line)
      if collapsed == "" && line != "" {
        // Nothing but spaces has no box at all.
        raise C4Error("svg element not in render tree")
      }
      guard stack.covers(collapsed) else {
        raise Unsupported("C4: text the embedded fonts do not cover: \{line}")
      }
      let box = stack.bbox(collapsed, font.size)
      width = js_round(width.max(box.width))
      let rounded = js_round(box.height)
      height += rounded
      line_height = js_round(line_height.max(rounded))
    }
    (width, height, line_height)
  }
  let generic = measure("sans-serif")
  let own = measure(font.family)
  if generic.1 > own.1 && generic.0 > own.0 && generic.2 > own.2 {
    (generic.0, generic.1)
  } else {
    (own.0, own.1)
  }
}

///|
/// Whether the port embeds what the reference browser draws `family` with
/// at `weight`: the first family that is installed there has to be one of
/// the embedded ones, in a face the port has.
fn measurable_family(family : String, weight : String) -> Bool {
  for name in family.split(",") {
    let name = name.trim(chars=" \t\n\"'").to_owned().to_lower()
    match name {
      "trebuchet ms" | "verdana" | "arial" | "times" | "serif" => return true
      // Helvetica, which is also the generic sans-serif there, has a
      // light face.
      "helvetica" | "sans-serif" => return !is_light(weight)
      // Not installed in the reference environment: skipped there too.
      "open sans" => continue
      _ => return false
    }
  }
  false
}

///|
/// mermaid's `calculateTextWidth`.
fn text_width(text : String, font : Font) -> Double raise {
  text_dimensions(text, font).0
}

///|
/// mermaid's `calculateTextHeight`.
fn text_height(text : String, font : Font) -> Double raise {
  text_dimensions(text, font).1
}

///|
/// mermaid's `breakString`: cut a word that is wider than a line into
/// hyphenated pieces. Returns the pieces and what is left of the word.
fn break_string(
  word : String,
  max_width : Double,
  font : Font,
) -> (Array[String], String) raise {
  let characters = word.to_array()
  let lines = []
  let mut current = ""
  for index, character in characters {
    let next = current + character.to_string()
    if text_width(next, font) >= max_width {
      let last = characters.length() == index + 1
      lines.push(if last { next } else { next + "-" })
      current = ""
    } else {
      current = next
    }
  }
  (lines, current)
}

///|
/// mermaid's `wrapLabel`: break `label` into lines no wider than
/// `max_width`, joined by `<br/>`.
fn wrap_label(label : String, max_width : Double, font : Font) -> String raise {
  if label == "" || line_break.replace_all(label, _ => "\n") != label {
    return label
  }
  let words = label
    .split(" ")
    .map(word => word.to_owned())
    .filter(word => word != "")
    .collect()
  let completed = []
  let mut next_line = ""
  for index, word in words {
    let word_length = text_width(word + " ", font)
    let next_line_length = text_width(next_line, font)
    if word_length > max_width {
      let (hyphenated, remaining) = break_string(word, max_width, font)
      completed.push(next_line)
      completed.append(hyphenated)
      next_line = remaining
    } else if next_line_length + word_length >= max_width {
      completed.push(next_line)
      next_line = word
    } else {
      next_line = if next_line == "" { word } else { next_line + " " + word }
    }
    if index + 1 == words.length() {
      completed.push(next_line)
    }
  }
  completed.filter(line => line != "").join("<br/>")
}

///|
/// A text of a boundary or relationship once measured: upstream's
/// `C4Text` with its layout fields.
priv struct Measured {
  /// The text, with `<br/>` where it was wrapped.
  text : String
  width : Double
  height : Double
  /// Where the text sits below the top of its boundary.
  mut y : Double
}

///|
/// upstream's `calcC4ShapeTextWH`: wrap `text` to `limit` when wrapping is
/// on, and measure it.
fn measure_text(
  text : String,
  wrap : Bool,
  font : Font,
  limit : Double,
) -> Measured raise {
  if wrap {
    let text = wrap_label(text, limit, font)
    { text, width: limit, height: text_height(text, font), y: 0.0, }
  } else {
    let mut width = 0.0
    let mut height = 0.0
    for line in split_breaks(text) {
      width = text_width(line, font).max(width)
      height = height + text_height(line, font)
    }
    { text, width, height, y: 0.0, }
  }
}
