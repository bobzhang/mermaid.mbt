// The nodes and edges handed to the unified renderer: `getData` of
// mermaid's `usecaseDb.ts` and what `usecaseRenderer.ts` makes of them
// before it draws.

///|
/// A node of the layout, with what its shape needs to know.
priv struct LayoutNode {
  id : String
  mut label : String
  mut label_type : String
  shape : String
  is_group : Bool
  padding : Double
  color_index : Int32?
  css_classes : String
  css_styles : Array[String]
  css_compiled_styles : Array[String]
  actor_type : String?
  business : Bool
  icon : String?
  mut stereotype : String?
  parent_id : String?
  note_target : String?
  mut json_rows : Array[JsonRow]
  boundary_type : String?
  wrapping_width : Double
  min_width : Double?
  spread_ports : Bool
  /// What a screen reader says for the node.
  mut accessible_name : String
  /// Whether the stereotype was made the first line of the label.
  mut folded_stereotype : Bool
}

///|
priv struct LayoutEdge {
  id : String
  source : String
  target : String
  /// `association`, `include`, `extend`, `generalization` or `note`.
  relationship_type : String
  /// Whether the edge ties a note to its target.
  internal : Bool
  arrow_type_start : String
  arrow_type_end : String
  pattern : String
  mut label : String?
  label_type : String?
  classes : String
  style : Array[String]
  css_compiled_styles : Array[String]
  animate : Bool
  animation : String?
  minlen : Int32
  is_user_defined_id : Bool
  mut accessible_name : String
}

///|
/// mermaid's `sanitizeText`: the text as DOMPurify hands it back, which
/// differs from what went in only when there is a `<` in it.
fn sanitize_text(text : String) -> String raise UsecaseError {
  @dom.sanitize_fragment(text) catch {
    _ => raise Unsupported("use case diagram text with markup: \{text}")
  }
}

///|
/// The names that are not empty, joined by spaces: `classNames`.
fn class_names(names : Array[String]) -> String {
  names.filter(name => name != "").join(" ")
}

///|
/// The declarations of the `default` class and of `classes`, a later
/// declaration of a property replacing an earlier one where that stood:
/// `getCompiledStyles`.
fn UsecaseDb::compiled_styles(
  self : UsecaseDb,
  classes : Array[String],
) -> Array[String] {
  let compiled : Map[String, String] = Map([])
  for name in ["default", ..classes] {
    guard self.class_defs.get(name) is Some(styles) else { continue }
    for raw in styles {
      let style = js_trim(raw)
      let property = js_trim(
        match style.find(":") {
          Some(colon) => style[:colon].to_owned()
          None => style
        },
      )
      if property != "" {
        compiled[property] = style
      }
    }
  }
  compiled.values().collect()
}

///|
/// The markers of an association: `associationMarkers`.
fn association_markers(arrow_type : Int32) -> (String, String) {
  match arrow_type {
    0 => ("none", "arrow_point")
    1 => ("arrow_point", "none")
    3 => ("none", "arrow_circle")
    4 => ("none", "arrow_cross")
    5 => ("arrow_circle", "none")
    6 => ("arrow_cross", "none")
    _ => ("none", "none")
  }
}

///|
/// A label as it is read out: a markdown label without its formatting.
fn accessible_label(
  label : String,
  label_type : String,
) -> String raise UsecaseError {
  if label_type == "markdown" {
    // Deep block quotes and emphasis are lexed by recursion; see
    // `@rendering.markdown_too_deep`.
    if @rendering.markdown_too_deep(label) {
      raise Unsupported(
        "a label nests block quotes or emphasis deeper than the port lexes",
      )
    }
    @rendering.markdown_plain_text(label)
  } else {
    label
  }
}

///|
/// The nodes and edges of the diagram: `getData`, with the accessible
/// names `draw` works out from them.
fn UsecaseDb::layout_data(
  self : UsecaseDb,
) -> (Array[LayoutNode], Array[LayoutEdge]) raise UsecaseError {
  let config = self.config
  let wrapping_width = config.number("usecase.wrappingWidth").unwrap_or(120.0)
  let min_node_width = config.number("usecase.minNodeWidth")
  let nodes : Array[LayoutNode] = []
  let edges : Array[LayoutEdge] = []
  let endpoint_label = (id : String) => {
    sanitize_text(
      match
        (
          self.actors.get(id),
          self.use_cases.get(id),
          self.json_nodes.get(id),
          self.notes.get(id),
        ) {
        (Some(actor), _, _, _) => actor.label
        (_, Some(use_case), _, _) => use_case.label
        (_, _, Some(json), _) => json.id
        (_, _, _, Some(note)) => note.label
        _ => id
      },
    )
  }
  let mut color_index = 0
  for _, actor in self.actors {
    nodes.push({
      id: actor.id,
      label: sanitize_text(actor.label),
      label_type: actor.label_type,
      shape: match actor.type_ {
        "hollow" => "usecaseActorHollow"
        "awesome" => "usecaseActorAwesome"
        "icon" => "usecaseActorIcon"
        _ => "usecaseActor"
      },
      is_group: false,
      padding: 10.0,
      color_index: Some(color_index),
      css_classes: class_names(
        [
          "default",
          "usecase-actor",
          "usecase-actor-\{actor.type_}",
          if actor.business {
            "usecase-business"
          } else {
            ""
          },
          ..actor.classes,
        ],
      ),
      css_styles: actor.styles.copy(),
      css_compiled_styles: self.compiled_styles(actor.classes),
      actor_type: Some(actor.type_),
      business: actor.business,
      icon: actor.icon,
      stereotype: match actor.stereotype {
        Some(text) => Some(sanitize_text(text))
        None => None
      },
      parent_id: actor.parent_id,
      note_target: None,
      json_rows: [],
      boundary_type: None,
      wrapping_width,
      min_width: None,
      spread_ports: false,
      accessible_name: "",
      folded_stereotype: false,
    })
    color_index += 1
  }
  for _, use_case in self.use_cases {
    let ellipse = use_case.shape == "ellipse"
    nodes.push({
      id: use_case.id,
      label: sanitize_text(use_case.label),
      label_type: use_case.label_type,
      shape: if !ellipse {
        use_case.shape
      } else if use_case.business {
        "usecaseBusiness"
      } else {
        "usecaseEllipse"
      },
      is_group: false,
      padding: if ellipse {
        20.0
      } else {
        10.0
      },
      color_index: Some(color_index),
      css_classes: class_names(
        [
          "default",
          "usecase-element",
          "usecase-\{use_case.shape}",
          if use_case.business {
            "usecase-business"
          } else {
            ""
          },
          ..use_case.classes,
        ],
      ),
      css_styles: use_case.styles.copy(),
      css_compiled_styles: self.compiled_styles(use_case.classes),
      actor_type: None,
      business: use_case.business,
      icon: None,
      stereotype: match use_case.stereotype {
        Some(text) => Some(sanitize_text(text))
        None => None
      },
      parent_id: use_case.parent_id,
      note_target: None,
      json_rows: [],
      boundary_type: None,
      wrapping_width,
      min_width: min_node_width,
      spread_ports: ellipse,
      accessible_name: "",
      folded_stereotype: false,
    })
    color_index += 1
  }
  for _, note in self.notes {
    nodes.push({
      id: note.id,
      label: sanitize_text(note.label),
      label_type: note.label_type,
      shape: "note",
      is_group: false,
      padding: 10.0,
      color_index: None,
      css_classes: "default usecase-note",
      css_styles: [],
      css_compiled_styles: self.compiled_styles([]),
      actor_type: None,
      business: false,
      icon: None,
      stereotype: None,
      parent_id: None,
      note_target: Some(note.target),
      json_rows: [],
      boundary_type: None,
      wrapping_width,
      min_width: min_node_width,
      spread_ports: false,
      accessible_name: "",
      folded_stereotype: false,
    })
  }
  for _, json in self.json_nodes {
    let rows = []
    for row in flatten_json_rows(json.value) {
      rows.push({
        key: sanitize_text(row.key),
        accessible_key: sanitize_text(row.accessible_key),
        value: sanitize_text(row.value),
      })
    }
    nodes.push({
      id: json.id,
      label: sanitize_text(json.id),
      label_type: "text",
      shape: "usecaseJsonTable",
      is_group: false,
      padding: 10.0,
      color_index: None,
      css_classes: class_names(
        ["default", "usecase-json-table", ..json.classes],
      ),
      css_styles: json.styles.copy(),
      css_compiled_styles: self.compiled_styles(json.classes),
      actor_type: None,
      business: false,
      icon: None,
      stereotype: None,
      parent_id: None,
      note_target: None,
      json_rows: rows,
      boundary_type: None,
      wrapping_width,
      min_width: min_node_width,
      spread_ports: false,
      accessible_name: "",
      folded_stereotype: false,
    })
  }
  let mut boundary_color_index = 0
  for _, boundary in self.boundaries {
    nodes.push({
      id: boundary.id,
      label: sanitize_text(boundary.label),
      label_type: boundary.label_type,
      shape: "usecaseSystemBoundary",
      is_group: true,
      padding: 20.0,
      color_index: Some(boundary_color_index),
      css_classes: class_names(
        [
          "default",
          "system-boundary",
          "system-boundary-\{boundary.type_}",
          ..boundary.classes,
        ],
      ),
      css_styles: boundary.styles.copy(),
      css_compiled_styles: self.compiled_styles(boundary.classes),
      actor_type: None,
      business: false,
      icon: None,
      stereotype: None,
      parent_id: None,
      note_target: None,
      json_rows: [],
      boundary_type: Some(boundary.type_),
      wrapping_width,
      min_width: None,
      spread_ports: false,
      accessible_name: "",
      folded_stereotype: false,
    })
    boundary_color_index += 1
  }
  for relationship in self.relationships {
    let (arrow_type_start, arrow_type_end, pattern, label, label_type) = match
      relationship.type_ {
      "include" | "extend" =>
        (
          "none",
          "arrow_point",
          "dotted",
          Some(relationship.type_),
          Some("text"),
        )
      "generalization" => ("none", "extension", "solid", None, None)
      _ => {
        let (start, end) = association_markers(relationship.arrow_type)
        (
          start,
          end,
          "solid",
          relationship.label.filter(label => label != ""),
          relationship.label_type,
        )
      }
    }
    let animation = match (relationship.animate, relationship.animation) {
      (_, Some(animation)) => ["edge-animation-\{animation}"]
      (true, None) => ["edge-animation-fast"]
      (false, None) => []
    }
    edges.push({
      id: relationship.id,
      source: relationship.source,
      target: relationship.target,
      relationship_type: relationship.type_,
      internal: false,
      arrow_type_start,
      arrow_type_end,
      pattern,
      label: match label {
        Some(label) => Some(sanitize_text(label))
        None => None
      },
      label_type,
      classes: class_names(
        [
          "default",
          "relationship",
          "relationship-\{relationship.type_}",
          ..relationship.classes,
          ..animation,
        ],
      ),
      style: relationship.styles.copy(),
      css_compiled_styles: self.compiled_styles(relationship.classes),
      animate: relationship.animate,
      animation: relationship.animation,
      minlen: relationship.minlen,
      is_user_defined_id: relationship.explicit_id,
      accessible_name: "",
    })
  }
  for _, note in self.notes {
    edges.push({
      id: "\{note.id}-edge",
      source: note.id,
      target: note.target,
      relationship_type: "note",
      internal: true,
      arrow_type_start: "none",
      arrow_type_end: "none",
      pattern: "dotted",
      label: None,
      label_type: None,
      classes: "default relationship relationship-note",
      style: [],
      css_compiled_styles: self.compiled_styles([]),
      animate: false,
      animation: None,
      minlen: 1,
      is_user_defined_id: false,
      accessible_name: "",
    })
  }
  // What `draw` reads out, from the labels as they stand here.
  let accessible_labels : Map[String, String] = Map([])
  for node in nodes {
    accessible_labels[node.id] = accessible_label(node.label, node.label_type)
  }
  for node in nodes {
    let label = accessible_labels.get(node.id).unwrap_or(node.id)
    let stereotype = match node.stereotype {
      Some(text) => ", stereotype \{text}"
      None => ""
    }
    let business = if node.business { "business " } else { "" }
    node.accessible_name = if node.is_group {
      "\{node.boundary_type.unwrap_or("rect")} system boundary \{label}"
    } else if node.actor_type is Some(actor_type) {
      let variant = if actor_type != "normal" { "\{actor_type} " } else { "" }
      "\{business}\{variant}actor \{label}\{stereotype}"
    } else if node.shape == "note" {
      let target = node.note_target.unwrap_or("")
      "Note for \{accessible_labels.get(target).unwrap_or(target)}: \{label}"
    } else if node.shape == "usecaseJsonTable" {
      let rows = node.json_rows
        .map(row => "\{row.accessible_key}: \{row.value}")
        .join("; ")
      if rows != "" {
        "\{label}: \{rows}"
      } else {
        label
      }
    } else {
      "\{business}use case \{label}\{stereotype}"
    }
  }
  for edge in edges {
    if edge.relationship_type == "note" {
      continue
    }
    let relation = match edge.label {
      Some(label) if edge.relationship_type == "association" && label != "" =>
        "association \{accessible_label(label, edge.label_type.unwrap_or("text"))}"
      _ => edge.relationship_type
    }
    let name = (id : String) => {
      match accessible_labels.get(id) {
        Some(label) => label
        None => endpoint_label(id)
      }
    }
    edge.accessible_name = "\{relation} from \{name(edge.source)} to \{name(edge.target)}"
  }
  (nodes, edges)
}

///|
/// `&`, `<` and `>` as references, for a label that is plain text:
/// `escapePlainLabel`.
fn escape_plain_label(label : String) -> String {
  label
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
}

///|
/// A backslash before every character markdown gives a meaning:
/// `escapeMarkdownMarkers`.
fn escape_markdown_markers(label : String) -> String {
  let out = StringBuilder()
  for character in label {
    if character is ('*' | '[' | '\\' | ']' | '_' | '`') {
      out.write_char('\\')
    }
    out.write_char(character)
  }
  out.to_string()
}

///|
/// The part of an element id that stands for a model id: every run of
/// characters other than letters, digits, `_` and `-` becomes one `_`, and
/// those at the ends go.
fn safe_id(id : String) -> String {
  let out = StringBuilder()
  let mut pending = false
  for character in id {
    if character is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_' | '-') {
      if pending {
        out.write_char('_')
        pending = false
      }
      out.write_char(character)
    } else {
      pending = true
    }
  }
  if pending {
    out.write_char('_')
  }
  let safe = out.to_string()
  let mut start = 0
  let mut end = safe.length()
  while start < end && safe.unsafe_get(start) == '_' {
    start += 1
  }
  while end > start && safe.unsafe_get(end - 1) == '_' {
    end -= 1
  }
  if start == end {
    "element"
  } else {
    safe[start:end].to_owned()
  }
}

///|
/// Make the labels ready for the label renderer, which takes them for
/// markup: `prepareUsecaseLayoutData`. Plain text is escaped, and the
/// stereotype of a use case drawn as a plain ellipse or rectangle becomes
/// the first line of a markdown label.
fn prepare_layout_data(
  nodes : Array[LayoutNode],
  edges : Array[LayoutEdge],
) -> Unit {
  for node in nodes {
    if node.label_type == "text" {
      node.label = escape_plain_label(node.label)
    }
    if node.stereotype is Some(stereotype) {
      node.stereotype = Some(escape_plain_label(stereotype))
    }
    if !node.is_group && node.shape == "usecaseJsonTable" {
      node.json_rows = node.json_rows.map(row => {
        ..row,
        key: escape_plain_label(row.key),
        value: escape_plain_label(row.value),
      })
    }
    if !node.is_group &&
      node.shape is ("usecaseEllipse" | "rect") &&
      node.stereotype is Some(stereotype) {
      let label = if node.label_type == "text" {
        escape_markdown_markers(node.label)
      } else {
        node.label
      }
      node.label = "«\{escape_markdown_markers(stereotype)}»<br/>\{label}"
      node.label_type = "markdown"
      node.folded_stereotype = true
      node.stereotype = None
    }
  }
  for edge in edges {
    if edge.label is Some(label) && edge.label_type == Some("text") {
      edge.label = Some(escape_plain_label(label))
    }
  }
}

///|
/// The parsed diagram as mermaid's `getData` describes it, for comparing
/// the parser with upstream's.
pub fn UsecaseDb::dump(self : UsecaseDb) -> Json raise UsecaseError {
  let (nodes, edges) = self.layout_data()
  let text = (value : String?) => {
    match value {
      Some(value) => Json::string(value)
      None => Json::null()
    }
  }
  let strings = (values : Array[String]) => {
    Json::array(values.map(value => Json::string(value)))
  }
  let node_list : Array[Json] = nodes.map(node => {
    let item : Map[String, Json] = Map([])
    item["id"] = Json::string(node.id)
    item["label"] = Json::string(node.label)
    item["labelType"] = Json::string(node.label_type)
    item["shape"] = Json::string(node.shape)
    item["isGroup"] = Json::boolean(node.is_group)
    item["padding"] = Json::number(node.padding)
    item["colorIndex"] = match node.color_index {
      Some(index) => Json::number(index.to_double())
      None => Json::null()
    }
    item["cssClasses"] = Json::string(node.css_classes)
    item["cssStyles"] = strings(node.css_styles)
    item["cssCompiledStyles"] = strings(node.css_compiled_styles)
    item["actorType"] = text(node.actor_type)
    item["business"] = Json::boolean(node.business)
    item["icon"] = text(node.icon)
    item["stereotype"] = text(node.stereotype)
    item["parentId"] = text(node.parent_id)
    item["noteTarget"] = text(node.note_target)
    item["jsonRows"] = Json::array(
      node.json_rows.map(row => {
        let cells : Json = {
          "key": row.key,
          "accessibleKey": row.accessible_key,
          "value": row.value,
        }
        cells
      }),
    )
    item["boundaryType"] = text(node.boundary_type)
    item["wrappingWidth"] = Json::number(node.wrapping_width)
    item["minWidth"] = match node.min_width {
      Some(width) => Json::number(width)
      None => Json::null()
    }
    item["spreadPorts"] = Json::boolean(node.spread_ports)
    item["accessibleName"] = Json::string(node.accessible_name)
    Json::object(item)
  })
  let edge_list : Array[Json] = edges.map(edge => {
    let item : Map[String, Json] = Map([])
    item["id"] = Json::string(edge.id)
    item["source"] = Json::string(edge.source)
    item["target"] = Json::string(edge.target)
    item["relationshipType"] = Json::string(edge.relationship_type)
    item["internal"] = Json::boolean(edge.internal)
    item["arrowTypeStart"] = Json::string(edge.arrow_type_start)
    item["arrowTypeEnd"] = Json::string(edge.arrow_type_end)
    item["pattern"] = Json::string(edge.pattern)
    item["label"] = text(edge.label)
    item["labelType"] = text(edge.label_type)
    item["classes"] = Json::string(edge.classes)
    item["style"] = strings(edge.style)
    item["cssCompiledStyles"] = strings(edge.css_compiled_styles)
    item["animate"] = Json::boolean(edge.animate)
    item["animation"] = text(edge.animation)
    item["minlen"] = Json::number(edge.minlen.to_double())
    item["isUserDefinedId"] = Json::boolean(edge.is_user_defined_id)
    item["accessibleName"] = Json::string(edge.accessible_name)
    Json::object(item)
  })
  let dump : Json = {
    "nodes": Json::array(node_list),
    "edges": Json::array(edge_list),
    "direction": self.direction,
    "accTitle": self.acc_title,
    "accDescription": self.acc_description,
  }
  dump
}
