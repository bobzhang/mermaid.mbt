///|
/// The cooling factor after each cooling cycle of an incremental layout
/// of up to 500 nodes run for 2500 iterations (`numIter`, mermaid's
/// default), read off Chrome as bit patterns:
///
/// ```js
/// Math.max(0.3 - Math.pow(cycle, Math.log(100 * (0.3 - 0.04)) / Math.log(25)) / 100 * 1, 0.04)
/// ```
///
/// `Math.pow` and `Math.log` are not correctly rounded in V8 and are not
/// ported; the layout refuses other schedules.
let cooling_schedule_2500 : FixedArray[UInt64] = [
  0x3fd28f5c28f5c28f, 0x3fd1e8bda42ead83, 0x3fd1410e636a7e33, 0x3fd098ad0e7a6bfe,
  0x3fcfdf8da42323da, 0x3fce8cecc0e25e4d, 0x3fcd399ad237741e, 0x3fcbe5b1098126e8,
  0x3fca91424593fb52, 0x3fc93c5d31f585a4, 0x3fc7e70d8af2d96e, 0x3fc6915ceb2041fa,
  0x3fc53b535407cd44, 0x3fc3e4f78ca4d23f, 0x3fc28e4f64cfb913, 0x3fc1375fe6a7405d,
  0x3fbfc05af737d02a, 0x3fbd11781185220c, 0x3fba621e09b7002e, 0x3fb7b253136cb734,
  0x3fb5021cc4383d1c, 0x3fb251802a2609c2, 0x3faf4103bc5a4668, 0x3fa9de4c26d64888,
  0x3fa47ae147ae147b,
]

///|
/// The cooling factor after `cycle` cooling cycles of a layout whose
/// iterations stop at `max_iterations`.
fn cooling_factor(
  cycle : Int32,
  max_iterations : Int32,
) -> Double raise FcoseError {
  guard max_iterations == 2500 && cycle >= 1 && cycle <= 25 else {
    raise Unsupported(
      "fcose: a cooling schedule for \{max_iterations} iterations was not measured",
    )
  }
  cooling_schedule_2500[cycle - 1].reinterpret_as_double()
}

///|
/// mermaid's `withSeededRandom`: `Math.random` as mulberry32, restarted
/// with the seed for every run of the layout.
priv struct Random {
  mut state : UInt32
}

///|
fn Random::next(self : Random) -> Double {
  self.state = self.state + 0x6d2b79f5U
  let mut t = self.state.reinterpret_as_int()
  t = (t ^ (t.reinterpret_as_uint() >> 15).reinterpret_as_int()) * (t | 1)
  t = t ^
    (t + (t ^ (t.reinterpret_as_uint() >> 7).reinterpret_as_int()) * (t | 61))
  (t ^ (t.reinterpret_as_uint() >> 14).reinterpret_as_int())
  .reinterpret_as_uint()
  .to_double() /
  4294967296.0
}
