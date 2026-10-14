///|
/// `String.prototype.trim`.
fn js_trim(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && @diagram.is_js_space(chars[start]) {
    start += 1
  }
  while end > start && @diagram.is_js_space(chars[end - 1]) {
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
  let is_blank = (c : Char) => @diagram.is_js_space(c) && c != '\n' && c != '\r'
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
          let value = @diagram.parse_float(js_trim(values[n - 1]))
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
