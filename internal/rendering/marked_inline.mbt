// marked's `inlineTokens`, with its GitHub flavoured rules: escapes,
// inline HTML, links, emphasis, code spans, line breaks, strikethroughs,
// autolinks, bare URLs and text, tried in that order at each position.

///|
/// The code point at UTF-16 offset `at` and how many code units it takes;
/// a lone surrogate stands for itself, as in a `u` pattern.
fn code_point_at(text : String, at : Int32) -> (Int32, Int32) {
  let c = text.code_unit_at(at).to_int()
  if c >= 0xd800 && c <= 0xdbff && at + 1 < text.length() {
    let low = text.code_unit_at(at + 1).to_int()
    if low >= 0xdc00 && low <= 0xdfff {
      return (0x10000 + ((c - 0xd800) << 10) + (low - 0xdc00), 2)
    }
  }
  (c, 1)
}

///|
/// The text `inlineTokens` looks for closing delimiters in: escaped
/// punctuation, links, code spans and tags masked so that what they hold
/// closes nothing, and references to known links likewise.
fn MdLexer::masked(self : MdLexer, source : String) -> String {
  let mut masked = source
  let replace = (text : String, start : Int32, end : Int32, fill : String) => {
    js_slice(text, 0, start) + fill + js_slice(text, end, text.length())
  }
  let brackets = (length : Int32) => "[" + "a".repeat(length - 2) + "]"
  if !self.links.is_empty() {
    let mut from = 0
    while inline_reflink_search.exec(masked, from~) is Some(found) {
      from = found.end
      let text = found.text()
      let label = match text.rev_find("[") {
        Some(at) => js_slice(text, at + 1, text.length() - 1)
        None => js_slice(text, 0, text.length() - 1)
      }
      if self.links.contains(label) {
        masked = replace(
          masked,
          found.start,
          found.end,
          brackets(text.length()),
        )
      }
    }
  }
  // `/\\([\p{P}\p{S}])/gu`, each match written `++`; the search goes on
  // where the match ended in the text before the change.
  let mut from = 0
  while from < masked.length() {
    let c = masked.code_unit_at(from).to_int()
    if c == '\\'.to_int() && from + 1 < masked.length() {
      let (next, width) = code_point_at(masked, from + 1)
      if is_punct_or_symbol(next) {
        masked = replace(masked, from, from + 1 + width, "++")
        from = from + 1 + width
        continue
      }
    }
    from += 1
  }
  let mut from = 0
  while inline_block_skip.exec(masked, from~) is Some(found) {
    from = found.end
    masked = replace(
      masked,
      found.start,
      found.end,
      brackets(found.end - found.start),
    )
  }
  masked
}

///|
/// marked's `inlineTokens`.
fn MdLexer::inline_tokens(self : MdLexer, source : String) -> Array[MdToken] {
  let masked = self.masked(source)
  let tokens : Array[MdToken] = []
  let push_text = (text : String) => {
    match tokens.last() {
      Some(MdText(before)) =>
        tokens[tokens.length() - 1] = MdText(before + text)
      _ => tokens.push(MdText(text))
    }
  }
  let n = source.length()
  let mut pos = 0
  // The last code unit of the text before, which emphasis looks at; -1
  // when what came before was not text.
  let mut previous = -1
  let mut after_text = false
  while pos < n {
    if !after_text {
      previous = -1
    }
    after_text = false
    if inline_escape.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      tokens.push(
        MdEscape(found.group(1).unwrap_or("").get_char(0).unwrap_or('\\')),
      )
      continue
    }
    if inline_tag.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      let raw = found.text()
      if !self.in_link && a_tag_start.match_prefix(raw) is Some(_) {
        self.in_link = true
      } else if self.in_link && a_tag_end.match_prefix(raw) is Some(_) {
        self.in_link = false
      }
      tokens.push(MdHtml(raw))
      continue
    }
    if link_raw(source, pos) is Some(raw) {
      pos += raw.length()
      self.in_link = false
      tokens.push(MdRaw(raw))
      continue
    }
    if self.reflink(source, pos) is Some((raw, is_link)) {
      pos += raw.length()
      if is_link {
        self.in_link = false
        tokens.push(MdRaw(raw))
      } else {
        // An unknown reference is its first character as text, which
        // does not count as text before emphasis.
        push_text(raw)
      }
      continue
    }
    if self.em_strong(source, pos, masked, previous) is Some((token, length)) {
      pos += length
      tokens.push(token)
      continue
    }
    // Code spans, line breaks, strikethroughs and autolinks are written
    // out as they stand.
    let mut raw = false
    for rule in [inline_code, inline_br, inline_del, inline_autolink] {
      if rule.match_prefix(source, from=pos) is Some(found) {
        pos = found.end
        tokens.push(MdRaw(found.text()))
        raw = true
        break
      }
    }
    if raw {
      continue
    }
    if !self.in_link && url_raw(source, pos) is Some(raw) {
      pos += raw.length()
      tokens.push(MdRaw(raw))
      continue
    }
    if inline_text.match_prefix(source, from=pos) is Some(found) {
      pos = found.end
      let last = source.code_unit_at(found.end - 1).to_int()
      if last != '_'.to_int() {
        previous = last
      }
      after_text = true
      push_text(found.text())
      continue
    }
    break
  }
  tokens
}

///|
/// The raw text of a link at `pos`: marked's `link` tokenizer, which cuts
/// the destination at its first unbalanced parenthesis.
fn link_raw(source : String, pos : Int32) -> String? {
  guard inline_link.match_prefix(source, from=pos) is Some(found) else {
    return None
  }
  let raw = found.text()
  let href = found.group(2).unwrap_or("")
  let trimmed = js_trim_text(href)
  if trimmed.has_prefix("<") {
    if !trimmed.has_suffix(">") {
      return None
    }
    let inner = js_slice(trimmed, 0, trimmed.length() - 1)
    if (trimmed.length() - rtrim_char(inner, '\\').length()) % 2 == 0 {
      return None
    }
    return Some(raw)
  }
  // marked's `findClosingBracket(href, "()")`.
  let mut close = -1
  if href.contains_char(')') {
    let mut depth = 0
    let mut i = 0
    while i < href.length() {
      let c = href.code_unit_at(i).to_int()
      if c == '\\'.to_int() {
        i += 1
      } else if c == '('.to_int() {
        depth += 1
      } else if c == ')'.to_int() {
        depth -= 1
        if depth < 0 {
          close = i
          break
        }
      }
      i += 1
    }
    if close < 0 && depth > 0 {
      return None
    }
  }
  if close > -1 {
    let start = if raw.has_prefix("!") { 5 } else { 4 }
    let length = start + found.group(1).unwrap_or("").length() + close
    Some(js_trim_text(js_slice(raw, 0, length)))
  } else {
    Some(raw)
  }
}

///|
/// marked's `reflink` tokenizer: a reference to a known link is a link;
/// any other is its first character as text (`false`).
fn MdLexer::reflink(
  self : MdLexer,
  source : String,
  pos : Int32,
) -> (String, Bool)? {
  let found = match inline_reflink.match_prefix(source, from=pos) {
    Some(found) => found
    None =>
      match inline_nolink.match_prefix(source, from=pos) {
        Some(found) => found
        None => return None
      }
  }
  let label = match found.group(2) {
    Some(label) if label != "" => label
    _ => found.group(1).unwrap_or("")
  }
  let label = js_space_runs.replace_all(label, _ => " ").to_lower()
  if self.links.contains(label) {
    Some((found.text(), true))
  } else {
    Some((js_slice(found.text(), 0, 1), false))
  }
}

///|
/// The raw text of a bare URL or e-mail address at `pos`: marked's `url`
/// tokenizer, which leaves trailing punctuation out of a URL.
fn url_raw(source : String, pos : Int32) -> String? {
  guard inline_url.match_prefix(source, from=pos) is Some(found) else {
    return None
  }
  if found.group(2) == Some("@") {
    return Some(found.text())
  }
  let mut raw = found.text()
  while true {
    let before = raw
    raw = match inline_backpedal.exec(raw) {
      Some(found) => found.text()
      None => ""
    }
    if raw == before {
      break
    }
  }
  Some(raw)
}

///|
/// `(?!~)[\p{P}\p{S}]`: punctuation for the GitHub flavoured `*` rules.
fn is_gfm_punct(c : Int32) -> Bool {
  c != '~'.to_int() && is_punct_or_symbol(c)
}

///|
/// `[\s\p{P}\p{S}]`.
fn is_punct_or_space(c : Int32) -> Bool {
  is_js_space_unit(c) || is_punct_or_symbol(c)
}

///|
/// A match of marked's `emStrongRDelimAst` or `emStrongRDelimUnd`: where
/// it starts and ends, which group holds the delimiter run (0 for the
/// matches that only skip text), the run's length and the length of the
/// character before it.
priv struct RightDelimiter {
  index : Int32
  end : Int32
  group : Int32
  run : Int32
  before : Int32
}

///|
/// The next match of the closing delimiter pattern for `delimiter` in
/// `text` at or after `from`, as the global `u` pattern finds it. For `*`
/// (`emStrongRDelimAst`, GitHub flavoured, where `~` is not punctuation):
///
/// ```text
/// ^[^_*]*?__[^_*]*?\*[^_*]*?(?=__)
/// | [^*]+(?=[^*])
/// | (?!\*)punct(\*+)(?=[\s]|$)
/// | notPunctSpace(\*+)(?!\*)(?=punctSpace|$)
/// | (?!\*)punctSpace(\*+)(?=notPunctSpace)
/// | [\s](\*+)(?!\*)(?=punct)
/// | (?!\*)punct(\*+)(?!\*)(?=punct)
/// | notPunctSpace(\*+)(?=notPunctSpace)
/// ```
///
/// and for `_` (`emStrongRDelimUnd`) the same with the two delimiters
/// swapped, plain punctuation and no last alternative.
fn right_delimiter(
  text : String,
  from : Int32,
  delimiter : Int32,
) -> RightDelimiter? {
  let ast = delimiter == '*'.to_int()
  let other = if ast { '_'.to_int() } else { '*'.to_int() }
  let n = text.length()
  let unit = (at : Int32) => text.code_unit_at(at).to_int()
  let punct = (c : Int32) => {
    if ast {
      is_gfm_punct(c)
    } else {
      is_punct_or_symbol(c)
    }
  }
  let punct_space = (c : Int32) => {
    if ast {
      c != '~'.to_int() && is_punct_or_space(c)
    } else {
      is_punct_or_space(c)
    }
  }
  let not_punct_space = (c : Int32) => {
    !is_punct_or_space(c) || (ast && c == '~'.to_int())
  }
  let mut p = from
  while p < n {
    if p == 0 {
      // `__a*b__` inside `*` (or `**a_b**` inside `_`) is skipped whole.
      let skip = (at : Int32) => {
        let mut at = at
        while at < n && unit(at) != delimiter && unit(at) != other {
          at += 1
        }
        at
      }
      let pair = (at : Int32) => {
        at + 1 < n && unit(at) == other && unit(at + 1) == other
      }
      let a = skip(0)
      if pair(a) {
        let b = skip(a + 2)
        if b < n && unit(b) == delimiter {
          let c = skip(b + 1)
          if pair(c) {
            return Some({ index: 0, end: c, group: 0, run: 0, before: 0, })
          }
        }
      }
    }
    let (c, width) = code_point_at(text, p)
    if c != delimiter {
      // `[^*]+(?=[^*])`: up to the last character before a delimiter.
      let mut q = p
      let mut last = p
      while q < n && unit(q) != delimiter {
        last = q
        q += code_point_at(text, q).1
      }
      if last > p {
        return Some({ index: p, end: last, group: 0, run: 0, before: 0, })
      }
      let start = p + width
      if start < n && unit(start) == delimiter {
        let mut end = start
        while end < n && unit(end) == delimiter {
          end += 1
        }
        let at_end = end == n
        let next = if at_end { -1 } else { code_point_at(text, end).0 }
        let space = is_js_space_unit(c)
        let group = if punct(c) && (at_end || is_js_space_unit(next)) {
          1
        } else if not_punct_space(c) && (at_end || punct_space(next)) {
          2
        } else if punct_space(c) && !at_end && not_punct_space(next) {
          3
        } else if space && !at_end && punct(next) {
          4
        } else if punct(c) && !at_end && punct(next) {
          5
        } else if ast && not_punct_space(c) && !at_end && not_punct_space(next) {
          6
        } else {
          0
        }
        if group > 0 {
          return Some({ index: p, end, group, run: end - start, before: width, })
        }
      }
    }
    p += width
  }
  None
}

///|
/// marked's `emStrong` tokenizer at `pos`, with `masked` the masked text
/// of the whole `inlineTokens` source and `previous` the code unit before
/// (-1 for none). Returns the token and how much of the source it takes.
fn MdLexer::em_strong(
  self : MdLexer,
  source : String,
  pos : Int32,
  masked : String,
  previous : Int32,
) -> (MdToken, Int32)? {
  let n = source.length()
  let delimiter = source.code_unit_at(pos).to_int()
  guard delimiter == '*'.to_int() || delimiter == '_'.to_int() else {
    return None
  }
  // `emStrongLDelim`: the run of delimiters and the character after it,
  // which is no space and, if punctuation, not the delimiter.
  let mut end = pos
  while end < n && source.code_unit_at(end).to_int() == delimiter {
    end += 1
  }
  guard end < n else { return None }
  let (next, _) = code_point_at(source, end)
  guard !is_js_space_unit(next) else { return None }
  let next_is_punct = is_gfm_punct(next)
  // `_` between two letters or digits is no delimiter.
  if delimiter == '_'.to_int() &&
    !next_is_punct &&
    previous >= 0 &&
    in_ranges(previous, letter_or_number) {
    return None
  }
  // A delimiter before punctuation opens only after white space or
  // punctuation (`*` and `_` aside).
  if next_is_punct &&
    previous >= 0 &&
    !(previous != '*'.to_int() &&
    previous != '_'.to_int() &&
    is_punct_or_space(previous)) {
    return None
  }
  let left = end - pos
  let rest = n - pos
  let text = js_slice(masked, -rest + left, masked.length())
  let mut total = left
  let mut middle = 0
  let mut from = 0
  while right_delimiter(text, from, delimiter) is Some(found) {
    from = found.end
    if found.group == 0 {
      continue
    }
    let mut run = found.run
    if found.group == 3 || found.group == 4 {
      // Another opening run.
      total += run
      continue
    } else if (found.group == 5 || found.group == 6) &&
      left % 3 != 0 &&
      (left + run) % 3 == 0 {
      // CommonMark's rule of three for runs that both open and close.
      middle += run
      continue
    }
    total -= run
    if total > 0 {
      continue
    }
    run = run.min(run + total + middle)
    let raw = js_slice(
      source,
      pos,
      pos + left + found.index + found.before + run,
    )
    let length = raw.length()
    let token = if left.min(run) % 2 != 0 {
      MdEm(self.inline_tokens(js_slice(raw, 1, -1)))
    } else {
      MdStrong(self.inline_tokens(js_slice(raw, 2, -2)))
    }
    return Some((token, length))
  }
  None
}
