// Text measurement, as utils.ts does it: `calculateTextDimensions` draws
// the text in a scratch `<svg>` and reads `getBBox()`, `wrapLabel` breaks
// lines with those widths.

///|
/// The font of one kind of text: participants, notes or messages. The
/// values are kept as configured — a size may be a number or a CSS length,
/// and a family may not be valid CSS at all.
priv struct TextFont {
  family : String?
  size : Json
  weight : Json
}

///|
/// mermaid's `parseFontSize`: the number a size starts with, and the size
/// as a CSS length. Both are missing when the size has no leading number.
fn parse_font_size(size : Json) -> (Double?, String?) {
  match size {
    Number(n, ..) => (Some(n), Some(@dom.number(n) + "px"))
    String(text) =>
      match @diagram.parse_font_size(text) {
        None => (None, None)
        Some(n) =>
          if text == @dom.number(n) {
            (Some(n), Some(text + "px"))
          } else {
            (Some(n), Some(text))
          }
      }
    _ => (None, None)
  }
}

///|
/// The pixels a CSS `font-size` computes to. Only absolute pixel sizes
/// can be told without the cascade.
fn css_pixels(size : String?) -> Double raise SequenceError {
  // Without a size the text takes the one it inherits, the browser's
  // default.
  guard size is Some(size) else { return 16.0 }
  let text = size.trim(chars=" \t\n").to_owned().to_lower()
  let unsupported = SequenceError("Unsupported font size: \{size}")
  guard text.strip_suffix("px") is Some(digits) else { raise unsupported }
  let value = @string.parse_double(digits.to_owned()) catch {
    _ => raise unsupported
  }
  guard value > 0.0 else { raise unsupported }
  value
}

///|
/// Whether a `font-weight` selects the bold face of a family that has a
/// regular and a bold one.
fn is_bold(weight : Json) -> Bool {
  match weight {
    Number(n, ..) => n >= 600.0 && n <= 1000.0
    String(text) =>
      match text.trim(chars=" \t\n").to_owned().to_lower() {
        "bold" | "bolder" => true
        digits => {
          let n = @string.parse_double(digits) catch { _ => return false }
          n >= 600.0 && n <= 1000.0
        }
      }
    _ => false
  }
}

///|
/// Whether the CSSOM accepts `value` for `font-family`. mermaid's default
/// family ends in a semicolon and is refused, which leaves the text in the
/// font it inherits.
fn is_valid_font_family(value : String) -> Bool {
  serialize_font_family(value) is Some(_)
}

///|
/// Families installed in the reference environment that this port has no
/// metrics for. Text in them cannot be measured exactly.
let unmeasured_families : Array[String] = [
  "courier", "courier new", "monospace", "georgia", "tahoma", "times new roman",
  "comic sans ms", "impact", "menlo", "monaco", "cursive", "fantasy", "system-ui",
  "-apple-system", "blinkmacsystemfont", "helvetica neue", "lucida grande", "palatino",
  "optima", "futura", "gill sans", "andale mono", "arial black", "arial narrow",
  "ui-sans-serif", "ui-serif", "ui-monospace", "ui-rounded", "math", "emoji", "geneva",
  "sf pro", "sf mono", "avenir", "avenir next", "baskerville", "didot", "hoefler text",
  "american typewriter", "trattatello", "papyrus", "brush script mt", "zapfino",
]

///|
/// The font stack a `font-family` declaration draws with.
fn font_stack(family : String, bold : Bool) -> @font.Stack raise SequenceError {
  for name in family.split(",") {
    let name = name.trim(chars=" \t\n\"'").to_owned().to_lower()
    if unmeasured_families.contains(name) {
      raise SequenceError("Unsupported font family: \{name}")
    }
  }
  @font.Stack::for_css(family, bold~)
}

///|
/// The text of a line as SVG lays it out: white space collapses, and
/// none is left at either end.
fn collapse_spaces(line : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  for c in line {
    if c is (' ' | '\t' | '\n' | '\r') {
      pending = out.to_string() != ""
      continue
    }
    if pending {
      out.write_char(' ')
      pending = false
    }
    out.write_char(c)
  }
  out.to_string()
}

///|
/// `getBBox()` of one line of SVG text in `stack` at `size` pixels: width
/// and height. A line of nothing but spaces renders nothing.
fn line_box(
  stack : @font.Stack,
  line : String,
  size : Double,
  baseline~ : @font.Baseline = Alphabetic,
) -> (Double, Double) raise SequenceError {
  let text = collapse_spaces(line)
  if text == "" {
    return (0.0, 0.0)
  }
  if stack.first_uncovered(text) is Some(c) {
    // The browser would fall back to a system font this port has no
    // metrics for.
    raise SequenceError(
      "Unsupported: no font metrics for the character U+\{c.to_int().to_string(radix=16).to_upper()}",
    )
  }
  let box = stack.bbox(text, size, baseline~)
  (box.width, box.height)
}

///|
/// `Math.round`.
fn js_round(value : Double) -> Double {
  (value + 0.5).floor()
}

///|
/// Split text at `<br>` tags (`common.lineBreakRegex`).
fn split_breaks(text : String) -> Array[String] {
  let breaks = try! @jsregex.Regex::compile("<\\/?br\\s*\\/?>", flags="gi")
  breaks.split(text)
}

///|
fn has_breaks(text : String) -> Bool {
  let breaks = try! @jsregex.Regex::compile("<\\/?br\\s*\\/?>", flags="i")
  breaks.exec(text) is Some(_)
}

///|
const ZERO_WIDTH_SPACE : String = "\u{200B}"

///|
/// The size of a text of several lines: the widest line by the sum of the
/// line heights, each rounded.
priv struct Dimensions {
  width : Double
  height : Double
  line_height : Double
}

///|
/// mermaid's `calculateTextDimensions`. The text is measured twice, in the
/// browser's `sans-serif` and in the configured family, and the first
/// measure only wins when it is larger in every respect.
fn text_dimensions(
  text : String,
  font : TextFont,
) -> Dimensions raise SequenceError {
  if text == "" {
    return { width: 0.0, height: 0.0, line_height: 0.0, }
  }
  let (_, size) = parse_font_size(font.size)
  let size = css_pixels(size)
  let bold = is_bold(font.weight)
  let family = font.family.unwrap_or("Arial")
  let stacks = [
    font_stack("sans-serif", bold),
    // A family the CSSOM refuses leaves the browser's standard font.
    if is_valid_font_family(family) {
      font_stack(family, bold)
    } else {
      @font.Stack::page_default(bold~)
    },
  ]
  let dims = []
  for stack in stacks {
    let mut width = 0.0
    let mut height = 0.0
    let mut line_height = 0.0
    for line in split_breaks(text) {
      let line = if line == "" { ZERO_WIDTH_SPACE } else { line }
      let (line_width, box_height) = line_box(stack, line, size)
      if line_width == 0.0 && box_height == 0.0 {
        raise SequenceError("svg element not in render tree")
      }
      width = js_round(width.max(line_width))
      let rounded = js_round(box_height)
      height += rounded
      line_height = js_round(line_height.max(rounded))
    }
    dims.push({ width, height, line_height, })
  }
  if dims[0].height > dims[1].height &&
    dims[0].width > dims[1].width &&
    dims[0].line_height > dims[1].line_height {
    dims[0]
  } else {
    dims[1]
  }
}

///|
fn text_width(text : String, font : TextFont) -> Double raise SequenceError {
  text_dimensions(text, font).width
}

///|
/// mermaid's `breakString`: cut a word that is wider than a line into
/// hyphenated pieces. Returns the full lines and what is left over.
fn break_string(
  word : String,
  max_width : Double,
  font : TextFont,
) -> (Array[String], String) raise SequenceError {
  let characters = word.iter().collect()
  let lines = []
  let mut current = ""
  for index, character in characters {
    let next = current + character.to_string()
    if text_width(next, font) >= max_width {
      let is_last = index + 1 == characters.length()
      lines.push(if is_last { next } else { next + "-" })
      current = ""
    } else {
      current = next
    }
  }
  (lines, current)
}

///|
/// mermaid's `wrapLabel`: break `label` into lines no wider than
/// `max_width`, joined with `<br/>`. A label that already has line breaks
/// is left alone.
fn wrap_label(
  label : String,
  max_width : Double,
  font : TextFont,
) -> String raise SequenceError {
  if label == "" || has_breaks(label) {
    return label
  }
  let words = label.split(" ").filter(word => !word.is_empty()).collect()
  let completed : Array[String] = []
  let mut next_line = ""
  for index, word in words {
    let word = word.to_owned()
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
