// What the browser lays a label out as: lines of text runs, each run in
// one font face.

///|
/// A stretch of text in one face.
priv struct Run {
  text : String
  bold : Bool
  italic : Bool
}

///|
/// The lines of a label's markup: split at `<br>` and at paragraph
/// boundaries, with bold and italic elements tracked.
fn label_lines(root : @dom.Element) -> Array[Array[Run]] {
  let lines : Array[Array[Run]] = [[]]
  let break_line = () => lines.push([])
  // A block starts on a fresh line and ends its last one.
  let block_boundary = () => {
    if lines.last() is Some(line) && !line.is_empty() {
      break_line()
    }
  }
  fn visit(element : @dom.Element, bold : Bool, italic : Bool) {
    for child in element.children() {
      match child {
        Text(text) =>
          if lines.last() is Some(line) {
            line.push({ text, bold, italic, })
          }
        Element(child) =>
          match child.tag {
            "br" => break_line()
            "p" | "div" => {
              block_boundary()
              visit(child, bold, italic)
              block_boundary()
            }
            "strong" | "b" => visit(child, true, italic)
            "em" | "i" => visit(child, bold, true)
            _ => visit(child, bold, italic)
          }
      }
    }
  }
  visit(root, false, false)
  // A trailing block boundary leaves an empty line behind.
  if lines.length() > 1 && lines.last() is Some(line) && line.is_empty() {
    lines.pop() |> ignore
  }
  lines
}

///|
/// Collapse white space across the runs of a line, as `white-space:
/// nowrap` lays it out: runs of spaces become one, the ends are trimmed.
fn collapse_runs(line : Array[Run]) -> Array[Run] {
  let out : Array[Run] = []
  let mut pending = false
  let mut started = false
  for run in line {
    let text = StringBuilder()
    for c in run.text {
      if c is (' ' | '\t' | '\n' | '\r') {
        pending = started
      } else {
        if pending {
          text.write_char(' ')
          pending = false
        }
        text.write_char(c)
        started = true
      }
    }
    if !text.is_empty() {
      out.push({ ..run, text: text.to_string(), })
    }
  }
  out
}

///|
/// The width of runs laid out side by side: every run is shaped on its
/// own and takes a whole number of layout units.
fn runs_width(runs : Array[Run], env : Env) -> Double {
  let mut width = 0.0
  // Adjacent runs in one face are shaped together.
  let mut index = 0
  while index < runs.length() {
    let first = runs[index]
    let text = StringBuilder()
    while index < runs.length() &&
          runs[index].bold == first.bold &&
          runs[index].italic == first.italic {
      text.write_string(runs[index].text)
      index += 1
    }
    width += env
      .font(bold=first.bold, italic=first.italic)
      .advance(text.to_string(), env.font_size)
  }
  width
}

///|
/// The number of rows a line takes in a box `width` wide with
/// `white-space: break-spaces`: spaces are kept, and the line may break
/// after any of them.
fn wrapped_rows(line : Array[Run], width : Double, env : Env) -> Int32 {
  let tokens : Array[Run] = []
  for run in line {
    let word = StringBuilder()
    for c in run.text {
      if c == ' ' {
        if !word.is_empty() {
          tokens.push({ ..run, text: word.to_string(), })
          word.reset()
        }
        tokens.push({ ..run, text: " ", })
      } else {
        word.write_char(c)
      }
    }
    if !word.is_empty() {
      tokens.push({ ..run, text: word.to_string(), })
    }
  }
  let mut rows = 1
  let mut current : Array[Run] = []
  for token in tokens {
    let candidate = [..current, token]
    if !current.is_empty() && runs_width(candidate, env) > width {
      rows += 1
      current = [token]
    } else {
      current = candidate
    }
  }
  rows
}
