///|
/// The alpha of a color as the browser serializes it in `rgba()`, or
/// nothing when the color is opaque.
///
/// The browser writes eight bits of alpha with two decimals when that is
/// enough to get the same eight bits back, with three otherwise (CSSOM,
/// "serializing an `<alphavalue>`"): `#ff000080` is
/// `rgba(255, 0, 0, 0.5)` and `#0f08` is `rgba(0, 255, 0, 0.533)`.
fn css_alpha(alpha : Double) -> String? {
  let clamped = if alpha < 0.0 {
    0.0
  } else if alpha > 1.0 {
    1.0
  } else {
    alpha
  }
  // `lroundf(alpha * 255.0f)`, the alpha being a `float`.
  let scaled = Float::from_double(clamped) * 255.0
  let bits = (scaled.to_double() + 0.5).floor().to_int()
  if bits >= 255 {
    return None
  }
  // Hundredths, to the nearest; never halfway.
  let hundredths = (bits * 200 + 255) / 510
  // `round(hundredths / 100 * 255)`, halves away from zero.
  if (hundredths * 255 + 50) / 100 == bits {
    Some(number(hundredths.to_double() / 100.0))
  } else {
    let thousandths = (bits * 2000 + 255) / 510
    Some(number(thousandths.to_double() / 1000.0))
  }
}
