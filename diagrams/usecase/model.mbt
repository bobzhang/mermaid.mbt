// Resolving what the statements say into a model: mermaid's
// `usecaseModelBuilder.ts`.

///|
/// What an id was first declared as.
priv struct Origin {
  /// `actor`, `usecase`, `boundary`, `json` or `edge`.
  kind : String
  location : Location
  generated : Bool
  label : String?
}

///|
/// An actor or use case while its declarations are being merged.
priv struct ElementState {
  kind : String
  id : String
  label : Label
  location : Location
  mut shape : String?
  mut parent : (String, Location)?
  mut stereotype : String?
  mut stereotype_location : Location?
  classes : Array[String]
  mut actor_type : String?
  mut icon : String?
  mut business : Bool?
}

///|
priv struct BoundaryState {
  id : String
  label : Label
  location : Location
  classes : Array[String]
  mut type_ : String?
}

///|
/// Two declarations that cannot both hold.
fn conflict(
  message : String,
  current : Location,
  previous : Location,
  current_label? : String,
  previous_label? : String,
) -> UsecaseError {
  let suffix = (label : String?) => {
    match label {
      Some(label) => " (label \"\{label}\")"
      None => ""
    }
  }
  Invalid(
    "\{message} at \{current.to_string()}\{suffix(current_label)}; previous declaration at \{previous.to_string()}\{suffix(previous_label)}",
  )
}

///|
/// The label an id was generated from, if it was.
fn generated_from(generated : Bool, label : String?) -> String? {
  if generated {
    label
  } else {
    None
  }
}

///|
fn push_unique(target : Array[String], values : Array[String]) -> Unit {
  for value in values {
    if !target.contains(value) {
      target.push(value)
    }
  }
}

///|
/// `items` in the order of their keys, equal keys staying as they are.
fn[T] sorted_by(items : Array[T], key : (T) -> Int32) -> Array[T] {
  let keyed = items.mapi((index, item) => (key(item), index, item))
  keyed.sort_by((a, b) => {
    if a.0 != b.0 {
      a.0.compare(b.0)
    } else {
      a.1.compare(b.1)
    }
  })
  keyed.map(entry => entry.2)
}

///|
fn invalid_metadata(
  id : String,
  kind : String,
  property : Property,
) -> UsecaseError {
  Invalid(
    "Metadata property '\{property.key}' is invalid for \{kind} '\{id}' at \{property.location.to_string()}",
  )
}

///|
/// `type`, `icon` and `business` on an actor. A declaration may not
/// contradict an earlier one; a separate metadata statement replaces.
fn ElementState::apply_actor_property(
  self : ElementState,
  property : Property,
  replace : Bool,
) -> Unit raise UsecaseError {
  let clash = (what : String) => {
    conflict(
      "Actor '\{self.id}' has conflicting \{what} metadata",
      property.location,
      self.location,
    )
  }
  match (property.key, property.value) {
    ("type", Text("normal" | "hollow" | "awesome" as value)) => {
      if !replace && self.actor_type is Some(previous) && previous != value {
        raise clash("type")
      }
      self.actor_type = Some(value)
    }
    ("icon", Text(value)) => {
      if !replace && self.icon is Some(previous) && previous != value {
        raise clash("icon")
      }
      self.icon = Some(value)
    }
    ("business", Flag(value)) => {
      if !replace && self.business is Some(previous) && previous != value {
        raise clash("business")
      }
      self.business = Some(value)
    }
    _ => raise invalid_metadata(self.id, self.kind, property)
  }
}

///|
/// The metadata written where an element is declared.
fn ElementState::apply_declaration_metadata(
  self : ElementState,
  metadata : Array[Property]?,
) -> Unit raise UsecaseError {
  guard metadata is Some(properties) else { return }
  for property in properties {
    if self.kind == "actor" {
      self.apply_actor_property(property, false)
    } else if property.key == "business" && property.value is Flag(value) {
      if self.business is Some(previous) && previous != value {
        raise conflict(
          "Use case '\{self.id}' has conflicting business metadata",
          property.location,
          self.location,
        )
      }
      self.business = Some(value)
    } else {
      raise invalid_metadata(self.id, self.kind, property)
    }
  }
}

///|
/// The kind of element a metadata statement seems meant for:
/// `inferMetadataKind`.
fn infer_metadata_kind(properties : Array[Property]) -> String? {
  let mut possible = ["actor", "usecase", "boundary", "edge"]
  for property in properties {
    match property.key {
      "icon" => possible = ["actor"]
      "animate" | "animation" => possible = ["edge"]
      "type" =>
        possible = match property.value {
          Text("rect" | "package") => ["boundary"]
          Text("normal" | "hollow" | "awesome") => ["actor"]
          _ => []
        }
      "business" =>
        possible = possible.filter(kind => kind != "boundary" && kind != "edge")
      _ => return None
    }
  }
  if possible is [kind] {
    Some(kind)
  } else {
    None
  }
}

///|
/// Write an element into the model as it stands: `setElementModel`.
fn UsecaseDb::set_element(self : UsecaseDb, state : ElementState) -> Unit {
  if state.kind == "actor" {
    self.use_cases.remove(state.id)
    self.actors[state.id] = {
      id: state.id,
      label: state.label.text,
      label_type: state.label.type_,
      type_: if state.icon is Some(icon) && icon != "" {
        "icon"
      } else {
        state.actor_type.unwrap_or("normal")
      },
      icon: state.icon.filter(icon => icon != ""),
      business: state.business.unwrap_or(false),
      stereotype: state.stereotype.filter(text => text != ""),
      parent_id: state.parent.map(parent => parent.0),
      classes: state.classes.copy(),
      styles: match self.actors.get(state.id) {
        Some(actor) => actor.styles
        None => []
      },
    }
  } else {
    self.actors.remove(state.id)
    self.use_cases[state.id] = {
      id: state.id,
      label: state.label.text,
      label_type: state.label.type_,
      shape: state.shape.unwrap_or("ellipse"),
      business: state.business.unwrap_or(false),
      stereotype: state.stereotype.filter(text => text != ""),
      parent_id: state.parent.map(parent => parent.0),
      classes: state.classes.copy(),
      styles: match self.use_cases.get(state.id) {
        Some(use_case) => use_case.styles
        None => []
      },
    }
  }
}

///|
/// Resolve the drafts into `db`: `UsecaseModelBuilder.finalize`.
fn Drafts::finalize(self : Drafts, db : UsecaseDb) -> Unit raise UsecaseError {
  let symbols : Map[String, Origin] = Map([])
  let elements : Map[String, ElementState] = Map([])
  let boundaries : Map[String, BoundaryState] = Map([])
  // Where each id first appears in the source.
  let first : Map[String, Int32] = Map([])
  let record_first = (id : String, offset : Int32) => {
    match first.get(id) {
      Some(previous) if previous <= offset => ()
      _ => first[id] = offset
    }
  }
  let first_of = (id : String) => first.get(id).unwrap_or(0)
  for relation in self.relationships {
    record_first(relation.source.id, relation.source.location.start)
    record_first(relation.target.id, relation.target.location.start)
  }
  for draft in self.elements {
    record_first(draft.id, draft.location.start)
  }
  for draft in self.boundaries {
    record_first(draft.id, draft.location.start)
  }
  for draft in self.json {
    record_first(draft.id, draft.location.start)
  }
  // Declarations of every kind, in the order of the source.
  let declarations : Array[(Int32, Declaration)] = []
  for draft in self.elements {
    declarations.push((draft.location.start, Element(draft)))
  }
  for draft in self.boundaries {
    declarations.push((draft.location.start, Boundary(draft)))
  }
  for draft in self.json {
    declarations.push((draft.location.start, Json(draft)))
  }
  for draft in self.relationships {
    if draft.explicit_id is Some((id, location)) {
      declarations.push((location.start, Edge(id, location)))
    }
  }
  let register_unique = (id : String, kind : String, location : Location) => {
    if symbols.get(id) is Some(previous) {
      raise conflict(
        "ID '\{id}' is declared more than once (\{previous.kind} and \{kind})",
        location,
        previous.location,
        previous_label?=generated_from(previous.generated, previous.label),
      )
    }
    symbols[id] = { kind, location, generated: false, label: None, }
  }
  for item in sorted_by(declarations, item => item.0) {
    match item.1 {
      Element(draft) => collect_element(draft, symbols, elements)
      Boundary(draft) => collect_boundary(draft, symbols, boundaries)
      Json(draft) => register_unique(draft.id, "json", draft.location)
      Edge(id, location) => register_unique(id, "edge", location)
    }
  }
  // materializeElements, materializeBoundaries, materializeJson
  for
    state in sorted_by(elements.values().collect(), state => first_of(state.id)) {
    db.set_element(state)
  }
  for
    state in sorted_by(boundaries.values().collect(), state => {
      first_of(state.id)
    }) {
    db.boundaries[state.id] = {
      id: state.id,
      label: state.label.text,
      label_type: state.label.type_,
      type_: state.type_.unwrap_or("rect"),
      classes: state.classes.copy(),
      styles: [],
    }
  }
  for draft in sorted_by(self.json, draft => first_of(draft.id)) {
    db.json_nodes[draft.id] = {
      id: draft.id,
      value: draft.value,
      classes: draft.classes.copy(),
      styles: [],
    }
  }
  // materializeRelationships
  let edges : Map[String, Relationship] = Map([])
  let mut anonymous = 0
  let resolve_endpoint = (endpoint : Endpoint) => {
    if endpoint.classes_on_reference && !endpoint.declaration {
      raise Invalid(
        "Relationship endpoint '\{endpoint.id}' uses ::: without declaring the node at \{endpoint.location.to_string()}",
      )
    }
    if symbols.get(endpoint.id) is Some(origin) {
      return origin.kind
    }
    elements[endpoint.id] = {
      kind: "usecase",
      id: endpoint.id,
      label: endpoint.label,
      location: endpoint.location,
      shape: Some("ellipse"),
      parent: None,
      stereotype: None,
      stereotype_location: None,
      classes: [],
      actor_type: None,
      icon: None,
      business: None,
    }
    symbols[endpoint.id] = {
      kind: "usecase",
      location: endpoint.location,
      generated: endpoint.generated,
      label: Some(endpoint.label.text),
    }
    record_first(endpoint.id, endpoint.location.start)
    "usecase"
  }
  for draft in self.relationships {
    let source_kind = resolve_endpoint(draft.source)
    let target_kind = resolve_endpoint(draft.target)
    validate_relationship(draft, source_kind, target_kind, symbols)
    let id = match draft.explicit_id {
      Some((id, _)) => id
      None => {
        anonymous += 1
        "edge-\{anonymous - 1}"
      }
    }
    let relationship : Relationship = {
      id,
      explicit_id: draft.explicit_id is Some(_),
      source: draft.source.id,
      target: draft.target.id,
      type_: draft.arrow.type_,
      arrow_type: draft.arrow.arrow_type,
      label: draft.arrow.label.map(label => label.text),
      label_type: draft.arrow.label.map(label => label.type_),
      minlen: draft.arrow.minlen,
      classes: [],
      styles: [],
      animate: false,
      animation: None,
    }
    db.relationships.push(relationship)
    edges[id] = relationship
  }
  // reorderElements: the elements relationships brought in take their
  // place among the declared ones.
  let actors = db.actors.copy()
  let use_cases = db.use_cases.copy()
  db.actors.clear()
  db.use_cases.clear()
  for
    state in sorted_by(elements.values().collect(), state => first_of(state.id)) {
    if !actors.contains(state.id) && !use_cases.contains(state.id) {
      db.set_element(state)
    }
    match (actors.get(state.id), db.actors.get(state.id)) {
      (Some(actor), _) | (None, Some(actor)) => db.actors[state.id] = actor
      (None, None) =>
        match (use_cases.get(state.id), db.use_cases.get(state.id)) {
          (Some(use_case), _) | (None, Some(use_case)) =>
            db.use_cases[state.id] = use_case
          (None, None) => ()
        }
    }
  }
  // applyMetadataAssignments
  for assignment in self.metadata_assignments {
    let target = assignment.target
    guard symbols.get(target) is Some(origin) else {
      let implied = match infer_metadata_kind(assignment.properties) {
        Some(kind) => " (metadata implies \{kind})"
        None => ""
      }
      raise Invalid(
        "Metadata target '\{target}' is unresolved\{implied} at \{assignment.target_location.to_string()}",
      )
    }
    match origin.kind {
      "actor" | "usecase" => {
        guard elements.get(target) is Some(state) else { continue }
        for property in assignment.properties {
          if state.kind == "actor" {
            state.apply_actor_property(property, true)
          } else if property.key == "business" && property.value is Flag(value) {
            state.business = Some(value)
          } else {
            raise invalid_metadata(state.id, state.kind, property)
          }
        }
      }
      "boundary" => {
        guard boundaries.get(target) is Some(boundary) else { continue }
        for property in assignment.properties {
          guard property.key == "type" &&
            property.value is Text("rect" | "package" as value) else {
            raise invalid_metadata(target, origin.kind, property)
          }
          boundary.type_ = Some(value)
        }
      }
      "edge" => {
        guard edges.get(target) is Some(edge) else {
          raise Invalid(
            "Metadata target '\{target}' is not an explicit edge at \{assignment.target_location.to_string()}",
          )
        }
        for property in assignment.properties {
          match (property.key, property.value) {
            ("animate", Flag(value)) => edge.animate = value
            ("animation", Text("fast" | "slow" as value)) => {
              edge.animation = Some(value)
              edge.animate = true
            }
            _ => raise invalid_metadata(target, origin.kind, property)
          }
        }
      }
      _ =>
        for property in assignment.properties {
          raise invalid_metadata(target, origin.kind, property)
        }
    }
  }
  for relationship in db.relationships {
    if relationship.animation is Some(_) {
      relationship.animate = true
    }
  }
  // validateAndRefreshElements
  for _, state in elements {
    let has_icon = state.icon is Some(icon) && icon != ""
    let type_ = if has_icon {
      "icon"
    } else {
      state.actor_type.unwrap_or("normal")
    }
    if state.kind == "actor" {
      if has_icon &&
        state.actor_type is Some(actor_type) &&
        actor_type != "normal" {
        raise Invalid(
          "Actor '\{state.id}' cannot combine icon with type '\{actor_type}' at \{state.location.to_string()}",
        )
      }
      if state.business == Some(true) && (type_ == "icon" || type_ == "awesome") {
        raise Invalid(
          "Business actor '\{state.id}' must use normal or hollow geometry at \{state.location.to_string()}",
        )
      }
    } else if state.shape.unwrap_or("ellipse") == "rect" &&
      state.business == Some(true) {
      raise Invalid(
        "Rectangular use case '\{state.id}' cannot be a business use case at \{state.location.to_string()}",
      )
    }
    db.set_element(state)
  }
  // refreshBoundaries
  for draft in self.elements {
    guard draft.parent is Some((parent_id, parent_location)) else { continue }
    if !boundaries.contains(parent_id) {
      raise Invalid(
        "Parent boundary '\{parent_id}' for '\{draft.id}' is unresolved at \{parent_location.to_string()}",
      )
    }
  }
  for _, state in boundaries {
    guard db.boundaries.get(state.id) is Some(boundary) else { continue }
    boundary.type_ = state.type_.unwrap_or("rect")
    boundary.classes = state.classes.copy()
  }
  // materializeNotes
  let mut counter = 0
  for draft in self.notes {
    guard symbols.get(draft.target) is Some(origin) else {
      raise Invalid(
        "Note target '\{draft.target}' is unresolved at \{draft.target_location.to_string()}",
      )
    }
    if origin.kind != "actor" && origin.kind != "usecase" {
      raise conflict(
        "Note target '\{draft.target}' must be an actor or use case, not \{origin.kind}",
        draft.target_location,
        origin.location,
      )
    }
    let id = "note-\{counter}"
    counter += 1
    db.notes[id] = {
      id,
      target: draft.target,
      label: draft.label.text,
      label_type: draft.label.type_,
    }
  }
  // applyClassDefinitions
  for definition in self.class_definitions {
    for id in definition.0 {
      db.class_defs[id] = definition.1.copy()
    }
  }
  // applyClassesAndStyles
  let stylable = (id : String, location : Location) => {
    let kind = symbols.get(id).map(origin => origin.kind).unwrap_or("")
    let target = match kind {
      "actor" => db.actors.get(id).map(actor => (actor.classes, actor.styles))
      "usecase" =>
        db.use_cases
        .get(id)
        .map(use_case => (use_case.classes, use_case.styles))
      "boundary" =>
        db.boundaries
        .get(id)
        .map(boundary => (boundary.classes, boundary.styles))
      "json" => db.json_nodes.get(id).map(json => (json.classes, json.styles))
      "edge" => edges.get(id).map(edge => (edge.classes, edge.styles))
      _ => None
    }
    guard target is Some(target) else {
      raise Invalid(
        "Class/style target '\{id}' is unresolved or anonymous at \{location.to_string()}",
      )
    }
    target
  }
  for assignment in self.class_assignments {
    for target in assignment.0 {
      push_unique(stylable(target.0, target.1).0, assignment.1)
    }
  }
  for assignment in self.style_assignments {
    stylable(assignment.0, assignment.1).1.append(assignment.2)
  }
  if self.directions.last() is Some(direction) {
    db.direction = direction
  }
  // commonDb's `setAccTitle` and `setAccDescription`: sanitized, without
  // leading white space and the indentation of continuation lines.
  let leading = try! @jsregex.Regex::compile("^\\s+")
  db.acc_title = leading.replace(sanitize_text(self.acc_title), _ => "")
  let indent = try! @jsregex.Regex::compile("\\n\\s+")
  db.acc_description = indent.replace_all(sanitize_text(self.acc_description), _ => {
    "\n"
  })
}

///|
/// Something that declares an id.
priv enum Declaration {
  Element(ElementDraft)
  Boundary(BoundaryDraft)
  Json(JsonDraft)
  Edge(String, Location)
}

///|
/// Merge a declaration of an actor or use case into what is known of it:
/// `collectElement`.
fn collect_element(
  draft : ElementDraft,
  symbols : Map[String, Origin],
  states : Map[String, ElementState],
) -> Unit raise UsecaseError {
  let origin = symbols.get(draft.id)
  let draft_label = generated_from(draft.generated, Some(draft.label.text))
  if origin is Some(origin) {
    let previous_label = generated_from(origin.generated, origin.label)
    if origin.kind != draft.kind {
      raise conflict(
        "ID '\{draft.id}' is declared as both \{origin.kind} and \{draft.kind}",
        draft.location,
        origin.location,
        current_label?=draft_label,
        previous_label?,
      )
    }
    if origin.generated || draft.generated {
      raise conflict(
        "Generated ID '\{draft.id}' collides with another declaration",
        draft.location,
        origin.location,
        current_label?=draft_label,
        previous_label?,
      )
    }
  }
  let stereotype = draft.stereotype.filter(text => text != "")
  guard states.get(draft.id) is Some(existing) else {
    let state : ElementState = {
      kind: draft.kind,
      id: draft.id,
      label: draft.label,
      location: draft.location,
      shape: draft.shape,
      parent: draft.parent,
      stereotype,
      stereotype_location: stereotype.map(_ => draft.location),
      classes: draft.classes.copy(),
      actor_type: None,
      icon: None,
      business: None,
    }
    state.apply_declaration_metadata(draft.metadata)
    states[draft.id] = state
    symbols[draft.id] = {
      kind: draft.kind,
      location: draft.location,
      generated: draft.generated,
      label: Some(draft.label.text),
    }
    return
  }
  if existing.label.text != draft.label.text ||
    existing.label.type_ != draft.label.type_ {
    raise conflict(
      "ID '\{draft.id}' has conflicting labels",
      draft.location,
      existing.location,
    )
  }
  if draft.shape is Some(shape) &&
    existing.shape is Some(previous) &&
    shape != previous {
    raise conflict(
      "Use case '\{draft.id}' has conflicting shapes",
      draft.location,
      existing.location,
    )
  }
  if draft.parent is Some((parent, location)) &&
    existing.parent is Some((previous, previous_location)) &&
    parent != previous {
    raise conflict(
      "Element '\{draft.id}' belongs to more than one system boundary",
      location,
      previous_location,
    )
  }
  if stereotype is Some(text) &&
    existing.stereotype is Some(previous) &&
    text != previous {
    raise conflict(
      "Element '\{draft.id}' has conflicting stereotypes",
      draft.location,
      existing.stereotype_location.unwrap_or(existing.location),
    )
  }
  if existing.shape is None {
    existing.shape = draft.shape
  }
  if existing.parent is None {
    existing.parent = draft.parent
  }
  if existing.stereotype is None {
    existing.stereotype = stereotype
  }
  if existing.stereotype_location is None && stereotype is Some(_) {
    existing.stereotype_location = Some(draft.location)
  }
  push_unique(existing.classes, draft.classes)
  existing.apply_declaration_metadata(draft.metadata)
}

///|
/// `collectBoundary`
fn collect_boundary(
  draft : BoundaryDraft,
  symbols : Map[String, Origin],
  states : Map[String, BoundaryState],
) -> Unit raise UsecaseError {
  let draft_label = generated_from(draft.generated, Some(draft.label.text))
  if symbols.get(draft.id) is Some(origin) {
    let previous_label = generated_from(origin.generated, origin.label)
    if origin.kind != "boundary" {
      raise conflict(
        "ID '\{draft.id}' is declared as both \{origin.kind} and boundary",
        draft.location,
        origin.location,
        current_label?=draft_label,
        previous_label?,
      )
    }
    if origin.generated || draft.generated {
      raise conflict(
        "Generated ID '\{draft.id}' collides with another declaration",
        draft.location,
        origin.location,
        current_label?=draft_label,
        previous_label?,
      )
    }
  }
  if states.get(draft.id) is Some(existing) {
    if existing.label.text != draft.label.text ||
      existing.label.type_ != draft.label.type_ {
      raise conflict(
        "Boundary '\{draft.id}' has conflicting titles",
        draft.location,
        existing.location,
      )
    }
    push_unique(existing.classes, draft.classes)
    return
  }
  states[draft.id] = {
    id: draft.id,
    label: draft.label,
    location: draft.location,
    classes: draft.classes.copy(),
    type_: None,
  }
  symbols[draft.id] = {
    kind: "boundary",
    location: draft.location,
    generated: draft.generated,
    label: Some(draft.label.text),
  }
}

///|
/// `validateRelationship`
fn validate_relationship(
  draft : RelationshipDraft,
  source_kind : String,
  target_kind : String,
  symbols : Map[String, Origin],
) -> Unit raise UsecaseError {
  let allowed = (kind : String) => kind is ("actor" | "usecase" | "json")
  let declared = (endpoint : Endpoint) => {
    match symbols.get(endpoint.id) {
      Some(origin) => origin.location
      None => endpoint.location
    }
  }
  if !allowed(source_kind) {
    raise conflict(
      "Relationship source '\{draft.source.id}' cannot be \{source_kind}",
      draft.source.location,
      declared(draft.source),
    )
  }
  if !allowed(target_kind) {
    raise conflict(
      "Relationship target '\{draft.target.id}' cannot be \{target_kind}",
      draft.target.location,
      declared(draft.target),
    )
  }
  let type_ = draft.arrow.type_
  let at = draft.location.to_string()
  if (type_ == "include" || type_ == "extend") &&
    (source_kind != "usecase" || target_kind != "usecase") {
    raise Invalid("\{type_} relationship requires use-case endpoints at \{at}")
  }
  if type_ == "generalization" &&
    (
      (source_kind != "actor" && source_kind != "usecase") ||
      source_kind != target_kind
    ) {
    raise Invalid(
      "Generalization requires actor-to-actor or use-case-to-use-case endpoints at \{at}",
    )
  }
  if type_ == "association" &&
    (source_kind == "json" || target_kind == "json") &&
    !(draft.arrow.arrow_type is (0 | 1 | 2)) {
    raise Invalid(
      "JSON relationship '\{draft.source.id}' to '\{draft.target.id}' permits only point, reversed-point, or markerless solid association at \{at}",
    )
  }
}
