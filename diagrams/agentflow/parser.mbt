///|
/// The `{ text, type }` value of an empty title.
fn empty_text() -> Json {
  { "text": "", "type": "text" }
}

///|
/// jison's `performAction` for agentflow.jison: run the semantic action of
/// one production. `None` keeps the default value, that of the first
/// symbol.
fn AgentDb::reduce(
  self : AgentDb,
  reduction : @jison.Reduction[Json],
) -> Json? raise {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  let string_of = @flowchart.string_of
  let ids_of = @flowchart.ids_of
  let strings = @flowchart.strings
  let field = @flowchart.statement_field
  let text_json = (text : Json, kind : String) => {
    let object : Map[String, Json] = {
      "text": text,
      "type": Json::string(kind),
    }
    Json::object(object)
  }
  let vertex = (id : Json, text : Json, shape : String) => {
    match @flowchart.text_object(text) {
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
  // The metadata of the last node of a list.
  let annotate_last = (nodes : Json, metadata : Json) => {
    let ids = ids_of(nodes)
    self.add_vertex(ids[ids.length() - 1], metadata=string_of(metadata))
  }
  let flow = self.flow
  match reduction.production {
    2 | 5 | 33 | 34 | 35 | 36 | 37 => Some(Json::array([]))
    3 => {
      if v(1) is Array(document) {
        match v(0) {
          Array([]) => ()
          statement => document.push(statement)
        }
      }
      Some(v(1))
    }
    4 | 198 => Some(v(0))
    13 => {
      flow.set_direction("TB")
      Some("TB")
    }
    14 => {
      flow.set_direction(string_of(v(1)))
      Some(v(1))
    }
    32 => Some(strings(field(v(1), "nodes")))
    38 => Some(Json::string(self.add_sub_graph(Some(v(6)), v(1), Some(v(4)))))
    39 => {
      let id = self.add_sub_graph(Some(v(7)), v(1), Some(v(5)))
      self.add_vertex(id, metadata=string_of(v(3)))
      Some(Json::string(id))
    }
    40 =>
      Some(
        Json::string(self.add_sub_graph(Some(v(3)), v(1), Some(empty_text()))),
      )
    41 => {
      let id = self.add_sub_graph(Some(v(4)), v(1), Some(empty_text()))
      self.add_vertex(id, metadata=string_of(v(3)))
      Some(Json::string(id))
    }
    42 => Some(Json::string(self.add_sub_graph(None, v(1), None)))
    43 => {
      self.add_global(v(1))
      Some(Json::array([]))
    }
    44 => Some(Json::string(self.add_connector(v(4), v(2))))
    45 => {
      let id = self.add_connector(v(5), v(3))
      self.add_vertex(id, metadata=string_of(v(1)))
      Some(Json::string(id))
    }
    46 => Some(Json::string(self.add_connector(v(1), empty_text())))
    47 => {
      let id = self.add_connector(v(2), empty_text())
      self.add_vertex(id, metadata=string_of(v(1)))
      Some(Json::string(id))
    }
    49 => {
      let title = string_of(v(0)).trim().to_owned()
      self.acc_title = flow.sanitize_text(title).trim_start().to_owned()
      Some(Json::string(title))
    }
    50 | 51 => {
      let description = string_of(v(0)).trim().to_owned()
      let indent = try! @jsregex.Regex::compile("\\n\\s+")
      self.acc_description = indent.replace_all(
        flow.sanitize_text(description),
        _ => "\n",
      )
      Some(Json::string(description))
    }
    56 | 148 => Some(Json::string(string_of(v(1)) + string_of(v(0))))
    57 | 67 | 89 | 196 => Some(v(0))
    58 => {
      annotate_last(v(1), v(0))
      let nodes = ids_of(v(1))
      flow.add_link(field(v(3), "stmt"), nodes, v(2))
      Some({ "stmt": v(1), "nodes": strings(nodes + field(v(3), "nodes")) })
    }
    59 => {
      let nodes = ids_of(v(0))
      flow.add_link(field(v(2), "stmt"), nodes, v(1))
      Some({ "stmt": v(0), "nodes": strings(nodes + field(v(2), "nodes")) })
    }
    60 => {
      let nodes = ids_of(v(1))
      flow.add_link(field(v(3), "stmt"), nodes, v(2))
      Some({ "stmt": v(1), "nodes": strings(nodes + field(v(3), "nodes")) })
    }
    61 => Some({ "stmt": v(1), "nodes": v(1) })
    62 => {
      annotate_last(v(1), v(0))
      Some({ "stmt": v(1), "nodes": v(1), "shapeData": v(0) })
    }
    63 => Some({ "stmt": v(0), "nodes": v(0) })
    64 | 143 | 145 => Some(Json::array([v(0)]))
    65 => {
      annotate_last(v(5), v(4))
      Some(strings(ids_of(v(5)) + ids_of(v(0))))
    }
    66 => Some(strings(ids_of(v(4)) + ids_of(v(0))))
    68 => {
      flow.set_class(string_of(v(2)), string_of(v(0)))
      Some(v(2))
    }
    69 => vertex(v(3), v(1), "square")
    70 => vertex(v(3), v(1), "doublecircle")
    71 => vertex(v(5), v(2), "circle")
    72 => vertex(v(3), v(1), "ellipse")
    73 => vertex(v(3), v(1), "stadium")
    74 => vertex(v(3), v(1), "subroutine")
    75 => vertex(v(7), v(1), "rect")
    76 => vertex(v(3), v(1), "cylinder")
    77 => vertex(v(3), v(1), "round")
    78 => vertex(v(3), v(1), "diamond")
    79 => vertex(v(5), v(2), "hexagon")
    80 => vertex(v(3), v(1), "odd")
    81 => vertex(v(3), v(1), "trapezoid")
    82 => vertex(v(3), v(1), "inv_trapezoid")
    83 => vertex(v(3), v(1), "lean_right")
    84 => vertex(v(3), v(1), "lean_left")
    85 => {
      self.add_vertex(string_of(v(0)))
      Some(v(0))
    }
    86 => link(v(1), { "text": v(0) })
    87 | 88 => link(v(2), { "text": v(1) })
    90 =>
      link(destruct_link(string_of(v(0)), start=string_of(v(2))), {
        "text": v(1),
      })
    91 =>
      link(destruct_link(string_of(v(0)), start=string_of(v(2))), {
        "text": v(1),
        "id": v(3),
      })
    92 | 99 | 116 | 118 => Some(text_json(v(0), "text"))
    93 | 100 | 117 => {
      let (text, kind) = @flowchart.text_object(v(1)).unwrap_or(("", "text"))
      Some(text_json(Json::string(text + string_of(v(0))), kind))
    }
    94 | 101 => Some(text_json(v(0), "string"))
    95 | 102 | 119 => Some(text_json(v(0), "markdown"))
    96 => Some(destruct_link(string_of(v(0))))
    97 => link(destruct_link(string_of(v(0))), { "id": v(1) })
    98 => Some(v(1))
    120 => {
      flow.add_class(string_of(v(2)), ids_of(v(0)))
      Some(v(4))
    }
    121 => {
      flow.set_class(string_of(v(2)), string_of(v(0)))
      Some(v(4))
    }
    122 | 130 => {
      flow.set_click_event(string_of(v(1)))
      Some(v(1))
    }
    123 | 131 => {
      flow.set_click_event(string_of(v(3)))
      flow.set_tooltip(string_of(v(3)), string_of(v(0)))
      Some(v(3))
    }
    124 => {
      flow.set_click_event(string_of(v(2)))
      Some(v(2))
    }
    125 => {
      flow.set_click_event(string_of(v(4)))
      flow.set_tooltip(string_of(v(4)), string_of(v(0)))
      Some(v(4))
    }
    126 => {
      flow.set_link(string_of(v(2)), string_of(v(0)), None)
      Some(v(2))
    }
    127 => {
      flow.set_link(string_of(v(4)), string_of(v(2)), None)
      flow.set_tooltip(string_of(v(4)), string_of(v(0)))
      Some(v(4))
    }
    128 => {
      flow.set_link(string_of(v(4)), string_of(v(2)), Some(string_of(v(0))))
      Some(v(4))
    }
    129 => {
      flow.set_link(string_of(v(6)), string_of(v(4)), Some(string_of(v(0))))
      flow.set_tooltip(string_of(v(6)), string_of(v(2)))
      Some(v(6))
    }
    132 => {
      flow.set_link(string_of(v(1)), string_of(v(0)), None)
      Some(v(1))
    }
    133 => {
      flow.set_link(string_of(v(3)), string_of(v(2)), None)
      flow.set_tooltip(string_of(v(3)), string_of(v(0)))
      Some(v(3))
    }
    134 => {
      flow.set_link(string_of(v(3)), string_of(v(2)), Some(string_of(v(0))))
      Some(v(3))
    }
    135 => {
      flow.set_link(string_of(v(5)), string_of(v(4)), Some(string_of(v(0))))
      flow.set_tooltip(string_of(v(5)), string_of(v(2)))
      Some(v(5))
    }
    136 => {
      self.add_vertex(string_of(v(2)), style=ids_of(v(0)))
      Some(v(4))
    }
    137 | 138 => {
      flow.update_link(@flowchart.link_positions(v(2)), ids_of(v(0)))
      Some(v(4))
    }
    139 | 140 => {
      let positions = @flowchart.link_positions(v(6))
      flow.update_link_interpolate(positions, string_of(v(2)))
      flow.update_link(positions, ids_of(v(0)))
      Some(v(8))
    }
    141 | 142 => {
      flow.update_link_interpolate(
        @flowchart.link_positions(v(4)),
        string_of(v(0)),
      )
      Some(v(6))
    }
    144 | 146 => {
      if v(2) is Array(items) {
        items.push(v(0))
      }
      Some(v(2))
    }
    197 | 199 => Some(Json::string(string_of(v(1)) + string_of(v(0))))
    200 => Some({ "stmt": "dir", "value": "TB" })
    201 => Some({ "stmt": "dir", "value": "BT" })
    202 => Some({ "stmt": "dir", "value": "RL" })
    203 => Some({ "stmt": "dir", "value": "LR" })
    204 => Some({ "stmt": "dir", "value": "TD" })
    _ => None
  }
}

///|
/// A closing brace followed by blanks before the end of its line.
let brace_blanks : @jsregex.Regex = try! @jsregex.Regex::compile(
  "}[^\\S\\n]*\\n",
)

///|
/// Parse agentflow source into its database.
pub fn parse(source : String, config : @config.Config) -> AgentDb raise {
  let db = AgentDb::new(config)
  // As upstream's parser wrapper: blanks after a `}` that ends a line go.
  let source = brace_blanks.replace_all(source, _ => "}\n")
  agentflow_grammar.parse(
    source,
    empty=Json::null(),
    token=text => Json::string(text),
    reduce=reduction => db.reduce(reduction),
    hook=(hook, lexer) => db.flow.lexer_hook(hook, lexer),
  )
  |> ignore
  db
}
