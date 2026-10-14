///|
/// jison's `less(n)`: keep the first `n` characters of the current token
/// and hand the rest back to the input, to be matched again.
pub fn Lexer::less(self : Lexer, n : Int32) -> Unit {
  let text = self.yytext
  guard n >= 0 && n < text.length() else { return }
  let returned = text[n:].to_owned()
  for c in returned {
    if c == '\n' {
      self.yylineno -= 1
    }
  }
  self.yytext = text[:n].to_owned()
  self.position -= returned.length()
}
