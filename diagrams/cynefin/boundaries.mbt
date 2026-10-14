// The wavy lines between the domains (`cynefinBoundaries.ts`). Their
// waviness comes from a seeded generator, so a diagram always looks the
// same: the seed is the configured one or, without it, a hash of the id
// of the `<svg>` element.

///|
/// JavaScript's `ToInt32`: the integer part modulo 2^32, as a signed
/// 32-bit number.
fn to_int32(value : Double) -> Int32 {
  if value != value || value == 1.0 / 0.0 || value == -1.0 / 0.0 {
    return 0
  }
  let integer = if value < 0.0 { value.ceil() } else { value.floor() }
  let modulo = integer - (integer / 4294967296.0).floor() * 4294967296.0
  modulo.to_uint().reinterpret_as_int()
}

///|
/// `x >>> n`
fn shift_right_unsigned(value : Int32, bits : Int32) -> Int32 {
  (value.reinterpret_as_uint() >> bits).reinterpret_as_int()
}

///|
/// One value in [0, 1) for a seed: a step of the mulberry32 generator.
fn seeded_random(seed : Double) -> Double {
  let mut t = to_int32(seed + 1831565813.0)
  t = (t ^ shift_right_unsigned(t, 15)) * (t | 1)
  t = t ^ (t + (t ^ shift_right_unsigned(t, 7)) * (t | 61))
  (t ^ shift_right_unsigned(t, 14)).reinterpret_as_uint().to_double() /
  4294967296.0
}

///|
/// The hash of a string that seeds the generator: Java's `hashCode`.
fn hash_string(text : String) -> Int32 {
  let mut hash = 0
  for i in 0..<text.length() {
    hash = (hash << 5) - hash + text[i].to_int()
  }
  hash
}

///|
/// The seed of the boundaries: the configured one unless it is zero or
/// not a finite number.
fn resolve_seed(configured : Double?, id : String) -> Double {
  match configured {
    Some(seed) if seed == seed &&
      seed != 1.0 / 0.0 &&
      seed != -1.0 / 0.0 &&
      seed != 0.0 => seed
    _ => hash_string(id).to_double()
  }
}

///|
/// The vertical wavy line through the centre: seven cubic curves between
/// points jittered sideways by up to `amplitude`, bulging to alternating
/// sides.
fn fold_path(
  width : Double,
  height : Double,
  seed : Double,
  amplitude : Double,
) -> String {
  let n = @dom.number
  let cx = width / 2.0
  let segments = 7
  let seg_height = height / segments.to_double()
  let points : Array[(Double, Double)] = []
  for i in 0..<=segments {
    let i = i.to_double()
    let jitter = seeded_random(seed + i * 17.0) * amplitude * 2.0 - amplitude
    points.push((cx + jitter, i * seg_height))
  }
  let d = StringBuilder()
  d.write_string("M\{n(points[0].0)},\{n(points[0].1)}")
  for i in 0..<(points.length() - 1) {
    let p0 = points[i]
    let p1 = points[i + 1]
    let mid_y = (p0.1 + p1.1) / 2.0
    let dir = if i % 2 == 0 { 1.0 } else { -1.0 }
    let offset = amplitude *
      1.5 *
      dir *
      seeded_random(seed + i.to_double() * 31.0 + 7.0)
    let cp1x = p0.0 + offset
    let cp2x = p1.0 - offset
    d.write_string(
      " C\{n(cp1x)},\{n(mid_y)} \{n(cp2x)},\{n(mid_y)} \{n(p1.0)},\{n(p1.1)}",
    )
  }
  d.to_string()
}

///|
/// The horizontal wavy line through the centre, built like the fold.
fn horizontal_boundary(
  width : Double,
  height : Double,
  seed : Double,
  amplitude : Double,
) -> String {
  let n = @dom.number
  let cy = height / 2.0
  let segments = 7
  let seg_width = width / segments.to_double()
  let points : Array[(Double, Double)] = []
  for i in 0..<=segments {
    let i = i.to_double()
    let jitter = seeded_random(seed + i * 23.0) * amplitude * 2.0 - amplitude
    points.push((i * seg_width, cy + jitter))
  }
  let d = StringBuilder()
  d.write_string("M\{n(points[0].0)},\{n(points[0].1)}")
  for i in 0..<(points.length() - 1) {
    let p0 = points[i]
    let p1 = points[i + 1]
    let mid_x = (p0.0 + p1.0) / 2.0
    let dir = if i % 2 == 0 { 1.0 } else { -1.0 }
    let offset = amplitude *
      1.5 *
      dir *
      seeded_random(seed + i.to_double() * 37.0 + 11.0)
    let cp1y = p0.1 + offset
    let cp2y = p1.1 - offset
    d.write_string(
      " C\{n(mid_x)},\{n(cp1y)} \{n(mid_x)},\{n(cp2y)} \{n(p1.0)},\{n(p1.1)}",
    )
  }
  d.to_string()
}

///|
/// The "cliff" between Clear and Chaotic: a steep S-curve from the centre
/// down to the bottom edge.
fn cliff_path(width : Double, height : Double) -> String {
  let n = @dom.number
  let cx = width / 2.0
  let top_y = height * 0.5
  let bottom_y = height
  let amplitude = width * 0.03
  let drop = bottom_y - top_y
  [
    "M\{n(cx)},\{n(top_y)}",
    "C\{n(cx + amplitude)},\{n(top_y + drop * 0.2)}",
    "\{n(cx - amplitude * 1.5)},\{n(top_y + drop * 0.55)}",
    "\{n(cx + amplitude * 0.5)},\{n(top_y + drop * 0.75)}",
    "C\{n(cx - amplitude)},\{n(top_y + drop * 0.85)}",
    "\{n(cx + amplitude * 0.3)},\{n(top_y + drop * 0.95)}",
    "\{n(cx)},\{n(bottom_y)}",
  ].join(" ")
}

///|
/// The ellipse of the Confusion region at the centre, as two arcs.
fn confusion_path(cx : Double, cy : Double, rx : Double, ry : Double) -> String {
  let n = @dom.number
  [
    "M\{n(cx - rx)},\{n(cy)}",
    "A\{n(rx)},\{n(ry)} 0 1,1 \{n(cx + rx)},\{n(cy)}",
    "A\{n(rx)},\{n(ry)} 0 1,1 \{n(cx - rx)},\{n(cy)}",
    "Z",
  ].join(" ")
}
