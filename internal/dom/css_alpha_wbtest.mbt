///|
test "alpha is written with as few decimals as give the same eight bits" {
  // Measured in the reference browser through `element.style.fill`.
  let cases = [
    (128.0 / 255.0, "0.5"),
    (136.0 / 255.0, "0.533"),
    (120.0 / 255.0, "0.47"),
    (0.333, "0.333"),
    (0.123456, "0.12"),
    (0.005, "0.004"),
    (0.0001, "0"),
    (0.25, "0.25"),
    (0.1, "0.1"),
    (0.7, "0.7"),
    (0.45, "0.45"),
    (0.335, "0.333"),
    (1.0 / 255.0, "0.004"),
    (254.0 / 255.0, "0.996"),
    (0.0, "0"),
    (0.4, "0.4"),
    (0.996, "0.996"),
    (0.4999, "0.498"),
    (0.5001, "0.5"),
    (0.12, "0.12"),
    (0.125, "0.125"),
    (0.129, "0.13"),
  ]
  for entry in cases {
    assert_eq(css_alpha(entry.0), Some(entry.1))
  }
  for solid in [1.0, 1.5, 0.999, 0.9999] {
    assert_eq(css_alpha(solid), None)
  }
}
