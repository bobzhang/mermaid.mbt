// The single-precision trigonometric functions of macOS's libm on arm64.
//
// Skia computes the conics of an SVG arc with `sinf`, `cosf`, `tanf` and
// `atan2f`, and Chrome takes them from the system. They are not correctly
// rounded: `tanf` and `atan2f` are an ulp off for one argument in twenty,
// and `atan2f(0, -1)` is deliberately the float below pi. A bounding box
// that passes through them can only be reproduced with the same
// arithmetic, so these are transcriptions of the library's routines,
// instruction for instruction: double precision throughout, with fused
// multiply-adds where the library has them. A C version of the same
// transcription agrees with the library on every float.

///|
/// The sine of `r`, at most an eighth of a turn.
fn sin_poly(r : Double) -> Double {
  let z = r * r
  let r3 = r * z
  let a = fma(z, sin_cos[7], sin_cos[8])
  let r5 = z * r3
  let b = fma(r3, sin_cos[9], r)
  fma(r5, a, b)
}

///|
/// The cosine of `r`, at most an eighth of a turn.
fn cos_poly(r : Double) -> Double {
  let z = r * r
  let a = fma(z, sin_cos[3], sin_cos[4])
  let b = fma(z, sin_cos[5], sin_cos[6])
  let a = fma(z * z, a, b)
  fma(z, a, 1.0)
}

///|
/// The sine of `n` quarter turns plus `r`.
fn quarter_turns(n : Int64, r : Double) -> Float {
  let value = if n.land(1L) != 0L { cos_poly(r) } else { sin_poly(r) }
  Float::from_double(if n.land(2L) != 0L { -value } else { value })
}

///|
/// The sine of half turns: `high + low` of them, where `high` carries the
/// whole ones.
fn half_turns(high : Double, low : Double) -> Float {
  let whole = round_even(high)
  let f = high - whole + low
  let signed = if whole.to_int64().land(1L) != 0L { -f } else { f }
  let z = f * f
  let p = fma(z, z + sin_cos[10], sin_cos[12])
  let q = fma(z, z + sin_cos[11], sin_cos[13])
  Float::from_double(signed * p * (sin_cos[14] * q))
}

///|
/// The index into the per-exponent tables: the top byte of the bits of
/// a float, from `first` on.
fn scale_index(magnitude : UInt32, first : UInt32) -> Int32 {
  let top = magnitude >> 24
  if top < first {
    0
  } else {
    (top - first).reinterpret_as_int()
  }
}

///|
/// The bits of 120, where sine and cosine change to the large-argument
/// method; of pi/4 and of 2^-12, below which the functions are their
/// first terms; of 2^26 and of infinity.
const BIG : UInt32 = 0x42f00000

///|
const QUARTER_PI : UInt32 = 0x3f490fdb

///|
const TINY : UInt32 = 0x39800000

///|
const HUGE : UInt32 = 0x4c800000

///|
const INFINITE : UInt32 = 0x7f800000

///|
/// `cosf`.
pub fn cosf(x : Float) -> Float {
  let x = x.abs()
  let w = x.reinterpret_as_uint()
  let d = x.to_double()
  if w >= BIG {
    if w >= HUGE {
      if w >= INFINITE {
        return x - x
      }
      let i = 2 * scale_index(w, 0x40)
      return half_turns(d * sin_cos_scale[i] + 0.5, d * sin_cos_scale[i + 1])
    }
    // Still quarter turns, with pi/2 in two parts.
    let turns = round_even(d * sin_cos[0])
    let r = fma(-turns, sin_cos[1], d)
    let r = fma(-turns, sin_cos[2], r)
    return quarter_turns(turns.to_int64() + 1L, r)
  }
  if w < QUARTER_PI {
    if w < TINY {
      // (2^26 - x) * 2^-26 in floats.
      return 1
    }
    return Float::from_double(cos_poly(d))
  }
  let turns = round_even(d * sin_cos[0])
  quarter_turns(turns.to_int64() + 1L, fma(-turns, sin_cos[1], d))
}

///|
/// `__sincosf_stret`: sine and cosine together, which is what a compiler
/// for macOS turns a `sinf` and a `cosf` of the same argument into. Its
/// results are not always those of the separate functions.
pub fn sincosf(x : Float) -> (Float, Float) {
  let w = x.reinterpret_as_uint() & 0x7fffffff
  let d = x.to_double()
  let (n, r) = if w >= BIG {
    if w >= INFINITE {
      let nan = x - x
      return (nan, nan)
    }
    let i = 2 * scale_index(w, 0x40)
    let d = d + d
    let high = d * sin_cos_scale[i]
    let low = d * sin_cos_scale[i + 1]
    let turns = round_even(high)
    (turns.to_int64(), high - turns + low)
  } else if w < TINY {
    // (x + x * 2^26) * 2^-26 and (2^26 - |x|) * 2^-26 in floats.
    return (x, 1)
  } else {
    let turns = d * sin_cos[0]
    let whole = round_even(turns)
    (whole.to_int64(), turns - whole)
  }
  // Sine and cosine of `r` quarter turns, each a product of two
  // quadratics in `z`.
  let k = sin_cos_pair
  let z = r * r
  let sine = r * k[4] * fma(z, z + k[0], k[6]) * fma(z, z + k[2], k[8])
  let cosine = k[5] * fma(z, z + k[1], k[7]) * fma(z, z + k[3], k[9])
  let mut s = Float::from_double(sine)
  let mut c = Float::from_double(cosine)
  if n.land(2L) != 0L {
    s = -s
    c = -c
  }
  if n.land(1L) != 0L {
    (c, -s)
  } else {
    (s, c)
  }
}

///|
/// `tanf`.
pub fn tanf(x : Float) -> Float {
  let w = x.reinterpret_as_uint() & 0x7fffffff
  let d = x.to_double()
  let k = tan_consts
  // The argument as quarter turns `f` away from a whole number of them,
  // and whether that number is odd.
  let (f, odd) = if w >= HUGE {
    if w >= INFINITE {
      return x - x
    }
    let i = 2 * scale_index(w, 0x4b)
    let high = d * tan_scale[i]
    let low = d * tan_scale[i + 1]
    // Adding 1.5 * 2^52 leaves the integer in the low bits.
    let shifted = high + k[0]
    let odd = shifted.reinterpret_as_int64().land(1L) != 0L
    (high - (shifted - k[0]) + low, odd)
  } else if w < QUARTER_PI {
    if w < TINY {
      // (x + x * 2^26) * 2^-26 in floats.
      return x
    }
    let z = d * d
    let a = fma(z, k[5], k[6])
    let b = fma(z, k[7], k[8])
    let c = fma(z, k[9], k[10])
    let z2 = z * z
    let a = fma(z2, k[4], a)
    let c = fma(z2, b, c)
    let c = fma(z2 * z2, a, c)
    return Float::from_double(fma(d, z * c, d))
  } else {
    let turns = d * k[2]
    let whole = round_even(turns)
    (fma(d, k[3], turns - whole), whole.to_int64().land(1L) != 0L)
  }
  let z = f * f
  let p = f * fma(z, k[12], k[13])
  let q1 = fma(z, z + k[14], k[17])
  let q2 = fma(z, z + k[15], k[18])
  let q3 = fma(z, z + k[16], k[19])
  let tangent = p * q1 * (q2 * q3)
  Float::from_double(if odd { k[1] / tangent } else { tangent })
}

///|
/// The arctangent of a quotient of magnitude at most one: a constant
/// times the quotient times four quadratics in its square.
fn atan_poly(q : Double) -> Double {
  let k = atan_consts
  let z = q * q
  let a = fma(z + k[0], z, k[2]) * fma(z + k[4], z, k[6]) * k[8]
  let b = fma(z + k[1], z, k[3]) * fma(z + k[5], z, k[7]) * q
  a * b
}

///|
/// `atan2f`. The plane is cut along its diagonals; on each side the
/// smaller coordinate is divided by the larger.
pub fn atan2f(y : Float, x : Float) -> Float {
  let k = atan_consts
  let yd = y.to_double()
  let xd = x.to_double()
  let negative = y.reinterpret_as_uint() >> 31 != 0
  // What the library returns for a point on the negative x axis: the
  // float below pi, never above it.
  let pi = if negative { -k[14] } else { k[14] }
  let angle = if y < x {
    if -x < y {
      atan_poly(yd / xd)
    } else if -x == y {
      k[18]
    } else {
      k[13] - atan_poly(xd / yd)
    }
  } else if y == x {
    if y < 0 {
      k[16]
    } else if y != 0 {
      k[17]
    } else if x.reinterpret_as_uint() >> 31 == 0 {
      return y
    } else {
      pi
    }
  } else if y != y || x != x {
    return y + x
  } else if -x < y {
    k[12] - atan_poly(xd / yd)
  } else if -x == y {
    k[15]
  } else {
    let q = yd / xd
    if q.abs() < k[9] {
      pi
    } else {
      atan_poly(q) + (if negative { k[11] } else { k[10] })
    }
  }
  Float::from_double(angle)
}
