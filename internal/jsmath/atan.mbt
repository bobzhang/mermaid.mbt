// `Math.atan` as V8 computes it: llvm-libc's double precision `atan`
// (`src/__support/math/atan.h`), which V8's `ieee754::atan` delegates to.
// It is not correctly rounded, so it is transcribed operation for
// operation, fused multiply-adds included, rather than computed to more
// precision and rounded.

///|
/// `atan(i / 64)` for `i` from 0 to 64 as the bits of a low and a high
/// double: llvm-libc's `ATAN_I`.
let atan_table : FixedArray[(Int64, Int64)] = [
  (0x0000000000000000L, 0x0000000000000000L),
  (0xbc2220c39d4dff50L, 0x3f8fff555bbb729bL),
  (0xbc35ec431444912cL, 0x3f9ffd55bba97625L),
  (0xbc086ef8f794f105L, 0x3fa7fb818430da2aL),
  (0xbc3c934d86d23f1dL, 0x3faff55bb72cfdeaL),
  (0x3c5ac4ce285df847L, 0x3fb3f59f0e7c559dL),
  (0xbc5cfb654c0c3d98L, 0x3fb7ee182602f10fL),
  (0x3c5f7b8f29a05987L, 0x3fbbe39ebe6f07c3L),
  (0xbc4cd37686760c17L, 0x3fbfd5ba9aac2f6eL),
  (0xbc4b485914dacf8cL, 0x3fc1e1fafb043727L),
  (0x3c661a3b0ce9281bL, 0x3fc3d6eee8c6626cL),
  (0xbc5054ab2c010f3dL, 0x3fc5c9811e3ec26aL),
  (0x3c5347b0b4f881caL, 0x3fc7b97b4bce5b02L),
  (0x3c4cf601e7b4348eL, 0x3fc9a6a8e96c8626L),
  (0x3c217b10d2e0e5abL, 0x3fcb90d7529260a2L),
  (0x3c6c648d1534597eL, 0x3fcd77d5df205736L),
  (0x3c68ab6e3cf7afbdL, 0x3fcf5b75f92c80ddL),
  (0x3c762e47390cb865L, 0x3fd09dc597d86362L),
  (0x3c630ca4748b1bf9L, 0x3fd18bf5a30bf178L),
  (0xbc7077cdd36dfc81L, 0x3fd278372057ef46L),
  (0xbc6963a544b672d8L, 0x3fd362773707ebccL),
  (0xbc75d5e43c55b3baL, 0x3fd44aa436c2af0aL),
  (0xbc62566480884082L, 0x3fd530ad9951cd4aL),
  (0xbc7a725715711f00L, 0x3fd614840309cfe2L),
  (0xbc7c63aae6f6e918L, 0x3fd6f61941e4def1L),
  (0x3c769c885c2b249aL, 0x3fd7d5604b63b3f7L),
  (0x3c7b6d0ba3748fa8L, 0x3fd8b24d394a1b25L),
  (0x3c79e6c988fd0a77L, 0x3fd98cd5454d6b18L),
  (0xbc724dec1b50b7ffL, 0x3fda64eec3cc23fdL),
  (0x3c7ae187b1ca5040L, 0x3fdb3a911da65c6cL),
  (0xbc7cc1ce70934c34L, 0x3fdc0db4c94ec9f0L),
  (0xbc7a2cfa4418f1adL, 0x3fdcde53432c1351L),
  (0x3c7a2b7f222f65e2L, 0x3fddac670561bb4fL),
  (0x3c70e53dc1bf3435L, 0x3fde77eb7f175a34L),
  (0xbc6a3992dc382a23L, 0x3fdf40dd0b541418L),
  (0xbc8b32c949c9d593L, 0x3fe0039c73c1a40cL),
  (0xbc7d5b495f6349e6L, 0x3fe0657e94db30d0L),
  (0x3c5974fa13b5404fL, 0x3fe0c6145b5b43daL),
  (0xbc52bdaee1c0ee35L, 0x3fe1255d9bfbd2a9L),
  (0x3c8c621cec00c301L, 0x3fe1835a88be7c13L),
  (0xbc5928df287a668fL, 0x3fe1e00babdefeb4L),
  (0x3c6c421c9f38224eL, 0x3fe23b71e2cc9e6aL),
  (0xbc709e73b0c6c087L, 0x3fe2958e59308e31L),
  (0x3c8c5d5e9ff0cf8dL, 0x3fe2ee628406cbcaL),
  (0x3c81021137c71102L, 0x3fe345f01cce37bbL),
  (0xbc82304331d8bf46L, 0x3fe39c391cd4171aL),
  (0x3c7ecf8b492644f0L, 0x3fe3f13fb89e96f4L),
  (0xbc7f76d0163f79c8L, 0x3fe445065b795b56L),
  (0x3c72419a87f2a458L, 0x3fe4978fa3269ee1L),
  (0x3c84a33dbeb3796cL, 0x3fe4e8de5bb6ec04L),
  (0xbc81bb74abda520cL, 0x3fe538f57b89061fL),
  (0xbc75e5c9d8c5a950L, 0x3fe587d81f732fbbL),
  (0x3c60028e4bc5e7caL, 0x3fe5d58987169b18L),
  (0xbc62b785350ee8c1L, 0x3fe6220d115d7b8eL),
  (0xbc76ea6febe8bbbaL, 0x3fe66d663923e087L),
  (0xbc8a80386188c50eL, 0x3fe6b798920b3d99L),
  (0xbc78c34d25aadef6L, 0x3fe700a7c5784634L),
  (0x3c47b2a6165884a1L, 0x3fe748978fba8e0fL),
  (0x3c8406a089803740L, 0x3fe78f6bbd5d315eL),
  (0x3c8560821e2f3aa9L, 0x3fe7d528289fa093L),
  (0xbc7bf76229d3b917L, 0x3fe819d0b7158a4dL),
  (0x3c66b66e7fc8b8c3L, 0x3fe85d69576cc2c5L),
  (0xbc855b9a5e177a1bL, 0x3fe89ff5ff57f1f8L),
  (0xbc7ec182ab042f61L, 0x3fe8e17aa99cc05eL),
  (0x3c81a62633145c07L, 0x3fe921fb54442d18L),
]

///|
/// The correctly rounded `a * b + c`: a fused multiply-add, which arm64
/// has as an instruction. The exact product and sums are rounded once,
/// through a sum rounded to odd (Boldo and Melquiond). Exact while
/// nothing overflows or underflows, which the arguments here never do.
fn fma(a : Double, b : Double, c : Double) -> Double {
  let u = two_prod(a, b)
  let t = two_sum(c, u.lo)
  let v = two_sum(u.hi, t.hi)
  let w = two_sum(v.lo, t.lo)
  // Round `v.lo + t.lo` to odd: when it is inexact and its rounding is
  // even, take the neighbour on the side of the error.
  let mut z = w.hi
  if w.lo != 0.0 {
    let bits = z.reinterpret_as_int64()
    if (bits & 1L) == 0L {
      // Away from zero when the error has the sign of `z`.
      let away = (w.lo > 0.0) == (z > 0.0)
      z = (if away { bits + 1L } else { bits - 1L }).reinterpret_as_double()
    }
  }
  v.hi + z
}

///|
/// Round to the nearest integer, halves to even: `frintn`.
fn nearest_integer(x : Double) -> Double {
  let floor = x.floor()
  let diff = x - floor
  if diff > 0.5 {
    floor + 1.0
  } else if diff < 0.5 {
    floor
  } else if floor % 2.0 == 0.0 {
    floor
  } else {
    floor + 1.0
  }
}

///|
/// llvm-libc's double-double division (Karp and Markstein).
fn dd_div(a : DD, b : DD) -> DD {
  let q = 1.0 / b.hi
  let hi = a.hi * q
  let e_hi = fma(b.hi, -hi, a.hi)
  let e_lo = fma(b.lo, -hi, a.lo)
  { hi, lo: q * (e_hi + e_lo), }
}

///|
/// `atan(x)` for `|x| <= 2^-7` by its Taylor polynomial of degree 9:
/// llvm-libc's `atan_eval`.
fn atan_eval(x : DD) -> DD {
  let x_hi_sq = x.hi * x.hi
  // x_hi^2 / 5 - 1/3
  let c0 = fma(
    x_hi_sq,
    0x3fc999999999999aL.reinterpret_as_double(),
    0xbfd5555555555555L.reinterpret_as_double(),
  )
  // x_hi^2 / 9 - 1/7
  let c1 = fma(
    x_hi_sq,
    0x3fbc71c71c71c71cL.reinterpret_as_double(),
    0xbfc2492492492492L.reinterpret_as_double(),
  )
  let x_hi_3 = x_hi_sq * x.hi
  let x_hi_4 = x_hi_sq * x_hi_sq
  let d0 = fma(x_hi_4, c1, c0)
  let d1 = fma(x_hi_4 - x_hi_sq, x.lo, x.lo)
  { hi: x.hi, lo: fma(x_hi_3, d0, d1), }
}

///|
/// Dekker's fast sum of `a` and `b`, as llvm-libc's `exact_add` computes
/// it whatever their magnitudes.
fn fast_two_sum(a : Double, b : Double) -> DD {
  let hi = a + b
  let t = hi - a
  { hi, lo: b - t, }
}

///|
/// `Math.atan`.
pub fn atan(x : Double) -> Double {
  if x.is_nan() {
    return x
  }
  let negative = x.reinterpret_as_int64() < 0L
  let sign = if negative { -1.0 } else { 1.0 }
  let x_abs = x.abs()
  let exponent = (x_abs.reinterpret_as_int64() >> 52).to_int() - 1023
  let entry = (index : Int32) => {
    let (lo, hi) = atan_table[index]
    { hi: hi.reinterpret_as_double(), lo: lo.reinterpret_as_double(), }
  }
  let sixty_fourth = 0.015625
  if exponent < 0 {
    if exponent < -26 {
      if x == 0.0 {
        return x
      }
      // |x| < 2^-26: x minus a hair.
      return fma(0xbc90000000000000L.reinterpret_as_double(), x, x)
    }
    // k = round(64 |x|) / 64, and atan(x) = atan(k) + atan(x_r) with
    // x_r = (|x| - k) / (1 + k |x|).
    let k = nearest_integer(64.0 * x_abs)
    let index = k.to_int()
    let k = k * sixty_fourth
    let num = { hi: x_abs - k, lo: 0.0, }
    let den_hi = fma(x_abs, k, 1.0)
    let prod_hi = x_abs * k
    let prod_lo = fma(x_abs, k, -prod_hi)
    let den = { hi: den_hi, lo: 1.0 - den_hi + prod_hi + prod_lo, }
    let p = atan_eval(dd_div(num, den))
    let table = entry(index)
    let c0 = fast_two_sum(table.hi, p.hi)
    let c1 = c0.lo + (table.lo + p.lo)
    return sign * (c0.hi + c1)
  }
  let pi_over_2_hi = 0x3ff921fb54442d18L.reinterpret_as_double()
  let pi_over_2_lo = 0x3c91a62633145c07L.reinterpret_as_double()
  if exponent >= 53 {
    return fma(sign, pi_over_2_hi, sign * pi_over_2_lo)
  }
  // atan(x) = pi/2 - atan(1/|x|), with the same reduction of 1/|x|:
  // x_r = (1 - k |x|) / (|x| + k).
  let y = 1.0 / x_abs
  let k = nearest_integer(64.0 * y)
  let index = k.to_int()
  let k = k * sixty_fourth
  let den = fast_two_sum(x_abs, k)
  let num_hi = fma(-x_abs, k, 1.0)
  let prod_hi = x_abs * k
  let prod_lo = fma(x_abs, k, -prod_hi)
  let num = { hi: num_hi, lo: 1.0 - num_hi - prod_hi - prod_lo, }
  let p = atan_eval(dd_div(num, den))
  let table = entry(index)
  let c0 = fast_two_sum(-pi_over_2_hi, table.hi)
  let c1 = fast_two_sum(c0.hi, p.hi)
  let c2 = c1.lo + (c0.lo + p.lo) + (table.lo + -pi_over_2_lo)
  -sign * (c1.hi + c2)
}
