// The constants of macOS's single-precision `sinf`, `cosf`,
// `__sincosf_stret`, `tanf` and `atan2f`, as bit patterns of doubles read
// from libsystem_m (arm64). Generated; see the notes in trig.mbt.

///|
fn bits(patterns : FixedArray[Int64]) -> FixedArray[Double] {
  FixedArray::makei(patterns.length(), i => patterns[i].reinterpret_as_double())
}

///|
/// For sine and cosine: 2/pi; pi/2 in two parts; four coefficients of the
/// cosine and three of the sine on a quarter turn; five constants of the
/// product form used on large arguments.
let sin_cos : FixedArray[Double] = bits([
  0x3fe45f306dc9c883L, 0x3ff921fb54442d18L, 0x3c91a62633145c07L, 0x3ef99169fc938f4aL,
  0xbf56c07f16945df4L, 0x3fa55553c7899699L, 0xbfdffffffcb82e97L, 0xbf29943e0fc4818fL,
  0x3f811073afd145ebL, 0xbfc555545268a02aL, 0xc010a8b9fc97b22cL, 0xc00d31f4a0a55230L,
  0x402ef88f0b1250c1L, 0x400537b6744fa779L, 0x3fb39502de83d49cL,
])

///|
/// 1/pi in two parts for every binary exponent from 2^1 up: the high part
/// keeps only the bits whose product with an argument of that size is not a
/// multiple of two.
let sin_cos_scale : FixedArray[Double] = bits([
  0x3fd45f306e000000L, 0xbdeb1bbead603d8bL, 0x3fd45f306e000000L, 0xbdeb1bbead603d8bL,
  0x3fd45f306e000000L, 0xbdeb1bbead603d8bL, 0x3fd45f306e000000L, 0xbdeb1bbead603d8bL,
  0x3fd45f306e000000L, 0xbdeb1bbead603d8bL, 0x3fd45f306e000000L, 0xbdeb1bbead603d8bL,
  0x3fd45f306e000000L, 0xbdeb1bbead603d8bL, 0x3fd45f306e000000L, 0xbdeb1bbead603d8bL,
  0x3fd45f306e000000L, 0xbdeb1bbead603d8bL, 0x3fd45f306e000000L, 0xbdeb1bbead603d8bL,
  0x3fd45f306e000000L, 0xbdeb1bbead603d8bL, 0x3fd45f306e000000L, 0xbdeb1bbead603d8bL,
  0xbfc7419f24000000L, 0xbdeb1bbead603d8bL, 0xbfad067c92000000L, 0x3dc391054a7f09d6L,
  0x3f77cc1b72000000L, 0x3d9c882a53f84eb0L, 0xbf6067c91b000000L, 0xbd6bbead603d8a83L,
  0xbf09f246c7000000L, 0x3d0054a7f09d5f48L, 0xbf09f246c7000000L, 0x3d0054a7f09d5f48L,
  0xbf09f246c7000000L, 0x3d0054a7f09d5f48L, 0x3ee836e4e4000000L, 0x3d0054a7f09d5f48L,
  0xbecf246c6f000000L, 0x3ca529fc2757d1f5L, 0x3e7b727221000000L, 0xbc95ac07b1505c16L,
  0x3e7b727221000000L, 0xbc95ac07b1505c16L, 0xbe5236377d000000L, 0xbc76b01ec5417056L,
  0x3e4b939105000000L, 0x3c629fc2757d1f53L, 0xbe21b1bbeb000000L, 0x3c34fe13abe8fa9aL,
  0xbdeb1bbead000000L, 0xbc080f62a0b82b2dL, 0xbdeb1bbead000000L, 0xbc080f62a0b82b2dL,
  0x3dc391054a000000L, 0x3befc2757d1f534eL, 0x3d9c882a54000000L, 0xbb7ec54170565912L,
  0xbd6bbead60000000L, 0xbb7ec54170565912L, 0xbd6bbead60000000L, 0xbb7ec54170565912L,
  0x3d41054a7f000000L, 0x3b33abe8fa9a6ee0L, 0x3d0054a7f1000000L, 0xbb28a82e0acb223fL,
  0x3d0054a7f1000000L, 0xbb28a82e0acb223fL, 0x3ca529fc27000000L, 0x3ac5f47d4d377037L,
  0x3ca529fc27000000L, 0x3ac5f47d4d377037L, 0x3ca529fc27000000L, 0x3ac5f47d4d377037L,
  0x3c84a7f09d000000L, 0x3aa7d1f534ddc0dbL, 0x3c629fc275000000L, 0x3a8f47d4d377036eL,
  0x3c34fe13ac000000L, 0xba370565911f924fL, 0xbc2603d8a8000000L, 0xba370565911f924fL,
  0xbc080f62a1000000L, 0x3a21f534ddc0db63L, 0x3befc2757d000000L, 0x39ef534ddc0db629L,
  0xbb7ec54170000000L, 0xb99596447e493ad5L, 0xbb7ec54170000000L, 0xb99596447e493ad5L,
  0xbb7ec54170000000L, 0xb99596447e493ad5L, 0x3b33abe8fb000000L, 0xb9596447e493ad4dL,
  0x3b33abe8fb000000L, 0xb9596447e493ad4dL, 0xbb28a82e0b000000L, 0x393a6ee06db14acdL,
  0x3b0d5f47d5000000L, 0xb916447e493ad4ceL, 0xbad505c159000000L, 0xb8f911f924eb5336L,
  0x3ac5f47d4d000000L, 0x38dbb81b6c52b328L, 0x3aa7d1f535000000L, 0xb8b11f924eb53362L,
  0x3a8f47d4d3000000L, 0x38adc0db6295993cL, 0xba37056591000000L, 0xb83f924eb53361deL,
  0xba37056591000000L, 0xb83f924eb53361deL, 0x3a21f534de000000L, 0xb83f924eb53361deL,
  0x39ef534ddc000000L, 0x37db6c52b3278872L, 0x39ef534ddc000000L, 0x37db6c52b3278872L,
  0xb99596447e000000L, 0xb7b24eb53361de38L, 0xb99596447e000000L, 0xb7b24eb53361de38L,
  0x3984d37703000000L, 0x37ab6295993c4390L, 0x39634ddc0e000000L, 0xb78275a99b0ef1bfL,
])

///|
/// For sine and cosine computed together, both as products of two
/// quadratics in the squared fraction of a quarter turn.
let sin_cos_pair : FixedArray[Double] = bits([
  0xc02c3d3ee4f8713fL, 0xc020bc0396540c13L, 0xc02ef09ab49e3a5bL, 0xc02d6f5ade6c8c37L,
  0x3f24bc899499342cL, 0x3f4d9c364e9721d5L, 0x40444921a30f0d80L, 0x401d78212789bc11L,
  0x406e97264e36bd93L, 0x4062c6b9c7f88fa0L,
])

///|
/// For the tangent: the constant that rounds to an integer when added and
/// subtracted, -1, 2/pi in two parts, eight coefficients for small
/// arguments, eight constants of the product form.
let tan_consts : FixedArray[Double] = bits([
  0x4338000000000000L, 0xbff0000000000000L, 0x3fe45f306e000000L, 0xbdfb1bbead603d8bL,
  0x3f6fe5da804efbdcL, 0x3f51e9c887f6c8a1L, 0x3f8487da95c9f173L, 0x3f961eb51f86747cL,
  0x3faba586a7f44ae7L, 0x3fc1110746e09b07L, 0x3fd555555d8d8930L, 0x0000000000000000L,
  0x40151d4a014005d8L, 0x400e91f74c2eeaabL, 0xbfd609394a49adf1L, 0xbff88f856cde0b64L,
  0x3fed3764811481d2L, 0x3fe81ba4203c502dL, 0x3fedb0d5be6b368bL, 0x3fe2d17a5cc6b70bL,
])

///|
/// 2/pi in two parts for every binary exponent from 2^26 up.
let tan_scale : FixedArray[Double] = bits([
  0x3fe45f306e000000L, 0xbdfb1bbead603d8bL, 0x3fc17cc1b7000000L, 0x3dd391054a7f09d6L,
  0x3f87cc1b72000000L, 0x3dac882a53f84eb0L, 0x3f87cc1b72000000L, 0x3dac882a53f84eb0L,
  0x3f6f306dca000000L, 0xbd7bbead603d8a83L, 0xbf19f246c7000000L, 0x3d1054a7f09d5f48L,
  0xbf19f246c7000000L, 0x3d1054a7f09d5f48L, 0x3ef836e4e4000000L, 0x3d1054a7f09d5f48L,
  0xbedf246c6f000000L, 0x3cb529fc2757d1f5L, 0x3e8b727221000000L, 0xbca5ac07b1505c16L,
  0x3e8b727221000000L, 0xbca5ac07b1505c16L, 0x3e8b727221000000L, 0xbca5ac07b1505c16L,
  0xbe6236377d000000L, 0xbc86b01ec5417056L, 0xbe31b1bbeb000000L, 0x3c44fe13abe8fa9aL,
  0x3e2c9c882a000000L, 0x3c44fe13abe8fa9aL, 0xbdfb1bbead000000L, 0xbc180f62a0b82b2dL,
  0x3dd391054a000000L, 0x3bffc2757d1f534eL, 0xbdc8ddf56b000000L, 0xbb8ec54170565912L,
  0x3dac882a54000000L, 0xbb8ec54170565912L, 0xbd7bbead60000000L, 0xbb8ec54170565912L,
  0x3d51054a7f000000L, 0x3b43abe8fa9a6ee0L, 0xbd4df56b02000000L, 0x3b43abe8fa9a6ee0L,
  0x3d1054a7f1000000L, 0xbb38a82e0acb223fL, 0xbd0f56b01f000000L, 0x3b1d5f47d4d37703L,
  0x3cb529fc27000000L, 0x3ad5f47d4d377037L, 0x3cb529fc27000000L, 0x3ad5f47d4d377037L,
  0xbca5ac07b1000000L, 0xbac4170565911f92L, 0xbc86b01ec5000000L, 0xbaa05c1596447e49L,
  0xbc6ac07b15000000L, 0xba470565911f924fL, 0x3c44fe13ac000000L, 0xba470565911f924fL,
  0x3c23f84eb0000000L, 0xba470565911f924fL, 0x3bffc2757d000000L, 0x39ff534ddc0db629L,
  0xbb8ec54170000000L, 0xb9a596447e493ad5L, 0xbb8ec54170000000L, 0xb9a596447e493ad5L,
  0xbb8ec54170000000L, 0xb9a596447e493ad5L, 0xbb8ec54170000000L, 0xb9a596447e493ad5L,
  0x3b43abe8fb000000L, 0xb9696447e493ad4dL, 0x3b43abe8fb000000L, 0xb9696447e493ad4dL,
  0x3b1d5f47d5000000L, 0xb926447e493ad4ceL, 0xbae505c159000000L, 0xb90911f924eb5336L,
  0xbae505c159000000L, 0xb90911f924eb5336L, 0xbac4170566000000L, 0x38ebb81b6c52b328L,
  0xbaa05c1596000000L, 0xb8c11f924eb53362L, 0xba47056591000000L, 0xb84f924eb53361deL,
  0xba47056591000000L, 0xb84f924eb53361deL, 0xba47056591000000L, 0xb84f924eb53361deL,
  0xba2c159644000000L, 0xb84f924eb53361deL, 0x39ff534ddc000000L, 0x37eb6c52b3278872L,
  0xb9a596447e000000L, 0xb7c24eb53361de38L, 0xb9a596447e000000L, 0xb7c24eb53361de38L,
  0xb9a596447e000000L, 0xb7c24eb53361de38L, 0xb9865911f9000000L, 0xb79275a99b0ef1bfL,
  0xb9696447e5000000L, 0x378b14acc9e21c82L,
])

///|
/// For the arctangent: eight constants of a product of four quadratics and
/// its scale; the bound below which a quotient counts as zero; pi, -pi,
/// pi/2, -pi/2; the largest double that is still pi as a float rounded
/// down; 3pi/4, -3pi/4, pi/4, -pi/4.
let atan_consts : FixedArray[Double] = bits([
  0x4002609372076e2cL, 0xc00792d5bf17c0bcL, 0x40038f4c070b63c1L, 0x4015e43168d7c2b6L,
  0x3f953db49b9fcf6bL, 0xc013e370146726b3L, 0x400e4fa479729042L, 0x401ae0fb08f2dc00L,
  0x3f680bc0fe23203dL, 0x3e90000000000000L, 0x400921fb54442d18L, 0xc00921fb54442d18L,
  0x3ff921fb54442d18L, 0xbff921fb54442d18L, 0x400921fb40080000L, 0x4002d97c7f3321d2L,
  0xc002d97c7f3321d2L, 0x3fe921fb54442d18L, 0xbfe921fb54442d18L,
])
