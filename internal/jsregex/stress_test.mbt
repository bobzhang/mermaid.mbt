///|
test "every pattern of the port on long repetitive subjects" {
  // `patterns` is written by scripts/gen_regex_stress.py. Each is matched
  // against a few thousand code units repeating one piece: a line of each
  // kind of markdown block, white space, and every character the pattern
  // names, so that each repeated construct iterates as far as it can.
  let pieces = [
    "a", " ", "\n", "\t", "a ", "a\n", "> a\n", "    code\n", "- a\n", "1. a\n",
    "|a|b|\n", "# h\n", "a\n===\n", "<b>", "**", "%%", "\"a\" ", "a:b;", "\\a",
  ]
  for pattern in patterns {
    let (source, flags) = pattern
    let regex = try! @jsregex.Regex::compile(source, flags~)
    let named = []
    for c in source {
      let piece = c.to_string()
      if !named.contains(piece) && named.length() < 24 {
        named.push(piece)
      }
    }
    for piece in [..pieces, ..named] {
      let subject = piece.repeat(4000 / piece.length() + 1)
      ignore(regex.match_prefix(subject))
      ignore(regex.match_prefix(piece + subject))
    }
  }
}
