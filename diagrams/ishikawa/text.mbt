///|
/// How the stylesheet has a kind of label set: the classes win over the
/// `text-anchor` attribute the renderer writes.
priv struct TextStyle {
  font : @font.Stack
  size : Double
  anchor : @font.Anchor
  baseline : @font.Baseline
}

///|
let line_break : @jsregex.Regex = try! @jsregex.Regex::compile(
  "<br\\s*\\/?>|\\n",
)

///|
let white_space : @jsregex.Regex = try! @jsregex.Regex::compile("\\s+")

///|
/// `wrapText`: break a label into lines of at most `max_chars` characters
/// where it has white space. A word longer than that stays whole.
fn wrap_text(text : String, max_chars : Int32) -> String {
  if text.length() <= max_chars {
    return text
  }
  let lines : Array[String] = []
  for word in white_space.split(text) {
    let last = lines.length() - 1
    if last >= 0 && lines[last].length() + 1 + word.length() <= max_chars {
      lines[last] = lines[last] + " " + word
    } else {
      lines.push(word)
    }
  }
  lines.join("\n")
}

///|
/// What SVG lays out of the lines of one text element: runs of white
/// space collapse into one space — also across lines, which are one line
/// of text to the browser until each is moved to its place — and the
/// spaces at both ends of the text go.
fn collapse_lines(lines : Array[String]) -> Array[String] {
  let out : Array[String] = []
  let mut after_space = true
  for line in lines {
    let text = StringBuilder()
    for c in line {
      if c is (' ' | '\t' | '\n' | '\r') {
        if !after_space {
          text.write_char(' ')
          after_space = true
        }
      } else {
        text.write_char(c)
        after_space = false
      }
    }
    out.push(text.to_string())
  }
  // The space the text ends with is in the last line that has anything.
  for i = out.length() - 1; i >= 0; i = i - 1 {
    if out[i] != "" {
      if out[i].strip_suffix(" ") is Some(rest) {
        out[i] = rest.to_owned()
      }
      break
    }
  }
  out
}

///|
/// `drawMultilineText`: a `<text>` with one `<tspan>` per line, the block
/// of lines centred on `y`. Returns the element and the box `getBBox()`
/// reports for it, which is also recorded on the element.
///
/// `font_size` is the configured size the line height derives from, not
/// necessarily the size `style` has the text drawn at.
fn draw_multiline_text(
  parent : @dom.Element,
  text : String,
  x : Double,
  y : Double,
  class_name : String,
  anchor : String,
  font_size : Double,
  style : TextStyle,
) -> (@dom.Element, @dom.Rect) raise Unsupported {
  let lines = line_break.split(text)
  let line_height = font_size * 1.05
  let element = parent
    .append("text")
    .attr("class", class_name)
    .attr("text-anchor", anchor)
    .attr_number("x", x)
    .attr_number("y", y - (lines.length() - 1).to_double() * line_height / 2.0)
  let f = Float::from_double
  // Positions as the browser holds them, in single precision.
  let held_x = element.length_attr("x").unwrap_or(0.0)
  let top = f(element.length_attr("y").unwrap_or(0.0))
  let mut dy : Float = 0
  let mut shift : Float = 0
  let chunks : Array[@font.Chunk] = []
  let laid_out = collapse_lines(lines)
  for i, line in lines {
    let span = element
      .append("tspan")
      .attr_number("x", x)
      .attr_number("dy", if i == 0 { 0.0 } else { line_height })
      .text(line)
    if i == 1 {
      dy = f(span.length_attr("dy").unwrap_or(0.0))
    }
    // A span nothing is laid out of takes no position: its `dy` is
    // never applied.
    let content = laid_out[i]
    if content == "" {
      continue
    }
    if i > 0 {
      shift = shift + dy
    }
    if !style.font.covers(content) {
      raise Unsupported(
        "text outside the fonts the port can measure: \{content}",
      )
    }
    chunks.push({ text: content, x: held_x, y: (top + shift).to_double(), })
  }
  if chunks.is_empty() {
    raise Unsupported("an Ishikawa label without text")
  }
  let box = style.font.chunks_box(
    chunks,
    style.size,
    anchor=style.anchor,
    baseline=style.baseline,
  )
  let box : @dom.Rect = {
    x: box.x,
    y: box.y,
    width: box.width,
    height: box.height,
  }
  element.set_text_box(box)
  (element, box)
}
