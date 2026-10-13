// JavaScript value semantics for the generated theme code. Theme variables
// are dynamically typed upstream, so they are modelled as `Json`, with
// `Json::null()` standing in for `undefined`.

///|
fn str(value : String) -> Json {
  Json::string(value)
}

///|
fn num(value : Double) -> Json {
  Json::number(value)
}

///|
fn boolean(value : Bool) -> Json {
  Json::boolean(value)
}

///|
/// JavaScript truthiness.
fn truthy(value : Json) -> Bool {
  match value {
    Null | False => false
    True => true
    Number(n, ..) => n != 0.0 && n == n
    String(s) => s != ""
    Array(_) | Object(_) => true
  }
}

///|
/// `left || right()`.
fn or_else(
  left : Json,
  right : () -> Json raise @color.ColorError,
) -> Json raise @color.ColorError {
  if truthy(left) {
    left
  } else {
    right()
  }
}

///|
/// `left ?? right()`.
fn nullish(
  left : Json,
  right : () -> Json raise @color.ColorError,
) -> Json raise @color.ColorError {
  if left is Null {
    right()
  } else {
    left
  }
}

///|
/// `left && right()`.
fn and_then(
  left : Json,
  right : () -> Json raise @color.ColorError,
) -> Json raise @color.ColorError {
  if truthy(left) {
    right()
  } else {
    left
  }
}

///|
/// Number-to-string conversion as JavaScript performs it.
fn number_to_string(value : Double) -> String {
  if value == 0.0 {
    "0"
  } else {
    value.to_string()
  }
}

///|
/// `String(value)`, as used for computed property names and concatenation.
fn to_string(value : Json) -> String {
  match value {
    String(s) => s
    Number(n, ..) => number_to_string(n)
    True => "true"
    False => "false"
    Null => "undefined"
    Array(items) => items.map(to_string).join(",")
    Object(_) => "[object Object]"
  }
}

///|
fn to_number(value : Json) -> Double {
  match value {
    Number(n, ..) => n
    True => 1.0
    False => 0.0
    _ => 0.0 / 0.0
  }
}

///|
fn to_int(value : Json) -> Int32 {
  to_number(value).to_int()
}

///|
fn to_array(value : Json) -> Array[Json] {
  match value {
    Array(items) => items
    _ => []
  }
}

///|
/// `left + right`: concatenation when either side is a string.
fn add(left : Json, right : Json) -> Json {
  match (left, right) {
    (String(_), _) | (_, String(_)) => str(to_string(left) + to_string(right))
    _ => num(to_number(left) + to_number(right))
  }
}

///|
fn mul(left : Json, right : Json) -> Json {
  num(to_number(left) * to_number(right))
}

///|
fn rem(left : Json, right : Json) -> Json {
  num(to_number(left) % to_number(right))
}

///|
fn neg(value : Json) -> Json {
  num(-to_number(value))
}

///|
/// `object?.name`.
fn field(object : Json, name : String) -> Json {
  match object {
    Object(fields) => fields.get(name).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
/// `array[index]`.
fn index(array : Json, index : Json) -> Json {
  match array {
    Array(items) => items.get(to_int(index)).unwrap_or(Json::null())
    Object(fields) => fields.get(to_string(index)).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
/// `array.length`.
fn length(value : Json) -> Json {
  match value {
    Array(items) => num(items.length().to_double())
    String(s) => num(s.length().to_double())
    _ => Json::null()
  }
}

///|
/// A color argument. khroma fails on anything but a string.
fn color_of(value : Json) -> String raise @color.ColorError {
  match value {
    String(s) => s
    other => raise @color.Unsupported(to_string(other))
  }
}

///|
/// A channel delta: `undefined` and `0` leave the channel untouched.
fn delta(value : Json?) -> Double {
  match value {
    Some(v) if truthy(v) => to_number(v)
    _ => 0.0
  }
}

///|
fn adjust(
  color : Json,
  h? : Json,
  s? : Json,
  l? : Json,
  r? : Json,
  g? : Json,
  b? : Json,
) -> Json raise @color.ColorError {
  str(
    @color.adjust(
      color_of(color),
      h=delta(h),
      s=delta(s),
      l=delta(l),
      r=delta(r),
      g=delta(g),
      b=delta(b),
    ),
  )
}

///|
/// `amount` may be omitted upstream, which makes the lightness `NaN`.
fn lighten(color : Json, amount : Json) -> Json raise @color.ColorError {
  str(@color.lighten(color_of(color), to_number(amount)))
}

///|
fn darken(color : Json, amount : Json) -> Json raise @color.ColorError {
  str(@color.darken(color_of(color), to_number(amount)))
}

///|
fn invert(color : Json) -> Json raise @color.ColorError {
  str(@color.invert(color_of(color)))
}

///|
fn rgba(r : Json, g : Json, b : Json, a : Json) -> Json {
  str(@color.rgba(to_number(r), to_number(g), to_number(b), a=to_number(a)))
}

///|
fn is_dark(color : Json) -> Json raise @color.ColorError {
  boolean(@color.is_dark(color_of(color)))
}

///|
/// A muted border for `color`: lighter on dark themes, darker otherwise.
fn mk_border(color : Json, dark_mode : Json) -> Json raise @color.ColorError {
  let l = if truthy(dark_mode) { 10.0 } else { -10.0 }
  str(@color.adjust(color_of(color), s=-40.0, l~))
}
