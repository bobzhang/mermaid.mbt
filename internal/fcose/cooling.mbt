///|
/// The cooling factor after each cooling cycle of an incremental layout,
/// by the number of iterations it stops at (`numIter`, mermaid's default
/// 2500, in steps of 500 up to 5000), read off Chrome as bit patterns:
///
/// ```js
/// Math.max(0.3 - Math.pow(cycle, Math.log(100 * (0.3 - 0.04)) / Math.log(iterations / 100)) / 100 * 1, 0.04)
/// ```
///
/// `Math.pow` and `Math.log` are not correctly rounded in V8 and are not
/// ported; the layout refuses other schedules.
let cooling_schedules : Map[Int32, FixedArray[UInt64]] = {
  500: [
    0x3fd28f5c28f5c28f, 0x3fd098ad0e7a6bfe, 0x3fca91424593fb52, 0x3fc1375fe6a7405d,
    0x3fa47ae147ae147b,
  ],
  1000: [
    0x3fd28f5c28f5c28f, 0x3fd17e501112dc32, 0x3fd02bc92480f56e, 0x3fcd4c703662d959,
    0x3fc9eb60c02cbdfd, 0x3fc63f0a80a665f1, 0x3fc24f1bc76ca440, 0x3fbc42e3eb145e9e,
    0x3fb3756c130dbe94, 0x3fa47ae147ae147b,
  ],
  1500: [
    0x3fd28f5c28f5c28f, 0x3fd1b9fb19871b2a, 0x3fd0cccc9565e57b, 0x3fcf9d68c5b10cd7,
    0x3fcd867d0bab51a2, 0x3fcb5940a6bf5022, 0x3fc918bf72beb9ec, 0x3fc6c73788eefb9c,
    0x3fc46663275eb325, 0x3fc1f7a295d0e00f, 0x3fbef82b916e9d12, 0x3fb9e95a00c57a44,
    0x3fb4c4681ff129e6, 0x3faf156934ae685c, 0x3fa47ae147ae147b,
  ],
  2000: [
    0x3fd28f5c28f5c28f, 0x3fd1d7030ad36322, 0x3fd11609c53cae28, 0x3fd04f3d91887cbc,
    0x3fcf07fe592e4e2b, 0x3fcd6a46c6c9132e, 0x3fcbc672e70d6af6, 0x3fca1d5173849770,
    0x3fc86f7efdce5808, 0x3fc6bd766afb1133, 0x3fc5079ae22b890d, 0x3fc34e3e270d67bd,
    0x3fc191a4dc2f6b73, 0x3fbfa412f41e8f84, 0x3fbc1f3ce082b2de, 0x3fb8951f6eb28eee,
    0x3fb50607ffc929f0, 0x3fb1723b367f6932, 0x3fabb3ecc6236a88, 0x3fa47ae147ae147b,
  ],
  2500: [
    0x3fd28f5c28f5c28f, 0x3fd1e8bda42ead83, 0x3fd1410e636a7e33, 0x3fd098ad0e7a6bfe,
    0x3fcfdf8da42323da, 0x3fce8cecc0e25e4d, 0x3fcd399ad237741e, 0x3fcbe5b1098126e8,
    0x3fca91424593fb52, 0x3fc93c5d31f585a4, 0x3fc7e70d8af2d96e, 0x3fc6915ceb2041fa,
    0x3fc53b535407cd44, 0x3fc3e4f78ca4d23f, 0x3fc28e4f64cfb913, 0x3fc1375fe6a7405d,
    0x3fbfc05af737d02a, 0x3fbd11781185220c, 0x3fba621e09b7002e, 0x3fb7b253136cb734,
    0x3fb5021cc4383d1c, 0x3fb251802a2609c2, 0x3faf4103bc5a4668, 0x3fa9de4c26d64888,
    0x3fa47ae147ae147b,
  ],
  3000: [
    0x3fd28f5c28f5c28f, 0x3fd1f4f02e9c697a, 0x3fd15de1dd009155, 0x3fd0c8f8b0b90cb2,
    0x3fd035a2b8a2b596, 0x3fcf4715f85b25d9, 0x3fce24f3ab04c20a, 0x3fcd0490022c746c,
    0x3fcbe5b0a369362c, 0x3fcac82881b30f6e, 0x3fc9abd3cb5dc100, 0x3fc89095598a886c,
    0x3fc77654fded2540, 0x3fc65cfe58281f6c, 0x3fc5448001af2457, 0x3fc42ccaf2fc56a5,
    0x3fc315d20ff8991a, 0x3fc1ff89cfee19b6, 0x3fc0e9e7f949749a, 0x3fbfa9c6d7ca1468,
    0x3fbd80e7ec64eece, 0x3fbb5924654a500c, 0x3fb9326ed6f21fe8, 0x3fb70cbb06e0626a,
    0x3fb4e7fdc4f759f0, 0x3fb2c42ccb0b9402, 0x3fb0a13ea182f8f2, 0x3facfe55101b36b8,
    0x3fa8bbd0c37640b0, 0x3fa47ae147ae147b,
  ],
  3500: [
    0x3fd28f5c28f5c28f, 0x3fd1fdf84b71ac20, 0x3fd172d0c56b68fd, 0x3fd0eb8fdd983a7b,
    0x3fd0672310bf0d8a, 0x3fcfc9d8b6dea20e, 0x3fcec90a5431c783, 0x3fcdcb4b4316e1fa,
    0x3fccd0315f697716, 0x3fcbd76b263d07c2, 0x3fcae0b8166b7b36, 0x3fc9ebe3e8f8a340,
    0x3fc8f8c36b4bb584, 0x3fc80732572d01ce, 0x3fc71711cc16abf0, 0x3fc628473308bcdf,
    0x3fc53abb6af7f206, 0x3fc44e5a28189950, 0x3fc3631177a3e023, 0x3fc278d15e52a9e7,
    0x3fc18f8b8ac2b870, 0x3fc0a73316f34eaa, 0x3fbf7f78aab86da6, 0x3fbdb2394e1cf030,
    0x3fbbe694b1e92874, 0x3fba1c790d7ef216, 0x3fb853d604c8398a, 0x3fb68c9c7e9b7ee4,
    0x3fb4c6be81313628, 0x3fb3022f1399dade, 0x3fb13ee2235bbd7a, 0x3faef998db144b80,
    0x3fab77c6d5911780, 0x3fa7f83a7b8d64a0, 0x3fa47ae147ae147b,
  ],
  4000: [
    0x3fd28f5c28f5c28f, 0x3fd204ffb92a69e8, 0x3fd182dca313eebf, 0x3fd105cb1de4eb02,
    0x3fd08c5d1aaa24ae, 0x3fd015c1ce53efb3, 0x3fcf42e543a4d975, 0x3fce5e23aed3c199,
    0x3fcd7cb512e4893c, 0x3fcc9e3010aa75d0, 0x3fcbc241951d305d, 0x3fcae8a6866181ca,
    0x3fca11279d569514, 0x3fc93b9690015786, 0x3fc867cc1179f151, 0x3fc795a65e6d80e4,
    0x3fc6c50829350401, 0x3fc5f5d7c8b8b11f, 0x3fc527fe97218150, 0x3fc45b6873790972,
    0x3fc390035d482e9c, 0x3fc2c5bf23dfad6c, 0x3fc1fc8d24b825d8, 0x3fc13460158e93b3,
    0x3fc06d2bd7bd0525, 0x3fbf4dcaa5d7ee9e, 0x3fbdc304ab54f794, 0x3fbc39f2f59e16f2,
    0x3fbab2842582c7a4, 0x3fb92ca81ff9e23c, 0x3fb7a84fec7e7e54, 0x3fb6256d97e33ff4,
    0x3fb4a3f41ae58aa0, 0x3fb323d743ebe2b0, 0x3fb1a50ba3758306, 0x3fb027867ad67a38,
    0x3fad567b59d97504, 0x3faa604f6110ae30, 0x3fa76c770898c3b8, 0x3fa47ae147ae147b,
  ],
  4500: [
    0x3fd28f5c28f5c28f, 0x3fd20aab601350e7, 0x3fd18fa623d9bed0, 0x3fd11a83fcbf724c,
    0x3fd0a992dca6e503, 0x3fd03bdd0b4ae176, 0x3fcfa18a1d2879f2, 0x3fcecfbb79c31da7,
    0x3fce01ae5abd1980, 0x3fcd36e8f65a9d68, 0x3fcc6f0b94276396, 0x3fcba9c91a21dfb4,
    0x3fcae6e22cedcedc, 0x3fca2621ddd9c2cc, 0x3fc9675b5468f2a1, 0x3fc8aa681d17bed9,
    0x3fc7ef26e83bebe8, 0x3fc7357a9717013a, 0x3fc67d4980c5168e, 0x3fc5c67cdfeb21a1,
    0x3fc511005eac07cf, 0x3fc45cc1b97bab2b, 0x3fc3a9b0737893c1, 0x3fc2f7bd9861d9bd,
    0x3fc246db893f5d0d, 0x3fc196fdd18982da, 0x3fc0e81903229039, 0x3fc03a2297d57605,
    0x3fbf1a21aead664e, 0x3fbdc1b581f5ae72, 0x3fbc6aeff1000830, 0x3fbb15c16ad0004e,
    0x3fb9c21b68f2de72, 0x3fb86ff05624c640, 0x3fb71f33780be4b8, 0x3fb5cfd8db95b014,
    0x3fb481d543960656, 0x3fb3351e1957eba6, 0x3fb1e9a95edc9ffc, 0x3fb09f6da2905a06,
    0x3faeacc3e88950cc, 0x3fac1cfbb68f5348, 0x3fa98f729aea8408, 0x3fa704194e48dff8,
    0x3fa47ae147ae147b,
  ],
  5000: [
    0x3fd28f5c28f5c28f, 0x3fd20f5ea7433019, 0x3fd19a23f7110afd, 0x3fd12b650adfe208,
    0x3fd0c13ba7799197, 0x3fd05a9649bcdf51, 0x3fcfed8d06086e60, 0x3fcf2aa7c8f2b500,
    0x3fce6bcd235d02b9, 0x3fcdb07792066368, 0x3fccf83e6b59c197, 0x3fcc42cd93e18f88,
    0x3fcb8fe013fedcdb, 0x3fcadf3c69a57d1d, 0x3fca30b1f23ab5b2, 0x3fc984170c214fd2,
    0x3fc8d947b4ad81d8, 0x3fc830247cba878a, 0x3fc78891bb0b4094, 0x3fc6e276ebad97fc,
    0x3fc63dbe30c40a0a, 0x3fc59a53ec80b3be, 0x3fc4f8266e698247, 0x3fc45725af922285,
    0x3fc3b7431a948131, 0x3fc318715cdb787e, 0x3fc27aa43f663c2b, 0x3fc1ddd0859711f0,
    0x3fc141ebd0f04500, 0x3fc0a6ec88decca2, 0x3fc00cc9c5e03586, 0x3fbee6f67ee99fc2,
    0x3fbdb5f278d55306, 0x3fbc86790a46ced4, 0x3fbb587caf102b2e, 0x3fba2bf0b8d71900,
    0x3fb900c93c4dc5b8, 0x3fb7d6fb0088428a, 0x3fb6ae7b70250bfc, 0x3fb587408c0ae570,
    0x3fb46140df87bfd6, 0x3fb33c7375a43dd8, 0x3fb218cfcf85eb3a, 0x3fb0f64ddbbfabd4,
    0x3fafa9cbdce8e460, 0x3fad692174684270, 0x3fab2a8e92fb6cd4, 0x3fa8ee05f1a92df8,
    0x3fa6b37ae2b25ce0, 0x3fa47ae147ae147b,
  ],
}

///|
/// The cooling factor after `cycle` cooling cycles of a layout whose
/// iterations stop at `max_iterations`.
fn cooling_factor(
  cycle : Int32,
  max_iterations : Double,
) -> Double raise FcoseError {
  let measured = if max_iterations == max_iterations.floor() &&
    max_iterations.abs() < 1.0e9 {
    cooling_schedules.get(max_iterations.to_int())
  } else {
    None
  }
  guard measured is Some(schedule) && cycle >= 1 && cycle <= schedule.length() else {
    raise Unsupported(
      "fcose: a cooling schedule for \{max_iterations} iterations was not measured",
    )
  }
  schedule[cycle - 1].reinterpret_as_double()
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
