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
/// A space stays in the run it was written in, which decides the face it
/// is measured in and the item it is rounded with.
fn collapse_runs(line : Array[Run]) -> Array[Run] {
  let texts : Array[StringBuilder] = line.map(_ => StringBuilder())
  // Whether the last character kept is a space, and the run holding it.
  let mut space_in : Int32? = None
  let mut started = false
  for index, run in line {
    for c in run.text {
      if c is (' ' | '\t' | '\n' | '\r') {
        if started && space_in is None {
          texts[index].write_char(' ')
          space_in = Some(index)
        }
      } else {
        texts[index].write_char(c)
        started = true
        space_in = None
      }
    }
  }
  let out : Array[Run] = []
  for index, run in line {
    let text = texts[index].to_string()
    // The space the line ends in takes no room.
    let text = if space_in == Some(index) {
      text[:text.length() - 1].to_owned()
    } else {
      text
    }
    if text != "" {
      out.push({ ..run, text, })
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
/// Whether a line may break between two ASCII characters that are not
/// spaces: Blink's table for ASCII, read off the reference browser.
/// `before` is the character ahead of `a`, which decides whether a hyphen
/// in front of a digit is a minus sign. Other scripts are not handled.
fn breaks_between(before : Char?, a : Char, b : Char) -> Bool {
  let is_alnum = (c : Char) => c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9')
  match a {
    '-' =>
      if b is ('0'..<='9') {
        before is Some(c) && is_alnum(c)
      } else {
        b
        is ('"'
        | '#'
        | '%'
        | '&'
        | '\''
        | '('
        | '*'
        | '+'
        | '-'
        | '<'
        | '='
        | '>'
        | '@'
        | 'A'..<='Z'
        | '['
        | '\\'
        | '^'
        | '_'
        | '`'
        | 'a'..<='z'
        | '{'
        | '|'
        | '~')
      }
    '?' =>
      b
      is ('#'
      | '$'
      | '%'
      | '&'
      | '('
      | '*'
      | '+'
      | '-'
      | '0'..<='9'
      | '<'
      | '='
      | '>'
      | '@'
      | 'A'..<='Z'
      | '['
      | '\\'
      | '^'
      | '_'
      | '`'
      | 'a'..<='z'
      | '{'
      | '|'
      | '~')
    '!'
    | '"'
    | '#'
    | '%'
    | '&'
    | ')'
    | '*'
    | '+'
    | ','
    | '.'
    | ':'
    | ';'
    | '='
    | '>'
    | '\\'
    | ']'
    | '|'
    | '}'
    | '~' => b is ('(' | '<' | '[' | '{')
    _ => false
  }
}

///|
/// Text in one face, shaped as a whole: positions inside it are measured
/// from its start, as the browser does when it breaks lines.
priv struct Item {
  chars : Array[Char]
  bold : Bool
  italic : Bool
  positions : Map[Int32, Double]
}

///|
/// The distance from the start of the item to a character offset, in
/// whole layout units.
fn Item::position(self : Item, offset : Int32, env : Env) -> Double {
  if offset <= 0 {
    return 0.0
  }
  if self.positions.get(offset) is Some(position) {
    return position
  }
  let position = env
    .font(bold=self.bold, italic=self.italic)
    .advance(String::from_array(self.chars[:offset]), env.font_size)
  self.positions[offset] = position
  position
}

///|
/// The runs of a line merged into items: adjacent runs in one face are
/// shaped together.
fn line_items(line : Array[Run]) -> Array[Item] {
  let items : Array[Item] = []
  for run in line {
    match items.last() {
      Some(item) if item.bold == run.bold && item.italic == run.italic =>
        for c in run.text {
          item.chars.push(c)
        }
      _ =>
        items.push({
          chars: run.text.to_array(),
          bold: run.bold,
          italic: run.italic,
          positions: Map([]),
        })
    }
  }
  items
}

///|
/// The widths of the pieces of a line that cannot be broken with
/// `white-space: break-spaces`: a line may break after every space and
/// wherever `breaks_between` allows.
fn unbreakable_widths(line : Array[Run], env : Env) -> Array[Double] {
  let items = line_items(line)
  // Every character with the item it is in.
  let flat : Array[(Int32, Int32, Char)] = []
  for index, item in items {
    for offset, c in item.chars {
      flat.push((index, offset, c))
    }
  }
  let widths = []
  let mut width = 0.0
  // Where the current piece starts within the current item.
  let mut start = 0
  for k, entry in flat {
    let (index, offset, c) = entry
    let item = items[index]
    let last_of_item = offset == item.chars.length() - 1
    let next = if k + 1 < flat.length() { Some(flat[k + 1].2) } else { None }
    let before = if k > 0 { Some(flat[k - 1].2) } else { None }
    let break_after = match next {
      None => true
      Some(next) =>
        if c == ' ' {
          true
        } else if next == ' ' {
          // A space stays with the word before it.
          false
        } else {
          breaks_between(before, c, next)
        }
    }
    if break_after || last_of_item {
      width += item.position(offset + 1, env) - item.position(start, env)
      start = if last_of_item { 0 } else { offset + 1 }
    }
    if break_after {
      widths.push(width)
      width = 0.0
    }
  }
  widths
}

///|
/// How a line is laid out in a box `width` wide with `white-space:
/// break-spaces`: the number of rows, and the width of the widest piece,
/// which the box grows to when it is wider.
fn wrapped_rows(
  line : Array[Run],
  width : Double,
  env : Env,
) -> (Int32, Double) {
  let mut rows = 1
  let mut widest = 0.0
  let mut current = 0.0
  let mut empty = true
  for unit in unbreakable_widths(line, env) {
    widest = widest.max(unit)
    if !empty && current + unit > width {
      rows += 1
      current = unit
    } else {
      current += unit
      empty = false
    }
  }
  (rows, widest)
}
