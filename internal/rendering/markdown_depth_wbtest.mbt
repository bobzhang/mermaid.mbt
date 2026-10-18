///|
fn lex_outcome(markdown : String) -> String {
  try {
    ignore(markdown_to_html(markdown, true))
    "lexed"
  } catch {
    LayoutError(_) => "refused"
    _ => "other"
  }
}

///|
test "how deep block quotes and emphasis may nest" {
  inspect(lex_outcome(">".repeat(250) + " a"), content="lexed")
  inspect(lex_outcome(">".repeat(251) + " a"), content="refused")
  inspect(lex_outcome("x\n" + "> ".repeat(251) + "a"), content="refused")
  inspect(lex_outcome(">".repeat(3000) + " a"), content="refused")
  // A carriage return ends a line as a line feed does.
  inspect(lex_outcome("x\r" + ">".repeat(3000) + " a"), content="refused")
  // What only looks deep is lexed: a `>` inside a line, a thousand
  // separate quotes, many delimiters that nest nothing.
  inspect(lex_outcome("a " + ">".repeat(3000)), content="lexed")
  inspect(lex_outcome("> a\n".repeat(3000)), content="lexed")
  inspect(lex_outcome("**b** c ".repeat(2000)), content="lexed")
  inspect(lex_outcome("***\n".repeat(1000)), content="lexed")
  // Two `*` on each side open a level of emphasis; `*_` runs nest none.
  inspect(lex_outcome("*".repeat(900) + "a" + "*".repeat(900)), content="lexed")
  inspect(
    lex_outcome("*".repeat(3000) + "a" + "*".repeat(3000)),
    content="refused",
  )
  inspect(
    lex_outcome("*_".repeat(3000) + "a" + "_*".repeat(3000)),
    content="lexed",
  )
}
