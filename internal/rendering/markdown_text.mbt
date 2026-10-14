///|
/// The words of a markdown label without their formatting, a newline
/// between its lines: what diagrams read out as the accessible name of a
/// markdown label (`markdownToLines`, the words of a line joined by
/// spaces).
pub fn markdown_plain_text(markdown : String) -> String {
  markdown_to_lines(markdown)
  .map(line => line.map(word => word.content).join(" "))
  .join("\n")
}
