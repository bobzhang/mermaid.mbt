///|
/// The title and the accessibility texts a diagram starts with.
priv struct Header {
  mut title : String
  mut acc_title : String
  mut acc_description : String
}

///|
/// What every grammar starts with: the diagram's keyword, then any number
/// of titles and accessibility texts, of which the last of a kind counts.
///
/// `unquote` is what the grammar's value converter does to a title in
/// quotes.
fn header(
  tokens : @langium.TokenStream,
  keyword : String,
  unquote : (StringView) -> String,
) -> Header raise @langium.ParseError {
  tokens.expect(keyword) |> ignore
  let header = { title: "", acc_title: "", acc_description: "", }
  while true {
    match tokens.peek() {
      "TITLE" => {
        let text = tokens.expect("TITLE").text
        let title = @langium.Lexer::new(text).title().unwrap_or("")
        let trimmed = @journeycommon.js_trim(title)
        let quoted = trimmed.length() > 0 &&
          (
            (trimmed.has_prefix("\"") && trimmed.has_suffix("\"")) ||
            (trimmed.has_prefix("'") && trimmed.has_suffix("'"))
          )
        header.title = if quoted { unquote(trimmed) } else { title }
      }
      "ACC_TITLE" => {
        let text = tokens.expect("ACC_TITLE").text
        header.acc_title = @langium.Lexer::new(text).acc_title().unwrap_or("")
      }
      "ACC_DESCR" => {
        let text = tokens.expect("ACC_DESCR").text
        header.acc_description = @langium.Lexer::new(text)
          .acc_descr()
          .unwrap_or("")
      }
      _ => break
    }
  }
  header
}

///|
/// The diagram a parser hands to the database: every text of it is
/// sanitized there.
fn Header::diagram(
  self : Header,
  rules : Array[Rule],
  entities~ : Bool,
) -> Railroad raise Unsupported {
  let acc_title = @journeycommon.acc_title(self.acc_title) catch {
    @journeycommon.SanitizeError(message) => raise Unsupported(message)
  }
  let acc_description = @journeycommon.acc_description(self.acc_description) catch {
    @journeycommon.SanitizeError(message) => raise Unsupported(message)
  }
  {
    title: sanitize_text(self.title),
    acc_title,
    acc_description,
    rules: rules.map(rule => {
      name: sanitize_text(rule.name),
      definition: sanitize_node(rule.definition),
    }),
    entities,
  }
}

///|
/// mermaid's `sanitizeText`, which the database applies to every text.
fn sanitize_text(text : String) -> String raise Unsupported {
  @journeycommon.sanitize_text(text) catch {
    @journeycommon.SanitizeError(message) => raise Unsupported(message)
  }
}

///|
/// The database's `sanitizeAstNode`.
fn sanitize_node(node : Node) -> Node raise Unsupported {
  match node {
    Terminal(value) => Terminal(sanitize_text(value))
    NonTerminal(name) => NonTerminal(sanitize_text(name))
    Sequence(elements) => Sequence(elements.map(sanitize_node))
    Choice(alternatives) => Choice(alternatives.map(sanitize_node))
    Optional(element) => Optional(sanitize_node(element))
    Repetition(element, min~, max~) =>
      Repetition(sanitize_node(element), min~, max~)
    Special(text) => Special(sanitize_text(text))
  }
}

///|
/// Parse a railroad diagram of the type the detector found: `railroad`
/// (constructors), `railroadEbnf`, `railroadAbnf` or `railroadPeg`.
pub fn parse(diagram_type : String, source : String) -> Railroad raise {
  let types = match diagram_type {
    "railroadEbnf" => ebnf_tokens
    "railroadAbnf" => abnf_tokens
    "railroadPeg" => peg_tokens
    _ => ir_tokens
  }
  let tokens = @langium.TokenStream::new(
    @langium.tokenize(source, types),
    source.length(),
  )
  let (header, rules) = match diagram_type {
    "railroadEbnf" => parse_ebnf(tokens)
    "railroadAbnf" => parse_abnf(tokens)
    "railroadPeg" => parse_peg(tokens)
    _ => parse_ir(tokens)
  }
  header.diagram(rules, entities=source.contains("ﬂ°"))
}
