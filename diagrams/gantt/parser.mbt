///|
/// `text.substr(start)`.
fn substr(text : String, start : Int32) -> String {
  if start >= text.length() {
    ""
  } else {
    text.unsafe_substring(start~, end=text.length())
  }
}

///|
/// mermaid's `sanitizeText`, which hands the text to an HTML sanitizer and
/// uses what comes back — HTML source — as plain text.
///
/// Text without a `<` is returned untouched by the sanitizer. Any other
/// text is parsed and written out again, so that what was text comes back
/// escaped: `&`, `<` and `>` as references (shown as such), character
/// references resolved. Text with actual tags in it would need the
/// sanitizer itself.
fn sanitize_text(text : String) -> String raise GanttError {
  if !text.contains("<") {
    return text
  }
  let out = StringBuilder()
  let length = text.length()
  // Ordinary text is copied in runs, from `copied` on.
  let mut copied = 0
  let mut i = 0
  while i < length {
    let c = text.unsafe_get(i)
    if !(c == '<' || c == '>' || c == '&' || c == '\u{a0}') {
      i += 1
      continue
    }
    out.write_string(text.unsafe_substring(start=copied, end=i))
    copied = i + 1
    if c == '<' {
      // A tag starts with a letter, a slash, a bang or a question mark.
      let next = if i + 1 < length {
        text.unsafe_get(i + 1).to_int()
      } else {
        0
      }
      if (next >= 'a' && next <= 'z') ||
        (next >= 'A' && next <= 'Z') ||
        next == '/' ||
        next == '!' ||
        next == '?' {
        raise Unsupported("HTML in a title or description")
      }
      out.write_string("&lt;")
    } else if c == '>' {
      out.write_string("&gt;")
    } else if c == '\u{a0}' {
      out.write_string("&nbsp;")
    } else {
      // A character reference, or just an ampersand.
      let rest = text.unsafe_substring(start=i, end=length)
      match character_reference.exec(rest) {
        Some(found) if found.text() is ("&amp;" | "&lt;" | "&gt;") ||
          @dom.sanitized_text(found.text()) != found.text() => {
          out.write_string(@dom.sanitized_text(found.text()))
          i += found.text().length()
          copied = i
          continue
        }
        _ => {
          // HTML also reads the oldest names without their semicolon.
          if legacy_reference.exec(rest) is Some(_) {
            raise Unsupported(
              "a character reference without a semicolon in a title or description",
            )
          }
          out.write_string("&amp;")
        }
      }
    }
    i += 1
  }
  out.write_string(text.unsafe_substring(start=copied, end=length))
  out.to_string()
}

///|
/// A character reference as it should be written.
let character_reference : @jsregex.Regex = regex(
  "^&(?:#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);",
)

///|
/// The names HTML resolves even without a semicolon.
let legacy_reference : @jsregex.Regex = regex(
  "^&(?:AElig|AMP|Aacute|Acirc|Agrave|Aring|Atilde|Auml|COPY|Ccedil|ETH|Eacute|Ecirc|Egrave|Euml|GT|Iacute|Icirc|Igrave|Iuml|LT|Ntilde|Oacute|Ocirc|Ograve|Oslash|Otilde|Ouml|QUOT|REG|THORN|Uacute|Ucirc|Ugrave|Uuml|Yacute|aacute|acirc|acute|aelig|agrave|amp|aring|atilde|auml|brvbar|ccedil|cedil|cent|copy|curren|deg|divide|eacute|ecirc|egrave|eth|euml|frac12|frac14|frac34|gt|iacute|icirc|iexcl|igrave|iquest|iuml|laquo|lt|macr|micro|middot|nbsp|not|ntilde|oacute|ocirc|ograve|ordf|ordm|oslash|otilde|ouml|para|plusmn|pound|quot|raquo|reg|sect|shy|sup1|sup2|sup3|szlig|thorn|times|uacute|ucirc|ugrave|uml|uuml|yacute|yen|yuml)",
)

///|
let indentation : @jsregex.Regex = regex("\\n\\s+")

///|
/// The semantic actions of `gantt.jison`, by production number.
fn GanttDb::reduce(
  self : GanttDb,
  reduction : @jison.Reduction[String],
) -> String? raise GanttError {
  let v = (index : Int32) => reduction.values[index]
  match reduction.production {
    8 => self.weekday = "monday"
    9 => self.weekday = "tuesday"
    10 => self.weekday = "wednesday"
    11 => self.weekday = "thursday"
    12 => self.weekday = "friday"
    13 => self.weekday = "saturday"
    14 => self.weekday = "sunday"
    15 => self.weekend = "friday"
    16 => self.weekend = "saturday"
    17 => self.date_format = substr(v(0), 11)
    18 => self.inclusive_end_dates = true
    // The grammar calls a function the database does not have.
    19 => raise GanttError("yy.TopAxis is not a function")
    20 => self.axis_format = substr(v(0), 11)
    21 => self.tick_interval = Some(substr(v(0), 13))
    22 => self.excludes = merge_tokens(self.excludes, substr(v(0), 9))
    23 => self.includes = merge_tokens(self.includes, substr(v(0), 9))
    24 => self.today_marker = substr(v(0), 12)
    27 => self.title = sanitize_text(substr(v(0), 6))
    28 => self.acc_title = sanitize_text(js_trim(v(1))).trim_start().to_owned()
    29 =>
      self.acc_description = indentation.replace_all(
        sanitize_text(js_trim(v(1))),
        _ => "\n",
      )
    30 =>
      self.acc_description = indentation.replace_all(
        sanitize_text(js_trim(v(0))),
        _ => "\n",
      )
    31 => self.add_section(substr(v(0), 8))
    33 => self.add_task(v(0), v(1))
    // A callback has no trace in the drawing beyond making the task
    // clickable; a link is also recorded.
    34 | 35 => self.set_class(v(0), "clickable")
    36 => {
      self.set_class(v(0), "clickable")
      self.set_link(v(0), v(2))
    }
    37 => {
      self.set_class(v(0), "clickable")
      self.set_link(v(0), v(3))
    }
    38 | 39 => {
      self.set_class(v(0), "clickable")
      self.set_link(v(0), v(1))
    }
    40 => self.set_link(v(0), v(1))
    _ => ()
  }
  None
}

///|
/// Parse Gantt chart source into its database. `title` is the title given
/// in the frontmatter, which a `title` statement in the chart replaces.
pub fn parse(source : String, title? : String) -> GanttDb raise {
  let db = GanttDb::new()
  if title is Some(title) {
    db.title = sanitize_text(title)
  }
  gantt_grammar.parse(source, empty="", token=text => text, reduce=reduction => {
    db.reduce(reduction)
  })
  |> ignore
  db
}
