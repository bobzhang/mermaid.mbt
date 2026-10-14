///|
/// Why a Cynefin diagram could not be parsed.
pub(all) suberror CynefinError {
  CynefinError(String)
} derive(Eq, Debug)

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
  let tokens = tokenize(source)
  let diagram = Cynefin::new()
  let mut cursor = 0
  let peek = (ahead : Int32) => tokens.get(cursor + ahead)
  let skip_newlines = () => {
    while tokens.get(cursor) is Some(Newline) {
      cursor += 1
    }
  }
  // EOL: one or more line breaks, or the end of the text.
  let end_of_line = () => {
    match tokens.get(cursor) {
      None => ()
      Some(Newline) => skip_newlines()
      _ => raise CynefinError("Expecting a line break")
    }
  }
  skip_newlines()
  guard peek(0) is Some(Keyword) else {
    raise CynefinError("Expecting token of type 'cynefin-beta'")
  }
  cursor += 1
  while peek(0) is Some(token) {
    cursor += 1
    match token {
      Newline => ()
      AccDescr(text) => {
        let value = metadata_value(acc_descr_pattern, text)
        if value != "" {
          diagram.acc_description = @journeycommon.acc_description(value) catch {
            @journeycommon.SanitizeError(message) => raise Unsupported(message)
          }
        }
        end_of_line()
      }
      AccTitle(text) => {
        let value = metadata_value(acc_title_pattern, text)
        if value != "" {
          diagram.acc_title = @journeycommon.acc_title(value) catch {
            @journeycommon.SanitizeError(message) => raise Unsupported(message)
          }
        }
        end_of_line()
      }
      Title(text) => {
        let value = metadata_value(title_pattern, text)
        if value != "" {
          diagram.title = sanitized(value)
        }
        end_of_line()
      }
      DomainName(from) =>
        if peek(0) is Some(Arrow) {
          cursor += 1
          guard peek(0) is Some(DomainName(to)) else {
            raise CynefinError("Expecting a domain name after '-->'")
          }
          cursor += 1
          let mut label = None
          if peek(0) is Some(Colon) {
            cursor += 1
            guard peek(0) is Some(Str(text)) else {
              raise CynefinError("Expecting a quoted label after ':'")
            }
            cursor += 1
            label = Some(text)
          }
          end_of_line()
          diagram.add_transition(from, to, label)
        } else {
          skip_newlines()
          let items = []
          while peek(0) is Some(Str(label)) {
            cursor += 1
            items.push(label)
            skip_newlines()
          }
          diagram.set_domain(from, items)
        }
      _ => raise CynefinError("Expecting a domain, a transition or a title")
    }
  }
  diagram
}
