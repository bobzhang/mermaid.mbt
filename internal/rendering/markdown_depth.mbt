// marked lexes a block quote's content as blocks again, and emphasis
// content as inline tokens again, so each level of nesting is a level of
// recursion, in marked and in the port alike (lists are not lexed inside
// here, and nest nothing). Deep nesting is refused before any label is
// lexed, well below the depth the stack of every backend takes: 800 block
// quotes lex on js, wasm-gc and native, 1600 overflow on js and wasm-gc;
// 2000 levels of emphasis lex there, 6000 do not.

///|
/// The deepest nesting of block quotes a label may have.
let max_quote_depth : Int32 = 250

///|
/// How many `*` and `_` a label may have: each level of emphasis takes
/// two at least, so this bounds its nesting at 500.
let max_emphasis_delimiters : Int32 = 1000

///|
/// Whether `text` may nest block quotes or emphasis deeper than the port
/// lexes: a line starting with more than `max_quote_depth` `>`, counting
/// the white space between them, or more than `max_emphasis_delimiters`
/// emphasis delimiters. Both bound the nesting from above (a `>` after
/// four spaces starts no quote, most `*` open nothing), which is all a
/// refusal needs.
pub fn markdown_too_deep(text : String) -> Bool {
  let mut depth = 0
  let mut delimiters = 0
  let mut at_line_start = true
  for c in text {
    if c is ('*' | '_') {
      delimiters += 1
      if delimiters > max_emphasis_delimiters {
        return true
      }
    }
    if c == '\n' {
      depth = 0
      at_line_start = true
    } else if at_line_start && c == '>' {
      depth += 1
      if depth > max_quote_depth {
        return true
      }
    } else if !(at_line_start && c is (' ' | '\t')) {
      at_line_start = false
    }
  }
  false
}

///|
fn quote_depth_error() -> LayoutError {
  LayoutError(
    "a label nests block quotes or emphasis deeper than the port lexes (more than \{max_quote_depth} quotes or \{max_emphasis_delimiters} `*` and `_`)",
  )
}

///|
/// Refuse a node whose texts could nest block quotes too deeply: its
/// label and what its shape writes besides.
fn check_node_quote_depth(node : Node) -> Unit raise LayoutError {
  let texts = [node.label]
  match node.data {
    Entity(alias_name~, attributes~) => {
      texts.push(alias_name)
      for attribute in attributes {
        texts.push(attribute.type_)
        texts.push(attribute.name)
        texts.push(attribute.comment)
      }
    }
    Requirement(name~, type_~, requirement_id~, text~, risk~, verify_method~) =>
      texts.append([name, type_, requirement_id, text, risk, verify_method])
    RequirementElement(name~, type_~, doc_ref~) =>
      texts.append([name, type_, doc_ref])
    ClassBox(text~, annotations~, members~, methods~) => {
      texts.push(text)
      texts.append(annotations)
      for line in [..members, ..methods] {
        texts.push(line.text)
      }
    }
    C4(stereotype~, ..) => texts.push(stereotype)
    KanbanItem(ticket_text~, assigned~, ..) =>
      texts.append([ticket_text, assigned])
    Usecase(stereotype~, rows~, ..) => {
      if stereotype is Some(stereotype) {
        texts.push(stereotype)
      }
      for row in rows {
        texts.append([row.0, row.1])
      }
    }
    _ => ()
  }
  if texts.iter().any(markdown_too_deep) {
    raise quote_depth_error()
  }
}

///|
/// Refuse an edge whose labels could nest block quotes too deeply.
fn check_edge_quote_depth(edge : Edge) -> Unit raise LayoutError {
  let texts = [
    edge.label,
    edge.start_label_left,
    edge.start_label_right,
    edge.end_label_left,
    edge.end_label_right,
  ]
  if texts.iter().any(markdown_too_deep) {
    raise quote_depth_error()
  }
}

///|
/// Refuse a diagram any of whose labels could nest block quotes too
/// deeply.
fn check_quote_depth(data : LayoutData) -> Unit raise LayoutError {
  for node in data.nodes {
    check_node_quote_depth(node)
  }
  for edge in data.edges {
    check_edge_quote_depth(edge)
  }
}
