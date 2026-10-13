///|
/// Print a color in the most compact faithful format: the source text when
/// unchanged, `hsl()` for HSL colors, hex for opaque integral RGB colors and
/// `rgb()`/`rgba()` otherwise.
pub fn Channels::stringify(self : Channels) -> String {
  if !self.changed && self.source is Some(source) {
    return source
  }
  if self.red is None {
    return self.to_hsl_string()
  }
  let (r, g, b) = self.rgb_data()
  if self.alpha < 1.0 || r != r.floor() || g != g.floor() || b != b.floor() {
    self.to_rgb_string()
  } else {
    self.to_hex_string()
  }
}

///|
fn Channels::to_hsl_string(self : Channels) -> String {
  let (h, s, l) = self.hsl_data()
  let h = number(round10(h))
  let s = number(round10(s))
  let l = number(round10(l))
  if self.alpha < 1.0 {
    "hsla(\{h}, \{s}%, \{l}%, \{number(self.alpha)})"
  } else {
    "hsl(\{h}, \{s}%, \{l}%)"
  }
}

///|
/// Print as `rgb()` or, when translucent, `rgba()`.
pub fn Channels::to_rgb_string(self : Channels) -> String {
  let (r, g, b) = self.rgb_data()
  let r = number(round10(r))
  let g = number(round10(g))
  let b = number(round10(b))
  if self.alpha < 1.0 {
    "rgba(\{r}, \{g}, \{b}, \{number(round10(self.alpha))})"
  } else {
    "rgb(\{r}, \{g}, \{b})"
  }
}

///|
fn hex_byte(value : Double) -> String {
  let n = js_round(value).to_int()
  let n = if n < 0 { 0 } else if n > 255 { 255 } else { n }
  let digits = "0123456789abcdef"
  let out = StringBuilder()
  out.write_char(digits.get_char(n / 16).unwrap_or('0'))
  out.write_char(digits.get_char(n % 16).unwrap_or('0'))
  out.to_string()
}

///|
fn Channels::to_hex_string(self : Channels) -> String {
  let (r, g, b) = self.rgb_data()
  let alpha = if self.alpha < 1.0 { hex_byte(self.alpha * 255.0) } else { "" }
  "#\{hex_byte(r)}\{hex_byte(g)}\{hex_byte(b)}\{alpha}"
}

///|
/// The 8-bit sRGB channels a browser resolves this color to. An HSL color
/// is converted in 32-bit floats with the CSS Color 4 formula, as Blink
/// does, which decides the rounding of channels that land on a half.
pub fn Channels::to_css_rgb(self : Channels) -> (Int32, Int32, Int32) {
  let round = (value : Float) => {
    let scaled = value * 255.0
    let rounded = if scaled < 0.0 {
      -((-scaled).to_double() + 0.5).floor()
    } else {
      (scaled.to_double() + 0.5).floor()
    }
    let n = rounded.to_int()
    if n < 0 {
      0
    } else if n > 255 {
      255
    } else {
      n
    }
  }
  guard self.red is None else {
    let (r, g, b) = self.rgb_data()
    return (
      round(Float::from_double(r / 255.0)),
      round(Float::from_double(g / 255.0)),
      round(Float::from_double(b / 255.0)),
    )
  }
  let (h, s, l) = self.hsl_data()
  let h = Float::from_double(h)
  // Percentages become floats before they are scaled down.
  let hundred : Float = 100.0
  let s = Float::from_double(s) / hundred
  let l = Float::from_double(l) / hundred
  if s == 0.0 {
    return (round(l), round(l), round(l))
  }
  let channel = (n : Float) => {
    let k = Float::from_double((n + h / 30.0).to_double() % 12.0)
    let a = s * (if l < 1.0 - l { l } else { 1.0 - l })
    let nine : Float = 9.0
    let one : Float = 1.0
    let mut m : Float = k - 3.0
    if nine - k < m {
      m = nine - k
    }
    if m > one {
      m = one
    }
    if m < -one {
      m = -one
    }
    l - a * m
  }
  (round(channel(0.0)), round(channel(8.0)), round(channel(4.0)))
}
