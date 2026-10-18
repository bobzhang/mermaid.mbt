// Markdown labels: mermaid's `markdownToHTML`, which keeps paragraphs,
// emphasis, escapes and inline HTML of what marked's lexer finds and
// passes everything else through as written. The lexer is in `marked.mbt`.

///|
/// An inline token of marked's lexer, as far as labels need them.
priv enum MdToken {
  MdText(String)
  MdStrong(Array[MdToken])
  MdEm(Array[MdToken])
  /// Inline HTML, kept as written.
  MdHtml(String)
  /// A character behind a backslash.
  MdEscape(Char)
  /// Anything else (code spans, links, line breaks, strikethroughs):
  /// written out as it stands in HTML labels and left out of text labels.
  MdRaw(String)
}

///|
/// A block of markdown: a paragraph, white space between blocks, or
/// anything else as raw text.
priv enum MdBlock {
  Paragraph(Array[MdToken])
  Space(String)
  Raw(String)
}

///|
/// Inline tokens as the HTML of a label.
fn tokens_to_html(
  tokens : Array[MdToken],
  auto_wrap : Bool,
  out : StringBuilder,
) -> Unit {
  for token in tokens {
    match token {
      MdText(text) => {
        // Line breaks, with the indentation after them, become `<br/>`.
        let chars = text.to_array()
        let mut i = 0
        while i < chars.length() {
          if chars[i] == '\n' {
            out.write_string("<br/>")
            i += 1
            while i < chars.length() && chars[i] == ' ' {
              i += 1
            }
          } else {
            if chars[i] == ' ' && !auto_wrap {
              out.write_string("&nbsp;")
            } else {
              out.write_char(chars[i])
            }
            i += 1
          }
        }
      }
      MdStrong(inner) => {
        out.write_string("<strong>")
        tokens_to_html(inner, auto_wrap, out)
        out.write_string("</strong>")
      }
      MdEm(inner) => {
        out.write_string("<em>")
        tokens_to_html(inner, auto_wrap, out)
        out.write_string("</em>")
      }
      MdHtml(text) | MdRaw(text) => out.write_string(text)
      MdEscape(c) => out.write_char(c)
    }
  }
}

///|
/// Markdown to the HTML of a label.
fn markdown_to_html(markdown : String, auto_wrap : Bool) -> String {
  let out = StringBuilder()
  for block in markdown_blocks(markdown) {
    match block {
      Paragraph(tokens) => {
        out.write_string("<p>")
        tokens_to_html(tokens, auto_wrap, out)
        out.write_string("</p>")
      }
      Raw(text) => out.write_string(text)
      Space(_) => ()
    }
  }
  out.to_string()
}
