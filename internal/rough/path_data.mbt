// Path data as rough.js reads it: its `path-data-parser`.

///|
/// One command of a path with its arguments.
priv struct Segment {
  key : Char
  data : Array[Double]
}

///|
fn param_count(key : Char) -> Int32? {
  match key {
    'A' | 'a' => Some(7)
    'C' | 'c' => Some(6)
    'H' | 'h' | 'V' | 'v' => Some(1)
    'L' | 'l' | 'M' | 'm' | 'T' | 't' => Some(2)
    'Q' | 'q' | 'S' | 's' => Some(4)
    'Z' | 'z' => Some(0)
    _ => None
  }
}

///|
priv enum Token {
  Command(Char)
  Number(Double)
}

///|
/// Split path data into commands and numbers; nothing when it holds
/// anything else.
fn tokenize(d : String) -> Array[Token]? {
  let chars = d.to_array()
  let n = chars.length()
  let tokens = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    if c is (' ' | '\t' | '\r' | '\n' | ',') {
      i += 1
      continue
    }
    if param_count(c) is Some(_) {
      tokens.push(Command(c))
      i += 1
      continue
    }
    // ([-+]?[0-9]+(\.[0-9]*)?|[-+]?\.[0-9]+)([eE][-+]?[0-9]+)?
    let start = i
    let mut j = i
    if j < n && chars[j] is ('-' | '+') {
      j += 1
    }
    let digits_start = j
    while j < n && chars[j] is ('0'..<='9') {
      j += 1
    }
    if j > digits_start {
      if j < n && chars[j] == '.' {
        j += 1
        while j < n && chars[j] is ('0'..<='9') {
          j += 1
        }
      }
    } else if j < n && chars[j] == '.' {
      j += 1
      let fraction_start = j
      while j < n && chars[j] is ('0'..<='9') {
        j += 1
      }
      if j == fraction_start {
        return None
      }
    } else {
      return None
    }
    if j < n && chars[j] is ('e' | 'E') {
      let mut k = j + 1
      if k < n && chars[k] is ('-' | '+') {
        k += 1
      }
      let exponent_start = k
      while k < n && chars[k] is ('0'..<='9') {
        k += 1
      }
      if k > exponent_start {
        j = k
      }
    }
    let text = String::from_array(chars[start:j])
    // A trailing dot is fine for JavaScript's parseFloat.
    let text = match text.strip_suffix(".") {
      Some(prefix) => prefix.to_owned()
      None => text
    }
    let text = match text.strip_prefix("+") {
      Some(rest) => rest.to_owned()
      None => text
    }
    tokens.push(Number(@string.parse_double(text) catch { _ => return None }))
    i = j
  }
  Some(tokens)
}

///|
/// Parse path data into its commands.
fn parse_path(d : String) -> Array[Segment] {
  guard tokenize(d) is Some(tokens) else { return [] }
  if tokens is [Command(c), ..] && !(c is ('M' | 'm')) {
    return parse_path("M0,0" + d)
  }
  if tokens is [Number(_), ..] {
    return parse_path("M0,0" + d)
  }
  let segments = []
  let mut mode = ' '
  let mut index = 0
  while index < tokens.length() {
    if tokens[index] is Command(c) {
      index += 1
      mode = c
    }
    guard param_count(mode) is Some(count) else { break }
    guard index + count <= tokens.length() else { break }
    let data = []
    for k in index..<(index + count) {
      guard tokens[k] is Number(value) else { return segments }
      data.push(value)
    }
    segments.push({ key: mode, data, })
    index += count
    if mode == 'M' {
      mode = 'L'
    }
    if mode == 'm' {
      mode = 'l'
    }
    // Commands without arguments do not repeat.
    if count == 0 && index < tokens.length() && tokens[index] is Number(_) {
      break
    }
  }
  segments
}

///|
/// Make every command absolute.
fn absolutize(segments : Array[Segment]) -> Array[Segment] {
  let mut cx = 0.0
  let mut cy = 0.0
  let mut subx = 0.0
  let mut suby = 0.0
  let out = []
  for segment in segments {
    let data = segment.data
    let shifted = () => {
      data.mapi((i, value) => if i % 2 == 1 { value + cy } else { value + cx })
    }
    match segment.key {
      'M' => {
        out.push({ key: 'M', data: data.copy(), })
        cx = data[0]
        cy = data[1]
        subx = data[0]
        suby = data[1]
      }
      'm' => {
        cx += data[0]
        cy += data[1]
        out.push({ key: 'M', data: [cx, cy], })
        subx = cx
        suby = cy
      }
      'L' => {
        out.push({ key: 'L', data: data.copy(), })
        cx = data[0]
        cy = data[1]
      }
      'l' => {
        cx += data[0]
        cy += data[1]
        out.push({ key: 'L', data: [cx, cy], })
      }
      'C' => {
        out.push({ key: 'C', data: data.copy(), })
        cx = data[4]
        cy = data[5]
      }
      'c' => {
        let absolute = shifted()
        out.push({ key: 'C', data: absolute, })
        cx = absolute[4]
        cy = absolute[5]
      }
      'Q' => {
        out.push({ key: 'Q', data: data.copy(), })
        cx = data[2]
        cy = data[3]
      }
      'q' => {
        let absolute = shifted()
        out.push({ key: 'Q', data: absolute, })
        cx = absolute[2]
        cy = absolute[3]
      }
      'A' => {
        out.push({ key: 'A', data: data.copy(), })
        cx = data[5]
        cy = data[6]
      }
      'a' => {
        cx += data[5]
        cy += data[6]
        out.push({
          key: 'A',
          data: [data[0], data[1], data[2], data[3], data[4], cx, cy],
        })
      }
      'H' => {
        out.push({ key: 'H', data: data.copy(), })
        cx = data[0]
      }
      'h' => {
        cx += data[0]
        out.push({ key: 'H', data: [cx], })
      }
      'V' => {
        out.push({ key: 'V', data: data.copy(), })
        cy = data[0]
      }
      'v' => {
        cy += data[0]
        out.push({ key: 'V', data: [cy], })
      }
      'S' => {
        out.push({ key: 'S', data: data.copy(), })
        cx = data[2]
        cy = data[3]
      }
      's' => {
        let absolute = shifted()
        out.push({ key: 'S', data: absolute, })
        cx = absolute[2]
        cy = absolute[3]
      }
      'T' => {
        out.push({ key: 'T', data: data.copy(), })
        cx = data[0]
        cy = data[1]
      }
      't' => {
        cx += data[0]
        cy += data[1]
        out.push({ key: 'T', data: [cx, cy], })
      }
      _ => {
        out.push({ key: 'Z', data: [], })
        cx = subx
        cy = suby
      }
    }
  }
  out
}

///|
/// Reduce absolute commands to `M`, `L`, `C` and `Z`. Arcs are not
/// converted yet and become straight lines.
fn normalize(segments : Array[Segment]) -> Array[Segment] {
  let out = []
  let mut last = ' '
  let mut cx = 0.0
  let mut cy = 0.0
  let mut subx = 0.0
  let mut suby = 0.0
  let mut lcx = 0.0
  let mut lcy = 0.0
  for segment in segments {
    let data = segment.data
    match segment.key {
      'M' => {
        out.push({ key: 'M', data: data.copy(), })
        cx = data[0]
        cy = data[1]
        subx = data[0]
        suby = data[1]
      }
      'C' => {
        out.push({ key: 'C', data: data.copy(), })
        cx = data[4]
        cy = data[5]
        lcx = data[2]
        lcy = data[3]
      }
      'L' => {
        out.push({ key: 'L', data: data.copy(), })
        cx = data[0]
        cy = data[1]
      }
      'H' => {
        cx = data[0]
        out.push({ key: 'L', data: [cx, cy], })
      }
      'V' => {
        cy = data[0]
        out.push({ key: 'L', data: [cx, cy], })
      }
      'S' => {
        let (cx1, cy1) = if last is ('C' | 'S') {
          (cx + (cx - lcx), cy + (cy - lcy))
        } else {
          (cx, cy)
        }
        out.push({ key: 'C', data: [cx1, cy1, ..data], })
        lcx = data[0]
        lcy = data[1]
        cx = data[2]
        cy = data[3]
      }
      'T' => {
        let x = data[0]
        let y = data[1]
        let (x1, y1) = if last is ('Q' | 'T') {
          (cx + (cx - lcx), cy + (cy - lcy))
        } else {
          (cx, cy)
        }
        let cx1 = cx + 2.0 * (x1 - cx) / 3.0
        let cy1 = cy + 2.0 * (y1 - cy) / 3.0
        let cx2 = x + 2.0 * (x1 - x) / 3.0
        let cy2 = y + 2.0 * (y1 - y) / 3.0
        out.push({ key: 'C', data: [cx1, cy1, cx2, cy2, x, y], })
        lcx = x1
        lcy = y1
        cx = x
        cy = y
      }
      'Q' => {
        let x1 = data[0]
        let y1 = data[1]
        let x = data[2]
        let y = data[3]
        let cx1 = cx + 2.0 * (x1 - cx) / 3.0
        let cy1 = cy + 2.0 * (y1 - cy) / 3.0
        let cx2 = x + 2.0 * (x1 - x) / 3.0
        let cy2 = y + 2.0 * (y1 - y) / 3.0
        out.push({ key: 'C', data: [cx1, cy1, cx2, cy2, x, y], })
        lcx = x1
        lcy = y1
        cx = x
        cy = y
      }
      'A' => {
        let x = data[5]
        let y = data[6]
        if data[0].abs() == 0.0 || data[1].abs() == 0.0 {
          out.push({ key: 'C', data: [cx, cy, x, y, x, y], })
        } else if cx != x || cy != y {
          out.push({ key: 'L', data: [x, y], })
        }
        cx = x
        cy = y
      }
      _ => {
        out.push({ key: 'Z', data: [], })
        cx = subx
        cy = suby
      }
    }
    last = segment.key
  }
  out
}
