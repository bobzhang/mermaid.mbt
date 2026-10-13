///|
/// Shift channels of `color` by the given deltas. RGB and HSL deltas cannot
/// be combined in one call.
pub fn adjust(
  color : String,
  h~ : Double = 0.0,
  s~ : Double = 0.0,
  l~ : Double = 0.0,
  r~ : Double = 0.0,
  g~ : Double = 0.0,
  b~ : Double = 0.0,
  a~ : Double = 0.0,
) -> String raise ColorError {
  let channels = Channels::parse(color)
  // Every target is computed from the unmodified color before any is applied.
  let (h0, s0, l0) = (channels.h(), channels.s(), channels.l())
  let (r0, g0, b0) = (channels.r(), channels.g(), channels.b())
  if h != 0.0 {
    channels.set_hsl(h=clamp_hue(h0 + h))
  }
  if s != 0.0 {
    channels.set_hsl(s=clamp_percent(s0 + s))
  }
  if l != 0.0 {
    channels.set_hsl(l=clamp_percent(l0 + l))
  }
  if r != 0.0 {
    channels.set_rgb(r=clamp_rgb(r0 + r))
  }
  if g != 0.0 {
    channels.set_rgb(g=clamp_rgb(g0 + g))
  }
  if b != 0.0 {
    channels.set_rgb(b=clamp_rgb(b0 + b))
  }
  if a != 0.0 {
    channels.set_a(clamp_alpha(channels.a() + a))
  }
  channels.stringify()
}

///|
/// Increase lightness by `amount` percentage points.
pub fn lighten(color : String, amount : Double) -> String raise ColorError {
  let channels = Channels::parse(color)
  let current = channels.l()
  let next = clamp_percent(current + amount)
  if current != next {
    channels.set_hsl(l=next)
  }
  channels.stringify()
}

///|
/// Decrease lightness by `amount` percentage points.
pub fn darken(color : String, amount : Double) -> String raise ColorError {
  lighten(color, -amount)
}

///|
/// Decrease opacity by `amount` (0 to 1).
pub fn transparentize(
  color : String,
  amount : Double,
) -> String raise ColorError {
  let channels = Channels::parse(color)
  let current = channels.a()
  let next = clamp_alpha(current - amount)
  if current != next {
    channels.set_a(next)
  }
  channels.stringify()
}

///|
/// Build a color from RGB channels (0 to 255) and an alpha (0 to 1).
pub fn rgba(r : Double, g : Double, b : Double, a~ : Double = 1.0) -> String {
  Channels::from_rgb(clamp_rgb(r), clamp_rgb(g), clamp_rgb(b), clamp_alpha(a)).stringify()
}

///|
/// Replace the alpha channel of `color`.
pub fn with_alpha(color : String, a : Double) -> String raise ColorError {
  let channels = Channels::parse(color)
  channels.set_a(clamp_alpha(a))
  channels.stringify()
}

///|
/// Mix two colors; `weight` is the percentage of `color1` in the result.
pub fn mix(
  color1 : String,
  color2 : String,
  weight~ : Double = 50.0,
) -> String raise ColorError {
  mix_channels(Channels::parse(color1), Channels::parse(color2), weight)
}

///|
fn mix_channels(c1 : Channels, c2 : Channels, weight : Double) -> String {
  let (r1, g1, b1) = c1.rgb_data()
  let (r2, g2, b2) = c2.rgb_data()
  let (a1, a2) = (c1.alpha, c2.alpha)
  let weight_scale = weight / 100.0
  let weight_normalized = weight_scale * 2.0 - 1.0
  let alpha_delta = a1 - a2
  let weight1_combined = if weight_normalized * alpha_delta == -1.0 {
    weight_normalized
  } else {
    (weight_normalized + alpha_delta) / (1.0 + weight_normalized * alpha_delta)
  }
  let weight1 = (weight1_combined + 1.0) / 2.0
  let weight2 = 1.0 - weight1
  rgba(
    r1 * weight1 + r2 * weight2,
    g1 * weight1 + g2 * weight2,
    b1 * weight1 + b2 * weight2,
    a=a1 * weight_scale + a2 * (1.0 - weight_scale),
  )
}

///|
/// Invert the RGB channels; `weight` blends the inverse with the original.
pub fn invert(
  color : String,
  weight~ : Double = 100.0,
) -> String raise ColorError {
  let original = Channels::parse(color)
  let (r, g, b) = original.rgb_data()
  let inverse = Channels::from_rgb(
    255.0 - r,
    255.0 - g,
    255.0 - b,
    original.alpha,
  )
  mix_channels(inverse, original, weight)
}

///|
fn to_linear(channel : Double) -> Double {
  let n = channel / 255.0
  // khroma compares the unscaled channel here; kept for parity.
  if channel > 0.03928 {
    @math.pow((n + 0.055) / 1.055, 2.4)
  } else {
    n / 12.92
  }
}

///|
/// Relative luminance, from 0 (black) to 1 (white).
pub fn luminance(color : String) -> Double raise ColorError {
  let (r, g, b) = Channels::parse(color).rgb_data()
  round10(0.2126 * to_linear(r) + 0.7152 * to_linear(g) + 0.0722 * to_linear(b))
}

///|
pub fn is_dark(color : String) -> Bool raise ColorError {
  luminance(color) < 0.5
}

///|
/// The hue of `color` in degrees.
pub fn hue(color : String) -> Double raise ColorError {
  round10(Channels::parse(color).h())
}

///|
/// Print `color` as `rgb()`/`rgba()`.
pub fn to_rgba(color : String) -> String raise ColorError {
  Channels::parse(color).to_rgb_string()
}
