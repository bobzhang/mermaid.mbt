///|
fn string_of(value : Json) -> String {
  match value {
    String(text) => text
    Number(n, ..) =>
      if n == n.floor() {
        n.to_int().to_string()
      } else {
        n.to_string()
      }
    _ => ""
  }
}

///|
/// A list of node ids built by the grammar.
fn ids_of(value : Json) -> Array[String] {
  match value {
    Array(items) => items.map(string_of)
    // `Array.prototype.concat` also takes a single id.
    String(id) => [id]
    _ => []
  }
}

///|
fn strings(values : Array[String]) -> Json {
  Json::array(values.map(Json::string))
}

///|
/// The fields of a statement object `{ stmt, nodes }`.
fn statement_field(value : Json, key : String) -> Array[String] {
  match value {
    Object(fields) => ids_of(fields.get(key).unwrap_or(Json::null()))
    _ => []
  }
}

///|
/// The grammar's custom lexer code; the numbers are those listed at the
/// top of gen_flow_grammar.mbt.
fn FlowDb::lexer_hook(
  self : FlowDb,
  hook : Int32,
  lexer : @jison.Lexer,
) -> @jison.HookResult {
  match hook {
    0 => lexer.set_text("")
    2 => {
      // Line breaks inside quoted shape data become <br/>.
      let breaks = try! @jsregex.Regex::compile("\\n\\s*")
      lexer.set_text(breaks.replace_all(lexer.text(), _ => "<br/>"))
    }
    3 | 4 | 5 | 6 =>
      // Only the first `graph`/`flowchart` keyword is followed by a
      // direction.
      if self.first_graph_flag {
        self.first_graph_flag = false
      } else {
        return SkipNext
      }
    _ => ()
  }
  Continue
}

///|
/// jison's `performAction` for flow.jison: run the semantic action of one
/// production. `None` keeps the default value, that of the first symbol.
fn FlowDb::reduce(
  self : FlowDb,
  reduction : @jison.Reduction[Json],
) -> Json? raise {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let text_json = (text : Json, kind : String) => {
    let object : Map[String, Json] = {
      "text": text,
      "type": Json::string(kind),
    }
    Json::object(object)
  }
  let vertex = (id : Json, text : Json, shape : String) => {
    match text_object(text) {
      Some(text) => self.add_vertex(string_of(id), text~, shape~)
      None => self.add_vertex(string_of(id), shape~)
    }
    Some(id)
  }
  let link = (info : Json, extra : Map[String, Json]) => {
    guard info is Object(fields) else { return Some(info) }
    let merged = fields.copy()
    for key, value in extra {
      merged[key] = value
    }
    Some(Json::object(merged))
  }
  match reduction.production {
    2 | 28 | 29 | 30 | 31 | 32 => Some(Json::array([]))
    3 => {
      if v(1) is Array(document) {
        match v(0) {
          Array([]) => ()
          statement => document.push(statement)
        }
      }
      Some(v(1))
    }
    4 | 44 | 54 | 76 | 181 | 183 => Some(v(0))
    11 => {
      self.set_direction("TB")
      Some("TB")
    }
    12 => {
      self.set_direction(string_of(v(1)))
      Some(v(1))
    }
    27 => Some(strings(statement_field(v(1), "nodes")))
    33 => Some(Json::string(self.add_sub_graph(Some(v(6)), v(1), Some(v(4)))))
    34 =>
      Some(
        Json::string(
          self.add_sub_graph(Some(v(3)), v(1), Some(v(3)), same_text=true),
        ),
      )
    35 =>
      // Upstream reads `.text` of a missing id here and fails.
      raise FlowError("Cannot read properties of undefined (reading 'text')")
    37 => {
      let title = string_of(v(0)).trim().to_owned()
      self.acc_title = self.sanitize_text(title).trim_start().to_owned()
      Some(Json::string(title))
    }
    38 | 39 => {
      let description = string_of(v(0)).trim().to_owned()
      let indent = try! @jsregex.Regex::compile("\\n\\s+")
      self.acc_description = indent.replace_all(
        self.sanitize_text(description),
        _ => "\n",
      )
      Some(Json::string(description))
    }
    43 | 133 | 182 | 184 =>
      Some(Json::string(string_of(v(1)) + string_of(v(0))))
    45 => {
      let nodes = ids_of(v(1))
      self.add_vertex(nodes[nodes.length() - 1], metadata=string_of(v(0)))
      self.add_link(statement_field(v(3), "stmt"), nodes, v(2))
      Some({
        "stmt": v(1),
        "nodes": strings(nodes + statement_field(v(3), "nodes")),
      })
    }
    46 => {
      let nodes = ids_of(v(0))
      self.add_link(statement_field(v(2), "stmt"), nodes, v(1))
      Some({
        "stmt": v(0),
        "nodes": strings(nodes + statement_field(v(2), "nodes")),
      })
    }
    47 => {
      let nodes = ids_of(v(1))
      self.add_link(statement_field(v(3), "stmt"), nodes, v(2))
      Some({
        "stmt": v(1),
        "nodes": strings(nodes + statement_field(v(3), "nodes")),
      })
    }
    48 => Some({ "stmt": v(1), "nodes": v(1) })
    49 => {
      let nodes = ids_of(v(1))
      self.add_vertex(nodes[nodes.length() - 1], metadata=string_of(v(0)))
      Some({ "stmt": v(1), "nodes": v(1), "shapeData": v(0) })
    }
    50 => Some({ "stmt": v(0), "nodes": v(0) })
    51 | 128 | 130 => Some(Json::array([v(0)]))
    52 => {
      let nodes = ids_of(v(5))
      self.add_vertex(nodes[nodes.length() - 1], metadata=string_of(v(4)))
      Some(strings(nodes + ids_of(v(0))))
    }
    53 => Some(strings(ids_of(v(4)) + ids_of(v(0))))
    55 => {
      self.set_class(string_of(v(2)), string_of(v(0)))
      Some(v(2))
    }
    56 => vertex(v(3), v(1), "square")
    57 => vertex(v(3), v(1), "doublecircle")
    58 => vertex(v(5), v(2), "circle")
    59 => vertex(v(3), v(1), "ellipse")
    60 => vertex(v(3), v(1), "stadium")
    61 => vertex(v(3), v(1), "subroutine")
    62 => vertex(v(7), v(1), "rect")
    63 => vertex(v(3), v(1), "cylinder")
    64 => vertex(v(3), v(1), "round")
    65 => vertex(v(3), v(1), "diamond")
    66 => vertex(v(5), v(2), "hexagon")
    67 => vertex(v(3), v(1), "odd")
    68 => vertex(v(3), v(1), "trapezoid")
    69 => vertex(v(3), v(1), "inv_trapezoid")
    70 => vertex(v(3), v(1), "lean_right")
    71 => vertex(v(3), v(1), "lean_left")
    72 => {
      self.add_vertex(string_of(v(0)))
      Some(v(0))
    }
    73 => link(v(1), { "text": v(0) })
    74 | 75 => link(v(2), { "text": v(1) })
    77 =>
      link(destruct_link(string_of(v(0)), start=string_of(v(2))), {
        "text": v(1),
      })
    78 =>
      link(destruct_link(string_of(v(0)), start=string_of(v(2))), {
        "text": v(1),
        "id": v(3),
      })
    79 | 86 | 101 | 103 => Some(text_json(v(0), "text"))
    80 | 87 | 102 => {
      let (text, kind) = text_object(v(1)).unwrap_or(("", "text"))
      Some(text_json(Json::string(text + string_of(v(0))), kind))
    }
    81 | 88 => Some(text_json(v(0), "string"))
    82 | 89 | 104 => Some(text_json(v(0), "markdown"))
    83 => Some(destruct_link(string_of(v(0))))
    84 => link(destruct_link(string_of(v(0))), { "id": v(1) })
    85 => Some(v(1))
    105 => {
      self.add_class(string_of(v(2)), ids_of(v(0)))
      Some(v(4))
    }
    106 => {
      self.set_class(string_of(v(2)), string_of(v(0)))
      Some(v(4))
    }
    107 | 115 => {
      self.set_click_event(string_of(v(1)))
      Some(v(1))
    }
    108 | 116 => {
      self.set_click_event(string_of(v(3)))
      self.set_tooltip(string_of(v(3)), string_of(v(0)))
      Some(v(3))
    }
    109 => {
      self.set_click_event(string_of(v(2)))
      Some(v(2))
    }
    110 => {
      self.set_click_event(string_of(v(4)))
      self.set_tooltip(string_of(v(4)), string_of(v(0)))
      Some(v(4))
    }
    111 => {
      self.set_link(string_of(v(2)), string_of(v(0)), None)
      Some(v(2))
    }
    112 => {
      self.set_link(string_of(v(4)), string_of(v(2)), None)
      self.set_tooltip(string_of(v(4)), string_of(v(0)))
      Some(v(4))
    }
    113 => {
      self.set_link(string_of(v(4)), string_of(v(2)), Some(string_of(v(0))))
      Some(v(4))
    }
    114 => {
      self.set_link(string_of(v(6)), string_of(v(4)), Some(string_of(v(0))))
      self.set_tooltip(string_of(v(6)), string_of(v(2)))
      Some(v(6))
    }
    117 => {
      self.set_link(string_of(v(1)), string_of(v(0)), None)
      Some(v(1))
    }
    118 => {
      self.set_link(string_of(v(3)), string_of(v(2)), None)
      self.set_tooltip(string_of(v(3)), string_of(v(0)))
      Some(v(3))
    }
    119 => {
      self.set_link(string_of(v(3)), string_of(v(2)), Some(string_of(v(0))))
      Some(v(3))
    }
    120 => {
      self.set_link(string_of(v(5)), string_of(v(4)), Some(string_of(v(0))))
      self.set_tooltip(string_of(v(5)), string_of(v(2)))
      Some(v(5))
    }
    121 => {
      self.add_vertex(string_of(v(2)), style=ids_of(v(0)))
      Some(v(4))
    }
    122 | 123 => {
      self.update_link(link_positions(v(2)), ids_of(v(0)))
      Some(v(4))
    }
    124 | 125 => {
      self.update_link_interpolate(link_positions(v(6)), string_of(v(2)))
      self.update_link(link_positions(v(6)), ids_of(v(0)))
      Some(v(8))
    }
    126 | 127 => {
      self.update_link_interpolate(link_positions(v(4)), string_of(v(0)))
      Some(v(6))
    }
    129 | 131 => {
      if v(2) is Array(items) {
        items.push(v(0))
      }
      Some(v(2))
    }
    185 => Some({ "stmt": "dir", "value": "TB" })
    186 => Some({ "stmt": "dir", "value": "BT" })
    187 => Some({ "stmt": "dir", "value": "RL" })
    188 => Some({ "stmt": "dir", "value": "LR" })
    189 => Some({ "stmt": "dir", "value": "TD" })
    _ => None
  }
}

///|
/// Parse flowchart source into its database.
pub fn parse(source : String, config : @config.Config) -> FlowDb raise {
  let db = FlowDb::new(config)
  flow_grammar.parse(
    source,
    empty=Json::null(),
    token=text => Json::string(text),
    reduce=reduction => db.reduce(reduction),
    hook=(hook, lexer) => db.lexer_hook(hook, lexer),
  )
  |> ignore
  db
}

///|
/// The same flowchart under another title.
pub fn FlowDb::set_title(self : FlowDb, title : String) -> Unit {
  self.title = title
}
