///|
const EPSILON : Double = 1.0e-6

///|
const PI : Double = 3.141592653589793

///|
const TAU : Double = 6.283185307179586

///|
/// `Math.round`: to the nearest integer, halves towards positive infinity.
pub fn js_round(value : Double) -> Double {
  let floor = value.floor()
  if value - floor >= 0.5 {
    floor + 1.0
  } else {
    floor
  }
}

///|
/// Print a number the way JavaScript's `String(number)` does.
pub fn number(value : Double) -> String {
  if value == 0.0 {
    "0"
  } else {
    value.to_string()
  }
}

///|
/// A port of d3-path's `Path`: SVG path data built from canvas-style
/// drawing calls.
pub struct Path {
  priv out : StringBuilder
  /// Decimal places kept, or `None` to print coordinates in full.
  priv digits : Int32?
  priv mut start : (Double, Double)?
  priv mut current : (Double, Double)?
}

///|
/// A path whose coordinates are rounded to `digits` decimal places. d3's
/// shape generators use three.
pub fn Path::new(digits? : Int32) -> Path {
  { out: StringBuilder(), digits, start: None, current: None, }
}

///|
fn Path::coordinate(self : Path, value : Double) -> String {
  match self.digits {
    Some(digits) if digits <= 15 => {
      let k = @jsmath.pow10(digits)
      number(js_round(value * k) / k)
    }
    _ => number(value)
  }
}

///|
pub fn Path::move_to(self : Path, x : Double, y : Double) -> Unit {
  self.start = Some((x, y))
  self.current = Some((x, y))
  self.out.write_string("M\{self.coordinate(x)},\{self.coordinate(y)}")
}

///|
pub fn Path::line_to(self : Path, x : Double, y : Double) -> Unit {
  self.current = Some((x, y))
  self.out.write_string("L\{self.coordinate(x)},\{self.coordinate(y)}")
}

///|
pub fn Path::close(self : Path) -> Unit {
  if self.current is Some(_) {
    self.current = self.start
    self.out.write_string("Z")
  }
}

///|
/// A circular arc centred on `(x, y)` from angle `a0` to `a1`.
pub fn Path::arc(
  self : Path,
  x : Double,
  y : Double,
  r : Double,
  a0 : Double,
  a1 : Double,
  counterclockwise~ : Bool = false,
) -> Unit {
  let dx = r * @jsmath.cos(a0)
  let dy = r * @jsmath.sin(a0)
  let x0 = x + dx
  let y0 = y + dy
  let cw = if counterclockwise { 0 } else { 1 }
  let mut da = if counterclockwise { a0 - a1 } else { a1 - a0 }
  match self.current {
    None =>
      self.out.write_string("M\{self.coordinate(x0)},\{self.coordinate(y0)}")
    Some((x1, y1)) =>
      if (x1 - x0).abs() > EPSILON || (y1 - y0).abs() > EPSILON {
        self.out.write_string("L\{self.coordinate(x0)},\{self.coordinate(y0)}")
      }
  }
  if r == 0.0 {
    return
  }
  if da < 0.0 {
    da = da % TAU + TAU
  }
  let radius = self.coordinate(r)
  if da > TAU - EPSILON {
    // A full circle is drawn as two half arcs.
    self.current = Some((x0, y0))
    self.out.write_string(
      "A\{radius},\{radius},0,1,\{cw},\{self.coordinate(x - dx)},\{self.coordinate(y - dy)}A\{radius},\{radius},0,1,\{cw},\{self.coordinate(x0)},\{self.coordinate(y0)}",
    )
  } else if da > EPSILON {
    let x1 = x + r * @jsmath.cos(a1)
    let y1 = y + r * @jsmath.sin(a1)
    let large = if da >= PI { 1 } else { 0 }
    self.current = Some((x1, y1))
    self.out.write_string(
      "A\{radius},\{radius},0,\{large},\{cw},\{self.coordinate(x1)},\{self.coordinate(y1)}",
    )
  }
}

///|
pub fn Path::to_string(self : Path) -> String {
  self.out.to_string()
}
