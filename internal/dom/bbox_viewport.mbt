///|
/// What a nested `<svg>` does to its content: moves it to the viewport's
/// `x` and `y` and fits the `viewBox` into the viewport's `width` and
/// `height`, centred and keeping proportions (`xMidYMid meet`). The
/// content keeps the box it has, mapped: `getBBox` does not clip it.
fn Element::viewport_transform(self : Element) -> Transform {
  let number = (name : String) => {
    match self.get_attr(name) {
      Some(text) => Some(parse_svg_number(text[:]))
      None => None
    }
  }
  let x = number("x").unwrap_or(0)
  let y = number("y").unwrap_or(0)
  let view_box = svg_numbers(self.get_attr("viewBox").unwrap_or("")[:])
  guard view_box is [min_x, min_y, box_width, box_height] &&
    box_width > 0 &&
    box_height > 0 &&
    number("width") is Some(width) &&
    number("height") is Some(height) else {
    return Axis(sx=1, sy=1, tx=x, ty=y)
  }
  let scale = (width / box_width).min(height / box_height)
  Axis(
    sx=scale,
    sy=scale,
    tx=x + (width - box_width * scale) / 2 - min_x * scale,
    ty=y + (height - box_height * scale) / 2 - min_y * scale,
  )
}
