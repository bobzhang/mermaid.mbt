///|
test "the functions agree with macOS's libm" {
  // The cases are bit patterns of arguments and of what the library
  // returned for them.
  let failures = []
  let same = (got : Float, want : UInt32) => {
    got.reinterpret_as_uint() == want ||
    // Every NaN is as good as another.
    (got != got && (want & 0x7fffffff) > 0x7f800000)
  }
  for case in unary_cases {
    let (bits, sine, cosine, cosine_alone, tangent) = case
    let x = Float::reinterpret_from_uint(bits)
    let (s, c) = sincosf(x)
    if !same(s, sine) || !same(c, cosine) {
      failures.push("sincosf \{bits}")
    }
    if !same(cosf(x), cosine_alone) {
      failures.push("cosf \{bits}")
    }
    if !same(tanf(x), tangent) {
      failures.push("tanf \{bits}")
    }
  }
  for case in atan2_cases {
    let (y, x, angle) = case
    let got = atan2f(
      Float::reinterpret_from_uint(y),
      Float::reinterpret_from_uint(x),
    )
    if !same(got, angle) {
      failures.push("atan2f \{y} \{x}")
    }
  }
  json_inspect(failures, content=[])
}

///|
test "fused multiply-add rounds once" {
  // Operands and the result of the processor's instruction, as bit
  // patterns: unrelated operands, sums that cancel, and ties.
  let failures = []
  for case in fma_cases {
    let (a, b, c, want) = case
    let got = fma(
      a.reinterpret_as_double(),
      b.reinterpret_as_double(),
      c.reinterpret_as_double(),
    )
    if got.reinterpret_as_int64() != want {
      failures.push((a, b, c))
    }
  }
  json_inspect(failures.length(), content=0)
}
