// Text measurement, as utils.ts does it for this diagram:
// `calculateTextDimensions` draws each line in a scratch `<svg>` and reads
// `getBBox()`, `wrapLabel` breaks lines with those widths. The font is
// fixed: bold, 16 pixels, mermaid's default families.

///|
const FONT_SIZE : Double = 16.0

///|
/// The two fonts every text is measured in: the browser's `sans-serif`,
/// and the families the database names.
let measuring_fonts : Array[@font.Stack] = [
  @font.Stack::sans_serif(bold=true),
  @font.Stack::for_family(
    "\"trebuchet ms\", verdana, arial, sans-serif",
    bold=true,
  ),
]

///|
/// mermaid's `lineBreakRegex`.
let line_break : @jsregex.Regex = try! @jsregex.Regex::compile(
  "<\\/?br\\s*\\/?>",
  flags="gi",
)

///|
/// What stands in for an empty line, so that it has a height.
const ZERO_WIDTH_SPACE : String = "\u{200B}"

///|
/// `Math.round`.
fn js_round(value : Double) -> Double {
  (value + 0.5).floor()
}

///|
/// `getBBox()` of one line of SVG text: width and height. A line of
/// nothing but white space draws nothing.
fn line_box(stack : @font.Stack, line : String) -> (Double, Double) raise {
  let text = @journeycommon.collapse_white_space(line)
  if text == "" {
    return (0.0, 0.0)
  }
  @journeycommon.require_glyphs(stack, text) catch {
    @journeycommon.MeasureError(message) => raise Unsupported(message)
  }
  let box = stack.bbox(text, FONT_SIZE)
  (box.width, box.height)
}

///|
/// mermaid's `calculateTextDimensions`: the widest line by the sum of the
/// line heights, each rounded. The text is measured in both fonts, and
/// the first measure only wins when it is larger in every respect.
fn text_dimensions(text : String) -> (Double, Double) raise {
  if text == "" {
    return (0.0, 0.0)
  }
  let dims = []
  for stack in measuring_fonts {
    let mut width = 0.0
    let mut height = 0.0
    let mut line_height = 0.0
    for line in line_break.split(text) {
      let line = if line == "" { ZERO_WIDTH_SPACE } else { line }
      let (line_width, box_height) = line_box(stack, line)
      // Upstream takes a box of nothing for an element that is not laid
      // out at all, and gives up.
      if line_width == 0.0 && box_height == 0.0 {
        raise Invalid("svg element not in render tree")
      }
      width = js_round(if line_width > width { line_width } else { width })
      let rounded = js_round(box_height)
      height += rounded
      line_height = js_round(
        if rounded > line_height {
          rounded
        } else {
          line_height
        },
      )
    }
    dims.push((width, height, line_height))
  }
  let (first, second) = (dims[0], dims[1])
  if first.1 > second.1 && first.0 > second.0 && first.2 > second.2 {
    (first.0, first.1)
  } else {
    (second.0, second.1)
  }
}

///|
fn text_width(text : String) -> Double raise {
  text_dimensions(text).0
}

///|
/// mermaid's `breakString`: cut a word that is wider than a line into
/// hyphenated pieces. Returns the full lines and what is left over.
fn break_string(
  word : String,
  max_width : Double,
) -> (Array[String], String) raise {
  let characters = word.iter().collect()
  let lines = []
  let mut current = ""
  for index, character in characters {
    let next = current + character.to_string()
    if text_width(next) >= max_width {
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
/// mermaid's `wrapLabel`: break `label` at its blanks into lines no wider
/// than `max_width`, joined with `<br/>`. A label that already has line
/// breaks is left alone.
fn wrap_label(label : String, max_width : Double) -> String raise {
  if label == "" || line_break.exec(label) is Some(_) {
    return label
  }
  let words = label.split(" ").filter(word => !word.is_empty()).collect()
  let completed : Array[String] = []
  let mut next_line = ""
  for index, word in words {
    let word = word.to_owned()
    let word_length = text_width(word + " ")
    let next_line_length = text_width(next_line)
    if word_length > max_width {
      let (hyphenated, remaining) = break_string(word, max_width)
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
