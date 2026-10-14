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
    _ => []
  }
}

///|
/// An end of a relation as the grammar passes it on: its number, or the
/// word `none`.
fn relation_end(value : Json) -> Int32? {
  match value {
    Number(kind, ..) => Some(kind.to_int())
    _ => None
  }
}

///|
/// The grammar's custom lexer code: the brace that ends a namespace is
/// read again once the namespace is left.
fn lexer_hook(_hook : Int32, lexer : @jison.Lexer) -> @jison.HookResult {
  lexer.less(0)
  Continue
}

///|
/// jison's `performAction` for classDiagram.jison: run the semantic action
/// of one production. `None` keeps the default value, that of the first
/// symbol.
fn ClassDb::reduce(
  self : ClassDb,
  reduction : @jison.Reduction[Json],
) -> Json? raise ClassError {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let s = (k : Int32) => string_of(v(k))
  let relation = (
    id1 : Int32,
    id2 : Int32,
    spec : Int32,
    titles : (String, String),
  ) => {
    let json : Json = {
      "id1": v(id1),
      "id2": v(id2),
      "relation": v(spec),
      "relationTitle1": Json::string(titles.0),
      "relationTitle2": Json::string(titles.1),
    }
    json
  }
  let add_relation = (relation : Json, title : String?) => {
    guard relation
      is {
        "id1": String(id1),
        "id2": String(id2),
        "relation": {
          "type1": type1,
          "type2": type2,
          "lineType": line_type,
          ..
        },
        "relationTitle1": String(title1),
        "relationTitle2": String(title2),
        ..
      } else {
      return
    }
    self.add_relation(
      id1,
      id2,
      relation_end(type1),
      relation_end(type2),
      line_type is Number(1.0, ..),
      title1,
      title2,
      title,
    )
  }
  let namespace_members = (id : Int32, statements : Int32) => {
    guard v(statements) is [classes, notes, ..] else { return }
    self.add_classes_to_namespace(s(id), strings_of(classes), strings_of(notes))
    self.namespace_stack.pop() |> ignore
  }
  let number = (value : Int32) => Some(Json::number(value.to_double()))
  match reduction.production {
    8 => Some(v(1))
    9 | 10 | 13 | 15 | 46 => Some(v(0))
    11 | 14 => Some(Json::string(s(2) + "." + s(0)))
    12 | 16 | 110 => Some(Json::string(s(1) + s(0)))
    17 | 18 => Some(Json::string(s(1) + "~" + s(0) + "~"))
    19 => {
      add_relation(v(0), None)
      None
    }
    20 => {
      let title = cleanup_label(s(0))
      add_relation(v(1), Some(title))
      None
    }
    31 => {
      let title = js_trim(s(0))
      self.acc_title = title.trim_start().to_owned()
      Some(Json::string(title))
    }
    32 | 33 => {
      let description = js_trim(s(0))
      let indent = try! @jsregex.Regex::compile("\\n\\s+", flags="g")
      self.acc_description = indent.replace_all(description, _ => "\n")
      Some(Json::string(description))
    }
    34 => {
      namespace_members(3, 1)
      None
    }
    35 => {
      namespace_members(4, 1)
      None
    }
    36 => Some(Json::string(self.add_namespace(s(0), None)))
    37 => Some(Json::string(self.add_namespace(s(1), Some(s(0)))))
    38 => Some([[v(0)], []])
    39 => Some([[v(1)], []])
    40 => {
      if v(0) is [Array(classes), ..] {
        classes.insert(0, v(2))
      }
      Some(v(0))
    }
    41 => Some([[], [v(0)]])
    42 => Some([[], [v(1)]])
    43 => {
      if v(0) is [_, Array(notes), ..] {
        notes.insert(0, v(2))
      }
      Some(v(0))
    }
    44 | 45 => Some([[], []])
    48 => {
      self.set_css_class(s(2), s(0))
      None
    }
    49 => {
      self.add_members(s(3), strings_of(v(1)))
      None
    }
    51 => {
      self.set_css_class(s(5), s(3))
      self.add_members(s(5), strings_of(v(1)))
      None
    }
    52 => {
      self.add_annotation(s(3), s(1))
      None
    }
    53 => {
      self.add_annotation(s(6), s(4))
      self.add_members(s(6), strings_of(v(1)))
      None
    }
    54 => {
      self.add_annotation(s(5), s(3))
      None
    }
    55 => {
      self.add_class(s(0))
      Some(v(0))
    }
    56 => {
      self.add_class(s(1))
      self.set_class_label(s(1), s(0))
      Some(v(1))
    }
    60 => {
      self.add_annotation(s(0), s(2))
      None
    }
    61 | 74 | 107 => Some([v(0)])
    62 => {
      if v(0) is Array(members) {
        members.push(v(1))
      }
      Some(v(0))
    }
    64 => {
      self.add_member(s(1), cleanup_label(s(0)))
      None
    }
    67 => Some(relation(2, 0, 1, ("none", "none")))
    68 => Some(relation(3, 0, 1, (s(2), "none")))
    69 => Some(relation(3, 0, 2, ("none", s(1))))
    70 => Some(relation(4, 0, 2, (s(3), s(1))))
    71 => Some(Json::string(self.add_note(s(0), Some(s(1)))))
    72 => Some(Json::string(self.add_note(s(0), None)))
    73 => {
      self.define_class(strings_of(v(1)), strings_of(v(0)))
      Some(v(2))
    }
    75 => Some(Json::array([..strings_of(v(2)).map(Json::string), v(0)]))
    76 => {
      self.direction = "TB"
      None
    }
    77 => {
      self.direction = "BT"
      None
    }
    78 => {
      self.direction = "RL"
      None
    }
    79 => {
      self.direction = "LR"
      None
    }
    80 => Some({ "type1": v(2), "type2": v(0), "lineType": v(1) })
    81 => Some({ "type1": "none", "type2": v(0), "lineType": v(1) })
    82 => Some({ "type1": v(1), "type2": "none", "lineType": v(0) })
    83 => Some({ "type1": "none", "type2": "none", "lineType": v(0) })
    84 => number(AGGREGATION)
    85 => number(EXTENSION)
    86 => number(COMPOSITION)
    87 => number(DEPENDENCY)
    88 => number(LOLLIPOP)
    89 => number(0)
    90 => number(1)
    91 | 97 => {
      self.set_click_event(s(1))
      Some(v(2))
    }
    92 | 98 => {
      self.set_click_event(s(2))
      self.set_tooltip(s(2), s(0))
      Some(v(3))
    }
    93 => {
      self.set_link(s(1), s(0), None)
      Some(v(2))
    }
    94 => {
      self.set_link(s(2), s(1), Some(s(0)))
      Some(v(3))
    }
    95 => {
      self.set_link(s(2), s(1), None)
      self.set_tooltip(s(2), s(0))
      Some(v(3))
    }
    96 => {
      self.set_link(s(3), s(2), Some(s(0)))
      self.set_tooltip(s(3), s(1))
      Some(v(4))
    }
    99 => {
      self.set_click_event(s(2))
      Some(v(3))
    }
    100 => {
      self.set_click_event(s(3))
      self.set_tooltip(s(3), s(0))
      Some(v(4))
    }
    101 => {
      self.set_link(s(2), s(0), None)
      Some(v(3))
    }
    102 => {
      self.set_link(s(3), s(1), Some(s(0)))
      Some(v(4))
    }
    103 => {
      self.set_link(s(3), s(1), None)
      self.set_tooltip(s(3), s(0))
      Some(v(4))
    }
    104 => {
      self.set_link(s(4), s(2), Some(s(0)))
      self.set_tooltip(s(4), s(1))
      Some(v(5))
    }
    105 => {
      self.set_css_style(s(1), strings_of(v(0)))
      Some(v(2))
    }
    106 => {
      self.set_css_class(s(1), s(0))
      None
    }
    108 => {
      if v(2) is Array(styles) {
        styles.push(v(0))
      }
      Some(v(2))
    }
    _ => None
  }
}

///|
/// Parse class diagram source into its database.
pub fn parse(source : String, config : @config.Config) -> ClassDb raise {
  let db = ClassDb::new(config)
  classdiagram_grammar.parse(
    source,
    empty=Json::null(),
    token=text => Json::string(text),
    reduce=reduction => db.reduce(reduction),
    hook=lexer_hook,
  )
  |> ignore
  db
}
