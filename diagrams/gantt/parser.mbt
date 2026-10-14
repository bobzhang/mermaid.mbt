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
/// mermaid's `sanitizeText` for text without markup: the text goes through
/// an HTML sanitizer and comes back as HTML source, so `&`, `<` and `>`
/// return as references (and show as such, the text being used as text).
/// Text with tags in it would need the sanitizer itself.
fn sanitize_text(text : String) -> String raise GanttError {
  let out = StringBuilder()
  let length = text.length()
  for i in 0..<length {
    let c = text.unsafe_get(i)
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
    } else {
      out.write_char(c.to_int().unsafe_to_char())
    }
  }
  // Character references are resolved, except the three above.
  @dom.sanitized_text(out.to_string())
}

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
