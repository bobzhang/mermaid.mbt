// The engine is also checked differentially against JavaScript on every
// lexer rule of mermaid's grammars; these cases document the semantics.

///|
fn prefix(
  source : String,
  input : String,
  flags~ : String = "",
) -> String raise {
  match @jsregex.Regex::compile(source, flags~).match_prefix(input) {
    Some(found) => "[\{found.text()}]"
    None => "no match"
  }
}

///|
test "literals, classes and quantifiers" {
  inspect(prefix("abc", "abcd"), content="[abc]")
  inspect(prefix("abc", "xabc"), content="no match")
  inspect(prefix("[a-c]+\\d*", "abca12!"), content="[abca12]")
  inspect(prefix("[^\\s\"]+", "word next"), content="[word]")
  inspect(prefix("a{2,3}", "aaaa"), content="[aaa]")
  inspect(prefix("a{2}", "a"), content="no match")
  inspect(prefix("x{y", "x{y"), content="[x{y]")
  inspect(prefix(".*", "one\ntwo"), content="[one]")
  inspect(prefix("\\u0041\\x42\\t", "AB\tC"), content="[AB\t]")
}

///|
test "alternatives are tried in order, quantifiers backtrack" {
  inspect(prefix("a|ab", "ab"), content="[a]")
  inspect(prefix("(?:a|ab)c", "abc"), content="[abc]")
  inspect(prefix("a*ab", "aaab"), content="[aaab]")
  inspect(prefix("a+?", "aaa"), content="[a]")
  inspect(prefix("<.*?>", "<a><b>"), content="[<a>]")
  inspect(prefix("(?:a*)*b", "aaab"), content="[aaab]")
}

///|
test "assertions" {
  inspect(prefix("end\\b\\s*", "end  x"), content="[end  ]")
  inspect(prefix("end\\b", "ending"), content="no match")
  inspect(prefix("\\-(?!\\-)+", "-x"), content="[-]")
  inspect(prefix("\\-(?!\\-)+", "--"), content="no match")
  inspect(prefix("[^\\s\"]+@(?=[^\\{\"])", "id@x"), content="[id@]")
  inspect(prefix("[^\\s\"]+@(?=[^\\{\"])", "id@{"), content="no match")
  inspect(prefix("^(?:a)$", "a"), content="[a]")
}

///|
test "case-insensitive matching" {
  inspect(prefix("flowchart", "FlowChart TD", flags="i"), content="[FlowChart]")
  inspect(prefix("[a-c]+", "ABCd", flags="i"), content="[ABC]")
  inspect(prefix("flowchart", "FlowChart TD"), content="no match")
}

///|
test "a prefix match sees nothing before its start" {
  let regex = @jsregex.Regex::compile("\\bend")
  // As a prefix of the tail, `\b` holds even though `p` precedes it.
  inspect(regex.match_prefix("append", from=3) is Some(_), content="true")
  // Searching the whole string, it does not.
  inspect(regex.exec("append") is Some(_), content="false")
}

///|
test "search, groups, replace and split" {
  let regex = @jsregex.Regex::compile("(\\w+)=(\\d+)?")
  guard regex.exec("  width=42 height=") is Some(found) else {
    fail("expected a match")
  }
  debug_inspect((found.start, found.end), content="(2, 10)")
  inspect(found.text(), content="width=42")
  debug_inspect(
    (found.group(1), found.group(2), found.group(3)),
    content=(
      #|(Some("width"), Some("42"), None)
    ),
  )
  inspect(
    regex.replace_all("a=1 b= c=3", m => "<" + m.group(1).unwrap_or("") + ">"),
    content="<a> <b> <c>",
  )
  inspect(
    @jsregex.Regex::compile("\\r\\n?").replace_all("a\r\nb\rc", _ => "\n"),
    content="a\nb\nc",
  )
  inspect(
    @jsregex.Regex::compile("x").replace("axbxc", _ => "-"),
    content="a-bxc",
  )
  debug_inspect(
    @jsregex.Regex::compile("\\s*,\\s*").split("a , b,c"),
    content=(
      #|["a", "b", "c"]
    ),
  )
  inspect(@jsregex.Regex::compile("^\\s*pie").matches("  pie"), content="true")
}

///|
test "invalid patterns are rejected" {
  try @jsregex.Regex::compile("(a") catch {
    error => debug_inspect(error, content="RegexError(\"unterminated group\")")
  } noraise {
    _ => fail("expected an error")
  }
  try @jsregex.Regex::compile("a)") catch {
    error => debug_inspect(error, content="RegexError(\"unmatched )\")")
  } noraise {
    _ => fail("expected an error")
  }
}
