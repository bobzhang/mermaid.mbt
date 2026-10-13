// SVG path data as the browser sees it: parsed into single-precision
// segments the way Blink does, then measured the way Skia does.

///|
/// One absolute segment of a path.
priv enum PathSegment {
  MoveTo(Float, Float)
  LineTo(Float, Float)
  QuadTo(Float, Float, Float, Float)
  CubicTo(Float, Float, Float, Float, Float, Float)
  /// Radii, x-axis rotation in degrees, large-arc flag, sweep flag, end.
  ArcTo(Float, Float, Float, Bool, Bool, Float, Float)
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
/// Parse path data into absolute segments.
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
          segments.push(
            ArcTo(
              args[i],
              args[i + 1],
              args[i + 2],
              args[i + 3] != 0,
              args[i + 4] != 0,
              x,
              y,
            ),
          )
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
fn path_bounds(data : String) -> Bounds? {
  let bounds = PointBounds::new()
  let mut x : Float = 0
  let mut y : Float = 0
  for segment in parse_path(data) {
    match segment {
      MoveTo(px, py) | LineTo(px, py) => {
        bounds.add(px, py)
        x = px
        y = py
      }
      QuadTo(cx, cy, px, py) => {
        // The curve is (A t + B) t + C.
        let ax = px - (cx + cx) + x
        let ay = py - (cy + cy) + y
        let bx = cx - x + (cx - x)
        let by = cy - y + (cy - y)
        let sx = x
        let sy = y
        let eval = (t : Float) => {
          bounds.add((ax * t + bx) * t + sx, (ay * t + by) * t + sy)
        }
        if valid_unit_divide(x - cx, x - cx - cx + px) is Some(t) {
          eval(t)
        }
        if valid_unit_divide(y - cy, y - cy - cy + py) is Some(t) {
          eval(t)
        }
        bounds.add(px, py)
        x = px
        y = py
      }
      CubicTo(c1x, c1y, c2x, c2y, px, py) => {
        cubic_extrema(x, y, c1x, c1y, c2x, c2y, px, py, bounds)
        x = px
        y = py
      }
      ArcTo(rx, ry, angle, large, sweep, px, py) => {
        let mut sx = x
        let mut sy = y
        for conic in arc_to_conics(x, y, rx, ry, angle, large, sweep, px, py) {
          conic_extrema(sx, sy, conic, bounds)
          sx = conic.x2
          sy = conic.y2
        }
        bounds.add(px, py)
        x = px
        y = py
      }
      Close => ()
    }
  }
  bounds.to_bounds()
}

///|
/// Skia's `SkFindUnitQuadRoots`: the roots of `A t^2 + B t + C` strictly
/// inside the unit interval.
fn unit_quad_roots(a : Float, b : Float, c : Float) -> Array[Float] {
  let roots = []
  if a == 0 {
    if valid_unit_divide(-c, b) is Some(root) {
      roots.push(root)
    }
    return roots
  }
  // In doubles, so that the discriminant cannot overflow.
  let discriminant = b.to_double() * b.to_double() -
    4.0 * a.to_double() * c.to_double()
  if discriminant < 0.0 {
    return roots
  }
  let r = Float::from_double(discriminant.sqrt())
  if r.is_nan() || r.is_inf() {
    return roots
  }
  let q = if b < 0 { -(b - r) / 2 } else { -(b + r) / 2 }
  if valid_unit_divide(q, a) is Some(root) {
    roots.push(root)
  }
  if valid_unit_divide(c, q) is Some(root) {
    roots.push(root)
  }
  roots
}

///|
/// Add the points where a cubic turns, and its end, to the bounds: Skia's
/// `compute_cubic_extremas`, with `SkFindCubicExtrema` for the parameters
/// and `SkCubicCoeff` for the points.
fn cubic_extrema(
  x0 : Float,
  y0 : Float,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
  x3 : Float,
  y3 : Float,
  bounds : PointBounds,
) -> Unit {
  // The derivative over 3 is A t^2 + B t + C.
  let two : Float = 2
  let three : Float = 3
  let turns = (a : Float, b : Float, c : Float, d : Float) => {
    unit_quad_roots(d - a + three * (b - c), two * (a - b - b + c), b - a)
  }
  let coordinate = (a : Float, b : Float, c : Float, d : Float, t : Float) => {
    let ca = d + three * (b - c) - a
    let cb = three * (c - (b + b) + a)
    let cc = three * (b - a)
    ((ca * t + cb) * t + cc) * t + a
  }
  for t in [..turns(x0, x1, x2, x3), ..turns(y0, y1, y2, y3)] {
    bounds.add(coordinate(x0, x1, x2, x3, t), coordinate(y0, y1, y2, y3, t))
  }
  bounds.add(x3, y3)
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
  // Where the path data puts the pen, which an arc's rounding can leave
  // a hair away from where the walk is.
  let mut pen_x : Float = 0
  let mut pen_y : Float = 0
  let third : Float = Float::from_int(1) / Float::from_int(3)
  let blend = (a : Float, b : Float) => (a + 2 * b) * third
  for segment in parse_path(data) {
    let (next_x, next_y) = match segment {
      MoveTo(px, py)
      | LineTo(px, py)
      | QuadTo(_, _, px, py)
      | CubicTo(_, _, _, _, px, py)
      | ArcTo(_, _, _, _, _, px, py) => (px, py)
      Close => (start_x, start_y)
    }
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
      ArcTo(rx, ry, angle, large, sweep, px, py) => {
        // The arc is placed from where the path says the pen is; its first
        // curve starts where the walk actually arrived.
        let cubics = arc_to_cubics(
          pen_x, pen_y, rx, ry, angle, large, sweep, px, py,
        )
        if cubics.is_empty() {
          // Degenerate arcs are straight lines.
          total = total + point_distance(x, y, px, py)
          x = px
          y = py
        }
        for i, cubic in cubics {
          let cubic = if i == 0 { { ..cubic, x0: x, y0: y, } } else { cubic }
          total = total + cubic_length(cubic)
          x = cubic.x3
          y = cubic.y3
        }
      }
      Close => {
        total = total + point_distance(x, y, start_x, start_y)
        x = start_x
        y = start_y
      }
    }
    pen_x = next_x
    pen_y = next_y
  }
  total.to_double()
}

///|
/// An elliptical arc in the unit-circle space Blink decomposes it in:
/// centre, radii, start angle and signed sweep.
priv struct ArcGeometry {
  cx : Float
  cy : Float
  rx : Float
  ry : Float
  theta1 : Float
  theta_arc : Float
}

///|
/// Single-precision library functions, taken as correctly rounded.
fn sin_f(x : Float) -> Float {
  Float::from_double(@jsmath.sin(x.to_double()))
}

///|
fn cos_f(x : Float) -> Float {
  Float::from_double(@jsmath.cos(x.to_double()))
}

///|
fn tan_f(x : Float) -> Float {
  let x = x.to_double()
  Float::from_double(@jsmath.sin(x) / @jsmath.cos(x))
}

///|
fn atan2_f(y : Float, x : Float) -> Float {
  Float::from_double(@jsmath.atan2(y.to_double(), x.to_double()))
}

///|
/// The conversion of an SVG arc from end points to a centre, as Blink's
/// `SVGPathNormalizer::DecomposeArcToCubic` does it. Nothing for an arc
/// that degenerates to a line.
fn arc_geometry(
  x0 : Float,
  y0 : Float,
  rx : Float,
  ry : Float,
  angle : Float,
  large : Bool,
  sweep : Bool,
  x1 : Float,
  y1 : Float,
) -> ArcGeometry? {
  let mut rx = rx.abs()
  let mut ry = ry.abs()
  if rx == 0 || ry == 0 {
    return None
  }
  if x0 == x1 && y0 == y1 {
    return None
  }
  let half : Float = 0.5
  let mid_x = (x0 - x1) * half
  let mid_y = (y0 - y1) * half
  // The transforms are held in doubles and applied to float points.
  let radians = angle.to_double() * (3.141592653589793 / 180.0)
  let sin_angle = @jsmath.sin(-radians)
  let cos_angle = @jsmath.cos(-radians)
  let rotate = (x : Float, y : Float) => {
    (
      Float::from_double(cos_angle * x.to_double() - sin_angle * y.to_double()),
      Float::from_double(sin_angle * x.to_double() + cos_angle * y.to_double()),
    )
  }
  let (tx, ty) = rotate(mid_x, mid_y)
  let radii_scale = tx * tx / (rx * rx) + ty * ty / (ry * ry)
  if radii_scale > 1 {
    rx = rx * radii_scale.sqrt()
    ry = ry * radii_scale.sqrt()
  }
  let one : Float = 1
  let sx = (one / rx).to_double()
  let sy = (one / ry).to_double()
  // Scale(1/rx, 1/ry) then Rotate(-angle).
  let map = (x : Float, y : Float) => {
    (
      Float::from_double(
        sx * cos_angle * x.to_double() + sy * -sin_angle * y.to_double(),
      ),
      Float::from_double(
        sx * sin_angle * x.to_double() + sy * cos_angle * y.to_double(),
      ),
    )
  }
  let (p1x, p1y) = map(x0, y0)
  let (p2x, p2y) = map(x1, y1)
  let delta_x = p2x - p1x
  let delta_y = p2y - p1y
  let d = delta_x * delta_x + delta_y * delta_y
  let quarter : Float = 0.25
  let squared = one / d - quarter
  let squared : Float = if squared > 0 { squared } else { 0 }
  let mut scale = squared.sqrt()
  if sweep == large {
    scale = -scale
  }
  let delta_x = delta_x * scale
  let delta_y = delta_y * scale
  let cx = (p1x + p2x) * half + -delta_y
  let cy = (p1y + p2y) * half + delta_x
  let theta1 = atan2_f(p1y - cy, p1x - cx)
  let theta2 = atan2_f(p2y - cy, p2x - cx)
  let two_pi = Float::from_double(6.283185307179586)
  let mut theta_arc = theta2 - theta1
  if theta_arc < 0 && sweep {
    theta_arc = theta_arc + two_pi
  } else if theta_arc > 0 && !sweep {
    theta_arc = theta_arc - two_pi
  }
  Some({ cx, cy, rx, ry, theta1, theta_arc, })
}

///|
/// The cubic curves Blink replaces an arc with when it walks a path.
fn arc_to_cubics(
  x0 : Float,
  y0 : Float,
  rx : Float,
  ry : Float,
  angle : Float,
  large : Bool,
  sweep : Bool,
  x1 : Float,
  y1 : Float,
) -> Array[Cubic] {
  guard arc_geometry(x0, y0, rx, ry, angle, large, sweep, x1, y1) is Some(arc) else {
    return []
  }
  let radians = angle.to_double() * (3.141592653589793 / 180.0)
  let sin_angle = @jsmath.sin(radians)
  let cos_angle = @jsmath.cos(radians)
  let rx = arc.rx.to_double()
  let ry = arc.ry.to_double()
  // Rotate(angle) then Scale(rx, ry).
  let map = (x : Float, y : Float) => {
    (
      Float::from_double(
        cos_angle * rx * x.to_double() + -sin_angle * ry * y.to_double(),
      ),
      Float::from_double(
        sin_angle * rx * x.to_double() + cos_angle * ry * y.to_double(),
      ),
    )
  }
  let half_pi = Float::from_double(1.5707963267948966)
  let step : Float = half_pi + Float::from_double(0.001)
  let segments = (arc.theta_arc / step).abs().ceil().to_int()
  let cubics = []
  let count = Float::from_int(segments)
  let factor : Float = Float::from_int(8) / Float::from_int(6)
  let quarter : Float = 0.25
  let mut start_x = x0
  let mut start_y = y0
  for i in 0..<segments {
    let start_theta = arc.theta1 + Float::from_int(i) * arc.theta_arc / count
    let end_theta = arc.theta1 + Float::from_int(i + 1) * arc.theta_arc / count
    let t = factor * tan_f(quarter * (end_theta - start_theta))
    if t.is_nan() || t.is_inf() {
      return []
    }
    let sin_start = sin_f(start_theta)
    let cos_start = cos_f(start_theta)
    let sin_end = sin_f(end_theta)
    let cos_end = cos_f(end_theta)
    let p1x = cos_start - t * sin_start + arc.cx
    let p1y = sin_start + t * cos_start + arc.cy
    let tx = cos_end + arc.cx
    let ty = sin_end + arc.cy
    let p2x = tx + t * sin_end
    let p2y = ty + -t * cos_end
    let (c1x, c1y) = map(p1x, p1y)
    let (c2x, c2y) = map(p2x, p2y)
    let (ex, ey) = map(tx, ty)
    cubics.push({
      x0: start_x,
      y0: start_y,
      x1: c1x,
      y1: c1y,
      x2: c2x,
      y2: c2y,
      x3: ex,
      y3: ey,
      depth: 0,
    })
    start_x = ex
    start_y = ey
  }
  cubics
}

///|
/// A rational quadratic segment: control point, end point and weight.
priv struct Conic {
  x1 : Float
  y1 : Float
  x2 : Float
  y2 : Float
  w : Float
}

///|
/// `SkScalarSinSnapToZero` and its cosine twin.
fn snap_to_zero(value : Float) -> Float {
  let tolerance : Float = Float::from_int(1) / Float::from_int(65536)
  if value.abs() <= tolerance {
    0
  } else {
    value
  }
}

///|
/// The conics Skia builds for an SVG arc (`SkPath::arcTo`), which is the
/// geometry `getBBox` sees. Nothing for an arc that degenerates to a line.
///
/// Skia takes its trigonometry from the C library, and what comes out
/// depends on it to the last bit: these are the functions of macOS, where
/// a sine and a cosine of the same angle are one call.
fn arc_to_conics(
  x0 : Float,
  y0 : Float,
  rx : Float,
  ry : Float,
  angle : Float,
  large : Bool,
  sweep : Bool,
  x : Float,
  y : Float,
) -> Array[Conic] {
  if rx == 0 || ry == 0 || (x0 == x && y0 == y) {
    return []
  }
  let mut rx = rx.abs()
  let mut ry = ry.abs()
  let half : Float = 0.5
  let one : Float = 1
  let pi = Float::from_double(3.141592653589793)
  // The rotation by -angle that comes first has the same cosine and the
  // opposite sine, exactly.
  let (sin_a, cos_a) = @libm.sincosf(angle * (pi / 180))
  let sin_a = snap_to_zero(sin_a)
  let cos_a = snap_to_zero(cos_a)
  // Skia holds every transform as a matrix and maps a point as
  // `x * scale_x + y * skew_x`, so a rotation combined with the radii
  // multiplies the two first and rounds differently from rotating and
  // scaling in turn. Without rotation the matrix is a plain scale.
  let rotated = !(sin_a == 0 && cos_a == 1)
  // Rotation by -angle.
  let unrotate = (px : Float, py : Float) => {
    if rotated {
      (px * cos_a + py * sin_a, py * cos_a + px * -sin_a)
    } else {
      (px, py)
    }
  }
  let (mid_x, mid_y) = unrotate((x0 - x) * half, (y0 - y) * half)
  let radii_scale = mid_x * mid_x / (rx * rx) + mid_y * mid_y / (ry * ry)
  if radii_scale > 1 {
    let scale = radii_scale.sqrt()
    rx = rx * scale
    ry = ry * scale
  }
  let inv_rx = one / rx
  let inv_ry = one / ry
  // `setScale(1 / rx, 1 / ry)` then `preRotate(-angle)`.
  let to_unit = (px : Float, py : Float) => {
    if rotated {
      (
        px * (inv_rx * cos_a) + py * (inv_rx * sin_a),
        py * (inv_ry * cos_a) + px * (inv_ry * -sin_a),
      )
    } else {
      (px * inv_rx, py * inv_ry)
    }
  }
  let (u0x, u0y) = to_unit(x0, y0)
  let (u1x, u1y) = to_unit(x, y)
  let delta_x = u1x - u0x
  let delta_y = u1y - u0y
  let d = delta_x * delta_x + delta_y * delta_y
  let quarter : Float = 0.25
  let squared = one / d - quarter
  let squared : Float = if squared > 0 { squared } else { 0 }
  let mut scale = squared.sqrt()
  // Skia's direction is clockwise for a set sweep flag.
  if !sweep != large {
    scale = -scale
  }
  let delta_x = delta_x * scale
  let delta_y = delta_y * scale
  let cx = (u0x + u1x) * half + -delta_y
  let cy = (u0y + u1y) * half + delta_x
  let theta1 = @libm.atan2f(u0y - cy, u0x - cx)
  let theta2 = @libm.atan2f(u1y - cy, u1x - cx)
  let mut theta_arc = theta2 - theta1
  if theta_arc < 0 && sweep {
    theta_arc = theta_arc + pi * 2
  } else if theta_arc > 0 && !sweep {
    theta_arc = theta_arc - pi * 2
  }
  if theta_arc.abs() < pi / Float::from_int(1000000) {
    return []
  }
  let segments = (theta_arc / (2 * pi / 3)).abs().ceil().to_int()
  let theta_width = theta_arc / Float::from_int(segments)
  let t = @libm.tanf(half * theta_width)
  if t.is_nan() || t.is_inf() {
    return []
  }
  let w = (half + @libm.cosf(theta_width) * half).sqrt()
  let is_integer = (value : Float) => value == value.floor()
  let nearly_zero = (value : Float) => {
    value.abs() <= Float::from_int(1) / Float::from_int(4096)
  }
  let expect_integers = nearly_zero(pi / 2 - theta_width.abs()) &&
    is_integer(rx) &&
    is_integer(ry) &&
    is_integer(x) &&
    is_integer(y)
  // `setRotate(angle)` then `preScale(rx, ry)`.
  let from_unit = (px : Float, py : Float) => {
    let (mx, my) = if rotated {
      (
        px * (cos_a * rx) + py * (-sin_a * ry),
        py * (cos_a * ry) + px * (sin_a * rx),
      )
    } else {
      (px * rx, py * ry)
    }
    if expect_integers {
      ((mx + half).floor(), (my + half).floor())
    } else {
      (mx, my)
    }
  }
  let conics = []
  let mut start_theta = theta1
  for i in 0..<segments {
    let end_theta = start_theta + theta_width
    let (sin_end, cos_end) = @libm.sincosf(end_theta)
    let sin_end = snap_to_zero(sin_end)
    let cos_end = snap_to_zero(cos_end)
    let end_x = cos_end + cx
    let end_y = sin_end + cy
    let ctrl_x = end_x + t * sin_end
    let ctrl_y = end_y + -t * cos_end
    let (x1, y1) = from_unit(ctrl_x, ctrl_y)
    let (x2, y2) = from_unit(end_x, end_y)
    // The arc ends exactly where it was asked to.
    let (x2, y2) = if i == segments - 1 { (x, y) } else { (x2, y2) }
    conics.push({ x1, y1, x2, y2, w, })
    start_theta = end_theta
  }
  conics
}

///|
/// Skia's `SkFindUnitQuadRoots` for the single root a conic's derivative
/// has in the unit interval.
fn unit_quad_root(a : Float, b : Float, c : Float) -> Float? {
  if a == 0 {
    return valid_unit_divide(-c, b)
  }
  let discriminant = b.to_double() * b.to_double() -
    4.0 * a.to_double() * c.to_double()
  if discriminant < 0.0 {
    return None
  }
  let r = Float::from_double(discriminant.sqrt())
  if r.is_nan() || r.is_inf() {
    return None
  }
  let q = if b < 0 { -(b - r) / 2 } else { -(b + r) / 2 }
  match valid_unit_divide(q, a) {
    Some(root) => Some(root)
    None => valid_unit_divide(c, q)
  }
}

///|
/// Add the points where a conic turns, and its end, to the bounds:
/// Skia's `compute_conic_extremas`.
fn conic_extrema(
  x0 : Float,
  y0 : Float,
  conic : Conic,
  bounds : PointBounds,
) -> Unit {
  let w = conic.w
  let root = (p0 : Float, p1 : Float, p2 : Float) => {
    let p20 = p2 - p0
    let p10 = p1 - p0
    let wp10 = w * p10
    unit_quad_root(w * p20 - p20, p20 - 2 * wp10, wp10)
  }
  let eval = (t : Float) => {
    let coordinate = (p0 : Float, p1 : Float, p2 : Float) => {
      let p1w = p1 * w
      let numer_a = p2 - (p1w + p1w) + p0
      let numer_b = p1w - p0 + (p1w - p0)
      let one : Float = 1
      let denom_b = w - one + (w - one)
      let zero : Float = 0
      let denom_a = zero - denom_b
      ((numer_a * t + numer_b) * t + p0) / ((denom_a * t + denom_b) * t + one)
    }
    bounds.add(
      coordinate(x0, conic.x1, conic.x2),
      coordinate(y0, conic.y1, conic.y2),
    )
  }
  if root(x0, conic.x1, conic.x2) is Some(t) {
    eval(t)
  }
  if root(y0, conic.y1, conic.y2) is Some(t) {
    eval(t)
  }
  bounds.add(conic.x2, conic.y2)
}
