// Cases follow upstream's comments.spec.ts, frontmatter.spec.ts and
// regexes.spec.ts.

///|
test "cleanup_comments removes comment lines" {
  let text =
    #|
    #|%% This is a comment
    #|%% This is another comment
    #|graph TD
    #|    A-->B
    #|%% This is a comment
    #|
  inspect(
    cleanup_comments(text),
    content=(
      #|graph TD
      #|    A-->B
      #|
    ),
  )
}

///|
test "cleanup_comments keeps init directives" {
  let text =
    #|
    #|%% This is a comment
    #|%%{init: {'theme': 'forest'}}%%
    #|%%{ init: {'theme': 'space before init'}}%%
    #|graph TD
    #|    A-->B
    #|    %% indented comment
    #|    B-->C
    #|%% no newline at the end
  inspect(
    cleanup_comments(text),
    content=(
      #|%%{init: {'theme': 'forest'}}%%
      #|%%{ init: {'theme': 'space before init'}}%%
      #|graph TD
      #|    A-->B
      #|    B-->C
      #|
    ),
  )
}

///|
test "strip_any_comments" {
  inspect(
    strip_any_comments("graph TD %% trailing\n  A-->B\n%% whole line\nC"),
    content=(
      #|graph TD
      #|  A-->B
      #|C
    ),
  )
  inspect(
    strip_any_comments("no comment %% unterminated"),
    content="no comment %% unterminated",
  )
}

///|
test "frontmatter is split off and parsed" {
  let front = extract_front_matter("---\ntitle: foo\n---\nbar")
  debug_inspect((front.text, front.title), content="(\"bar\", Some(\"foo\"))")
  // No frontmatter: the text is untouched.
  let front = extract_front_matter("bar\n---\ntitle: foo\n---")
  inspect(front.text, content="bar\n---\ntitle: foo\n---")
  inspect(front.title is None, content="true")
  // Indented fences, numeric title, display mode and nested config.
  let front = extract_front_matter(
    "  ---\n  title: 123\n  displayMode: compact\n  config:\n    theme: forest\n    pie:\n      textPosition: 0.5\n  ---\npie",
  )
  inspect(front.text, content="pie")
  debug_inspect(
    (front.title, front.display_mode),
    content="(Some(\"123\"), Some(\"compact\"))",
  )
  json_inspect(front.config, content=[
    { "theme": "forest", "pie": { "textPosition": 0.5 } },
  ])
  // Dashes inside the body do not end the block.
  let front = extract_front_matter("---\ntitle: a --- b\n---\n\n\nrest")
  debug_inspect(
    (front.text, front.title),
    content="(\"rest\", Some(\"a --- b\"))",
  )
}

///|
test "invalid frontmatter YAML raises" {
  try extract_front_matter("---\n- a\n b: [\n---\nbar") catch {
    _ => ()
  } noraise {
    _ => fail("expected to raise")
  }
}

///|
test "directives are found and removed" {
  let text = "%%{init: {'theme': 'dark', 'pie': {'textPosition': 0.2}}}%%\npie\n  \"a\": 1\n%%{wrap}%%\n"
  inspect(remove_directives(text), content="\npie\n  \"a\": 1\n\n")
  json_inspect(detect_init(text), content=[
    { "theme": "dark", "pie": { "textPosition": 0.2 } },
  ])
  inspect(has_wrap_directive(text), content="true")
  inspect(has_wrap_directive("pie"), content="false")
  inspect(detect_init("pie") is None, content="true")
  // Several init directives merge; `initialize` is accepted too.
  json_inspect(
    detect_init(
      "%%{init: {'theme': 'dark'}}%%\n%%{initialize: {'logLevel': 2}}%%\ngraph TD",
    ),
    content=[{ "theme": "dark", "logLevel": 2 }],
  )
  // A `config` key moves to the section of the detected diagram.
  json_inspect(
    detect_init(
      "%%{init: {'config': {'htmlLabels': false}}}%%\nflowchart TD\n A-->B",
    ),
    content=[{ "flowchart": { "htmlLabels": false } }],
  )
  // Broken JSON yields nothing rather than an error.
  inspect(detect_init("%%{init: {'theme': }}%%\npie") is None, content="true")
}

///|
test "cleanup_text normalizes line endings and tag quotes" {
  inspect(
    cleanup_text("a\r\nb\rc <span class=\"x\" id=\"y\">t</span> 1 < 2"),
    content="a\nb\nc <span class='x' id='y'>t</span> 1 < 2",
  )
}

///|
test "detect_type looks past frontmatter, directives and comments" {
  inspect(
    detect_type("---\ntitle: x\n---\n%%{init: {}}%%\n%% hi\n  pie\n \"a\": 1"),
    content="pie",
  )
  inspect(detect_type("graph TD\nA-->B"), content="flowchart-v2")
  inspect(detect_type("flowchart-elk TD\nA-->B"), content="flowchart-elk")
  inspect(detect_type("sequenceDiagram\nA->>B: hi"), content="sequence")
  inspect(detect_type("stateDiagram-v2\n[*] --> A"), content="stateDiagram")
  inspect(detect_type("C4Context\n"), content="c4")
  inspect(detect_type("Ishikawa-Beta\n"), content="ishikawa")
  inspect(detect_type("ERROR"), content="error")
  try detect_type("nonsense") catch {
    error =>
      debug_inspect(
        error,
        content=(
          #|UnknownDiagramError("No diagram type detected matching given configuration for text: nonsense")
        ),
      )
  } noraise {
    _ => fail("expected to raise")
  }
}

///|
test "preprocess merges frontmatter config with the init directive" {
  let diagram = preprocess(
    "---\ntitle: My pie\nconfig:\n  theme: forest\n  pie:\n    textPosition: 0.5\n---\n%%{init: {'pie': {'donutHole': 0.3}}}%%\n%% comment\npie\n  \"a\": 1\n",
  )
  inspect(diagram.code, content="pie\n  \"a\": 1\n")
  debug_inspect(diagram.title, content="Some(\"My pie\")")
  json_inspect(diagram.config, content={
    "theme": "forest",
    "pie": { "textPosition": 0.5, "donutHole": 0.3 },
  })
}
