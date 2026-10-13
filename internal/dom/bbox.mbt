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
/// An axis-aligned box by its edges, in 32-bit floats.
priv struct Bounds {
  mut left : Float
  mut top : Float
  mut right : Float
  mut bottom : Float
}

///|
fn Bounds::unite(self : Bounds, other : Bounds) -> Unit {
  if other.left < self.left {
    self.left = other.left
  }
  if other.top < self.top {
    self.top = other.top
  }
  if other.right > self.right {
    self.right = other.right
  }
  if other.bottom > self.bottom {
    self.bottom = other.bottom
  }
}

///|
/// A leading number of an attribute such as `12.5` or `120px`.
fn number_attr(element : Element, name : String) -> Double? {
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
  Some(value)
}

///|
/// The translation of a `transform` attribute. Only `translate(x, y)` is
/// understood; that is the one transform the renderers position with.
fn translation(element : Element) -> (Double, Double) {
  guard element.get_attr("transform") is Some(transform) else {
    return (0.0, 0.0)
  }
  guard transform.find("translate(") is Some(start) else { return (0.0, 0.0) }
  let rest = transform[start + 10:]
  guard rest.find(")") is Some(end) else { return (0.0, 0.0) }
  let parts = []
  for part in rest[:end].to_owned().replace_all(old=",", new=" ").split(" ") {
    if !part.is_empty() {
      parts.push(@string.parse_double(part) catch { _ => 0.0 })
    }
  }
  match parts {
    [x, y, ..] => (x, y)
    [x] => (x, 0.0)
    [] => (0.0, 0.0)
  }
}

///|
/// The element's box in its own coordinate system, before its transform.
fn Element::local_bounds(self : Element) -> Bounds? {
  let f = Float::from_double
  match self.tag {
    "rect" | "foreignObject" | "image" => {
      let width = number_attr(self, "width").unwrap_or(0.0)
      let height = number_attr(self, "height").unwrap_or(0.0)
      // A shape without area is not rendered and adds nothing.
      if self.tag == "rect" && (width <= 0.0 || height <= 0.0) {
        return None
      }
      let x = f(number_attr(self, "x").unwrap_or(0.0))
      let y = f(number_attr(self, "y").unwrap_or(0.0))
      Some({ left: x, top: y, right: x + f(width), bottom: y + f(height), })
    }
    "circle" => {
      let r = f(number_attr(self, "r").unwrap_or(0.0))
      if r <= 0.0 {
        return None
      }
      let cx = f(number_attr(self, "cx").unwrap_or(0.0))
      let cy = f(number_attr(self, "cy").unwrap_or(0.0))
      Some({ left: cx - r, top: cy - r, right: cx + r, bottom: cy + r, })
    }
    "ellipse" => {
      let rx = f(number_attr(self, "rx").unwrap_or(0.0))
      let ry = f(number_attr(self, "ry").unwrap_or(0.0))
      if rx <= 0.0 || ry <= 0.0 {
        return None
      }
      let cx = f(number_attr(self, "cx").unwrap_or(0.0))
      let cy = f(number_attr(self, "cy").unwrap_or(0.0))
      Some({ left: cx - rx, top: cy - ry, right: cx + rx, bottom: cy + ry, })
    }
    "polygon" | "polyline" => {
      let points = self.get_attr("points").unwrap_or("")
      let numbers = []
      for part in points.replace_all(old=",", new=" ").split(" ") {
        if !part.is_empty() {
          numbers.push(@string.parse_double(part) catch { _ => 0.0 })
        }
      }
      let mut bounds : Bounds? = None
      for i = 0; i + 1 < numbers.length(); i = i + 2 {
        let point = {
          left: f(numbers[i]),
          top: f(numbers[i + 1]),
          right: f(numbers[i]),
          bottom: f(numbers[i + 1]),
        }
        match bounds {
          Some(bounds) => bounds.unite(point)
          None => bounds = Some(point)
        }
      }
      bounds
    }
    "path" => path_bounds(self.get_attr("d").unwrap_or(""))
    "g" | "svg" | "a" => {
      let mut bounds : Bounds? = None
      for node in self.children {
        guard node is Element(child) else { continue }
        guard child.bounds() is Some(child_bounds) else { continue }
        match bounds {
          Some(bounds) => bounds.unite(child_bounds)
          None => bounds = Some(child_bounds)
        }
      }
      bounds
    }
    // `defs`, `marker`, `style`, `title`, `desc` and text are not part of
    // the geometry measured here.
    _ => None
  }
}

///|
/// The element's box in its parent's coordinate system.
fn Element::bounds(self : Element) -> Bounds? {
  guard self.local_bounds() is Some(bounds) else { return None }
  let (dx, dy) = translation(self)
  if dx == 0.0 && dy == 0.0 {
    return Some(bounds)
  }
  let shift = (value : Float, delta : Double) => {
    Float::from_double(value.to_double() + delta)
  }
  Some({
    left: shift(bounds.left, dx),
    top: shift(bounds.top, dy),
    right: shift(bounds.right, dx),
    bottom: shift(bounds.bottom, dy),
  })
}

///|
/// `getBBox()`: the union of the element's rendered geometry in its own
/// coordinate system. An element with nothing to render has an empty box
/// at the origin.
pub fn Element::bbox(self : Element) -> Rect {
  match self.local_bounds() {
    Some(bounds) =>
      {
        x: bounds.left.to_double(),
        y: bounds.top.to_double(),
        width: (bounds.right - bounds.left).to_double(),
        height: (bounds.bottom - bounds.top).to_double(),
      }
    None => { x: 0.0, y: 0.0, width: 0.0, height: 0.0, }
  }
}
