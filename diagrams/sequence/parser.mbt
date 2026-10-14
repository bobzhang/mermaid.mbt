///|
fn string_of(value : Json) -> String {
  match value {
    String(text) => text
    _ => ""
  }
}

///|
/// A statement object of the grammar: `{ type, signalType, ... }`.
fn statement(
  kind : String,
  signal_type : Int32,
  fields : Map[String, Json],
) -> Json {
  let object : Map[String, Json] = {
    "type": Json::string(kind),
    "signalType": Json::number(signal_type.to_double()),
  }
  for key, value in fields {
    object[key] = value
  }
  Json::object(object)
}

///|
/// Set a field of a statement object in place, as the grammar's actions
/// do.
fn set_field(object : Json, key : String, value : Json) -> Unit {
  if object is Object(fields) {
    fields[key] = value
  }
}

///|
/// The line type a signal token stands for, by production number.
fn signal_type(production : Int32) -> Int32? {
  let kind = match production {
    80 => SOLID_OPEN
    81 => DOTTED_OPEN
    82 => SOLID
    83 => SOLID_TOP
    84 => SOLID_BOTTOM
    85 => STICK_TOP
    86 => STICK_BOTTOM
    87 => SOLID_TOP_DOTTED
    88 => SOLID_BOTTOM_DOTTED
    89 => STICK_TOP_DOTTED
    90 => STICK_BOTTOM_DOTTED
    91 => SOLID_ARROW_TOP_REVERSE
    92 => SOLID_ARROW_BOTTOM_REVERSE
    93 => STICK_ARROW_TOP_REVERSE
    94 => STICK_ARROW_BOTTOM_REVERSE
    95 => SOLID_ARROW_TOP_REVERSE_DOTTED
    96 => SOLID_ARROW_BOTTOM_REVERSE_DOTTED
    97 => STICK_ARROW_TOP_REVERSE_DOTTED
    98 => STICK_ARROW_BOTTOM_REVERSE_DOTTED
    99 => BIDIRECTIONAL_SOLID
    100 => DOTTED
    101 => BIDIRECTIONAL_DOTTED
    102 => SOLID_CROSS
    103 => DOTTED_CROSS
    104 => SOLID_POINT
    105 => DOTTED_POINT
    _ => return None
  }
  Some(kind)
}

///|
/// jison's `performAction` for sequenceDiagram.jison: run the semantic
/// action of one production. `None` keeps the default value, that of the
/// first symbol.
fn SequenceDb::reduce(
  self : SequenceDb,
  reduction : @jison.Reduction[Json],
) -> Json? raise {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let number = (kind : Int32) => Json::number(kind.to_double())
  // A block: its opening entry goes before what the block holds, its
  // closing entry after.
  let block = (
    start : String,
    start_type : Int32,
    text_key : String,
    end : String,
    end_type : Int32,
  ) => {
    if v(1) is Array(items) {
      items.insert(
        0,
        statement(
          start,
          start_type,
          Map([(text_key, parse_message(string_of(v(2))))]),
        ),
      )
      items.push(statement(end, end_type, {}))
    }
    Some(v(1))
  }
  // A further section of a block: `else`, `and`, `option`.
  let section = (kind : String, signal : Int32, text_key : String) => {
    let items = match v(3) {
      Array(items) => items.copy()
      _ => []
    }
    items.push(
      statement(kind, signal, Map([(text_key, parse_message(string_of(v(1))))])),
    )
    items.push(v(0))
    Some(Json::array(items))
  }
  let participant = (actor : Json, draw : String, description : Json?) => {
    set_field(actor, "draw", Json::string(draw))
    set_field(actor, "type", "addParticipant")
    if description is Some(description) {
      set_field(actor, "description", parse_message(string_of(description)))
    }
    Some(actor)
  }
  let about_actor = (kind : String) => {
    let object : Map[String, Json] = {
      "type": Json::string(kind),
      "actor": field(v(1), "actor"),
      "text": v(0),
    }
    Some(Json::array([v(1), Json::object(object)]))
  }
  let add_message = (
    from : Json,
    to : Json,
    kind : Json,
    extra : Map[String, Json],
  ) => {
    let object : Map[String, Json] = {
      "type": "addMessage",
      "from": field(from, "actor"),
      "to": field(to, "actor"),
      "signalType": kind,
      "msg": v(0),
    }
    for key, value in extra {
      object[key] = value
    }
    Json::object(object)
  }
  let marker = (kind : String, signal : Int32, actor : Json) => {
    statement(kind, signal, { "actor": field(actor, "actor") })
  }
  if signal_type(reduction.production) is Some(kind) {
    return Some(number(kind))
  }
  match reduction.production {
    3 => {
      self.apply(v(0))
      Some(v(0))
    }
    4 | 10 | 8 | 9 | 14 => Some(Json::array([]))
    5 | 11 => {
      if v(1) is Array(items) {
        items.push(v(0))
      }
      Some(v(1))
    }
    6 | 7 | 12 | 13 => Some(v(0))
    16 => {
      set_field(v(0), "type", "createParticipant")
      Some(v(0))
    }
    17 => {
      if v(1) is Array(items) {
        let start : Map[String, Json] = {
          "type": "boxStart",
          "boxData": parse_box_data(string_of(v(2))),
        }
        items.insert(0, Json::object(start))
        let end : Map[String, Json] = { "type": "boxEnd", "boxText": v(2) }
        items.push(Json::object(end))
      }
      Some(v(1))
    }
    19 =>
      Some(
        statement("sequenceIndex", AUTONUMBER, {
          "sequenceIndex": js_number(string_of(v(2))),
          "sequenceIndexStep": js_number(string_of(v(1))),
          "sequenceVisible": true,
        }),
      )
    20 =>
      Some(
        statement("sequenceIndex", AUTONUMBER, {
          "sequenceIndex": js_number(string_of(v(1))),
          "sequenceIndexStep": 1,
          "sequenceVisible": true,
        }),
      )
    21 =>
      Some(statement("sequenceIndex", AUTONUMBER, { "sequenceVisible": false }))
    22 =>
      Some(statement("sequenceIndex", AUTONUMBER, { "sequenceVisible": true }))
    23 => Some(marker("activeStart", ACTIVE_START, v(1)))
    24 => Some(marker("activeEnd", ACTIVE_END, v(1)))
    30 | 31 => {
      // `title ` or `title: ` precedes the text.
      let prefix = if reduction.production == 30 { 6 } else { 7 }
      let text = string_of(v(0))
      let title = if text.length() > prefix {
        text[prefix:].to_owned()
      } else {
        ""
      }
      self.title = sanitize_text(title)
      Some(Json::string(title))
    }
    32 => {
      let title = js_trim(string_of(v(0)))
      self.acc_title = sanitize_text(title).trim_start().to_owned()
      Some(Json::string(title))
    }
    33 | 34 => {
      let description = js_trim(string_of(v(0)))
      let indent = try! @jsregex.Regex::compile("\\n\\s+")
      self.acc_description = indent.replace_all(sanitize_text(description), _ => {
        "\n"
      })
      Some(Json::string(description))
    }
    35 => block("loopStart", LOOP_START, "loopText", "loopEnd", LOOP_END)
    36 => block("rectStart", RECT_START, "color", "rectEnd", RECT_END)
    37 => block("optStart", OPT_START, "optText", "optEnd", OPT_END)
    38 => block("altStart", ALT_START, "altText", "altEnd", ALT_END)
    39 => block("parStart", PAR_START, "parText", "parEnd", PAR_END)
    40 => block("parStart", PAR_OVER_START, "parText", "parEnd", PAR_END)
    41 =>
      block(
        "criticalStart",
        CRITICAL_START,
        "criticalText",
        "criticalEnd",
        CRITICAL_END,
      )
    42 => block("breakStart", BREAK_START, "breakText", "breakEnd", BREAK_END)
    44 => section("option", CRITICAL_OPTION, "optionText")
    46 => section("and", PAR_AND, "parText")
    48 => section("else", ALT_ELSE, "altText")
    49 | 54 => participant(v(3), "participant", Some(v(1)))
    50 | 55 => participant(v(1), "participant", None)
    51 | 56 => participant(v(3), "actor", Some(v(1)))
    52 | 57 => participant(v(1), "actor", None)
    53 => {
      set_field(v(1), "type", "destroyParticipant")
      Some(v(1))
    }
    58 => {
      let note : Map[String, Json] = {
        "type": "addNote",
        "placement": v(2),
        "actor": field(v(1), "actor"),
        "text": v(0),
      }
      Some(Json::array([v(1), Json::object(note)]))
    }
    59 => {
      // One participant, or the first two of a pair.
      let (first, second) = match v(1) {
        Array([first, second, ..]) => (first, second)
        one => (one, one)
      }
      let note : Map[String, Json] = {
        "type": "addNote",
        "placement": number(OVER),
        "actor": Json::array([field(first, "actor"), field(second, "actor")]),
        "text": v(0),
      }
      Some(Json::array([v(1), Json::object(note)]))
    }
    60 => about_actor("addLinks")
    61 => about_actor("addALink")
    62 => about_actor("addProperties")
    63 => about_actor("addDetails")
    66 => Some(Json::array([v(2), v(0)]))
    67 => Some(v(0))
    68 => Some(number(LEFT_OF))
    69 => Some(number(RIGHT_OF))
    70 =>
      Some(
        Json::array([
          v(4),
          v(1),
          add_message(v(4), v(1), v(3), { "activate": true }),
          marker("activeStart", ACTIVE_START, v(1)),
        ]),
      )
    71 =>
      Some(
        Json::array([
          v(4),
          v(1),
          add_message(v(4), v(1), v(3), {}),
          marker("activeEnd", ACTIVE_END, v(4)),
        ]),
      )
    72 =>
      Some(
        Json::array([
          v(4),
          v(1),
          add_message(v(4), v(1), v(3), {
            "activate": true,
            "centralConnection": number(CENTRAL_CONNECTION),
          }),
          marker("centralConnection", CENTRAL_CONNECTION, v(1)),
        ]),
      )
    73 =>
      Some(
        Json::array([
          v(4),
          v(1),
          add_message(v(4), v(1), v(2), {
            "activate": false,
            "centralConnection": number(CENTRAL_CONNECTION_REVERSE),
          }),
          marker("centralConnectionReverse", CENTRAL_CONNECTION_REVERSE, v(4)),
        ]),
      )
    74 =>
      Some(
        Json::array([
          v(5),
          v(1),
          add_message(v(5), v(1), v(3), {
            "activate": true,
            "centralConnection": number(CENTRAL_CONNECTION_DUAL),
          }),
          marker("centralConnection", CENTRAL_CONNECTION, v(1)),
          marker("centralConnectionReverse", CENTRAL_CONNECTION_REVERSE, v(5)),
        ]),
      )
    75 => Some(Json::array([v(3), v(1), add_message(v(3), v(1), v(2), {})]))
    76 => {
      let actor : Map[String, Json] = {
        "type": "addParticipant",
        "actor": v(1),
        "config": v(0),
      }
      Some(Json::object(actor))
    }
    77 => Some(Json::string(js_trim(string_of(v(1)))))
    78 | 79 => {
      let actor : Map[String, Json] = {
        "type": "addParticipant",
        "actor": v(0),
      }
      Some(Json::object(actor))
    }
    106 => {
      // The text follows a colon.
      let text = js_trim(string_of(v(0)))
      Some(
        parse_message(if text.length() > 1 { text[1:].to_owned() } else { "" }),
      )
    }
    _ => None
  }
}

///|
/// JavaScript's `Number(text)` for the grammar's `NUM` token.
fn js_number(text : String) -> Json {
  let text = if text.has_prefix(".") { "0" + text } else { text }
  Json::number(@string.parse_double(text) catch { _ => 0.0 })
}

///|
/// Parse sequence diagram source into its database.
pub fn parse(source : String, config : @config.Config) -> SequenceDb raise {
  let db = SequenceDb::new(config)
  sequencediagram_grammar.parse(
    source,
    empty=Json::null(),
    token=text => Json::string(text),
    reduce=reduction => db.reduce(reduction),
    hook=(_, lexer) => {
      // Every custom action of this grammar trims the token.
      lexer.set_text(js_trim(lexer.text()))
      Continue
    },
  )
  |> ignore
  db
}
