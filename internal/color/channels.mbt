///|
/// Errors raised while parsing or manipulating colors.
pub(all) suberror ColorError {
  /// The string is not a hex, `rgb()`, `hsl()` or keyword color.
  Unsupported(String)
  /// RGB and HSL channels of one color were modified together.
  MixedChannels
} derive(Eq, Debug)

///|
/// Which family of channels has been written since the color was parsed.
priv enum Kind {
  All
  Rgb
  Hsl
} derive(Eq)

///|
/// A color whose RGB and HSL channels are converted lazily, mirroring
/// khroma's `Channels`: the channels the color was written in are kept
/// verbatim, and the other family is derived on demand.
pub struct Channels {
  priv mut red : Double?
  priv mut green : Double?
  priv mut blue : Double?
  priv mut hue : Double?
  priv mut saturation : Double?
  priv mut lightness : Double?
  priv mut alpha : Double
  priv mut kind : Kind
  priv mut changed : Bool
  /// The source text, returned verbatim while the color is unchanged.
  priv source : String?
}

///|
fn Channels::from_rgb(
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  source? : String,
) -> Channels {
  {
    red: Some(r),
    green: Some(g),
    blue: Some(b),
    hue: None,
    saturation: None,
    lightness: None,
    alpha: a,
    kind: All,
    changed: false,
    source,
  }
}

///|
fn Channels::from_hsl(
  h : Double,
  s : Double,
  l : Double,
  a : Double,
  source? : String,
) -> Channels {
  {
    red: None,
    green: None,
    blue: None,
    hue: Some(h),
    saturation: Some(s),
    lightness: Some(l),
    alpha: a,
    kind: All,
    changed: false,
    source,
  }
}

///|
fn Channels::mark(self : Channels, kind : Kind) -> Unit raise ColorError {
  if self.kind != All && self.kind != kind {
    raise MixedChannels
  }
  self.kind = kind
  self.changed = true
}

///|
fn Channels::rgb_data(self : Channels) -> (Double, Double, Double) {
  match (self.red, self.green, self.blue) {
    (Some(r), Some(g), Some(b)) => (r, g, b)
    _ => {
      let (h, s, l) = self.hsl_data()
      let r = self.red.unwrap_or(hsl_to_rgb(h, s, l, Red))
      let g = self.green.unwrap_or(hsl_to_rgb(h, s, l, Green))
      let b = self.blue.unwrap_or(hsl_to_rgb(h, s, l, Blue))
      (r, g, b)
    }
  }
}

///|
fn Channels::hsl_data(self : Channels) -> (Double, Double, Double) {
  match (self.hue, self.saturation, self.lightness) {
    (Some(h), Some(s), Some(l)) => (h, s, l)
    _ => {
      guard (self.red, self.green, self.blue) is (Some(r), Some(g), Some(b)) else {
        // Unreachable: a color always carries one complete channel family.
        (0.0, 0.0, 0.0)
      }
      let h = self.hue.unwrap_or(rgb_to_hsl(r, g, b, Hue))
      let s = self.saturation.unwrap_or(rgb_to_hsl(r, g, b, Saturation))
      let l = self.lightness.unwrap_or(rgb_to_hsl(r, g, b, Lightness))
      (h, s, l)
    }
  }
}

///|
pub fn Channels::r(self : Channels) -> Double {
  self.rgb_data().0
}

///|
pub fn Channels::g(self : Channels) -> Double {
  self.rgb_data().1
}

///|
pub fn Channels::b(self : Channels) -> Double {
  self.rgb_data().2
}

///|
pub fn Channels::h(self : Channels) -> Double {
  self.hsl_data().0
}

///|
pub fn Channels::s(self : Channels) -> Double {
  self.hsl_data().1
}

///|
pub fn Channels::l(self : Channels) -> Double {
  self.hsl_data().2
}

///|
pub fn Channels::a(self : Channels) -> Double {
  self.alpha
}

///|
/// Overwrite the RGB channels. The HSL family is dropped so that later reads
/// derive it from the updated color.
fn Channels::set_rgb(
  self : Channels,
  r? : Double,
  g? : Double,
  b? : Double,
) -> Unit raise ColorError {
  let (r0, g0, b0) = self.rgb_data()
  self.mark(Rgb)
  self.red = Some(r.unwrap_or(r0))
  self.green = Some(g.unwrap_or(g0))
  self.blue = Some(b.unwrap_or(b0))
  self.hue = None
  self.saturation = None
  self.lightness = None
}

///|
/// Overwrite the HSL channels. The RGB family is dropped so that later reads
/// derive it from the updated color.
fn Channels::set_hsl(
  self : Channels,
  h? : Double,
  s? : Double,
  l? : Double,
) -> Unit raise ColorError {
  let (h0, s0, l0) = self.hsl_data()
  self.mark(Hsl)
  self.hue = Some(h.unwrap_or(h0))
  self.saturation = Some(s.unwrap_or(s0))
  self.lightness = Some(l.unwrap_or(l0))
  self.red = None
  self.green = None
  self.blue = None
}

///|
fn Channels::set_a(self : Channels, value : Double) -> Unit {
  self.changed = true
  self.alpha = value
}
