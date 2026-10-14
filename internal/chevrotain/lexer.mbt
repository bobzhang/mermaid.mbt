///|
/// A token: a piece of the input and the type it was recognized as.
pub struct Token {
  /// The name of the token's type.
  name : String
  image : String
  /// Where the token starts and where it ends, in UTF-16 code units; the
  /// end is exclusive.
  start : Int32
  end : Int32
  priv kind : Int32
}

///|
/// The match of the token type at `index` at `offset`, as a length.
fn Grammar::match_at(
  self : Grammar,
  index : Int32,
  text : String,
  offset : Int32,
  custom : (String, String, Int32) -> Int32?,
) -> Int32? {
  let token = self.tokens[index]
  if token.custom {
    return custom(token.name, text, offset)
  }
  guard token.regex is Some(regex) else { return None }
  guard regex.match_prefix(text, from=offset) is Some(found) else {
    return None
  }
  Some(found.end - found.start)
}

///|
/// Split `text` into tokens: chevrotain's `Lexer.tokenize`. The token
/// types of the current mode are tried in order and the first that matches
/// wins, unless one of its longer alternatives matches more. `custom`
/// stands for the patterns that are functions: given the name of a token
/// type, the text and an offset, it answers with the length of the match
/// there. Text no token type matches is an error.
pub fn Grammar::tokenize(
  self : Grammar,
  text : String,
  custom~ : (String, String, Int32) -> Int32? = (_, _, _) => None,
) -> Array[Token] raise ParseError {
  let tokens = []
  let modes = [self.default_mode]
  let mut offset = 0
  let length = text.length()
  while offset < length {
    guard self.modes.get(modes[modes.length() - 1]) is Some(candidates) else {
      raise ParseError(message="unknown lexer mode", offset~)
    }
    let mut found : (Int32, Int32)? = None
    for index in candidates {
      guard self.match_at(index, text, offset, custom) is Some(matched) else {
        continue
      }
      found = Some((index, matched))
      for alternative in self.tokens[index].longer_alt {
        if self.match_at(alternative, text, offset, custom) is Some(longer) &&
          longer > matched {
          found = Some((alternative, longer))
          break
        }
      }
      break
    }
    guard found is Some((index, matched)) && matched > 0 else {
      let character = text[offset:offset + 1].to_owned()
      raise ParseError(
        message="unexpected character: ->\{character}<- at offset: \{offset}, skipped 1 characters.",
        offset~,
      )
    }
    let token = self.tokens[index]
    if !token.skipped {
      tokens.push({
        name: token.name,
        image: text[offset:offset + matched].to_owned(),
        start: offset,
        end: offset + matched,
        kind: index,
      })
    }
    offset += matched
    if token.pop_mode {
      guard modes.length() > 1 || token.push_mode is Some(_) else {
        raise ParseError(
          message="Unable to pop Lexer Mode after encountering Token ->\{token.name}<- The Mode Stack is empty",
          offset~,
        )
      }
      if modes.length() > 1 {
        modes.pop() |> ignore
      }
    }
    if token.push_mode is Some(mode) {
      modes.push(mode)
    }
  }
  tokens
}
