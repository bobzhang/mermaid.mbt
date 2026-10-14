///|
/// What the port cannot reproduce exactly and therefore refuses.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// An event model that is invalid, with upstream's message.
pub(all) suberror Invalid {
  Invalid(String)
} derive(Eq, Debug)

///|
/// What a frame stands for, which decides its swimlane and its colors.
pub(all) enum EntityType {
  Ui
  Processor
  ReadModel
  Command
  Event
} derive(Eq, Debug)

///|
/// A frame of the timeline: a box.
pub struct Frame {
  /// A reset frame takes no relation from the frame before it.
  reset : Bool
  /// The number the frame is referred to by, as written.
  name : String
  entity_type : EntityType
  /// The entity's name, behind its namespace and a dot when it has one.
  entity_identifier : String
  /// The frames named after `->>`, as written.
  source_frames : Array[String]
  /// The data block named in `[[ ]]`.
  data_reference : String?
  /// Data on the frame's own line, with its delimiters.
  data_inline : String?
} derive(Debug)

///|
/// A parsed event model: the frames, and the data blocks they refer to.
/// Entities, notes and given-when-then blocks are parsed and not drawn.
pub struct EventModel {
  frames : Array[Frame]
  /// Name and text, braces included, in the order written.
  data_entities : Array[(String, String)]
  acc_title : String
  acc_description : String
  /// Whether the text holds entity codes (`#35;`), shielded as
  /// placeholders until the diagram is serialized.
  entities : Bool
}

///|
/// The grammar's `EmModelEntityType`.
fn entity_type(
  tokens : @langium.TokenStream,
) -> EntityType raise @langium.ParseError {
  let kind = tokens.peek()
  let entity_type = match kind {
    "ui" => Ui
    "pcr" | "processor" => Processor
    "rmo" | "readmodel" => ReadModel
    "cmd" | "command" => Command
    "evt" | "event" => Event
    _ => tokens.fail("Expecting an entity type")
  }
  tokens.expect(kind) |> ignore
  entity_type
}

///|
fn at_entity_type(tokens : @langium.TokenStream) -> Bool {
  tokens.peek()
  is ("ui"
  | "pcr"
  | "processor"
  | "rmo"
  | "readmodel"
  | "cmd"
  | "command"
  | "evt"
  | "event")
}

///|
/// The grammar's `QualifiedName`: identifiers joined by dots, whatever
/// white space was between them.
fn qualified_name(
  tokens : @langium.TokenStream,
) -> String raise @langium.ParseError {
  let mut name = tokens.expect("ID").text
  while tokens.accept(".") is Some(_) {
    name = name + "." + tokens.expect("ID").text
  }
  name
}

///|
/// The optional data type in backticks before data.
fn data_type(tokens : @langium.TokenStream) -> Unit raise @langium.ParseError {
  guard tokens.accept("`") is Some(_) else { return }
  let kind = tokens.peek()
  guard kind
    is ("json" | "jsobj" | "figma" | "salt" | "uri" | "md" | "html" | "text") else {
    tokens.fail("Expecting a data type")
  }
  tokens.expect(kind) |> ignore
  tokens.expect("`") |> ignore
}

///|
/// The grammar's `EmDataBlock`: the text of the block, braces included.
fn data_block(
  tokens : @langium.TokenStream,
) -> String raise @langium.ParseError {
  data_type(tokens)
  tokens.expect("DATA_BLOCK").text
}

///|
/// The grammar's `EmTimeFrame` and `EmResetFrame`, after their keyword.
fn frame(
  tokens : @langium.TokenStream,
  reset : Bool,
) -> Frame raise @langium.ParseError {
  let name = tokens.expect("FID").text
  let entity_type = entity_type(tokens)
  let entity_identifier = qualified_name(tokens)
  let source_frames = []
  while tokens.accept("->>") is Some(_) {
    source_frames.push(tokens.expect("FID").text)
  }
  let data_reference = match tokens.accept("[[") {
    Some(_) => {
      let reference = tokens.expect("ID").text
      tokens.expect("]]") |> ignore
      Some(reference)
    }
    None => None
  }
  let data_inline = if tokens.at("`") || tokens.at("DATA_INLINE") {
    data_type(tokens)
    Some(tokens.expect("DATA_INLINE").text)
  } else {
    None
  }
  {
    reset,
    name,
    entity_type,
    entity_identifier,
    source_frames,
    data_reference,
    data_inline,
  }
}

///|
/// The grammar's `EmGwtStatement+`.
fn gwt_statements(
  tokens : @langium.TokenStream,
) -> Unit raise @langium.ParseError {
  entity_type(tokens) |> ignore
  tokens.expect("ID") |> ignore
  while at_entity_type(tokens) {
    entity_type(tokens) |> ignore
    tokens.expect("ID") |> ignore
  }
}

///|
/// Parse an event model, following the Langium grammar:
///
/// ```text
/// EventModel: "eventmodeling"
///   ( ACC_DESCR | ACC_TITLE | TITLE | "entity" QualifiedName | Frame
///   | "data" ID DataBlock | "note" FID DataBlock
///   | "gwt" FID "given" Statement+ ("when" Statement+)? "then" Statement+ )*
/// Frame: ("tf" | "timeframe" | "rf" | "resetframe") FID EntityType
///   QualifiedName ("->>" FID)* ("[[" ID "]]")? (DataType? DATA_INLINE)?
/// DataBlock: DataType? DATA_BLOCK
/// DataType: "`" ("json" | "jsobj" | ...) "`"
/// Statement: EntityType ID
/// QualifiedName: ID ("." ID)*
/// ```
pub fn parse(source : String) -> EventModel raise {
  let tokens = @langium.TokenStream::new(
    @langium.tokenize(source, token_types),
    source.length(),
  )
  tokens.expect("eventmodeling") |> ignore
  let frames : Array[Frame] = []
  let data_entities = []
  // The grammar's own terminals have no value converter: the texts are
  // the tokens as written, keyword and blanks included.
  let mut acc_title = ""
  let mut acc_description = ""
  while !tokens.at("EOF") {
    match tokens.peek() {
      "ACC_DESCR" => acc_description = tokens.expect("ACC_DESCR").text
      "ACC_TITLE" => acc_title = tokens.expect("ACC_TITLE").text
      // Nothing draws the title.
      "TITLE" => tokens.expect("TITLE") |> ignore
      "entity" => {
        tokens.expect("entity") |> ignore
        qualified_name(tokens) |> ignore
      }
      "tf" | "timeframe" | "rf" | "resetframe" as kind => {
        tokens.expect(kind) |> ignore
        frames.push(frame(tokens, kind is ("rf" | "resetframe")))
      }
      "data" => {
        tokens.expect("data") |> ignore
        let name = tokens.expect("ID").text
        data_entities.push((name, data_block(tokens)))
      }
      "note" => {
        tokens.expect("note") |> ignore
        tokens.expect("FID") |> ignore
        data_block(tokens) |> ignore
      }
      "gwt" => {
        tokens.expect("gwt") |> ignore
        tokens.expect("FID") |> ignore
        tokens.expect("given") |> ignore
        gwt_statements(tokens)
        if tokens.accept("when") is Some(_) {
          gwt_statements(tokens)
        }
        tokens.expect("then") |> ignore
        gwt_statements(tokens)
      }
      _ => tokens.fail("Expecting a frame, data, a note or an entity")
    }
  }
  // The database's `setAst`.
  let names : Map[String, Unit] = Map([])
  for frame in frames {
    if names.contains(frame.name) {
      raise Invalid("Duplicate event modeling frame ID \"\{frame.name}\"")
    }
    names[frame.name] = ()
  }
  let acc_title = @journeycommon.acc_title(acc_title) catch {
    @journeycommon.SanitizeError(message) => raise Unsupported(message)
  }
  let acc_description = @journeycommon.acc_description(acc_description) catch {
    @journeycommon.SanitizeError(message) => raise Unsupported(message)
  }
  {
    frames,
    data_entities,
    acc_title,
    acc_description,
    entities: source.contains("ﬂ°"),
  }
}
