///|
test "wrap_text breaks at white space only" {
  inspect(wrap_text("Too dark", 15), content="Too dark")
  inspect(
    wrap_text("Protective film not removed", 15),
    content="Protective film\nnot removed",
  )
  // A long word stays whole, and never shares a line it does not fit on.
  inspect(
    wrap_text("a Supercalifragilistic word", 15),
    content="a\nSupercalifragilistic\nword",
  )
  // Short text is kept as written, runs of blanks included.
  inspect(wrap_text("a   b", 15), content="a   b")
}

///|
test "collapse_lines treats the lines as one run of text" {
  debug_inspect(collapse_lines(["foo ", " bar"]), content="[\"foo \", \"bar\"]")
  debug_inspect(collapse_lines(["foo", " bar "]), content="[\"foo\", \" bar\"]")
  debug_inspect(
    collapse_lines([" a  b", "", " "]),
    content="[\"a b\", \"\", \"\"]",
  )
  debug_inspect(
    collapse_lines(["a ", " ", " b"]),
    content="[\"a \", \"\", \"b\"]",
  )
}

///|
/// The tree as an outline, one node per line, indented by depth.
fn outline(source : String) -> String raise {
  let out = StringBuilder()
  fn visit(node : Node, depth : Int32) -> Unit {
    out.write_string("  ".repeat(depth) + node.text + "\n")
    for child in node.children {
      visit(child, depth + 1)
    }
  }

  if parse(source).root is Some(root) {
    visit(root, 0)
  }
  out.to_string()
}

///|
test "causes are levelled relative to the first cause" {
  // The effect's own indentation does not count, and a cause indented
  // less than the first one is a main cause all the same.
  let source =
    #|ishikawa-beta
    #|        Effect
    #|    Cause A
    #|        Sub
    #|  Dedented
    #|            Jump
    #|    Cause C
    #|
  inspect(
    outline(source),
    content=(
      #|Effect
      #|  Cause A
      #|    Sub
      #|  Dedented
      #|    Jump
      #|  Cause C
      #|
    ),
  )
}

///|
test "comments, blank lines and the keyword's spellings" {
  let source =
    #|%% a comment
    #|
    #|Ishikawa
    #|    Effect %% kept
    #|    %% dropped
    #|    Cause
    #|
    #|        Sub
    #|
  inspect(
    outline(source),
    content=(
      #|Effect %% kept
      #|  Cause
      #|    Sub
      #|
    ),
  )
  // The keyword is a token wherever a line starts with it.
  let rejected = try
    parse("ishikawa-beta\n    Effect\n    Ishikawa method\n")
  catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(rejected, content="true")
}
