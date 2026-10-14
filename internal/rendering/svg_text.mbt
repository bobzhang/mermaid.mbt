// Labels as SVG text, for `htmlLabels: false`: mermaid's `createText`
// without HTML, with the text boxes the browser would report.

///|
/// A word of a label with its emphasis: `normal`, `strong` or `em`.
priv struct Word {
  content : String
  kind : String
}

///|
/// Plain text as lines of words: mermaid's `nonMarkdownToLines`.
fn non_markdown_to_lines(text : String) -> Array[Array[Word]] {
  let text = normalize_breaks(text).replace_all(old="\\n", new="\n")
  let lines = []
  for line in text.split("\n") {
    // Tags stay whole; everything else splits at white space.
    let words = []
    let chars = line.trim().to_owned().to_array()
    let n = chars.length()
    let mut i = 0
    while i < n {
      let c = chars[i]
      if c is (' ' | '\t' | '\n' | '\r') {
        i += 1
        continue
      }
      let mut j = i
      if c == '<' {
        // <[^>]+>
        j = i + 1
        while j < n && chars[j] != '>' {
          j += 1
        }
        if j < n && j > i + 1 {
          words.push({
            content: String::from_array(chars[i:j + 1]),
            kind: "normal",
          })
          i = j + 1
          continue
        }
        // A lone bracket belongs to no word.
        i += 1
        continue
      }
      if c == '>' {
        i += 1
        continue
      }
      while j < n && !(chars[j] is (' ' | '\t' | '\n' | '\r' | '<' | '>')) {
        j += 1
      }
      words.push({ content: String::from_array(chars[i:j]), kind: "normal", })
      i = j
    }
    lines.push(words)
  }
  lines
}

///|
/// `&amp;`, `&lt;` and `&gt;` as the characters they stand for.
fn decode_basic_entities(text : String) -> String {
  text
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&amp;", new="&")
}

///|
/// The text of the items of a line: the first word, then every other word
/// with a space in front.
fn line_items_text(line : Array[Word]) -> Array[Run] {
  line.mapi((index, word) => {
    let text = decode_basic_entities(word.content)
    {
      text: if index == 0 {
        text
      } else {
        " " + text
      },
      bold: word.kind == "strong",
      italic: word.kind == "em",
    }
  })
}

///|
/// The widths of the items of a line. Consecutive items in one face are
/// shaped as one run, so kerning reaches across them; every item takes
/// whole layout units.
fn item_widths(items : Array[Run], env : Env) -> Array[Double] {
  let widths = []
  let mut index = 0
  while index < items.length() {
    let first = items[index]
    let group = []
    while index < items.length() &&
          items[index].bold == first.bold &&
          items[index].italic == first.italic {
      group.push(items[index].text)
      index += 1
    }
    widths.append(
      env
      .font(bold=first.bold, italic=first.italic)
      .item_advances(group, env.font_size),
    )
  }
  widths
}

///|
/// What `getComputedTextLength()` reports for a line.
fn text_line_width(line : Array[Word], env : Env) -> Double {
  item_widths(line_items_text(line), env).fold(init=0.0, (a, b) => a + b)
}

///|
/// Break a line that is too wide: mermaid's `splitLineToFitWidth`. Words
/// move to the next line whole; a word wider than a line is cut.
fn split_line_to_fit(
  line : Array[Word],
  fits : (Array[Word]) -> Bool,
) -> Array[Array[Word]] {
  let words = line.copy()
  let lines : Array[Array[Word]] = []
  let mut current : Array[Word] = []
  while !words.is_empty() {
    let mut joiner = false
    if words[0].content == " " {
      joiner = true
      words.remove(0) |> ignore
    }
    let next = if words.is_empty() {
      { content: " ", kind: "normal", }
    } else {
      words.remove(0)
    }
    let candidate = current.copy()
    if joiner {
      candidate.push({ content: " ", kind: "normal", })
    }
    candidate.push(next)
    if fits(candidate) {
      current = candidate
      continue
    }
    if !current.is_empty() {
      lines.push(current)
      words.insert(0, next)
    } else if next.content != "" {
      // Take as many characters as fit, at least one.
      let chars = next.content.to_array()
      let mut used = 0
      while used < chars.length() &&
            fits([{ ..next, content: String::from_array(chars[:used + 1]), }]) {
        used += 1
      }
      if used == 0 {
        used = 1
      }
      lines.push([{ ..next, content: String::from_array(chars[:used]), }])
      if used < chars.length() {
        words.insert(0, { ..next, content: String::from_array(chars[used:]), })
      }
    }
    current = []
  }
  if !current.is_empty() {
    lines.push(current)
  }
  lines
}

///|
/// A box in single precision, united the way `gfx::RectF` does.
priv struct BoxF {
  x : Float
  y : Float
  width : Float
  height : Float
}

///|
/// A box from its edges: where origin plus the rounded size falls short
/// of the far edge, the size grows by one step.
fn BoxF::from_edges(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> BoxF {
  let mut width = right - left
  let mut height = bottom - top
  if left + width < right {
    width = Float::reinterpret_from_uint(width.reinterpret_as_uint() + 1)
  }
  if top + height < bottom {
    height = Float::reinterpret_from_uint(height.reinterpret_as_uint() + 1)
  }
  { x: left, y: top, width, height, }
}

///|
fn BoxF::is_empty(self : BoxF) -> Bool {
  self.width <= 0 || self.height <= 0
}

///|
fn BoxF::unite(self : BoxF, other : BoxF) -> BoxF {
  if self.is_empty() {
    return other
  }
  if other.is_empty() {
    return self
  }
  let min = (a : Float, b : Float) => if b < a { b } else { a }
  let max = (a : Float, b : Float) => if a < b { b } else { a }
  BoxF::from_edges(
    min(self.x, other.x),
    min(self.y, other.y),
    max(self.x + self.width, other.x + other.width),
    max(self.y + self.height, other.y + other.height),
  )
}

///|
/// An `em` length of a text position in pixels, as Blink resolves it: the
/// number and the font size multiplied in single precision.
fn em_to_px(value : Double, size : Double) -> Float {
  Float::from_double(value) * Float::from_double(size)
}

///|
/// The box `getBBox()` reports for a text element laid out by
/// `create_svg_label`: line `i` has its baseline at
/// `(1.1 i - 0.1)em + 1.1em`, starts at x = 0 and is centred there when
/// anchored in the middle. Every item contributes its cell, from the
/// ascent above the baseline to the descent below, and its ink.
fn text_box(
  lines : Array[Array[Word]],
  env : Env,
  anchor_middle : Bool,
  restyle~ : (Int32, Run) -> Run = (_, run) => run,
) -> @dom.Rect {
  let mut box : BoxF = { x: 0, y: 0, width: 0, height: 0, }
  let size = env.font_size
  let f = Float::from_double
  for index, line in lines {
    let y = em_to_px(index.to_double() * 1.1 - 0.1, size)
    let baseline = y + em_to_px(1.1, size)
    // `restyle` changes the face of the items of a line, as a style
    // on its elements would.
    let items = line_items_text(line).map(run => restyle(index, run))
    let widths = item_widths(items, env)
    let total = widths.fold(init=0.0, (a, b) => a + b)
    let mut x = if anchor_middle { -total / 2.0 } else { 0.0 }
    for k, item in items {
      let font = env.font(bold=item.bold, italic=item.italic)
      let (ascent, descent) = font.line_metrics(size)
      let cell = BoxF::from_edges(
        f(x),
        baseline - f(ascent),
        f(x + widths[k]),
        baseline + f(descent),
      )
      let ink = font.ink(item.text, size)
      let ink_box : BoxF = {
        x: f(x) + f(ink.x),
        y: baseline + f(ink.y),
        width: f(ink.width),
        height: f(ink.height),
      }
      box = box.unite(ink_box.unite(cell))
      x += widths[k]
    }
  }
  {
    x: box.x.to_double(),
    y: box.y.to_double(),
    width: box.width.to_double(),
    height: box.height.to_double(),
  }
}

///|
/// A label drawn as SVG text.
priv struct SvgLabel {
  /// The group holding the background rectangle and the text.
  group : @dom.Element
  /// The box of the text element.
  text_box : @dom.Rect
  /// The text element and its lines as they were broken.
  element : @dom.Element
  lines : Array[Array[Word]]
}

///|
/// mermaid's `createText` for SVG labels: a group with a background
/// rectangle and a `<text>` of one `<tspan>` per line, each word in a
/// `<tspan>` of its own. Lines wider than `width` are broken.
fn create_svg_label(
  parent : @dom.Element,
  text : String,
  env : Env,
  width? : Double,
  style~ : String = "",
  is_node~ : Bool = true,
  add_background~ : Bool = false,
  markdown~ : Bool = false,
  anchor_middle~ : Bool = !is_node,
  sanitize~ : Bool = true,
  is_title~ : Bool = false,
) -> SvgLabel {
  // The style is written on the text, which is laid out with it.
  let env = env.styled(style, faces=false)
  // Node labels are sanitized on their way here, which resolves the
  // character references of text that has markup in it: the sanitizer
  // hands back text without a tag as it is. Edge labels are not
  // sanitized, and keep their references as text.
  let source = @dom.placeholders_to_references(text)
  let source = if sanitize && source.contains("<") {
    @dom.sanitized_text(source)
  } else {
    source
  }
  let structured = if markdown {
    markdown_to_lines(source)
  } else {
    non_markdown_to_lines(source)
  }
  let center = !is_node
  let group = parent.append("g")
  let background = group
    .append("rect")
    .attr("class", "background")
    .attr("style", "stroke: none")
  let element = group.append("text").attr("y", "-10.1")
  if center {
    element.attr("text-anchor", "middle") |> ignore
  }
  let fits = (line : Array[Word]) => {
    match width {
      Some(width) => text_line_width(line, env) <= width
      None => true
    }
  }
  let lines = []
  for line in structured {
    if fits(line) {
      lines.push(line)
    } else {
      lines.append(split_line_to_fit(line, fits))
    }
  }
  let n = @dom.number
  for index, line in lines {
    let tspan = element
      .append("tspan")
      .attr("class", "text-outer-tspan")
      .attr("x", "0")
      .attr("y", n(index.to_double() * 1.1 - 0.1) + "em")
      .attr("dy", "1.1em")
    if center {
      tspan.attr("text-anchor", "middle") |> ignore
    }
    for item in line_items_text(line) {
      tspan
      .append("tspan")
      .attr("font-style", if item.italic { "italic" } else { "normal" })
      .attr("class", "text-inner-tspan")
      .attr("font-weight", if item.bold { "bold" } else { "normal" })
      .text(item.text)
      |> ignore
    }
  }
  let box = text_box(lines, env, anchor_middle)
  element.set_text_box(box)
  if add_background && text != "" {
    background
    .attr_number("x", box.x - 2.0)
    .attr_number("y", box.y - 2.0)
    .attr_number("width", box.width + 4.0)
    .attr_number("height", box.height + 4.0)
    |> ignore
  }
  // Styles: fills and strokes belong to shapes, `color` paints the text.
  let text_style = drop_declarations(style, ["stroke", "stroke-width", "fill"]).replace_all(
    old="color:",
    new="fill:",
  )
  if is_node {
    element.attr("style", text_style) |> ignore
  } else {
    background.attr(
      "style",
      drop_declarations(style, ["stroke", "stroke-width", "fill"]).replace_all(
        old="background:",
        new="fill:",
      ),
    )
    |> ignore
    element.attr("style", text_style) |> ignore
  }
  let row = if is_title { "title-row" } else { "row" }
  for tspan in element.child_elements() {
    tspan.attr("class", "text-outer-tspan \{row}") |> ignore
  }
  { group, text_box: box, element, lines, }
}

///|
/// Remove the declarations of some properties from a style text, the way
/// `style.replace(/name:[^;]+;?/g, '')` does.
fn drop_declarations(style : String, names : Array[String]) -> String {
  let mut result = style
  for name in names {
    let out = StringBuilder()
    let mut rest = result[:]
    let needle = name + ":"
    while rest.find(needle) is Some(at) {
      let after = rest[at + needle.length():]
      let end = after.find(";").unwrap_or(after.length())
      if end == 0 {
        // Nothing to remove without a value.
        out.write_view(rest[:at + needle.length()])
        rest = after
        continue
      }
      out.write_view(rest[:at])
      rest = if end < after.length() { after[end + 1:] } else { after[end:] }
    }
    out.write_view(rest)
    result = out.to_string()
  }
  result
}

///|
/// Markdown as lines of words: mermaid's `markdownToLines`. Line breaks
/// inside paragraphs start new lines; paragraphs themselves do not.
fn markdown_to_lines(markdown : String) -> Array[Array[Word]] {
  // <br/> is a line break, runs of line breaks collapse, and common
  // indentation goes.
  let source = markdown.replace_all(old="<br/>", new="\n")
  let collapsed = StringBuilder()
  let mut previous_newline = false
  for c in source {
    if c == '\n' {
      if !previous_newline {
        collapsed.write_char(c)
      }
      previous_newline = true
    } else {
      collapsed.write_char(c)
      previous_newline = false
    }
  }
  let lines : Array[Array[Word]] = [[]]
  let push_word = (content : String, kind : String) => {
    if lines.last() is Some(line) {
      line.push({ content, kind, })
    }
  }
  fn add_text(text : String, kind : String) {
    for index, text_line in text.split("\n").collect() {
      if index != 0 {
        lines.push([])
      }
      for word in text_line.split(" ") {
        let word = word.to_owned().replace_all(old="&#39;", new="'")
        if word != "" {
          push_word(word, kind)
        }
      }
    }
  }
  fn walk(tokens : Array[MdToken], kind : String) {
    for token in tokens {
      match token {
        MdText(text) => add_text(text, kind)
        MdStrong(inner) => walk(inner, "strong")
        MdEm(inner) => walk(inner, "em")
        MdHtml(text) => push_word(text, "normal")
        MdEscape(_) | MdRaw(_) => ()
      }
    }
  }
  for block in markdown_blocks(dedent(collapsed.to_string())) {
    match block {
      Paragraph(tokens) => walk(tokens, "normal")
      Raw(text) => push_word(text, "normal")
    }
  }
  lines
}

///|
/// Remove the indentation all non-blank lines share, and blank lines at
/// both ends: what `ts-dedent` does to a single string.
fn dedent(text : String) -> String {
  let lines = text.split("\n").map(line => line.to_owned()).collect()
  let mut indent = -1
  for line in lines {
    let trimmed = line.trim_start(chars=" \t")
    if trimmed.length() == 0 {
      continue
    }
    let leading = line.length() - trimmed.length()
    if indent < 0 || leading < indent {
      indent = leading
    }
  }
  let out = lines.map(line => {
    if indent > 0 && line.length() >= indent {
      line[indent:].to_owned()
    } else {
      line
    }
  })
  out.join("\n").trim().to_owned()
}
