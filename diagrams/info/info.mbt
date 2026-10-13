///|
/// The mermaid version this port reproduces, shown by the info diagram.
pub const VERSION : String = "12.2.0"

///|
/// Check that `source` is a valid info diagram. Nothing in it affects the
/// drawing: upstream's info diagram keeps no title or accessibility text.
///
/// ```text
/// Info: NEWLINE* "info" NEWLINE* ("showInfo" NEWLINE*)?
///       TitleAndAccessibilities?
/// ```
pub fn parse(source : String) -> Unit raise @langium.ParseError {
  let lexer = @langium.Lexer::new(source)
  while lexer.newline() {

  }
  if !lexer.keyword("info") {
    lexer.fail("Expecting keyword 'info'")
  }
  while lexer.newline() {

  }
  if lexer.keyword("showInfo") {
    while lexer.newline() {

    }
  }
  while !lexer.at_end() {
    if lexer.acc_descr() is None &&
      lexer.acc_title() is None &&
      lexer.title() is None {
      lexer.fail("Expecting end of input")
    }
    if !lexer.eol() {
      lexer.fail("Expecting end of line")
    }
  }
}

///|
/// Draw the version banner.
pub fn draw(context : @diagram.Context) -> Unit {
  let svg = context.svg
  @diagram.configure_svg_size(svg, 100.0, 400.0, true)
  svg
  .append("g")
  .append("text")
  .attr_number("x", 100.0)
  .attr_number("y", 40.0)
  .attr("class", "version")
  .attr_number("font-size", 32.0)
  .style("text-anchor", "middle")
  .text("v\{VERSION}")
  |> ignore
}
