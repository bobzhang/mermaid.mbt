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
fn Bounds::from_edges(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> Bounds {
  { x: left, y: top, width: right - left, height: bottom - top, }
}

///|
/// `RectF::UnionEvenIfEmpty`.
fn Bounds::unite(self : Bounds, other : Bounds) -> Bounds {
  let min = (a : Float, b : Float) => if b < a { b } else { a }
  let max = (a : Float, b : Float) => if a < b { b } else { a }
  Bounds::from_edges(
    min(self.x, other.x),
    min(self.y, other.y),
    max(self.x + self.width, other.x + other.width),
    max(self.y + self.height, other.y + other.height),
  )
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
/// A length attribute such as `12.5` or `120px`, as a float.
fn number_attr(element : Element, name : String) -> Float? {
  guard element.get_attr(name) is Some(text) else { return None }
  let text = text.trim().to_owned()
  let mut end = 0
  for i, c in text {
    if c is ('0'..<='9' | '.' | '-' | '+' | 'e' | 'E') {
      end = i + 1
    } else {
      break
    }
  }
  let value = @string.parse_double(text[:end]) catch { _ => return None }
  Some(Float::from_double(value))
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

///|
/// The translation of a `transform` attribute. Only `translate(x, y)` is
/// understood; that is the one transform the renderers position with.
fn translation(element : Element) -> (Float, Float) {
  guard element.get_attr("transform") is Some(transform) else { return (0, 0) }
  guard transform.find("translate(") is Some(start) else { return (0, 0) }
  let rest = transform[start + 10:]
  guard rest.find(")") is Some(end) else { return (0, 0) }
  match svg_numbers(rest[:end]) {
    [x, y, ..] => (x, y)
    [x] => (x, 0)
    [] => (0, 0)
  }
}

///|
/// The element's box in its own coordinate system, before its transform.
/// Nothing for an element that renders no geometry.
fn Element::local_bounds(self : Element) -> Bounds? {
  let attr = (name : String) => number_attr(self, name).unwrap_or(0)
  match self.tag {
    "rect" | "foreignObject" | "image" => {
      let width = attr("width")
      let height = attr("height")
      if width <= 0 || height <= 0 {
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
    "g" | "svg" | "a" => {
      let mut bounds : Bounds? = None
      for node in self.children {
        guard node is Element(child) else { continue }
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
/// The element's box in its parent's coordinate system: moved by its
/// translation, size unchanged.
fn Element::bounds(self : Element) -> Bounds? {
  guard self.local_bounds() is Some(bounds) else { return None }
  let (dx, dy) = translation(self)
  if dx == 0 && dy == 0 {
    return Some(bounds)
  }
  Some({ ..bounds, x: bounds.x + dx, y: bounds.y + dy, })
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
