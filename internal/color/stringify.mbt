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
