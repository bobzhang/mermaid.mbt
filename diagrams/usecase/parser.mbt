// From source text to drafts of the model: mermaid's `usecase.parser.ts`
// (the predicates of the grammar) and `usecase.visitor.ts`.

///|
/// Where something stands in the source: its span in UTF-16 code units,
/// and the line and column of its start, counting from one.
priv struct Location {
  start : Int32
  end : Int32
  line : Int32
  column : Int32
}

///|
fn Location::to_string(self : Location) -> String {
  "line \{self.line}, column \{self.column} [\{self.start},\{self.end})"
}

///|
/// A label and whether it is `text` or `markdown`.
priv struct Label {
  text : String
  type_ : String
}

///|
priv enum MetadataValue {
  Flag(Bool)
  Text(String)
}

///|
priv struct Property {
  key : String
  value : MetadataValue
  location : Location
}

///|
/// An actor or a use case where it is named, with what is written after
/// the name.
priv struct Entity {
  id : String
  label : Label
  location : Location
  /// Whether the id is made from a quoted label.
  generated : Bool
  mut shape : String?
  metadata : Array[Property]?
  stereotype : String?
  classes : Array[String]
  /// Whether this mention declares a use case, rather than refer to one.
  mut explicit_declaration : Bool
}

///|
priv struct ElementDraft {
  id : String
  /// `actor` or `usecase`.
  kind : String
  label : Label
  location : Location
  generated : Bool
  parent : (String, Location)?
  shape : String?
  metadata : Array[Property]?
  stereotype : String?
  classes : Array[String]
}

///|
priv struct BoundaryDraft {
  id : String
  label : Label
  location : Location
  generated : Bool
  classes : Array[String]
}

///|
priv struct JsonDraft {
  id : String
  value : JsonValue
  location : Location
  classes : Array[String]
}

///|
priv struct Endpoint {
  id : String
  label : Label
  location : Location
  generated : Bool
  declaration : Bool
  classes_on_reference : Bool
}

///|
priv struct Arrow {
  type_ : String
  arrow_type : Int32
  label : Label?
  minlen : Int32
}

///|
priv struct RelationshipDraft {
  source : Endpoint
  target : Endpoint
  location : Location
  explicit_id : (String, Location)?
  arrow : Arrow
}

///|
priv struct NoteDraft {
  target : String
  target_location : Location
  label : Label
}

///|
priv struct MetadataAssignment {
  target : String
  target_location : Location
  properties : Array[Property]
}

///|
/// Everything the statements of a diagram say, before it is resolved into
/// a model.
priv struct Drafts {
  elements : Array[ElementDraft]
  boundaries : Array[BoundaryDraft]
  json : Array[JsonDraft]
  relationships : Array[RelationshipDraft]
  notes : Array[NoteDraft]
  metadata_assignments : Array[MetadataAssignment]
  class_definitions : Array[(Array[String], Array[String])]
  class_assignments : Array[(Array[(String, Location)], Array[String])]
  style_assignments : Array[(String, Location, Array[String])]
  directions : Array[String]
  mut acc_title : String
  mut acc_description : String
}

///|
/// Whether a token can be part of an edge label.
fn is_label_token(
  grammar : @chevrotain.Grammar,
  token : @chevrotain.Token,
) -> Bool {
  grammar.accepts("LABEL_TEXT", token) ||
  token.name is ("PLAIN_STRING" | "MARKDOWN_STRING")
}

///|
/// Whether a label and then one of the `allowed` operators follow:
/// `hasLabeledRight`.
fn has_labeled_right(
  parser : @chevrotain.Parser,
  allowed : Array[String],
) -> Bool {
  if !is_label_token(usecase_grammar, parser.la(1)) {
    return false
  }
  let mut index = 2
  while true {
    let token = parser.la(index)
    if allowed.contains(token.name) {
      return true
    }
    if !is_label_token(usecase_grammar, token) {
      return false
    }
    index += 1
  }
  false
}

///|
/// The predicates of the grammar.
fn gate(key : String, parser : @chevrotain.Parser) -> Bool {
  match key {
    // `isStatementStart`
    "line:Alternation0:2" =>
      !(parser.la(1).name is ("EOF" | "NEWLINE" | "COMMENT"))
    // `isMetadataAssignment`
    "statement:Alternation0:10" =>
      parser.la(1).name is ("IDENTIFIER" | "PLAIN_STRING" | "MARKDOWN_STRING") &&
      parser.la(2).name == "METADATA_START"
    // `!isForbiddenPlantUmlStatement`
    "statement:Alternation0:11" => {
      let token = parser.la(1)
      !(token.name == "IDENTIFIER" &&
      ascii_lower(token.image)
      is ("allowmixing" | "newpage" | "package" | "rectangle" | "skinparam"))
    }
    "relationTail:Option0" =>
      parser.la(1).name == "IDENTIFIER" && parser.la(2).name == "AT"
    "backwardSolidOperator:Option0" =>
      parser.la(0).image == "<--" &&
      has_labeled_right(parser, ["MARKERLESS_SOLID"])
    "markerlessSolidOperator:Option0" =>
      parser.la(0).image == "--" &&
      has_labeled_right(parser, [
        "FORWARD_SOLID", "MARKERLESS_SOLID", "FORWARD_CIRCLE", "FORWARD_CROSS",
      ])
    "backwardCircleOperator:Option0" | "backwardCrossOperator:Option0" =>
      has_labeled_right(parser, ["MARKERLESS_SOLID"])
    _ => true
  }
}

///|
/// `toLowerCase` of an identifier, which is ASCII.
fn ascii_lower(text : String) -> String {
  String::from_array(
    text
    .iter()
    .map(c => {
      if c is ('A'..<='Z') {
        (c.to_int() + 32).unsafe_to_char()
      } else {
        c
      }
    })
    .collect(),
  )
}

///|
/// Walks the syntax tree of a diagram and collects what it says.
priv struct Visitor {
  source : String
  drafts : Drafts
  mut parent_boundary : (String, Location)?
}

///|
/// The line and column of an offset, counting from one, as chevrotain's
/// lexer tracks them.
fn Visitor::position(self : Visitor, offset : Int32) -> (Int32, Int32) {
  let mut line = 1
  let mut line_start = 0
  let mut index = 0
  while index < offset && index < self.source.length() {
    match code_at(self.source, index) {
      '\r' => {
        if code_at(self.source, index + 1) == '\n' && index + 1 < offset {
          index += 1
        }
        line += 1
        line_start = index + 1
      }
      '\n' => {
        line += 1
        line_start = index + 1
      }
      _ => ()
    }
    index += 1
  }
  (line, offset - line_start + 1)
}

///|
/// How much of a string token its quotes take at each end.
fn quote_width(token : @chevrotain.Token) -> Int32 {
  match token.name {
    "PLAIN_STRING" => 1
    "MARKDOWN_STRING" => 2
    _ => 0
  }
}

///|
/// Where the content of a token is: `tokenLocation`.
fn Visitor::token_location(
  self : Visitor,
  token : @chevrotain.Token,
) -> Location {
  let trim = quote_width(token)
  let (line, column) = self.position(token.start)
  let length = self.source.length()
  {
    start: token.start + trim,
    end: length.min(token.end - trim),
    line,
    column: column + trim,
  }
}

///|
/// Where a node of the tree is: `nodeLocation`.
fn Visitor::node_location(
  self : Visitor,
  node : @chevrotain.CstNode,
) -> Location {
  let tokens = node.all_tokens().filter(token => token.name != "NEWLINE")
  guard tokens is [first, ..] && tokens is [.., last] else {
    return { start: 0, end: 0, line: 1, column: 1, }
  }
  let (line, column) = self.position(first.start)
  { start: first.start, end: self.source.length().min(last.end), line, column, }
}

///|
/// The label a name or string token spells: `tokenLabel`.
fn Visitor::token_label(self : Visitor, token : @chevrotain.Token) -> Label {
  let trim = quote_width(token)
  let end = self.source.length().min(token.end - trim)
  {
    text: self.source[token.start + trim:end].to_owned(),
    type_: if token.name == "MARKDOWN_STRING" {
      "markdown"
    } else {
      "text"
    },
  }
}

///|
/// The id made from a label: `generateId`.
fn generate_id(label : String) -> String {
  String::from_array(
    label
    .to_array()
    .map(c => {
      if c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_') {
        c
      } else {
        '_'
      }
    }),
  )
}

///|
/// `nodeLabel` and `edgeLabel`: a string, or the source from the first
/// token of the label to the last.
fn Visitor::label(self : Visitor, node : @chevrotain.CstNode) -> Label {
  let tokens = node.all_tokens()
  if tokens is [token] && token.name is ("PLAIN_STRING" | "MARKDOWN_STRING") {
    return self.token_label(token)
  }
  {
    text: self.source[tokens[0].start:tokens[tokens.length() - 1].end].to_owned(),
    type_: "text",
  }
}

///|
/// What a string token holds: `decodePlain`.
fn decode_plain(token : @chevrotain.Token) -> String {
  if token.name == "PLAIN_STRING" {
    token.image[1:token.image.length() - 1].to_owned()
  } else {
    token.image
  }
}

///|
fn Visitor::metadata(
  self : Visitor,
  node : @chevrotain.CstNode,
) -> Array[Property] {
  node
  .nodes("metadataProperty")
  .map(property => {
    let tokens = property.all_tokens().filter(token => token.name != "COLON")
    let key = tokens[0]
    let value = tokens[1]
    {
      key: decode_plain(key),
      value: match value.name {
        "TRUE" => Flag(true)
        "FALSE" => Flag(false)
        _ => Text(decode_plain(value))
      },
      location: self.token_location(key),
    }
  })
}

///|
fn stereotype(node : @chevrotain.CstNode) -> String {
  js_trim(node.tokens("STEREOTYPE_TEXT")[0].image)
}

///|
/// JavaScript's `String.prototype.trim`.
fn js_trim(text : String) -> String {
  let mut start = 0
  let mut end = text.length()
  while start < end && is_blank(text[start:start + 1]) {
    start += 1
  }
  while end > start && is_blank(text[end - 1:end]) {
    end -= 1
  }
  text[start:end].to_owned()
}

///|
fn class_suffix(node : @chevrotain.CstNode) -> Array[String] {
  match node.nodes("classSuffix") {
    [suffix, ..] => suffix.tokens("IDENTIFIER").map(token => token.image)
    [] => []
  }
}

///|
/// `actorItem` with its `actorName`.
fn Visitor::actor_item(self : Visitor, node : @chevrotain.CstNode) -> Entity {
  let name = node.nodes("actorName")[0]
  let metadata = node.nodes("metadata").get(0).map(node => self.metadata(node))
  let stereotype = node.nodes("stereotype").get(0).map(stereotype)
  let classes = class_suffix(node)
  match name.tokens("IDENTIFIER") {
    [identifier, ..] =>
      {
        id: identifier.image,
        label: match name.nodes("nodeLabel") {
          [label, ..] => self.label(label)
          [] => self.token_label(identifier)
        },
        location: self.token_location(identifier),
        generated: false,
        shape: None,
        metadata,
        stereotype,
        classes,
        explicit_declaration: true,
      }
    [] => {
      let string = match name.tokens("PLAIN_STRING") {
        [string, ..] => string
        [] => name.tokens("MARKDOWN_STRING")[0]
      }
      let label = self.token_label(string)
      {
        id: generate_id(label.text),
        label,
        location: self.token_location(string),
        generated: true,
        shape: None,
        metadata,
        stereotype,
        classes,
        explicit_declaration: true,
      }
    }
  }
}

///|
fn Visitor::entity_name(self : Visitor, node : @chevrotain.CstNode) -> Entity {
  let metadata = node
    .nodes("useCaseMetadata")
    .get(0)
    .map(node => self.metadata(node.nodes("metadata")[0]))
  let stereotype = node.nodes("stereotype").get(0).map(stereotype)
  let classes = class_suffix(node)
  match node.tokens("IDENTIFIER") {
    [identifier, ..] => {
      let label_node = node.nodes("nodeLabel").get(0)
      let shape = match label_node {
        Some(_) =>
          Some(
            if node.tokens("LBRACKET").is_empty() {
              "ellipse"
            } else {
              "rect"
            },
          )
        None => None
      }
      {
        id: identifier.image,
        label: match label_node {
          Some(label) => self.label(label)
          None => self.token_label(identifier)
        },
        location: self.token_location(identifier),
        generated: false,
        shape,
        metadata,
        stereotype,
        classes,
        explicit_declaration: shape is Some(_) ||
        metadata is Some(_) ||
        stereotype is Some(_),
      }
    }
    [] => {
      let string = match node.tokens("PLAIN_STRING") {
        [string, ..] => string
        [] => node.tokens("MARKDOWN_STRING")[0]
      }
      let label = self.token_label(string)
      {
        id: generate_id(label.text),
        label,
        location: self.token_location(string),
        generated: true,
        shape: None,
        metadata,
        stereotype,
        classes,
        explicit_declaration: metadata is Some(_) || stereotype is Some(_),
      }
    }
  }
}

///|
fn Visitor::element_draft(
  self : Visitor,
  entity : Entity,
  kind : String,
) -> ElementDraft {
  {
    id: entity.id,
    kind,
    label: entity.label,
    location: entity.location,
    generated: entity.generated,
    parent: self.parent_boundary,
    shape: entity.shape,
    metadata: entity.metadata,
    stereotype: entity.stereotype,
    classes: entity.classes,
  }
}

///|
fn endpoint(entity : Entity, declaration : Bool) -> Endpoint {
  {
    id: entity.id,
    label: entity.label,
    location: entity.location,
    generated: entity.generated,
    declaration,
    classes_on_reference: !entity.classes.is_empty(),
  }
}

///|
/// `Math.max(1, dashes - 1)` of a solid operator: `solidMinlen`.
fn solid_minlen(token : @chevrotain.Token) -> Int32 {
  let dashes = token.image.iter().filter(c => c == '-').count()
  // An operator without a dash counts as two.
  let dashes = if dashes == 0 { 2 } else { dashes }
  (dashes - 1).max(1)
}

///|
fn Visitor::arrow(self : Visitor, node : @chevrotain.CstNode) -> Arrow {
  let association = (arrow_type : Int32, minlen : Int32, label : Label?) => {
    let arrow : Arrow = { type_: "association", arrow_type, label, minlen, }
    arrow
  }
  let edge_label = (operator : @chevrotain.CstNode) => {
    operator.nodes("edgeLabel").get(0).map(label => self.label(label))
  }
  for name, elements in node.children {
    guard elements is [Node(operator), ..] else { continue }
    match name {
      "semanticRelation" => {
        if !operator.tokens("GENERALIZATION").is_empty() {
          return {
            type_: "generalization",
            arrow_type: SOLID_ARROW,
            label: None,
            minlen: 1,
          }
        }
        let type_ = if operator.tokens("INCLUDE").is_empty() {
          "extend"
        } else {
          "include"
        }
        return {
          type_,
          arrow_type: SOLID_ARROW,
          label: Some({ text: type_, type_: "text", }),
          minlen: 1,
        }
      }
      "forwardSolidOperator" =>
        return association(
          SOLID_ARROW,
          solid_minlen(operator.tokens("FORWARD_SOLID")[0]),
          None,
        )
      "backwardSolidOperator" => {
        let label = edge_label(operator)
        let length_token = match (label, operator.tokens("MARKERLESS_SOLID")) {
          (Some(_), [.., last]) => last
          _ => operator.tokens("BACKWARD_SOLID")[0]
        }
        return association(BACK_ARROW, solid_minlen(length_token), label)
      }
      "markerlessSolidOperator" => {
        guard edge_label(operator) is Some(label) else {
          return association(
            LINE_SOLID,
            solid_minlen(operator.tokens("MARKERLESS_SOLID")[0]),
            None,
          )
        }
        let tokens = operator.all_tokens()
        let last = tokens[tokens.length() - 1]
        let arrow_type = match last.name {
          "FORWARD_SOLID" => SOLID_ARROW
          "FORWARD_CIRCLE" => CIRCLE_ARROW
          "FORWARD_CROSS" => CROSS_ARROW
          _ => LINE_SOLID
        }
        return association(
          arrow_type,
          if arrow_type == SOLID_ARROW || arrow_type == LINE_SOLID {
            solid_minlen(last)
          } else {
            1
          },
          Some(label),
        )
      }
      "forwardCircleOperator" => return association(CIRCLE_ARROW, 1, None)
      "backwardCircleOperator" =>
        return association(CIRCLE_ARROW_REVERSED, 1, edge_label(operator))
      "forwardCrossOperator" => return association(CROSS_ARROW, 1, None)
      "backwardCrossOperator" =>
        return association(CROSS_ARROW_REVERSED, 1, edge_label(operator))
      _ => ()
    }
  }
  association(LINE_SOLID, 1, None)
}

///|
/// A relationship from `source` along a `relationTail`.
fn Visitor::relationship(
  self : Visitor,
  source : Endpoint,
  tail : @chevrotain.CstNode,
) -> Unit {
  let target = self.entity_name(tail.nodes("entityName")[0])
  if target.explicit_declaration {
    self.drafts.elements.push(self.element_draft(target, "usecase"))
  }
  let explicit_id = tail
    .tokens("IDENTIFIER")
    .get(0)
    .map(token => (token.image, self.token_location(token)))
  self.drafts.relationships.push({
    source,
    target: endpoint(target, target.explicit_declaration),
    location: self.node_location(tail),
    explicit_id,
    arrow: self.arrow(tail.nodes("arrow")[0]),
  })
}

///|
fn Visitor::actor_declarations(
  self : Visitor,
  node : @chevrotain.CstNode,
) -> Array[Entity] {
  let items = node.nodes("actorItem").map(item => self.actor_item(item))
  for item in items {
    self.drafts.elements.push(self.element_draft(item, "actor"))
  }
  items
}

///|
fn Visitor::styles(self : Visitor, node : @chevrotain.CstNode) -> Array[String] {
  node.nodes("styles")[0]
  .nodes("styleValue")
  .map(value => {
    let tokens = value.all_tokens()
    self.source[tokens[0].start:tokens[tokens.length() - 1].end]
    .to_owned()
    .replace_all(old="\\,", new=",")
  })
}

///|
fn Visitor::statement(
  self : Visitor,
  node : @chevrotain.CstNode,
) -> Unit raise UsecaseError {
  let drafts = self.drafts
  match node.name {
    "accTitleStatement" => {
      let image = node.tokens("ACC_TITLE_LINE")[0].image
      guard image.find(":") is Some(colon) else { return }
      drafts.acc_title = js_trim(image[colon + 1:].to_owned())
    }
    "accDescrStatement" =>
      match node.tokens("ACC_DESCR_LINE") {
        [line, ..] => {
          guard line.image.find(":") is Some(colon) else { return }
          drafts.acc_description = js_trim(line.image[colon + 1:].to_owned())
        }
        [] => {
          let image = node.tokens("ACC_DESCR_BLOCK")[0].image
          guard image.find("{") is Some(open) &&
            image.rev_find("}") is Some(close) else {
            return
          }
          // The block ends at the first closing brace of the source.
          drafts.acc_description = js_trim(image[open + 1:close].to_owned())
        }
      }
    "directionStatement" =>
      for token in node.all_tokens() {
        if token.name is ("TD" | "TB" | "BT" | "RL" | "LR") {
          drafts.directions.push(
            if token.image == "TD" {
              "TB"
            } else {
              token.image
            },
          )
          break
        }
      }
    "actorStatement" => {
      let items = self.actor_declarations(node)
      if node.nodes("relationTail") is [tail, ..] {
        self.relationship(endpoint(items[0], true), tail)
      }
    }
    "actorDeclarationOnly" => self.actor_declarations(node) |> ignore
    "entityStatement" => {
      let source = self.entity_name(node.nodes("entityName")[0])
      guard node.nodes("relationTail") is [tail, ..] else {
        source.explicit_declaration = true
        if source.shape is None {
          source.shape = Some("ellipse")
        }
        drafts.elements.push(self.element_draft(source, "usecase"))
        return
      }
      if source.explicit_declaration {
        drafts.elements.push(self.element_draft(source, "usecase"))
      }
      self.relationship(endpoint(source, source.explicit_declaration), tail)
    }
    "boundaryElement" =>
      match node.nodes("actorDeclarationOnly") {
        [actors, ..] => self.statement(actors)
        [] => {
          let entity = self.entity_name(node.nodes("entityName")[0])
          entity.explicit_declaration = true
          if entity.shape is None {
            entity.shape = Some("ellipse")
          }
          drafts.elements.push(self.element_draft(entity, "usecase"))
        }
      }
    "systemBoundaryStatement" => {
      let name = node.nodes("systemBoundaryName")[0]
      let (id, label, location, generated) = match name.tokens("IDENTIFIER") {
        [identifier, ..] =>
          (
            identifier.image,
            match name.nodes("nodeLabel") {
              [label, ..] => self.label(label)
              [] => self.token_label(identifier)
            },
            self.token_location(identifier),
            false,
          )
        [] => {
          let token = match name.tokens("PLAIN_STRING") {
            [token, ..] => token
            [] => name.tokens("MARKDOWN_STRING")[0]
          }
          let label = self.token_label(token)
          (generate_id(label.text), label, self.token_location(token), true)
        }
      }
      drafts.boundaries.push({
        id,
        label,
        location,
        generated,
        classes: class_suffix(node),
      })
      let previous = self.parent_boundary
      self.parent_boundary = Some((id, location))
      if node.nodes("systemBoundaryContent") is [content, ..] {
        // Blank lines and comments say nothing; the elements are visited
        // in the order of the source.
        for element in content.nodes("boundaryElement") {
          self.statement(element)
        }
      }
      self.parent_boundary = previous
      if node.nodes("metadata") is [metadata, ..] {
        drafts.metadata_assignments.push({
          target: id,
          target_location: location,
          properties: self.metadata(metadata),
        })
      }
    }
    "metadataAssignmentStatement" => {
      let token = node.nodes("metadataAssignmentTarget")[0].all_tokens()[0]
      drafts.metadata_assignments.push({
        target: if token.name == "IDENTIFIER" {
          token.image
        } else {
          generate_id(self.token_label(token).text)
        },
        target_location: self.token_location(token),
        properties: self.metadata(node.nodes("metadata")[0]),
      })
    }
    "noteStatement" => {
      let target = node.tokens("IDENTIFIER")[0]
      drafts.notes.push({
        target: target.image,
        target_location: self.token_location(target),
        label: self.label(node.nodes("nodeLabel")[0]),
      })
    }
    "jsonStatement" => {
      let start = node.tokens("JSON_DECLARATION_START")[0]
      let literal = node.tokens("JSON_OBJECT_LITERAL")[0]
      // `json[\t ]+(\w+)`
      let image = start.image
      let mut id_start = 4
      while code_at(image, id_start) is (' ' | '\t') {
        id_start += 1
      }
      let mut id_end = id_start
      while code_at(image, id_end)
            is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_') {
        id_end += 1
      }
      let (line, column) = self.position(start.start)
      drafts.json.push({
        id: image[id_start:id_end].to_owned(),
        value: parse_json_object(literal.image),
        location: {
          start: start.start + id_start,
          end: start.start + id_end,
          line,
          column: column + id_start,
        },
        classes: class_suffix(node),
      })
    }
    "classDefStatement" =>
      drafts.class_definitions.push(
        (node.tokens("IDENTIFIER").map(token => token.image), self.styles(node)),
      )
    "classStatement" => {
      // The targets are the names joined by commas; the classes follow.
      let ids = node.tokens("IDENTIFIER")
      let mut split = 1
      while split < ids.length() {
        let between = self.source[ids[split - 1].end:ids[split].start]
        if !between.contains(",") {
          break
        }
        split += 1
      }
      drafts.class_assignments.push(
        (
          ids[:split]
          .iter()
          .map(token => (token.image, self.token_location(token)))
          .collect(),
          ids[split:].iter().map(token => token.image).collect(),
        ),
      )
    }
    "styleStatement" => {
      let target = node.tokens("IDENTIFIER")[0]
      drafts.style_assignments.push(
        (target.image, self.token_location(target), self.styles(node)),
      )
    }
    _ => ()
  }
}

///|
/// Read a use case diagram: mermaid's `usecase.chevrotain.ts`.
pub fn parse(
  source : String,
  config : @config.Config,
) -> UsecaseDb raise UsecaseError {
  let tokens = usecase_grammar.tokenize(source, custom=custom_token) catch {
    @chevrotain.ParseError(message~, ..) =>
      raise Invalid("Error lexing usecase diagram: \{message}")
  }
  let tree = usecase_grammar.parse(tokens, gate~) catch {
    @chevrotain.ParseError(message~, ..) =>
      raise Invalid("Error parsing usecase diagram: \{message}")
  }
  let visitor : Visitor = {
    source,
    drafts: {
      elements: [],
      boundaries: [],
      json: [],
      relationships: [],
      notes: [],
      metadata_assignments: [],
      class_definitions: [],
      class_assignments: [],
      style_assignments: [],
      directions: [],
      acc_title: "",
      acc_description: "",
    },
    parent_boundary: None,
  }
  for line in tree.nodes("line") {
    guard line.nodes("statement") is [statement, ..] else { continue }
    for _, elements in statement.children {
      if elements is [Node(node), ..] {
        visitor.statement(node)
      }
    }
  }
  let db = UsecaseDb::new(config)
  visitor.drafts.finalize(db)
  db
}
