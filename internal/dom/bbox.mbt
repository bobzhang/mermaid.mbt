///|
/// A bounding box in user units, as `getBBox()` reports it. The browser
/// computes these in 32-bit floats.
pub(all) struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// A box as Blink's `gfx::RectF` holds it: origin and size in 32-bit
/// floats. The far edges are sums, so they round again whenever they are
/// needed.
priv struct Bounds {
  x : Float
  y : Float
  width : Float
  height : Float
}

///|
/// The next float above a size: `std::nextafter(size, +inf)`. Sizes are
/// never negative.
fn next_size(size : Float) -> Float {
  if size == 0 {
    // The smallest subnormal.
    Float::reinterpret_from_int(1)
  } else {
    Float::reinterpret_from_int(size.reinterpret_as_int() + 1)
  }
}

///|
/// `gfx::BoundingRect` of two corners, which is how a Skia rectangle
/// becomes a `RectF`: when the size loses precision, so that origin plus
/// size is not the far edge again, it grows to the next float.
fn Bounds::from_edges(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> Bounds {
  let mut width = right - left
  let mut height = bottom - top
  if left + width != right {
    width = next_size(width)
  }
  if top + height != bottom {
    height = next_size(height)
  }
  { x: left, y: top, width, height, }
}

///|
/// `RectF::UnionEvenIfEmpty`: the size is the difference of the edges, and
/// grows to the next float when rounding left the far edge outside.
fn Bounds::unite(self : Bounds, other : Bounds) -> Bounds {
  let min = (a : Float, b : Float) => if b < a { b } else { a }
  let max = (a : Float, b : Float) => if a < b { b } else { a }
  let x = min(self.x, other.x)
  let y = min(self.y, other.y)
  let right = max(self.x + self.width, other.x + other.width)
  let bottom = max(self.y + self.height, other.y + other.height)
  let mut width = right - x
  let mut height = bottom - y
  if x + width < right {
    width = next_size(width)
  }
  if y + height < bottom {
    height = next_size(height)
  }
  { x, y, width, height, }
}

///|
/// The box of a set of points, as Skia bounds a path.
priv struct PointBounds {
  mut left : Float
  mut top : Float
  mut right : Float
  mut bottom : Float
  mut empty : Bool
}

///|
fn PointBounds::new() -> PointBounds {
  { left: 0, top: 0, right: 0, bottom: 0, empty: true, }
}

///|
fn PointBounds::add(self : PointBounds, x : Float, y : Float) -> Unit {
  if self.empty {
    self.left = x
    self.right = x
    self.top = y
    self.bottom = y
    self.empty = false
    return
  }
  if x < self.left {
    self.left = x
  }
  if x > self.right {
    self.right = x
  }
  if y < self.top {
    self.top = y
  }
  if y > self.bottom {
    self.bottom = y
  }
}

///|
fn PointBounds::to_bounds(self : PointBounds) -> Bounds? {
  if self.empty {
    None
  } else {
    Some(Bounds::from_edges(self.left, self.top, self.right, self.bottom))
  }
}

///|
/// A length attribute such as `12.5` or `120px`, as a float. These go
/// through Blink's fast path for simple CSS lengths, which reads at most
/// seven decimals; anything else gets the exact value.
fn number_attr(element : Element, name : String) -> Float? {
  guard element.get_attr(name) is Some(text) else { return None }
  let text = text.trim().to_owned()
  let text = match text.strip_suffix("px") {
    Some(number) => number.to_owned()
    None => text
  }
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let n = chars.length()
  let mut i = 0
  let negative = chars[0] == '-'
  if negative {
    i = 1
  }
  let mut whole = 0.0
  let mut simple = i < n
  while i < n && chars[i] is ('0'..<='9') {
    whole = whole * 10.0 + (chars[i].to_int() - '0').to_double()
    i += 1
  }
  let mut fraction = 0.0
  let mut scale = 1.0
  if i < n && chars[i] == '.' {
    i += 1
    while i < n && chars[i] is ('0'..<='9') {
      if scale < 10000000.0 {
        fraction = fraction * 10.0 + (chars[i].to_int() - '0').to_double()
        scale = scale * 10.0
      }
      i += 1
    }
  }
  if i < n {
    simple = false
  }
  let value = if simple {
    whole + fraction / scale
  } else {
    let magnitude = if negative { text[1:].to_owned() } else { text }
    // `NaN` and `Infinity`, as JavaScript prints them, are not numbers
    // here: the attribute is invalid.
    if magnitude.contains("N") || magnitude.contains("n") {
      return None
    }
    @string.parse_double(magnitude) catch {
      _ => return None
    }
  }
  Some(Float::from_double(if negative { -value } else { value }))
}

///|
/// The value of a length attribute such as `x` or `width` as the browser
/// holds it, in single precision; nothing when the attribute is missing
/// or is not a number.
pub fn Element::length_attr(self : Element, name : String) -> Double? {
  number_attr(self, name).map(value => value.to_double())
}

///|
/// Numbers separated by spaces or commas, read with the SVG number parser.
fn svg_numbers(text : StringView) -> Array[Float] {
  let numbers = []
  for part in text.to_owned().replace_all(old=",", new=" ").split(" ") {
    let part = part.trim()
    if !part.is_empty() {
      numbers.push(parse_svg_number(part))
    }
  }
  numbers
}

// An SVG `transform` attribute reaches layout as a CSS transform: Blink
// turns the list into transform operations and applies them one by one to
// a `gfx::Transform`. That class keeps a scale and a translation in
// single precision for as long as nothing else is asked of it, and only a
// rotation makes it a matrix of doubles. So `translate(a, b) rotate(...)`
// adds its translations as floats before the rotation, and the float
// rounding shows in the boxes of rotated labels.

///|
/// A transform as `gfx::Transform` holds it.
priv enum Transform {
  /// `AxisTransform2d`: a scale, then a translation, in floats.
  Axis(sx~ : Float, sy~ : Float, tx~ : Float, ty~ : Float)
  /// The matrix `[a c e; b d f]` in doubles.
  Full(
    a~ : Double,
    b~ : Double,
    c~ : Double,
    d~ : Double,
    e~ : Double,
    f~ : Double
  )
}

///|
/// `Transform::Translate`
fn Transform::translate(self : Transform, x : Float, y : Float) -> Transform {
  match self {
    Axis(sx~, sy~, tx~, ty~) => Axis(sx~, sy~, tx=tx + x * sx, ty=ty + y * sy)
    Full(a~, b~, c~, d~, e~, f~) => {
      let x = x.to_double()
      let y = y.to_double()
      Full(a~, b~, c~, d~, e=a * x + c * y + e, f=b * x + d * y + f)
    }
  }
}

///|
/// `Transform::Scale`
fn Transform::scale(self : Transform, x : Float, y : Float) -> Transform {
  match self {
    Axis(sx~, sy~, tx~, ty~) => Axis(sx=sx * x, sy=sy * y, tx~, ty~)
    Full(a~, b~, c~, d~, e~, f~) => {
      let x = x.to_double()
      let y = y.to_double()
      Full(a=a * x, b=b * x, c=c * y, d=d * y, e~, f~)
    }
  }
}

///|
/// `gfx::SinCosDegrees`: quarter turns are exact, everything else goes
/// through the system's `sin` and `cos`.
fn sin_cos_degrees(degrees : Double) -> (Double, Double) {
  let quarters = degrees / 90.0
  if quarters == quarters.trunc() && quarters.abs() < 2147483648.0 {
    return match (quarters.to_int() % 4 + 4) % 4 {
      0 => (0.0, 1.0)
      1 => (1.0, 0.0)
      2 => (0.0, -1.0)
      _ => (-1.0, 0.0)
    }
  }
  let radians = degrees * 3.141592653589793 / 180.0
  (@jsmath.sin(radians), @jsmath.cos(radians))
}

///|
/// `Transform::RotateAboutZAxis`: the first operation that needs the full
/// matrix.
fn Transform::rotate(self : Transform, degrees : Double) -> Transform {
  let (sin, cos) = sin_cos_degrees(degrees)
  if sin == 0.0 && cos == 1.0 {
    return self
  }
  let (a, b, c, d, e, f) = self.matrix()
  Full(
    a=a * cos + c * sin,
    b=b * cos + d * sin,
    c=c * cos - a * sin,
    d=d * cos - b * sin,
    e~,
    f~,
  )
}

///|
/// The matrix in doubles: `AffineTransform::FromTransform`.
fn Transform::matrix(
  self : Transform,
) -> (Double, Double, Double, Double, Double, Double) {
  match self {
    Axis(sx~, sy~, tx~, ty~) =>
      (sx.to_double(), 0.0, 0.0, sy.to_double(), tx.to_double(), ty.to_double())
    Full(a~, b~, c~, d~, e~, f~) => (a, b, c, d, e, f)
  }
}

///|
/// Apply one function of a transform list. Nothing for a function or an
/// argument count SVG does not define, and for `matrix`, `skewX` and
/// `skewY`, which are not ported.
fn Transform::apply(
  self : Transform,
  name : String,
  arguments : Array[Float],
) -> Transform? {
  match (name, arguments) {
    ("translate", [tx]) => Some(self.translate(tx, 0))
    ("translate", [tx, ty]) => Some(self.translate(tx, ty))
    ("scale", [s]) => Some(self.scale(s, s))
    ("scale", [sx, sy]) => Some(self.scale(sx, sy))
    ("rotate", [angle]) => Some(self.rotate(angle.to_double()))
    // A rotation about a point is three operations.
    ("rotate", [angle, cx, cy]) =>
      Some(self.translate(cx, cy).rotate(angle.to_double()).translate(-cx, -cy))
    ("matrix", [ma, mb, mc, md, me, mf]) => {
      let (a, b, c, d, e, f) = self.matrix()
      let v = Float::to_double
      Some(
        Full(
          a=a * v(ma) + c * v(mb),
          b=b * v(ma) + d * v(mb),
          c=a * v(mc) + c * v(md),
          d=b * v(mc) + d * v(md),
          e=a * v(me) + c * v(mf) + e,
          f=b * v(me) + d * v(mf) + f,
        ),
      )
    }
    _ => None
  }
}

///|
/// The transform of a `transform` attribute: its functions applied in
/// order. A list that does not parse, or that uses a function that is
/// not ported, transforms nothing.
fn element_transform(element : Element) -> Transform {
  let identity = Transform::Axis(sx=1, sy=1, tx=0, ty=0)
  guard element.get_attr("transform") is Some(text) else { return identity }
  let mut transform = identity
  let mut rest = text[:]
  while true {
    rest = rest.trim_start(chars=" \t\n\r,")
    if rest.is_empty() {
      break
    }
    guard rest.find("(") is Some(open) else { return identity }
    guard rest[open:].find(")") is Some(length) else { return identity }
    let name = rest[:open].trim(chars=" \t\n\r").to_owned()
    let arguments = []
    for
      part in rest[open + 1:open + length]
      .to_owned()
      .replace_all(old=",", new=" ")
      .split(" ") {
      let part = part.trim(chars=" \t\n\r")
      if !part.is_empty() {
        arguments.push(parse_svg_number(part))
      }
    }
    guard transform.apply(name, arguments) is Some(next) else {
      return identity
    }
    transform = next
    rest = rest[open + length + 1:]
  }
  transform
}

///|
/// `AffineTransform::MapRect`: a translation moves the box; anything else
/// maps its four corners in doubles, rounds each to a float, and bounds
/// them.
fn Transform::map(self : Transform, bounds : Bounds) -> Bounds {
  let to_float = Float::from_double
  let (a, b, c, d, e, f) = self.matrix()
  if a == 1.0 && b == 0.0 && c == 0.0 && d == 1.0 {
    if e == 0.0 && f == 0.0 {
      return bounds
    }
    return {
      ..bounds,
      x: to_float(bounds.x.to_double() + e),
      y: to_float(bounds.y.to_double() + f),
    }
  }
  let left = bounds.x.to_double()
  let top = bounds.y.to_double()
  let right = (bounds.x + bounds.width).to_double()
  let bottom = (bounds.y + bounds.height).to_double()
  let corners = PointBounds::new()
  for corner in [(left, top), (right, top), (right, bottom), (left, bottom)] {
    let (x, y) = corner
    corners.add(to_float(a * x + c * y + e), to_float(b * x + d * y + f))
  }
  // `QuadF::BoundingBox`: the size is the plain difference of the edges.
  {
    x: corners.left,
    y: corners.top,
    width: corners.right - corners.left,
    height: corners.bottom - corners.top,
  }
}

///|
/// The length in pixels an inline style declares for a property; nothing
/// when there is no such declaration or it is not in pixels.
fn pixel_declaration(element : Element, name : String) -> Float? {
  for declaration in element.declarations {
    if declaration.0 == name && declaration.1.strip_suffix("px") is Some(number) {
      let value = @string.parse_double(number.trim().to_owned()) catch {
        _ => return None
      }
      return Some(Float::from_double(value))
    }
  }
  None
}

///|
/// `gfx::SizeF::kTrivial`: `8 * std::numeric_limits<float>::epsilon()`.
const TRIVIAL_SIZE : Float = 9.5367431640625e-7

///|
/// The element's box in its own coordinate system, before its transform.
/// Nothing for an element that renders no geometry.
fn Element::local_bounds(self : Element) -> Bounds? {
  let attr = (name : String) => number_attr(self, name).unwrap_or(0)
  match self.tag {
    "rect" | "foreignObject" | "image" => {
      // The size is a CSS property too, and a declaration wins over the
      // attribute.
      let width = pixel_declaration(self, "width").unwrap_or(attr("width"))
      let height = pixel_declaration(self, "height").unwrap_or(attr("height"))
      if width <= 0 || height <= 0 {
        return None
      }
      // The box of a `<rect>` is a `gfx::RectF`, whose `SizeF` takes
      // anything up to eight float epsilons for nothing.
      if self.tag == "rect" && (width <= TRIVIAL_SIZE || height <= TRIVIAL_SIZE) {
        return None
      }
      Some({ x: attr("x"), y: attr("y"), width, height, })
    }
    "circle" => {
      let r = attr("r")
      if r <= 0 {
        return None
      }
      Some({
        x: attr("cx") - r,
        y: attr("cy") - r,
        width: r * 2,
        height: r * 2,
      })
    }
    "ellipse" => {
      let rx = attr("rx")
      let ry = attr("ry")
      if rx <= 0 || ry <= 0 {
        return None
      }
      Some({
        x: attr("cx") - rx,
        y: attr("cy") - ry,
        width: rx * 2,
        height: ry * 2,
      })
    }
    "polygon" | "polyline" => {
      let numbers = svg_numbers(self.get_attr("points").unwrap_or(""))
      let bounds = PointBounds::new()
      for i = 0; i + 1 < numbers.length(); i = i + 2 {
        bounds.add(numbers[i], numbers[i + 1])
      }
      bounds.to_bounds()
    }
    "path" => path_bounds(self.get_attr("d").unwrap_or(""))
    "line" => {
      // A line is the path between its ends, however thin its box.
      let bounds = PointBounds::new()
      bounds.add(attr("x1"), attr("y1"))
      bounds.add(attr("x2"), attr("y2"))
      bounds.to_bounds()
    }
    "g" | "svg" | "a" => {
      let mut bounds : Bounds? = None
      for node in self.children {
        guard node is Element(child) else { continue }
        // A link directly inside a link is not rendered.
        if self.tag == "a" && child.tag == "a" {
          continue
        }
        guard child.bounds() is Some(child_bounds) else { continue }
        bounds = match bounds {
          Some(bounds) => Some(bounds.unite(child_bounds))
          None => Some(child_bounds)
        }
      }
      bounds
    }
    "text" =>
      match self.text_box {
        Some(box) => {
          let f = Float::from_double
          Some({
            x: f(box.x),
            y: f(box.y),
            width: f(box.width),
            height: f(box.height),
          })
        }
        None => None
      }
    // `defs`, `marker`, `style`, `title` and `desc` are not rendered
    // geometry.
    _ => None
  }
}

///|
/// Whether the element's inline style hides it: with `display: none` it
/// has no box at all, and its parent's box ignores it.
fn Element::is_display_none(self : Element) -> Bool {
  for declaration in self.declarations {
    if declaration.0 == "display" {
      return declaration.1 == "none"
    }
  }
  guard self.get_attr("style") is Some(text) else { return false }
  let mut hidden = false
  for part in text.split(";") {
    guard part.find(":") is Some(colon) else { continue }
    if part[:colon].trim().to_owned().to_lower() == "display" {
      let value = part[colon + 1:].trim().to_owned().to_lower()
      let value = match value.strip_suffix("!important") {
        Some(base) => base.trim().to_owned()
        None => value
      }
      hidden = value == "none"
    }
  }
  hidden
}

///|
/// The element's box in its parent's coordinate system: its own box
/// mapped through its `transform`.
fn Element::bounds(self : Element) -> Bounds? {
  if self.is_display_none() {
    return None
  }
  guard self.local_bounds() is Some(bounds) else { return None }
  Some(element_transform(self).map(bounds))
}

///|
/// `getBBox()`: the union of the element's rendered geometry in its own
/// coordinate system. An element with nothing to render has an empty box
/// at the origin.
pub fn Element::bbox(self : Element) -> Rect {
  match self.local_bounds() {
    Some(bounds) =>
      {
        x: bounds.x.to_double(),
        y: bounds.y.to_double(),
        width: bounds.width.to_double(),
        height: bounds.height.to_double(),
      }
    None => { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }
  }
}
