///|
priv enum RgbChannel {
  Red
  Green
  Blue
}

///|
priv enum HslChannel {
  Hue
  Saturation
  Lightness
}

///|
fn clamp_rgb(value : Double) -> Double {
  if value >= 255.0 {
    255.0
  } else if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
/// Hue wraps like JavaScript's `%`, so a negative hue stays negative.
fn clamp_hue(value : Double) -> Double {
  value % 360.0
}

///|
fn clamp_percent(value : Double) -> Double {
  if value >= 100.0 {
    100.0
  } else if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn clamp_alpha(value : Double) -> Double {
  if value >= 1.0 {
    1.0
  } else if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn hue_to_rgb(p : Double, q : Double, t : Double) -> Double {
  let t = if t < 0.0 { t + 1.0 } else if t > 1.0 { t - 1.0 } else { t }
  if t < 1.0 / 6.0 {
    p + (q - p) * 6.0 * t
  } else if t < 1.0 / 2.0 {
    q
  } else if t < 2.0 / 3.0 {
    p + (q - p) * (2.0 / 3.0 - t) * 6.0
  } else {
    p
  }
}

///|
fn hsl_to_rgb(
  h : Double,
  s : Double,
  l : Double,
  channel : RgbChannel,
) -> Double {
  if s == 0.0 {
    return l * 2.55
  }
  let h = h / 360.0
  let s = s / 100.0
  let l = l / 100.0
  let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s }
  let p = 2.0 * l - q
  match channel {
    Red => hue_to_rgb(p, q, h + 1.0 / 3.0) * 255.0
    Green => hue_to_rgb(p, q, h) * 255.0
    Blue => hue_to_rgb(p, q, h - 1.0 / 3.0) * 255.0
  }
}

///|
fn rgb_to_hsl(
  r : Double,
  g : Double,
  b : Double,
  channel : HslChannel,
) -> Double {
  let r = r / 255.0
  let g = g / 255.0
  let b = b / 255.0
  let max = r.max(g).max(b)
  let min = r.min(g).min(b)
  let l = (max + min) / 2.0
  if channel is Lightness {
    return l * 100.0
  }
  if max == min {
    return 0.0
  }
  let d = max - min
  let s = if l > 0.5 { d / (2.0 - max - min) } else { d / (max + min) }
  if channel is Saturation {
    return s * 100.0
  }
  if max == r {
    ((g - b) / d + (if g < b { 6.0 } else { 0.0 })) * 60.0
  } else if max == g {
    ((b - r) / d + 2.0) * 60.0
  } else {
    ((r - g) / d + 4.0) * 60.0
  }
}

///|
/// `Math.round`: halves round towards positive infinity.
fn js_round(value : Double) -> Double {
  (value + 0.5).floor()
}

///|
/// Round to ten decimal places, as khroma does before printing a channel.
fn round10(value : Double) -> Double {
  js_round(value * 10000000000.0) / 10000000000.0
}

///|
/// Print a number the way JavaScript's string conversion does.
fn number(value : Double) -> String {
  if value == 0.0 {
    "0"
  } else {
    value.to_string()
  }
}
