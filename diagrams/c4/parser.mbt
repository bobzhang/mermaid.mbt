///|
/// The attribute list of a statement.
fn attributes(value : Json) -> Array[Json] {
  match value {
    Array(items) => items
    _ => []
  }
}

///|
fn string_of(value : Json) -> String {
  match value {
    String(text) => text
    _ => ""
  }
}

///|
/// `text.substring(start)`
fn substring(text : String, start : Int32) -> String {
  if start >= text.length() {
    ""
  } else {
    text[start:].to_owned()
  }
}

///|
/// JavaScript's `String.prototype.trim`.
fn js_trim(text : String) -> String {
  text
  .trim(chars=" \t\n\r\u{0b}\u{0c}\u{a0}\u{feff}\u{2028}\u{2029}")
  .to_owned()
}

///|
/// jison's `performAction` for c4Diagram.jison: run the semantic action of
/// one production. `None` keeps the default value, that of the first
/// symbol.
fn C4Db::reduce(self : C4Db, reduction : @jison.Reduction[Json]) -> Json? raise {
  let values = reduction.values
  let n = values.length()
  // `$$[$0 - k]`
  let v = (k : Int32) => values[n - 1 - k]
  // `$2.splice(2, 0, kind)`
  let spliced = (kind : String) => {
    let list = attributes(v(0))
    list.insert(list.length().min(2), Json::string(kind))
    list
  }
  match reduction.production {
    3 | 4 | 5 | 6 =>
      // Upstream calls a `setDirection` the database does not have.
      raise C4Error("yy.setDirection is not a function")
    8 | 9 | 10 | 11 | 12 => {
      self.c4_type = string_of(v(3))
      None
    }
    19 => {
      let title = substring(string_of(v(0)), 6)
      self.title = sanitize_text(title, self.config, "the title")
      Some(Json::string(title))
    }
    20 => {
      let description = substring(string_of(v(0)), 15)
      self.set_acc_description(description)
      Some(Json::string(description))
    }
    21 => {
      let title = js_trim(string_of(v(0)))
      self.title = sanitize_text(title, self.config, "the title")
      Some(Json::string(title))
    }
    22 | 23 => {
      let description = js_trim(string_of(v(0)))
      self.set_acc_description(description)
      Some(Json::string(description))
    }
    28 => {
      self.add_boundary("system", spliced("ENTERPRISE"))
      Some(v(0))
    }
    29 => {
      self.add_boundary("system", spliced("SYSTEM"))
      Some(v(0))
    }
    30 => {
      self.add_boundary("system", attributes(v(0)))
      Some(v(0))
    }
    31 => {
      self.add_boundary("container", spliced("CONTAINER"))
      Some(v(0))
    }
    32 | 33 | 34 => {
      let node_type = match reduction.production {
        32 => "node"
        33 => "nodeL"
        _ => "nodeR"
      }
      self.add_deployment_node(node_type, attributes(v(0)))
      Some(v(0))
    }
    35 => {
      self.pop_boundary_parse_stack()
      None
    }
    39..<=46 => {
      let kind = match reduction.production {
        39 => "person"
        40 => "external_person"
        41 => "system"
        42 => "system_db"
        43 => "system_queue"
        44 => "external_system"
        45 => "external_system_db"
        _ => "external_system_queue"
      }
      self.add_person_or_system(kind, attributes(v(0)))
      Some(v(0))
    }
    47..<=58 => {
      let kind = match reduction.production {
        47 => "container"
        48 => "container_db"
        49 => "container_queue"
        50 => "external_container"
        51 => "external_container_db"
        52 => "external_container_queue"
        53 => "component"
        54 => "component_db"
        55 => "component_queue"
        56 => "external_component"
        57 => "external_component_db"
        _ => "external_component_queue"
      }
      self.add_container(kind, attributes(v(0)))
      Some(v(0))
    }
    60..<=66 => {
      let kind = match reduction.production {
        60 => "rel"
        61 => "birel"
        62 => "rel_u"
        63 => "rel_d"
        64 => "rel_l"
        65 => "rel_r"
        _ => "rel_b"
      }
      self.add_rel(kind, attributes(v(0)))
      Some(v(0))
    }
    67 => {
      // `RelIndex` drops its index.
      let list = attributes(v(0))
      if !list.is_empty() {
        list.remove(0) |> ignore
      }
      self.add_rel("rel", list)
      Some(v(0))
    }
    68 => {
      self.update_el_style(attributes(v(0)))
      Some(v(0))
    }
    69 => {
      self.update_rel_style(attributes(v(0)))
      Some(v(0))
    }
    70 => {
      self.update_layout_config(attributes(v(0)))
      Some(v(0))
    }
    71 => Some(Json::array([v(0)]))
    72 => {
      let list = attributes(v(0))
      list.insert(0, v(1))
      Some(v(0))
    }
    73 | 75 => Some(Json::string(js_trim(string_of(v(0)))))
    74 => {
      let pair : Map[String, Json] = Map([])
      pair[js_trim(string_of(v(1)))] = Json::string(js_trim(string_of(v(0))))
      Some(Json::object(pair))
    }
    76 => Some(Json::string(""))
    _ => None
  }
}

///|
/// mermaid's `setAccDescription`: indentation after line breaks goes.
fn C4Db::set_acc_description(
  self : C4Db,
  description : String,
) -> Unit raise Unsupported {
  let indent = try! @jsregex.Regex::compile("\\n\\s+", flags="g")
  self.acc_description = indent.replace_all(
    sanitize_text(description, self.config, "the description"),
    _ => "\n",
  )
}

///|
/// Parse a C4 diagram. `config` is the configuration in effect, which
/// decides whether texts wrap.
pub fn parse(source : String, config : @config.Config) -> C4Db raise {
  let db = C4Db::new(config)
  c4diagram_grammar.parse(
    source,
    empty=Json::null(),
    token=text => Json::string(text),
    reduce=reduction => db.reduce(reduction),
    // The only custom code belongs to a comment rule that never matches.
    hook=(_, _) => Continue,
  )
  |> ignore
  db
}
