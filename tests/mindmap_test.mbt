///|
test "mindmap" {
  json_inspect(mismatches("mindmap"), content=[])
}

///|
/// The error the port renders `source` with, as text.
fn refusal(source : String) -> String {
  try @mermaid.render(source) catch {
    Unsupported(message) => "Unsupported: \{message}"
    error => "other: \{Repr(error)}"
  } noraise {
    _ => "rendered"
  }
}

///|
test "mindmaps the port refuses rather than draw differently" {
  // Text the embedded fonts cannot measure, as the browser would draw it
  // from a system font.
  inspect(
    refusal("mindmap\n  root[東京]\n"),
    content="Unsupported: the character 東 has no embedded font to measure it with: 東京",
  )
  // An emoji is measured in HTML labels, not in SVG text, which takes the
  // height of the font it is drawn from.
  inspect(
    refusal(
      "---\nconfig:\n  htmlLabels: false\n---\nmindmap\n  root[a 😀 b]\n",
    ),
    content="Unsupported: the character 😀 has no embedded font to measure it with: a 😀 b",
  )
  // An emoji sequence is drawn as one glyph.
  inspect(
    refusal("mindmap\n  root[thumbs 👍🏽]\n"),
    content="Unsupported: the character 🏽 has no embedded font to measure it with: thumbs 👍🏽",
  )
  // Subscripts and superscripts change the height of their line.
  inspect(
    refusal("mindmap\n  root[H<sub>2</sub>O]\n"),
    content="Unsupported: subscripts and superscripts in mindmap labels are not measured: H<sub>2</sub>O",
  )
  inspect(
    refusal("---\nconfig:\n  look: handDrawn\n---\nmindmap\n  root\n"),
    content="Unsupported: The hand-drawn look is not supported yet.",
  )
  inspect(
    refusal("---\nconfig:\n  layout: dagre\n---\nmindmap\n  root\n"),
    content="Unsupported: The dagre layout is not supported yet.",
  )
}
