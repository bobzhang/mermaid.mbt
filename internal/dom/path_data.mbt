// SVG path data as the browser sees it: parsed into single-precision
// segments the way Blink does, then measured the way Skia does.

///|
/// One absolute segment of a path.
priv enum PathSegment {
  MoveTo(Float, Float)
  LineTo(Float, Float)
  QuadTo(Float, Float, Float, Float)
  CubicTo(Float, Float, Float, Float, Float, Float)
  Close
}

///|
/// Blink's SVG number parser: single-precision arithmetic digit by digit,
/// which is not always the nearest float to the decimal.
fn parse_svg_number(text : StringView) -> Float {
  let chars = text.to_array()
  let n = chars.length()
  let mut i = 0
  let mut sign : Float = 1
  if i < n && chars[i] == '+' {
    i += 1
  } else if i < n && chars[i] == '-' {
    i += 1
    sign = -1
  }
  let digits_start = i
  while i < n && chars[i] is ('0'..<='9') {
    i += 1
  }
  let mut integer : Float = 0
  let mut multiplier : Float = 1
  for j = i - 1; j >= digits_start; j = j - 1 {
    integer = integer + multiplier * Float::from_int(chars[j].to_int() - '0')
    multiplier = multiplier * 10
  }
  let mut decimal : Float = 0
  if i < n && chars[i] == '.' {
    i += 1
    let mut frac : Float = 1
    let tenth : Float = 0.1
    while i < n && chars[i] is ('0'..<='9') {
      frac = frac * tenth
      decimal = decimal + Float::from_int(chars[i].to_int() - '0') * frac
      i += 1
    }
  }
  let mut number = (integer + decimal) * sign
  if i < n && chars[i] is ('e' | 'E') {
    i += 1
    let mut negative = false
    if i < n && chars[i] == '+' {
      i += 1
    } else if i < n && chars[i] == '-' {
      i += 1
      negative = true
    }
    let mut exponent = 0
    while i < n && chars[i] is ('0'..<='9') {
      exponent = exponent * 10 + (chars[i].to_int() - '0')
      i += 1
    }
    if exponent != 0 {
      let mut power = 1.0
      for _ in 0..<exponent {
        power = power * 10.0
      }
      if negative {
        power = 1.0 / power
      }
      number = number * Float::from_double(power)
    }
  }
  number
}

///|
/// Split path data into commands and their numbers.
fn tokenize_path(data : String) -> Array[(Char, Array[Float])] {
  let commands : Array[(Char, Array[Float])] = []
  let current = StringBuilder()
  let flush = () => {
    if !current.is_empty() {
      if commands.last() is Some((_, numbers)) {
        numbers.push(parse_svg_number(current.to_string()))
      }
      current.reset()
    }
  }
  for c in data {
    match c {
      'e' | 'E' => current.write_char(c)
      'A'..<='Z' | 'a'..<='z' => {
        flush()
        commands.push((c, []))
      }
      ' ' | ',' | '\n' | '\t' | '\r' => flush()
      '-' | '+' => {
        // A sign starts a new number unless it follows an exponent.
        let text = current.to_string()
        if !(text.has_suffix("e") || text.has_suffix("E")) {
          flush()
        }
        current.write_char(c)
      }
      '.' => {
        // A second decimal point starts a new number.
        let text = current.to_string()
        if text.contains(".") && !text.contains("e") && !text.contains("E") {
          flush()
        }
        current.write_char(c)
      }
      _ => current.write_char(c)
    }
  }
  flush()
  commands
}

///|
/// Parse path data into absolute segments. Arcs are not supported yet and
/// become straight lines to their end point.
fn parse_path(data : String) -> Array[PathSegment] {
  let segments = []
  let mut x : Float = 0
  let mut y : Float = 0
  let mut start_x : Float = 0
  let mut start_y : Float = 0
  // The last control point, for smooth curves.
  let mut control : (Float, Float)? = None
  let mut control_is_cubic = false
  for command in tokenize_path(data) {
    let (name, args) = command
    let relative = name is ('a'..<='z')
    let dx : Float = if relative { x } else { 0 }
    let dy : Float = if relative { y } else { 0 }
    match name {
      'M' | 'm' => {
        let mut first = true
        let mut bx = dx
        let mut by = dy
        for i = 0; i + 1 < args.length(); i = i + 2 {
          x = args[i] + bx
          y = args[i + 1] + by
          if first {
            segments.push(MoveTo(x, y))
            start_x = x
            start_y = y
            first = false
          } else {
            segments.push(LineTo(x, y))
          }
          if relative {
            bx = x
            by = y
          }
        }
        control = None
      }
      'L' | 'l' => {
        let mut bx = dx
        let mut by = dy
        for i = 0; i + 1 < args.length(); i = i + 2 {
          x = args[i] + bx
          y = args[i + 1] + by
          segments.push(LineTo(x, y))
          if relative {
            bx = x
            by = y
          }
        }
        control = None
      }
      'H' | 'h' => {
        for value in args {
          x = if relative { x + value } else { value }
          segments.push(LineTo(x, y))
        }
        control = None
      }
      'V' | 'v' => {
        for value in args {
          y = if relative { y + value } else { value }
          segments.push(LineTo(x, y))
        }
        control = None
      }
      'Q' | 'q' =>
        for i = 0; i + 3 < args.length(); i = i + 4 {
          let bx : Float = if relative { x } else { 0 }
          let by : Float = if relative { y } else { 0 }
          let cx = args[i] + bx
          let cy = args[i + 1] + by
          x = args[i + 2] + bx
          y = args[i + 3] + by
          segments.push(QuadTo(cx, cy, x, y))
          control = Some((cx, cy))
          control_is_cubic = false
        }
      'T' | 't' =>
        for i = 0; i + 1 < args.length(); i = i + 2 {
          let bx : Float = if relative { x } else { 0 }
          let by : Float = if relative { y } else { 0 }
          let (cx, cy) = match control {
            Some((px, py)) if !control_is_cubic => (x + x - px, y + y - py)
            _ => (x, y)
          }
          x = args[i] + bx
          y = args[i + 1] + by
          segments.push(QuadTo(cx, cy, x, y))
          control = Some((cx, cy))
          control_is_cubic = false
        }
      'C' | 'c' =>
        for i = 0; i + 5 < args.length(); i = i + 6 {
          let bx : Float = if relative { x } else { 0 }
          let by : Float = if relative { y } else { 0 }
          let c2x = args[i + 2] + bx
          let c2y = args[i + 3] + by
          segments.push(
            CubicTo(
              args[i] + bx,
              args[i + 1] + by,
              c2x,
              c2y,
              args[i + 4] + bx,
              args[i + 5] + by,
            ),
          )
          x = args[i + 4] + bx
          y = args[i + 5] + by
          control = Some((c2x, c2y))
          control_is_cubic = true
        }
      'S' | 's' =>
        for i = 0; i + 3 < args.length(); i = i + 4 {
          let bx : Float = if relative { x } else { 0 }
          let by : Float = if relative { y } else { 0 }
          let (c1x, c1y) = match control {
            Some((px, py)) if control_is_cubic => (x + x - px, y + y - py)
            _ => (x, y)
          }
          let c2x = args[i] + bx
          let c2y = args[i + 1] + by
          x = args[i + 2] + bx
          y = args[i + 3] + by
          segments.push(CubicTo(c1x, c1y, c2x, c2y, x, y))
          control = Some((c2x, c2y))
          control_is_cubic = true
        }
      'A' | 'a' => {
        for i = 0; i + 6 < args.length(); i = i + 7 {
          let bx : Float = if relative { x } else { 0 }
          let by : Float = if relative { y } else { 0 }
          x = args[i + 5] + bx
          y = args[i + 6] + by
          segments.push(LineTo(x, y))
        }
        control = None
      }
      'Z' | 'z' => {
        segments.push(Close)
        x = start_x
        y = start_y
        control = None
      }
      _ => ()
    }
  }
  segments
}

///|
/// Skia's `valid_unit_divide`: `numer / denom` when it lies strictly
/// between 0 and 1.
fn valid_unit_divide(numer : Float, denom : Float) -> Float? {
  let mut numer = numer
  let mut denom = denom
  if numer < 0 {
    numer = -numer
    denom = -denom
  }
  if denom == 0 || numer == 0 || numer >= denom {
    return None
  }
  let r = numer / denom
  if r.is_nan() || r == 0 {
    return None
  }
  Some(r)
}

///|
/// The tight box of path data, as `SkPath::computeTightBounds` finds it.
/// Cubics are bounded by their control points for now.
fn path_bounds(data : String) -> Bounds? {
  let mut bounds : Bounds? = None
  let add = (x : Float, y : Float) => {
    let point = { left: x, top: y, right: x, bottom: y, }
    match bounds {
      Some(bounds) => bounds.unite(point)
      None => bounds = Some(point)
    }
  }
  let mut x : Float = 0
  let mut y : Float = 0
  for segment in parse_path(data) {
    match segment {
      MoveTo(px, py) | LineTo(px, py) => {
        add(px, py)
        x = px
        y = py
      }
      QuadTo(cx, cy, px, py) => {
        // The curve is (A t + B) t + C.
        let ax = px - (cx + cx) + x
        let ay = py - (cy + cy) + y
        let bx = cx - x + (cx - x)
        let by = cy - y + (cy - y)
        let eval = (t : Float) => {
          add((ax * t + bx) * t + x, (ay * t + by) * t + y)
        }
        if valid_unit_divide(x - cx, x - cx - cx + px) is Some(t) {
          eval(t)
        }
        if valid_unit_divide(y - cy, y - cy - cy + py) is Some(t) {
          eval(t)
        }
        add(px, py)
        x = px
        y = py
      }
      CubicTo(c1x, c1y, c2x, c2y, px, py) => {
        add(c1x, c1y)
        add(c2x, c2y)
        add(px, py)
        x = px
        y = py
      }
      Close => ()
    }
  }
  bounds
}

///|
/// The distance between two points as Blink's `gfx::Vector2dF::Length`
/// computes it: in double precision, rounded once.
fn point_distance(x0 : Float, y0 : Float, x1 : Float, y1 : Float) -> Float {
  let dx = (x1 - x0).to_double()
  let dy = (y1 - y0).to_double()
  Float::from_double((dx * dx + dy * dy).sqrt())
}

///|
/// A cubic Bezier segment being measured.
priv struct Cubic {
  x0 : Float
  y0 : Float
  x1 : Float
  y1 : Float
  x2 : Float
  y2 : Float
  x3 : Float
  y3 : Float
  depth : Int32
}

///|
/// The length of the control polygon: never less than the curve's.
fn Cubic::approximate_distance(self : Cubic) -> Float {
  point_distance(self.x0, self.y0, self.x1, self.y1) +
  point_distance(self.x1, self.y1, self.x2, self.y2) +
  point_distance(self.x2, self.y2, self.x3, self.y3)
}

///|
fn Cubic::split(self : Cubic) -> (Cubic, Cubic) {
  let mid = (a : Float, b : Float) => (a + b) / 2
  let mx = mid(self.x1, self.x2)
  let my = mid(self.y1, self.y2)
  let lx1 = mid(self.x0, self.x1)
  let ly1 = mid(self.y0, self.y1)
  let lx2 = mid(lx1, mx)
  let ly2 = mid(ly1, my)
  let rx2 = mid(self.x2, self.x3)
  let ry2 = mid(self.y2, self.y3)
  let rx1 = mid(rx2, mx)
  let ry1 = mid(ry2, my)
  let cx = mid(lx2, rx1)
  let cy = mid(ly2, ry1)
  let depth = self.depth + 1
  (
    {
      x0: self.x0,
      y0: self.y0,
      x1: lx1,
      y1: ly1,
      x2: lx2,
      y2: ly2,
      x3: cx,
      y3: cy,
      depth,
    },
    {
      x0: cx,
      y0: cy,
      x1: rx1,
      y1: ry1,
      x2: rx2,
      y2: ry2,
      x3: self.x3,
      y3: self.y3,
      depth,
    },
  )
}

///|
/// The length of a cubic as Blink's `PathTraversalState` measures it:
/// split until the control polygon and the chord agree, then sum the
/// control polygons.
fn cubic_length(curve : Cubic) -> Float {
  let squared = (x : Float, y : Float) => {
    x.to_double() * x.to_double() + y.to_double() * y.to_double()
  }
  let scale = (
      squared(curve.x0, curve.y0) +
      squared(curve.x1, curve.y1) +
      squared(curve.x2, curve.y2) +
      squared(curve.x3, curve.y3)
    ) /
    16.0
  let tolerance = 1.0e-16
  if scale < tolerance {
    return 0
  }
  let stack = [curve]
  let mut curve = curve
  let mut total : Float = 0
  while !stack.is_empty() {
    let length = curve.approximate_distance()
    let discrepancy = (length -
    point_distance(curve.x0, curve.y0, curve.x3, curve.y3)).to_double()
    if discrepancy * discrepancy / scale > tolerance && curve.depth < 20 {
      let (left, right) = curve.split()
      curve = left
      stack.push(right)
    } else {
      total = total + length
      guard stack.pop() is Some(next) else { break }
      curve = next
    }
  }
  total
}

///|
/// The total length of path data: `SVGPathElement.getTotalLength()`. Blink
/// walks the segments itself, with quadratic curves raised to cubics.
pub fn path_length(data : String) -> Double {
  let mut total : Float = 0
  let mut x : Float = 0
  let mut y : Float = 0
  let mut start_x : Float = 0
  let mut start_y : Float = 0
  let third : Float = Float::from_int(1) / Float::from_int(3)
  let blend = (a : Float, b : Float) => (a + 2 * b) * third
  for segment in parse_path(data) {
    match segment {
      MoveTo(px, py) => {
        x = px
        y = py
        start_x = px
        start_y = py
      }
      LineTo(px, py) => {
        total = total + point_distance(x, y, px, py)
        x = px
        y = py
      }
      QuadTo(cx, cy, px, py) => {
        total = total +
          cubic_length({
            x0: x,
            y0: y,
            x1: blend(x, cx),
            y1: blend(y, cy),
            x2: blend(px, cx),
            y2: blend(py, cy),
            x3: px,
            y3: py,
            depth: 0,
          })
        x = px
        y = py
      }
      CubicTo(c1x, c1y, c2x, c2y, px, py) => {
        total = total +
          cubic_length({
            x0: x,
            y0: y,
            x1: c1x,
            y1: c1y,
            x2: c2x,
            y2: c2y,
            x3: px,
            y3: py,
            depth: 0,
          })
        x = px
        y = py
      }
      Close => {
        total = total + point_distance(x, y, start_x, start_y)
        x = start_x
        y = start_y
      }
    }
  }
  total.to_double()
}
