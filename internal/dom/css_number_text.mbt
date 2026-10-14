///|
/// A number as the CSSOM serializes it in a declaration (`fill-opacity`,
/// a unitless `stroke-width`, ...): six significant digits.
pub fn css_number_text(value : Double) -> String {
  css_number(value)
}
