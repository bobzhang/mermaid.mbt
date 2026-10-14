///|
/// A feature the port does not reproduce exactly.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
let blank_runs : @jsregex.Regex = regex("[\\t ]{2,}")

///|
fn multiline(source : String) -> @jsregex.Regex {
  try! @jsregex.Regex::compile(source, flags="gm")
}

///|
/// The common value converter reads title and accessibility tokens again
/// with its own patterns.
let title_pattern : @jsregex.Regex = regex("title([\\t ][^\\n\\r]*|)")

///|
let acc_title_pattern : @jsregex.Regex = regex("accTitle[\\t ]*:([^\\n\\r]*)")

///|
let acc_descr_pattern : @jsregex.Regex = regex(
  "accDescr(?:[\\t ]*:([^\\n\\r]*)|\\s*{([^}]*)})",
)

///|
/// The value of a TITLE, ACC_TITLE or ACC_DESCR token: one line, trimmed
/// and with runs of blanks collapsed, or the lines of a `{ ... }` block
/// without their indentation and blank lines.
fn metadata_value(pattern : @jsregex.Regex, token : String) -> String {
  guard pattern.exec(token) is Some(found) else { return "" }
  if found.group(1) is Some(line) {
    return blank_runs.replace_all(@journeycommon.js_trim(line), _ => " ")
  }
  guard found.group(2) is Some(block) else { return "" }
  let block = multiline("^\\s*").replace_all(block, _ => "")
  let block = multiline("\\s+$").replace_all(block, _ => "")
  let block = blank_runs.replace_all(block, _ => " ")
  multiline("[\\n\\r]{2,}").replace_all(block, _ => "\n")
}

///|
fn sanitized(text : String) -> String raise Unsupported {
  @journeycommon.sanitize_text(text) catch {
    @journeycommon.SanitizeError(message) => raise Unsupported(message)
  }
}

///|
/// Parse a Cynefin diagram:
///
/// ```text
/// Cynefin: NEWLINE* ("cynefin-beta" | "cynefin-beta:") NEWLINE*
///          ((ACC_DESCR | ACC_TITLE | TITLE) EOL
///           | DomainBlock | Transition | NEWLINE)*
/// DomainBlock: DOMAIN_NAME NEWLINE* (STRING NEWLINE*)*
/// Transition: DOMAIN_NAME "-->" DOMAIN_NAME (":" STRING)? EOL
/// ```
pub fn parse(source : String) -> Cynefin raise {
  let tokens = @langium.TokenStream::new(
    @langium.tokenize(source, token_types),
    source.length(),
  )
  let diagram = Cynefin::new()
  let skip_newlines = () => {
    while tokens.accept("NEWLINE") is Some(_) {

    }
  }
  // EOL: one or more line breaks, or the end of the text.
  let end_of_line = () => {
    if tokens.at("EOF") {
      return
    }
    tokens.expect("NEWLINE") |> ignore
    skip_newlines()
  }
  skip_newlines()
  if tokens.accept("cynefin-beta:") is None {
    tokens.expect("cynefin-beta") |> ignore
  }
  while !tokens.at("EOF") {
    if tokens.accept("NEWLINE") is Some(_) {
      continue
    }
    if tokens.accept("ACC_DESCR") is Some(token) {
      let value = metadata_value(acc_descr_pattern, token.text)
      if value != "" {
        diagram.acc_description = @journeycommon.acc_description(value) catch {
          @journeycommon.SanitizeError(message) => raise Unsupported(message)
        }
      }
      end_of_line()
    } else if tokens.accept("ACC_TITLE") is Some(token) {
      let value = metadata_value(acc_title_pattern, token.text)
      if value != "" {
        diagram.acc_title = @journeycommon.acc_title(value) catch {
          @journeycommon.SanitizeError(message) => raise Unsupported(message)
        }
      }
      end_of_line()
    } else if tokens.accept("TITLE") is Some(token) {
      let value = metadata_value(title_pattern, token.text)
      if value != "" {
        diagram.title = sanitized(value)
      }
      end_of_line()
    } else if tokens.accept("DOMAIN_NAME") is Some(from) {
      if tokens.accept("-->") is Some(_) {
        let to = tokens.expect("DOMAIN_NAME")
        let label = if tokens.accept(":") is Some(_) {
          Some(unquote(tokens.expect("STRING").text))
        } else {
          None
        }
        end_of_line()
        diagram.add_transition(from.text, to.text, label)
      } else {
        skip_newlines()
        let items = []
        while tokens.accept("STRING") is Some(item) {
          items.push(unquote(item.text))
          skip_newlines()
        }
        diagram.set_domain(from.text, items)
      }
    } else {
      tokens.fail("Expecting a domain, a transition or a title")
    }
  }
  diagram
}
