///|
/// An ER diagram that cannot be built from its source.
pub(all) suberror ErError {
  ErError(String)
} derive(Eq, Debug)

///|
fn string_of(value : Json) -> String {
  match value {
    String(text) => text
    _ => ""
  }
}

///|
fn strings_of(value : Json) -> Array[String] {
  match value {
    Array(items) => items.map(string_of)
    String(text) => [text]
    _ => []
  }
}

///|
fn strings(values : Array[String]) -> Json {
  Json::array(values.map(Json::string))
}

///|
/// `text.replace(/"/g, '')`
fn unquote(value : Json) -> Json {
  Json::string(string_of(value).replace_all(old="\"", new=""))
}

///|
/// The attributes of an entity block, as the grammar listed them.
fn attributes_of(value : Json) -> Array[Attribute] {
  guard value is Array(items) else { return [] }
  items.map(item => {
    guard item is Object(fields) else {
      return { type_: "", name: "", keys: [], comment: "", }
    }
    {
      type_: string_of(fields.get("type").unwrap_or(Json::null())),
      name: string_of(fields.get("name").unwrap_or(Json::null())),
      keys: strings_of(fields.get("keys").unwrap_or(Json::null())),
      comment: string_of(fields.get("comment").unwrap_or(Json::null())),
    }
  })
}

///|
/// What the statements of a subgraph listed: names, and directions.
fn members_of(value : Json) -> Array[Member] {
  guard value is Array(items) else { return [] }
  let members = []
  for item in items {
    match item {
      String(name) => members.push(Name(name))
      { "stmt": String("dir"), "value": String(dir), .. } =>
        members.push(Dir(dir))
      _ => ()
    }
  }
  members
}

///|
/// The grammar's custom lexer code: characters no rule names are tokens
/// called after themselves.
fn lexer_hook(_hook : Int32, lexer : @jison.Lexer) -> @jison.HookResult {
  match lexer.text().get_char(0) {
    Some(c) => Token(c.to_string())
    None => Continue
  }
}

///|
/// jison's `performAction` for erDiagram.jison: run the semantic action of
/// one production. `None` keeps the default value, that of the first
/// symbol.
fn ErDb::reduce(self : ErDb, reduction : @jison.Reduction[Json]) -> Json? {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let s = (k : Int32) => string_of(v(k))
  let relationship = (a : Int32, role : Int32, b : Int32, spec : Int32) => {
    let field = (name : String) => {
      match v(spec) {
        Object(fields) => string_of(fields.get(name).unwrap_or(Json::null()))
        _ => ""
      }
    }
    self.add_relationship(
      s(a),
      s(role),
      s(b),
      card_a=field("cardA"),
      card_b=field("cardB"),
      rel_type=field("relType"),
    )
  }
  match reduction.production {
    2 | 5 | 6 => Some(Json::array([]))
    3 => {
      // `Array.prototype.concat`: arrays are spliced in, the rest appended.
      let document = match v(1) {
        Array(items) => items.copy()
        other => [other]
      }
      match v(0) {
        Array(items) => document.append(items)
        other => document.push(other)
      }
      Some(Json::array(document))
    }
    4 | 34 | 59 | 60 | 61 | 62 | 69 | 71 | 74 | 86 => Some(v(0))
    7 => {
      self.add_entity(s(4)) |> ignore
      self.add_entity(s(2)) |> ignore
      relationship(4, 0, 2, 3)
      Some([v(4), v(2)])
    }
    8 => {
      self.add_entity(s(8)) |> ignore
      self.add_entity(s(4)) |> ignore
      relationship(8, 0, 4, 5)
      self.set_class([s(8)], strings_of(v(6)))
      self.set_class([s(4)], strings_of(v(2)))
      Some([v(8), v(4)])
    }
    9 => {
      self.add_entity(s(6)) |> ignore
      self.add_entity(s(2)) |> ignore
      relationship(6, 0, 2, 3)
      self.set_class([s(6)], strings_of(v(4)))
      Some([v(6), v(2)])
    }
    10 => {
      self.add_entity(s(6)) |> ignore
      self.add_entity(s(4)) |> ignore
      relationship(6, 0, 4, 5)
      self.set_class([s(4)], strings_of(v(2)))
      Some([v(6), v(4)])
    }
    11 => {
      self.add_entity(s(3)) |> ignore
      self.add_attributes(s(3), attributes_of(v(1)))
      Some([v(3)])
    }
    12 => {
      self.add_entity(s(5)) |> ignore
      self.add_attributes(s(5), attributes_of(v(1)))
      self.set_class([s(5)], strings_of(v(3)))
      Some([v(5)])
    }
    13 => {
      self.add_entity(s(2)) |> ignore
      Some([v(2)])
    }
    14 => {
      self.add_entity(s(4)) |> ignore
      self.set_class([s(4)], strings_of(v(2)))
      Some([v(4)])
    }
    15 => {
      self.add_entity(s(0)) |> ignore
      Some([v(0)])
    }
    16 => {
      self.add_entity(s(2)) |> ignore
      self.set_class([s(2)], strings_of(v(0)))
      Some([v(2)])
    }
    17 => {
      self.add_entity(s(6), alias_name=s(4)) |> ignore
      self.add_attributes(s(6), attributes_of(v(1)))
      Some([v(6)])
    }
    18 => {
      self.add_entity(s(8), alias_name=s(6)) |> ignore
      self.add_attributes(s(8), attributes_of(v(1)))
      self.set_class([s(8)], strings_of(v(3)))
      Some([v(8)])
    }
    19 => {
      self.add_entity(s(5), alias_name=s(3)) |> ignore
      Some([v(5)])
    }
    20 => {
      self.add_entity(s(7), alias_name=s(5)) |> ignore
      self.set_class([s(7)], strings_of(v(2)))
      Some([v(7)])
    }
    21 => {
      self.add_entity(s(3), alias_name=s(1)) |> ignore
      None
    }
    22 => {
      self.add_entity(s(5), alias_name=s(3)) |> ignore
      self.set_class([s(5)], strings_of(v(0)))
      None
    }
    23 | 24 => {
      let title = s(0).trim().to_owned()
      self.acc_title = title.trim_start().to_owned()
      Some(Json::string(title))
    }
    25 | 26 => {
      let description = s(0).trim().to_owned()
      let indent = try! @jsregex.Regex::compile("\\n\\s+")
      self.acc_description = indent.replace_all(description, _ => "\n")
      Some(Json::string(description))
    }
    27 =>
      if self.subgraph_depth == 0 {
        if v(0) is { "value": String(direction), .. } {
          self.direction = direction
        }
        Some(Json::array([]))
      } else {
        Some(v(0))
      }
    31 => {
      self.subgraph_depth = (if self.subgraph_depth == 0 {
          1
        } else {
          self.subgraph_depth
        }) -
        1
      guard v(2) is { "id": String(id), "text": String(text), .. } else {
        return None
      }
      Some(Json::string(self.add_sub_graph(id, members_of(v(1)), text)))
    }
    32 => {
      self.subgraph_depth += 1
      Some({ "id": v(1), "text": v(1) })
    }
    33 => {
      self.subgraph_depth += 1
      Some({ "id": v(4), "text": v(2) })
    }
    35 => Some(Json::string(s(1) + " " + s(0)))
    36 => Some({ "stmt": "dir", "value": "TB" })
    37 => Some({ "stmt": "dir", "value": "BT" })
    38 => Some({ "stmt": "dir", "value": "RL" })
    39 => Some({ "stmt": "dir", "value": "LR" })
    40 => {
      self.add_class(strings_of(v(2)), strings_of(v(1)))
      Some(v(3))
    }
    41 | 42 | 47 | 63 | 72 => Some([v(0)])
    43 | 44 => Some(strings([..strings_of(v(2)), s(0)]))
    45 => {
      self.set_class(strings_of(v(1)), strings_of(v(0)))
      Some(v(2))
    }
    46 => {
      self.add_css_styles(strings_of(v(2)), strings_of(v(1)))
      Some(v(3))
    }
    48 | 73 => {
      if v(2) is Array(items) {
        items.push(v(0))
      }
      Some(v(2))
    }
    50 | 70 => Some(Json::string(s(1) + s(0)))
    58 | 75 | 84 | 85 => Some(unquote(v(0)))
    64 => {
      if v(0) is Array(items) {
        items.push(v(1))
      }
      Some(v(0))
    }
    65 => Some({ "type": v(1), "name": v(0) })
    66 => Some({ "type": v(2), "name": v(1), "keys": v(0) })
    67 => Some({ "type": v(2), "name": v(1), "comment": v(0) })
    68 => Some({ "type": v(3), "name": v(2), "keys": v(1), "comment": v(0) })
    76 => Some({ "cardA": v(0), "relType": v(1), "cardB": v(2) })
    77 => Some("ZERO_OR_ONE")
    78 => Some("ZERO_OR_MORE")
    79 => Some("ONE_OR_MORE")
    80 => Some("ONLY_ONE")
    81 => Some("MD_PARENT")
    82 => Some("NON_IDENTIFYING")
    83 => Some("IDENTIFYING")
    _ => None
  }
}

///|
/// Parse ER diagram source into its database.
pub fn parse(source : String, config : @config.Config) -> ErDb raise {
  let db = ErDb::new(config)
  erdiagram_grammar.parse(
    source,
    empty=Json::null(),
    token=text => Json::string(text),
    reduce=reduction => db.reduce(reduction),
    hook=lexer_hook,
  )
  |> ignore
  db
}
