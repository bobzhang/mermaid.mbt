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
/// The grammar's custom lexer code: unquoted text loses the white space
/// around it.
fn lexer_hook(_hook : Int32, lexer : @jison.Lexer) -> @jison.HookResult {
  lexer.set_text(lexer.text().trim().to_owned())
  Continue
}

///|
/// jison's `performAction` for requirementDiagram.jison: run the semantic
/// action of one production. `None` keeps the default value, that of the
/// first symbol.
fn RequirementDb::reduce(
  self : RequirementDb,
  reduction : @jison.Reduction[Json],
) -> Json? {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let s = (k : Int32) => string_of(v(k))
  let word = (text : String) => Some(Json::string(text))
  match reduction.production {
    4 => {
      let title = s(0).trim().to_owned()
      self.acc_title = title.trim_start().to_owned()
      word(title)
    }
    5 | 6 => {
      let description = s(0).trim().to_owned()
      let indent = try! @jsregex.Regex::compile("\\n\\s+")
      self.acc_description = indent.replace_all(description, _ => "\n")
      word(description)
    }
    7 => Some(Json::array([]))
    17 => {
      self.direction = "TB"
      None
    }
    18 => {
      self.direction = "BT"
      None
    }
    19 => {
      self.direction = "RL"
      None
    }
    20 => {
      self.direction = "LR"
      None
    }
    21 => {
      self.add_requirement(s(3), s(4))
      None
    }
    22 => {
      self.add_requirement(s(5), s(6))
      self.set_class([s(5)], strings_of(v(3)))
      None
    }
    23 => {
      self.new_id = s(2)
      None
    }
    24 => {
      self.new_text = s(2)
      None
    }
    25 => {
      self.new_risk = s(2)
      None
    }
    26 => {
      self.new_verify_method = s(2)
      None
    }
    29 => word("Requirement")
    30 => word("Functional Requirement")
    31 => word("Interface Requirement")
    32 => word("Performance Requirement")
    33 => word("Physical Requirement")
    34 => word("Design Constraint")
    35 => word("Low")
    36 => word("Medium")
    37 => word("High")
    38 => word("Analysis")
    39 => word("Demonstration")
    40 => word("Inspection")
    41 => word("Test")
    42 => {
      self.add_element(s(3))
      None
    }
    43 => {
      self.add_element(s(5))
      self.set_class([s(5)], strings_of(v(3)))
      None
    }
    44 => {
      self.new_type = s(2)
      None
    }
    45 => {
      self.new_doc_ref = s(2)
      None
    }
    48 => {
      self.relations.push({ type_: s(2), src: s(0), dst: s(4), })
      None
    }
    49 => {
      self.relations.push({ type_: s(2), src: s(4), dst: s(0), })
      None
    }
    50 => word("contains")
    51 => word("copies")
    52 => word("derives")
    53 => word("satisfies")
    54 => word("verifies")
    55 => word("refines")
    56 => word("traces")
    57 => {
      self.define_class(strings_of(v(1)), strings_of(v(0)))
      Some(v(2))
    }
    58 => {
      self.set_class(strings_of(v(1)), strings_of(v(0)))
      None
    }
    59 => {
      self.set_class([s(2)], strings_of(v(0)))
      None
    }
    60 | 62 | 65 => Some([v(0)])
    61 | 63 => Some(Json::array([..strings_of(v(2)).map(Json::string), v(0)]))
    64 => {
      self.set_css_style(strings_of(v(1)), strings_of(v(0)))
      Some(v(2))
    }
    66 => {
      if v(2) is Array(items) {
        items.push(v(0))
      }
      Some(v(2))
    }
    68 => word(s(1) + s(0))
    _ => None
  }
}

///|
/// Parse requirement diagram source into its database.
pub fn parse(source : String, config : @config.Config) -> RequirementDb raise {
  let db = RequirementDb::new(config)
  requirementdiagram_grammar.parse(
    source,
    empty=Json::null(),
    token=text => Json::string(text),
    reduce=reduction => db.reduce(reduction),
    hook=lexer_hook,
  )
  |> ignore
  db
}
