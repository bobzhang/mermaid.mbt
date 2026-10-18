// marked's lexer (see `marked_rules.mbt`): `blockTokens` for the blocks,
// `inlineTokens` for the inline tokens of paragraphs. Positions are UTF-16
// offsets, as in JavaScript.

///|
/// What JavaScript's `\s` takes for white space, by code unit.
fn is_js_space_unit(c : Int32) -> Bool {
  c
  is (0x09..<=0x0d
  | 0x20
  | 0xa0
  | 0x1680
  | 0x2000..<=0x200a
  | 0x2028
  | 0x2029
  | 0x202f
  | 0x205f
  | 0x3000
  | 0xfeff)
}

///|
/// Whether `c` is in one of the sorted `ranges`.
fn in_ranges(c : Int32, ranges : Array[(Int32, Int32)]) -> Bool {
  let mut lo = 0
  let mut hi = ranges.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    let (start, end) = ranges[mid]
    if c < start {
      hi = mid
    } else if c > end {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
/// `/[\p{P}\p{S}]/u`.
fn is_punct_or_symbol(c : Int32) -> Bool {
  c >= 0 && in_ranges(c, punctuation_or_symbol)
}

///|
/// `String.prototype.slice` with its clamping, on UTF-16 offsets.
fn js_slice(text : String, start : Int32, end : Int32) -> String {
  let n = text.length()
  let clamp = (i : Int32) => if i < 0 { (n + i).max(0) } else { i.min(n) }
  let start = clamp(start)
  let end = clamp(end)
  if start >= end {
    ""
  } else {
    text.view(start_offset=start, end_offset=end).to_owned()
  }
}

///|
/// JavaScript's `trim`, `trimEnd` and `trimStart` emptiness: whether the
/// text is all white space.
fn js_blank(text : String) -> Bool {
  for i in 0..<text.length() {
    if !is_js_space_unit(text.code_unit_at(i).to_int()) {
      return false
    }
  }
  true
}

///|
/// JavaScript's `trim`.
fn js_trim_text(text : String) -> String {
  let n = text.length()
  let mut start = 0
  while start < n && is_js_space_unit(text.code_unit_at(start).to_int()) {
    start += 1
  }
  let mut end = n
  while end > start && is_js_space_unit(text.code_unit_at(end - 1).to_int()) {
    end -= 1
  }
  js_slice(text, start, end)
}

///|
/// JavaScript's `trimEnd`.
fn js_trim_end(text : String) -> String {
  let mut end = text.length()
  while end > 0 && is_js_space_unit(text.code_unit_at(end - 1).to_int()) {
    end -= 1
  }
  js_slice(text, 0, end)
}

///|
/// marked's `rtrim(text, c)`: the text without the copies of `c` it ends
/// with.
fn rtrim_char(text : String, c : Char) -> String {
  let mut end = text.length()
  while end > 0 && text.code_unit_at(end - 1).to_int() == c.to_int() {
    end -= 1
  }
  js_slice(text, 0, end)
}

///|
/// `text.split("\n")`.
fn split_lines(text : String) -> Array[String] {
  text.split("\n").map(line => line.to_owned()).collect()
}

///|
/// `text.split("\n", 1)[0]`.
fn first_line(text : String) -> String {
  match text.find("\n") {
    Some(at) => js_slice(text, 0, at)
    None => text
  }
}

///|
/// `text.search(/[^ ]/)`.
fn first_non_space(text : String) -> Int32 {
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() != ' '.to_int() {
      return i
    }
  }
  -1
}

///|
/// The kinds of block marked's lexer finds.
priv enum BlockKind {
  Space
  Code
  Heading
  Rule
  Quote
  List
  HtmlBlock
  Definition
  Table
  Para
} derive(Eq)

///|
/// A block token: its raw text, and what its inline tokens are lexed from
/// (paragraphs), or the text of a quote.
priv struct BlockToken {
  kind : BlockKind
  mut raw : String
  mut text : String
}

///|
/// The state of marked's lexer that outlives a token.
priv struct MdLexer {
  /// The labels of the link definitions, lower-cased.
  links : Map[String, Bool]
  /// Inside `<a>`: bare URLs are not links there.
  mut in_link : Bool
}

///|
/// The blocks of `markdown`: marked's `lex`.
fn markdown_blocks(markdown : String) -> Array[MdBlock] {
  let lexer = { links: Map([]), in_link: false, }
  let source = markdown
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let tokens = []
  lexer.block_tokens(source, tokens, false)
  // Inline tokens are lexed once every block is known, with all the
  // link definitions.
  tokens.map(token => {
    match token.kind {
      Para => Paragraph(lexer.inline_tokens(token.text))
      Space => Space(token.raw)
      _ => Raw(token.raw)
    }
  })
}

///|
/// Append `token` to a paragraph before it, as marked does with lines
/// that cannot start a block of their own there.
fn BlockToken::absorb(self : BlockToken, raw : String, text : String) -> Unit {
  self.raw = self.raw +
    (if self.raw.has_suffix("\n") { "" } else { "\n" }) +
    raw
  self.text = self.text + "\n" + text
}

///|
/// marked's `blockTokens` at the top level, where paragraphs are lexed
/// (`state.top`); `clipped` is its `lastParagraphClipped`.
fn MdLexer::block_tokens(
  self : MdLexer,
  source : String,
  tokens : Array[BlockToken],
  clipped : Bool,
) -> Unit {
  let mut clipped = clipped
  let mut pos = 0
  let n = source.length()
  let rest = () => js_slice(source, pos, n)
  while pos < n {
    if block_newline.match_prefix(source, from=pos) is Some(found) &&
      found.end > found.start {
      pos = found.end
      // A single line break joins the block before it.
      match tokens.last() {
        Some(last) if found.end - found.start == 1 => last.raw = last.raw + "\n"
        _ => tokens.push({ kind: Space, raw: found.text(), text: "", })
      }
      continue
    }
    if block_code.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      let raw = found.text()
      let text = rtrim_char(code_remove_indent.replace_all(raw, _ => ""), '\n')
      match tokens.last() {
        Some(last) if last.kind == Para => last.absorb(raw, text)
        _ => tokens.push({ kind: Code, raw, text, })
      }
      continue
    }
    if block_fences.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      tokens.push({ kind: Code, raw: found.text(), text: "", })
      continue
    }
    if block_heading.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      tokens.push({ kind: Heading, raw: found.text(), text: "", })
      continue
    }
    if block_hr.match_prefix(source, from=pos) is Some(found) {
      // The line breaks after the rule are not part of it.
      let raw = rtrim_char(found.text(), '\n')
      pos += raw.length()
      tokens.push({ kind: Rule, raw, text: "", })
      continue
    }
    if self.blockquote(rest()) is Some(token) {
      pos += token.raw.length()
      tokens.push(token)
      continue
    }
    if list_raw(rest()) is Some(raw) {
      pos += raw.length()
      tokens.push({ kind: List, raw, text: "", })
      continue
    }
    if block_html.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      tokens.push({ kind: HtmlBlock, raw: found.text(), text: "", })
      continue
    }
    if block_def.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      let raw = found.text()
      match tokens.last() {
        Some(last) if last.kind == Para => last.absorb(raw, raw)
        _ => {
          // `tag`: the label lower-cased, its white space collapsed. A
          // second definition of a label is dropped.
          let tag = js_space_runs.replace_all(
            found.group(1).unwrap_or("").to_lower(),
            _ => " ",
          )
          if !self.links.contains(tag) {
            self.links[tag] = true
            tokens.push({ kind: Definition, raw, text: "", })
          }
        }
      }
      continue
    }
    if table_raw(source, pos) is Some(raw) {
      pos += raw.length()
      tokens.push({ kind: Table, raw, text: "", })
      continue
    }
    if block_lheading.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      tokens.push({ kind: Heading, raw: found.text(), text: "", })
      continue
    }
    if block_paragraph.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      let raw = found.text()
      let text = found.group(1).unwrap_or("")
      let text = if text.has_suffix("\n") {
        js_slice(text, 0, text.length() - 1)
      } else {
        text
      }
      match tokens.last() {
        Some(last) if clipped && last.kind == Para => last.absorb(raw, text)
        _ => tokens.push({ kind: Para, raw, text, })
      }
      clipped = false
      continue
    }
    // Every line is a paragraph at the top level; nothing is left.
    break
  }
}

///|
/// `/\s+/g`.
let js_space_runs : @jsregex.Regex = md_rule("\\s+")

///|
/// marked's `blockquote` tokenizer. The quote's lines are lexed as blocks
/// to find where it ends: a code block ends it, and a quote or list at its
/// end takes in the lines after it.
fn MdLexer::blockquote(self : MdLexer, source : String) -> BlockToken? {
  guard block_blockquote.match_prefix(source) is Some(found) else {
    return None
  }
  let mut lines = split_lines(rtrim_char(found.text(), '\n'))
  let mut raw = ""
  let mut text = ""
  let tokens : Array[BlockToken] = []
  while lines.length() > 0 {
    let mut in_quote = false
    let current = []
    let mut u = 0
    while u < lines.length() {
      if blockquote_start.match_prefix(lines[u]) is Some(_) {
        current.push(lines[u])
        in_quote = true
      } else if !in_quote {
        current.push(lines[u])
      } else {
        break
      }
      u += 1
    }
    lines = lines[u:].to_owned()
    let quoted = current.join("\n")
    let content = blockquote_setext_replace2.replace_all(
      blockquote_setext_replace.replace_all(quoted, found => {
        "\n    " + found.group(1).unwrap_or("")
      }),
      _ => "",
    )
    raw = if raw == "" { quoted } else { raw + "\n" + quoted }
    text = if text == "" { content } else { text + "\n" + content }
    self.block_tokens(content, tokens, true)
    if lines.length() == 0 {
      break
    }
    guard tokens.last() is Some(last) else { continue }
    match last.kind {
      Code => break
      Quote => {
        let joined = last.raw + "\n" + lines.join("\n")
        guard self.blockquote(joined) is Some(merged) else { break }
        tokens[tokens.length() - 1] = merged
        raw = js_slice(raw, 0, raw.length() - last.raw.length()) + merged.raw
        text = js_slice(text, 0, text.length() - last.text.length()) +
          merged.text
        break
      }
      List => {
        let joined = last.raw + "\n" + lines.join("\n")
        guard list_raw(joined) is Some(merged) else { break }
        tokens[tokens.length() - 1] = { kind: List, raw: merged, text: "", }
        raw = js_slice(raw, 0, raw.length() - last.raw.length()) + merged
        text = js_slice(text, 0, text.length() - last.raw.length()) + merged
        lines = split_lines(js_slice(joined, merged.length(), joined.length()))
        continue
      }
      _ => ()
    }
  }
  Some({ kind: Quote, raw, text, })
}

///|
/// The raw text of the list `source` starts with: marked's `list`
/// tokenizer as far as it decides where the items end. (What it lexes
/// inside the items only decides whether the list is loose.)
fn list_raw(source : String) -> String? {
  guard block_list.match_prefix(source) is Some(found) else { return None }
  let bullet = js_trim_text(found.group(1).unwrap_or(""))
  let marker = if bullet.length() > 1 {
    "\\d{1,9}\\" + js_slice(bullet, bullet.length() - 1, bullet.length())
  } else {
    "\\" + bullet
  }
  let item = md_rule("^( {0,3}" + marker + ")((?:[\t ][^\\n]*)?(?:\\n|$))")
  let mut rest = source
  let mut raw = ""
  let mut items = 0
  while rest != "" {
    guard item.match_prefix(rest) is Some(found) &&
      !(block_hr.match_prefix(rest) is Some(_)) else {
      break
    }
    let mut item_raw = found.text()
    rest = js_slice(rest, item_raw.length(), rest.length())
    let bullet = found.group(1).unwrap_or("")
    let after = found.group(2).unwrap_or("")
    let mut line = list_tabs.replace_all(first_line(after), tabs => {
      " ".repeat(3 * tabs.text().length())
    })
    let mut next = first_line(rest)
    let mut blank = js_blank(line)
    let mut indent = 0
    let mut ended = false
    if blank {
      indent = bullet.length() + 1
    } else {
      indent = first_non_space(after)
      indent = if indent > 4 { 1 } else { indent }
      indent += bullet.length()
    }
    if blank && blank_line.match_prefix(next) is Some(_) {
      item_raw = item_raw + next + "\n"
      rest = js_slice(rest, next.length() + 1, rest.length())
      ended = true
    }
    if !ended {
      let up_to = (indent - 1).min(3).to_string()
      let next_bullet = md_rule(
        "^ {0," + up_to + "}(?:[*+-]|\\d{1,9}[.)])((?:[ \t][^\\n]*)?(?:\\n|$))",
      )
      let hr = md_rule(
        "^ {0," + up_to + "}((?:- *){3,}|(?:_ *){3,}|(?:\\* *){3,})(?:\\n+|$)",
      )
      let fences = md_rule("^ {0," + up_to + "}(?:```|~~~)")
      let heading = md_rule("^ {0," + up_to + "}#")
      let html = md_rule("^ {0," + up_to + "}<(?:[a-z].*>|!--)", flags="i")
      let starts = (regex : @jsregex.Regex, text : String) => {
        regex.match_prefix(text) is Some(_)
      }
      while rest != "" {
        let raw_line = first_line(rest)
        next = raw_line
        let expanded = next.replace_all(old="\t", new="    ")
        if starts(fences, next) ||
          starts(heading, next) ||
          starts(html, next) ||
          starts(next_bullet, next) ||
          starts(hr, next) {
          break
        }
        if !(first_non_space(expanded) >= indent || js_blank(next)) {
          // A lazy continuation line, unless the item is done.
          if blank ||
            first_non_space(line.replace_all(old="\t", new="    ")) >= 4 ||
            starts(fences, line) ||
            starts(heading, line) ||
            starts(hr, line) {
            break
          }
        }
        if !blank && js_blank(next) {
          blank = true
        }
        item_raw = item_raw + raw_line + "\n"
        rest = js_slice(rest, raw_line.length() + 1, rest.length())
        line = js_slice(expanded, indent, expanded.length())
      }
    }
    raw = raw + item_raw
    items += 1
  }
  if items == 0 {
    return None
  }
  Some(js_trim_end(raw))
}

///|
/// `/^\t+/`.
let list_tabs : @jsregex.Regex = md_rule("^\\t+")

///|
/// `/^[ \t]*$/`.
let blank_line : @jsregex.Regex = md_rule("^[ \\t]*$")

///|
/// The raw text of a table at `pos`: marked's `table` tokenizer, which
/// takes it when the header has as many cells as the delimiter row.
fn table_raw(source : String, pos : Int32) -> String? {
  guard block_table.match_prefix(source, from=pos) is Some(found) else {
    return None
  }
  let delimiter = found.group(2).unwrap_or("")
  guard delimiter.contains_char(':') || delimiter.contains_char('|') else {
    return None
  }
  let header = table_cell_count(found.group(1).unwrap_or(""))
  let aligns = table_align_chars
    .replace_all(delimiter, _ => "")
    .split("|")
    .count()
  if header == aligns {
    Some(found.text())
  } else {
    None
  }
}

///|
/// How many cells marked's `splitCells` finds in a table row: pipes not
/// escaped by an odd number of backslashes separate them, and an empty
/// first and last cell do not count.
fn table_cell_count(row : String) -> Int32 {
  let spaced = StringBuilder()
  for i in 0..<row.length() {
    let c = row.code_unit_at(i)
    if c.to_int() == '|'.to_int() {
      let mut escaped = false
      let mut back = i - 1
      while back >= 0 && row.code_unit_at(back).to_int() == '\\'.to_int() {
        escaped = !escaped
        back -= 1
      }
      spaced.write_string(if escaped { "|" } else { " |" })
    } else {
      spaced.write_string(js_slice(row, i, i + 1))
    }
  }
  let cells = spaced
    .to_string()
    .split(" |")
    .map(cell => cell.to_owned())
    .collect()
  if js_blank(cells[0]) {
    cells.remove(0) |> ignore
  }
  if cells.length() > 0 && js_blank(cells[cells.length() - 1]) {
    cells.pop() |> ignore
  }
  cells.length()
}
