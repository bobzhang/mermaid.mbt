///|
/// Why a treemap cannot be rendered.
pub(all) suberror TreemapError {
  /// The diagram is invalid, with upstream's message.
  Invalid(String)
  /// What the port cannot reproduce exactly and therefore refuses.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// A row of the diagram text.
priv enum Row {
  Item(
    indent~ : Int32?,
    name~ : String,
    /// The value of a leaf; a section has none.
    value~ : Double?,
    class_selector~ : String?
  )
  ClassDef(name~ : String, style_text~ : String)
}

///|
/// The value converter's expression for a `classDef` statement.
let class_def_pattern : @jsregex.Regex = try! @jsregex.Regex::compile(
  (
    #|classDef\s+([A-Z_a-z]\w+)(?:\s+([^\n\r;]*))?;?
  ),
)

///|
/// The grammar's `(STYLE_SEPARATOR classSelector=ID2)?`.
fn class_selector(
  tokens : @langium.TokenStream,
) -> String? raise @langium.ParseError {
  guard tokens.accept("STYLE_SEPARATOR") is Some(_) else { return None }
  Some(tokens.expect("ID2").text)
}

///|
/// The grammar's `TreemapRow: indent=INDENTATION? (item=Item | ClassDef)`.
fn row(tokens : @langium.TokenStream) -> Row raise @langium.ParseError {
  // The value converter turns an indentation into its length.
  let indent = tokens.accept("INDENTATION").map(token => token.text.length())
  if tokens.accept("CLASS_DEF") is Some(token) {
    let (name, style_text) = match class_def_pattern.exec(token.text) {
      Some(found) =>
        (found.group(1).unwrap_or(""), found.group(2).unwrap_or(""))
      None => ("", "")
    }
    return ClassDef(name~, style_text~)
  }
  guard tokens.accept("STRING2") is Some(token) else {
    tokens.fail("Expecting an item or a class definition")
  }
  let name = token.text[1:token.text.length() - 1].to_owned()
  // A leaf: `name [:,] value`, with white space allowed around the
  // separator.
  let separator = if tokens.at("INDENTATION") { 1 } else { 0 }
  if !(tokens.peek(ahead=separator) is ("SEPARATOR" | "COMMA")) {
    return Item(
      indent~,
      name~,
      value=None,
      class_selector=class_selector(tokens),
    )
  }
  tokens.accept("INDENTATION") |> ignore
  if tokens.accept("SEPARATOR") is None {
    tokens.expect("COMMA") |> ignore
  }
  tokens.accept("INDENTATION") |> ignore
  let number = tokens.expect("NUMBER2").text
  // Commas group digits: `1,000` is a thousand.
  let value = @diagram.parse_float(number.replace_all(old=",", new=""))
  Item(indent~, name~, value=Some(value), class_selector=class_selector(tokens))
}

///|
/// Parse treemap source, following the Langium grammar:
///
/// ```text
/// Treemap: TREEMAP_KEYWORD (TitleAndAccessibilities | TreemapRow)*
/// TreemapRow: INDENTATION? (Item | CLASS_DEF)
/// Item: Leaf | Section
/// Section: STRING2 (":::" ID2)?
/// Leaf: STRING2 INDENTATION? (":" | ",") INDENTATION? NUMBER2 (":::" ID2)?
/// ```
pub fn parse(source : String) -> Treemap raise {
  let tokens = @langium.TokenStream::new(
    @langium.tokenize(source, token_types),
    source.length(),
  )
  tokens.expect("TREEMAP_KEYWORD") |> ignore
  let rows = []
  let mut title = ""
  let mut acc_title = ""
  let mut acc_description = ""
  while !tokens.at("EOF") {
    match tokens.peek() {
      "ACC_DESCR" | "ACC_TITLE" | "TITLE" as kind => {
        let lexer = @langium.Lexer::new(tokens.expect(kind).text)
        // The last statement of a kind counts, even an empty one.
        match kind {
          "ACC_DESCR" => acc_description = lexer.acc_descr().unwrap_or("")
          "ACC_TITLE" => acc_title = lexer.acc_title().unwrap_or("")
          _ => title = lexer.title().unwrap_or("")
        }
      }
      _ => rows.push(row(tokens))
    }
  }
  for text in [title, acc_title, acc_description] {
    if text.contains("<") {
      raise Unsupported(
        "markup in a title or accessible text of a treemap: \{text}",
      )
    }
  }
  let treemap = Treemap::new(title, acc_title, acc_description)
  treemap.populate(rows)
  treemap
}
