///|
/// A parsed pie chart.
pub struct Pie {
  /// Slices in source order. A label that appears twice keeps its first
  /// value.
  sections : Map[String, Double]
  /// Whether `showData` was given: legend entries then include the value.
  show_data : Bool
  title : String
  acc_title : String
  acc_description : String
}

///|
/// Parse pie chart source, following the Langium grammar:
///
/// ```text
/// Pie: NEWLINE* "pie" "showData"?
///      (TitleAndAccessibilities | PieSection | NEWLINE)*
/// PieSection: STRING ":" NUMBER EOL
/// ```
pub fn parse(source : String) -> Pie raise @langium.ParseError {
  let lexer = @langium.Lexer::new(source)
  while lexer.newline() {

  }
  if !lexer.keyword("pie") {
    lexer.fail("Expecting keyword 'pie'")
  }
  let show_data = lexer.keyword("showData")
  let sections : Map[String, Double] = Map([])
  let mut title = ""
  let mut acc_title = ""
  let mut acc_description = ""
  while !lexer.at_end() {
    if lexer.newline() {
      continue
    }
    if lexer.acc_descr() is Some(text) {
      acc_description = text
    } else if lexer.acc_title() is Some(text) {
      acc_title = text
    } else if lexer.title() is Some(text) {
      title = text
    } else if lexer.string() is Some(label) {
      if !lexer.symbol(":") {
        lexer.fail("Expecting token of type ':'")
      }
      guard lexer.number(signed=true) is Some(value) else {
        lexer.fail("Expecting a number")
      }
      if value < 0.0 {
        lexer.fail(
          "\"\{label}\" has invalid value: \{value}. Negative values are not allowed in pie charts. All slice values must be >= 0.",
        )
      }
      if !sections.contains(label) {
        sections[label] = value
      }
    } else {
      lexer.fail("Expecting a section, title or accessibility statement")
    }
    if !lexer.eol() {
      lexer.fail("Expecting end of line")
    }
  }
  { sections, show_data, title, acc_title, acc_description, }
}

///|
/// The same chart under another title.
pub fn Pie::with_title(self : Pie, title : String) -> Pie {
  { ..self, title, }
}
