///|
/// Why an architecture diagram cannot be rendered.
pub(all) suberror ArchitectureError {
  /// The diagram is invalid, with upstream's message.
  Invalid(String)
  /// What the port cannot reproduce exactly and therefore refuses.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// A `group` statement.
priv struct GroupStatement {
  id : String
  icon : String?
  title : String?
  parent : String?
}

///|
/// A `service` statement.
priv struct ServiceStatement {
  id : String
  icon : String?
  icon_text : String?
  title : String?
  parent : String?
}

///|
/// A `junction` statement.
priv struct JunctionStatement {
  id : String
  parent : String?
}

///|
/// The statements of a diagram, by kind: the AST, whose lists the database
/// is filled from one kind after the other.
priv struct Statements {
  groups : Array[GroupStatement]
  services : Array[ServiceStatement]
  junctions : Array[JunctionStatement]
  edges : Array[Edge]
  alignments : Array[LayoutHint]
  mut title : String
  mut acc_title : String
  mut acc_description : String
}

///|
/// Langium's conversion of a `STRING`: the quotes go and a backslash
/// escapes the character after it.
fn convert_string(text : String) -> String {
  let out = StringBuilder()
  let chars = text.to_array()
  let mut i = 1
  while i < chars.length() - 1 {
    let c = chars[i]
    if c == '\\' {
      i += 1
      let escaped = if i < chars.length() { chars[i] } else { '\\' }
      out.write_char(
        match escaped {
          'b' => '\b'
          'f' => '\u{c}'
          'n' => '\n'
          'r' => '\r'
          't' => '\t'
          'v' => '\u{b}'
          '0' => '\u{0}'
          other => other
        },
      )
    } else {
      out.write_char(c)
    }
    i += 1
  }
  out.to_string()
}

///|
/// The value converter of `ARCH_ICON`: `input.replace(/[()]/g, '').trim()`.
fn convert_icon(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    if c != '(' && c != ')' {
      out.write_char(c)
    }
  }
  js_trim(out.to_string())
}

///|
/// The value converter of `ARCH_TITLE`: the brackets go, then outer quotes
/// of either kind, with escaped quotes inside them unescaped.
fn convert_title(text : String) -> String {
  // `input.replace(/^\[|]$/g, '').trim()`
  let inner = text[1:text.length() - 1].to_owned()
  let result = js_trim(inner)
  let quoted = result.length() >= 2 &&
    (
      (result.has_prefix("\"") && result.has_suffix("\"")) ||
      (result.has_prefix("'") && result.has_suffix("'"))
    )
  if !quoted {
    // `startsWith` and `endsWith` also hold for a lone quote.
    if result == "\"" || result == "'" {
      return ""
    }
    return result
  }
  let unquoted = result[1:result.length() - 1]
    .to_owned()
    .replace_all(old="\\\"", new="\"")
    .replace_all(old="\\'", new="'")
  js_trim(unquoted)
}

///|
/// White space as `String.prototype.trim` sees it.
fn is_js_space(c : Char) -> Bool {
  match c.to_int() {
    0x09
    | 0x0a
    | 0x0b
    | 0x0c
    | 0x0d
    | 0x20
    | 0xa0
    | 0x1680
    | 0x2028
    | 0x2029
    | 0x202f
    | 0x205f
    | 0x3000
    | 0xfeff => true
    code => code >= 0x2000 && code <= 0x200a
  }
}

///|
/// `String.prototype.trim`.
fn js_trim(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_js_space(chars[start]) {
    start += 1
  }
  while end > start && is_js_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
/// The grammar's `EOL: NEWLINE+ | EOF`.
fn eol(tokens : @langium.TokenStream) -> Unit raise @langium.ParseError {
  if tokens.at("EOF") {
    return
  }
  tokens.expect("NEWLINE") |> ignore
  while tokens.accept("NEWLINE") is Some(_) {

  }
}

///|
/// The grammar's `('in' in=ID)?`.
fn parent(tokens : @langium.TokenStream) -> String? raise @langium.ParseError {
  guard tokens.accept("in") is Some(_) else { return None }
  Some(tokens.expect("ID").text)
}

///|
/// The grammar's `Edge` after its left-hand id.
fn edge(
  tokens : @langium.TokenStream,
  lhs_id : String,
) -> Edge raise @langium.ParseError {
  let lhs_group = tokens.accept("ARROW_GROUP") is Some(_)
  tokens.expect(":") |> ignore
  let lhs_dir = tokens.expect("ARROW_DIRECTION").text
  let lhs_into = tokens.accept("ARROW_INTO") is Some(_)
  let title = if tokens.accept("--") is Some(_) {
    None
  } else {
    tokens.expect("-") |> ignore
    let title = convert_title(tokens.expect("ARCH_TITLE").text)
    tokens.expect("-") |> ignore
    Some(title)
  }
  let rhs_into = tokens.accept("ARROW_INTO") is Some(_)
  let rhs_dir = tokens.expect("ARROW_DIRECTION").text
  tokens.expect(":") |> ignore
  let rhs_id = tokens.expect("ID").text
  let rhs_group = tokens.accept("ARROW_GROUP") is Some(_)
  eol(tokens)
  {
    lhs_id,
    lhs_dir: direction_of(lhs_dir),
    lhs_into,
    lhs_group,
    rhs_id,
    rhs_dir: direction_of(rhs_dir),
    rhs_into,
    rhs_group,
    title,
  }
}

///|
/// Parse the statements of an architecture diagram, following the Langium
/// grammar:
///
/// ```text
/// Architecture: NEWLINE* "architecture-beta"
///   (NEWLINE | TitleAndAccessibilities | Statement)*
/// Group: 'group' ID ARCH_ICON? ARCH_TITLE? ('in' ID)? EOL
/// Service: 'service' ID (STRING | ARCH_ICON)? ARCH_TITLE? ('in' ID)? EOL
/// Junction: 'junction' ID ('in' ID)? EOL
/// Edge: ID ARROW_GROUP? ':' ARROW_DIRECTION ARROW_INTO?
///   ('--' | '-' ARCH_TITLE '-') ARROW_INTO? ARROW_DIRECTION ':' ID
///   ARROW_GROUP? EOL
/// Alignment: 'align' ('row' | 'column') ID ID+ EOL
/// ```
fn statements(source : String) -> Statements raise @langium.ParseError {
  let tokens = @langium.TokenStream::new(
    @langium.tokenize(source, token_types),
    source.length(),
  )
  while tokens.accept("NEWLINE") is Some(_) {

  }
  tokens.expect("architecture-beta") |> ignore
  let result : Statements = {
    groups: [],
    services: [],
    junctions: [],
    edges: [],
    alignments: [],
    title: "",
    acc_title: "",
    acc_description: "",
  }
  while !tokens.at("EOF") {
    match tokens.peek() {
      "NEWLINE" => tokens.accept("NEWLINE") |> ignore
      "ACC_DESCR" | "ACC_TITLE" | "TITLE" as kind => {
        let lexer = @langium.Lexer::new(tokens.expect(kind).text)
        // A later statement of a kind replaces an earlier one.
        match kind {
          "ACC_DESCR" =>
            result.acc_description = lexer.acc_descr().unwrap_or("")
          "ACC_TITLE" => result.acc_title = lexer.acc_title().unwrap_or("")
          _ => result.title = lexer.title().unwrap_or("")
        }
        eol(tokens)
      }
      "group" => {
        tokens.expect("group") |> ignore
        let id = tokens.expect("ID").text
        let icon = tokens
          .accept("ARCH_ICON")
          .map(token => convert_icon(token.text))
        let title = tokens
          .accept("ARCH_TITLE")
          .map(token => convert_title(token.text))
        let parent = parent(tokens)
        eol(tokens)
        result.groups.push({ id, icon, title, parent, })
      }
      "service" => {
        tokens.expect("service") |> ignore
        let id = tokens.expect("ID").text
        let mut icon = None
        let mut icon_text = None
        if tokens.accept("STRING") is Some(token) {
          icon_text = Some(convert_string(token.text))
        } else if tokens.accept("ARCH_ICON") is Some(token) {
          icon = Some(convert_icon(token.text))
        }
        let title = tokens
          .accept("ARCH_TITLE")
          .map(token => convert_title(token.text))
        let parent = parent(tokens)
        eol(tokens)
        result.services.push({ id, icon, icon_text, title, parent, })
      }
      "junction" => {
        tokens.expect("junction") |> ignore
        let id = tokens.expect("ID").text
        let parent = parent(tokens)
        eol(tokens)
        result.junctions.push({ id, parent, })
      }
      "align" => {
        tokens.expect("align") |> ignore
        let direction = if tokens.accept("row") is Some(_) {
          Row
        } else {
          tokens.expect("column") |> ignore
          Column
        }
        let members = [tokens.expect("ID").text, tokens.expect("ID").text]
        while tokens.accept("ID") is Some(token) {
          members.push(token.text)
        }
        eol(tokens)
        result.alignments.push({ direction, members, })
      }
      "ID" => {
        let lhs_id = tokens.expect("ID").text
        result.edges.push(edge(tokens, lhs_id))
      }
      _ => tokens.fail("Expecting a statement")
    }
  }
  result
}

///|
/// Parse an architecture diagram and fill its database the way upstream's
/// `populateDb` does: every group, then every service, every junction,
/// every edge and every alignment.
pub fn parse(source : String) -> Db raise {
  let ast = statements(source)
  let db = Db::new()
  db.title = ast.title
  db.acc_title = ast.acc_title
  db.acc_description = ast.acc_description
  for group in ast.groups {
    db.add_group(group.id, group.icon, group.title, group.parent)
  }
  for service in ast.services {
    db.add_service(
      service.id,
      service.icon,
      service.icon_text,
      service.title,
      service.parent,
    )
  }
  for junction in ast.junctions {
    db.add_junction(junction.id, junction.parent)
  }
  for edge in ast.edges {
    db.add_edge(edge)
  }
  for hint in ast.alignments {
    db.add_layout_hint(hint)
  }
  db
}
