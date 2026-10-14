// What the browser lays a label out as: lines of text runs, each run in
// one font face.

///|
/// A stretch of text in one face.
priv struct Run {
  text : String
  bold : Bool
  italic : Bool
  /// Whether the text is in a bold element inside bold text. Its weight
  /// is `bolder` than bold: drawn with the same face, but a font of its
  /// own, shaped apart from the bold text around it.
  heavy : Bool
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
  fn visit(element : @dom.Element, bold : Bool, italic : Bool, heavy : Bool) {
    for child in element.children() {
      match child {
        Text(text) =>
          if lines.last() is Some(line) {
            line.push({ text, bold, italic, heavy, })
          }
        Element(child) =>
          match child.tag {
            "br" => break_line()
            "p" | "div" => {
              block_boundary()
              visit(child, bold, italic, heavy)
              block_boundary()
            }
            "strong" | "b" => visit(child, true, italic, bold)
            "em" | "i" => visit(child, bold, true, heavy)
            _ => visit(child, bold, italic, heavy)
          }
      }
    }
  }
  visit(root, false, false, false)
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
          runs[index].italic == first.italic &&
          runs[index].heavy == first.heavy {
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
  heavy : Bool
  positions : Map[Int32, Double]
  unrounded : Map[Int32, Double]
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
/// The width of the item's text between two character offsets before it
/// is rounded to layout units. The text is shaped on its own: a row that
/// starts inside an item is shaped anew from there where the break is not
/// safe (a kerning pair across it), and measures the same otherwise.
fn Item::unrounded_width(
  self : Item,
  start : Int32,
  end : Int32,
  env : Env,
) -> Double {
  let key = start * 65536 + end
  if self.unrounded.get(key) is Some(width) {
    return width
  }
  let width = env
    .font(bold=self.bold, italic=self.italic)
    .advance_unrounded(String::from_array(self.chars[start:end]), env.font_size)
  self.unrounded[key] = width
  width
}

///|
/// The runs of a line merged into items: adjacent runs in one face are
/// shaped together.
fn line_items(line : Array[Run]) -> Array[Item] {
  let items : Array[Item] = []
  for run in line {
    match items.last() {
      Some(item) if item.bold == run.bold &&
        item.italic == run.italic &&
        item.heavy == run.heavy =>
        for c in run.text {
          item.chars.push(c)
        }
      _ =>
        items.push({
          chars: run.text.to_array(),
          bold: run.bold,
          heavy: run.heavy,
          italic: run.italic,
          positions: Map([]),
          unrounded: Map([]),
        })
    }
  }
  items
}

///|
/// A stretch of one item inside a piece of a line: the item and the
/// character offsets it runs between.
priv struct Segment {
  item : Int32
  start : Int32
  end : Int32
}

///|
/// A piece of a line that cannot be broken: its width in whole layout
/// units, and the stretches of items it is made of.
priv struct Piece {
  width : Double
  segments : Array[Segment]
}

///|
/// The pieces of a line that cannot be broken with `white-space:
/// break-spaces`: a line may break after every space and wherever
/// `breaks_between` allows.
fn unbreakable_pieces(items : Array[Item], env : Env) -> Array[Piece] {
  // Every character with the item it is in.
  let flat : Array[(Int32, Int32, Char)] = []
  for index, item in items {
    for offset, c in item.chars {
      flat.push((index, offset, c))
    }
  }
  let pieces = []
  let mut width = 0.0
  let mut segments = []
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
      segments.push({ item: index, start, end: offset + 1, })
      start = if last_of_item { 0 } else { offset + 1 }
    }
    if break_after {
      pieces.push({ width, segments, })
      width = 0.0
      segments = []
    }
  }
  pieces
}

///|
/// How a line is laid out in a box `width` wide with `white-space:
/// break-spaces`: the number of rows, and the width of the widest piece,
/// which the box grows to when it is wider.
///
/// Whether a piece still fits on a row is decided as the line breaker
/// decides it: the text of the row is measured from its start, shaped
/// from there and not rounded (an item that ends before the row does
/// takes whole layout units), and may overflow the box by one layout unit
/// (`AvailableWidthToFit` adds an epsilon).
fn wrapped_rows(
  line : Array[Run],
  width : Double,
  env : Env,
) -> (Int32, Double) {
  let items = line_items(line)
  let fit = width + 1.0 / 64.0
  let mut rows = 1
  let mut widest = 0.0
  let mut empty = true
  // The items the row has finished, and where the row's part of the
  // item it is in started.
  let mut finished = 0.0
  let mut open : (Int32, Int32)? = None
  // The width of the row up to the end of `segment`, from the state of
  // the row before it.
  let measure = (
    finished : Double,
    open : (Int32, Int32)?,
    segments : Array[Segment],
  ) => {
    let mut finished = finished
    let mut open = open
    let mut width = 0.0
    for segment in segments {
      let item = items[segment.item]
      let from = match open {
        Some((index, from)) if index == segment.item => from
        Some((index, from)) => {
          // The row moves on to another item.
          let done = items[index]
          finished += done
            .unrounded_width(from, done.chars.length(), env)
            .ceil_to_unit()
          segment.start
        }
        None => segment.start
      }
      open = Some((segment.item, from))
      width = finished + item.unrounded_width(from, segment.end, env)
    }
    (width, finished, open)
  }
  for piece in unbreakable_pieces(items, env) {
    widest = widest.max(piece.width)
    let (row_width, next_finished, next_open) = measure(
      finished,
      open,
      piece.segments,
    )
    if !empty && row_width > fit {
      rows += 1
      let (_, restart_finished, restart_open) = measure(
        0.0,
        None,
        piece.segments,
      )
      finished = restart_finished
      open = restart_open
    } else {
      finished = next_finished
      open = next_open
      empty = false
    }
  }
  (rows, widest)
}

///|
/// A width rounded up to whole layout units.
fn Double::ceil_to_unit(self : Double) -> Double {
  (self * 64.0).ceil() / 64.0
}
