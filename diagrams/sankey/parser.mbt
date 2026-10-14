///|
/// Whether JavaScript's `\s` (and `String.prototype.trim`) takes `c` for
/// white space.
fn is_js_space(c : Char) -> Bool {
  c
  is ('\t'
  | '\n'
  | '\u{0b}'
  | '\u{0c}'
  | '\r'
  | ' '
  | '\u{a0}'
  | '\u{1680}'
  | '\u{2000}'..<='\u{200a}'
  | '\u{2028}'
  | '\u{2029}'
  | '\u{202f}'
  | '\u{205f}'
  | '\u{3000}'
  | '\u{feff}')
}

///|
/// `String.prototype.trim`.
fn js_trim(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_js_space(chars[start]) {
    start += 1
  }
  while end > start && is_js_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
/// mermaid's `prepareTextForParsing`: blank lines go, and so does the
/// white space around the whole text. (The expression that looks as if it
/// trimmed every row has no `m` flag, so it only reaches both ends.)
fn prepare_text_for_parsing(text : String) -> String {
  let chars = text.to_array()
  let is_blank = (c : Char) => is_js_space(c) && c != '\n' && c != '\r'
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_blank(chars[start]) {
    start += 1
  }
  while end > start && is_blank(chars[end - 1]) {
    end -= 1
  }
  let out = StringBuilder()
  let mut in_break = false
  for c in chars[start:end] {
    if c is ('\n' | '\r') {
      if !in_break {
        out.write_char('\n')
      }
      in_break = true
    } else {
      in_break = false
      out.write_char(c)
    }
  }
  js_trim(out.to_string())
}

///|
/// JavaScript's `parseFloat`: the number the longest numeric prefix of
/// the text stands for, `NaN` without one.
fn parse_float(text : String) -> Double {
  let chars = text.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && is_js_space(chars[i]) {
    i += 1
  }
  let start = i
  let mut negative = false
  if i < n && chars[i] is ('+' | '-') {
    negative = chars[i] == '-'
    i += 1
  }
  if String::from_array(chars[i:]).has_prefix("Infinity") {
    return if negative { @double.neg_infinity } else { @double.infinity }
  }
  let is_digit = (k : Int32) => k < n && chars[k] is ('0'..<='9')
  let mut digits = 0
  while is_digit(i) {
    i += 1
    digits += 1
  }
  if i < n && chars[i] == '.' && (digits > 0 || is_digit(i + 1)) {
    i += 1
    while is_digit(i) {
      i += 1
      digits += 1
    }
  }
  if digits == 0 {
    return @double.not_a_number
  }
  if i < n && chars[i] is ('e' | 'E') {
    let mut j = i + 1
    if j < n && chars[j] is ('+' | '-') {
      j += 1
    }
    if is_digit(j) {
      while is_digit(j) {
        j += 1
      }
      i = j
    }
  }
  let literal = String::from_array(chars[start:i])
  // A trailing point is part of the number in JavaScript.
  let literal = if literal.has_suffix(".") { literal + "0" } else { literal }
  let literal = literal
    .replace(old="+.", new="+0.")
    .replace(old="-.", new="-0.")
  let literal = if literal.has_prefix(".") { "0" + literal } else { literal }
  let literal = literal
    .replace(old=".e", new=".0e")
    .replace(old=".E", new=".0E")
  @string.parse_double(literal) catch {
    _ => @double.not_a_number
  }
}

///|
/// Parse Sankey source with sankey.jison, a CSV dialect:
///
/// ```text
/// start: SANKEY NEWLINE csv opt_eof
/// csv: record (NEWLINE csv)?
/// record: field COMMA field COMMA field
/// ```
pub fn parse(source : String, config : @config.Config) -> Sankey raise {
  let db = Sankey::new(config)
  sankey_grammar.parse(
    prepare_text_for_parsing(source),
    empty="",
    token=text => text,
    reduce=reduction => {
      let values = reduction.values
      let n = values.length()
      match reduction.production {
        7 => {
          let field = (k : Int32) => {
            js_trim(values[n - 1 - k]).replace_all(old="\"\"", new="\"")
          }
          let source = db.find_or_create_node(field(4))
          let target = db.find_or_create_node(field(2))
          let value = parse_float(js_trim(values[n - 1]))
          db.links.push((source, target, value))
          None
        }
        10 => Some(values[n - 2])
        _ => None
      }
    },
    hook=(hook, lexer) => {
      if hook == 0 {
        lexer.pop_state()
      }
      Continue
    },
  )
  |> ignore
  db
}
