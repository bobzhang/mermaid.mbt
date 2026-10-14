///|
/// A `label [x, y]` clause: where a node's label goes, relative to it.
priv struct LabelOffset {
  x : Double
  y : Double
}

///|
priv struct AstStage {
  name : String
  boundary : Double?
  second_name : String?
}

///|
priv struct AstPoint {
  name : String
  visibility : Double
  evolution : Double
}

///|
priv struct AstComponent {
  name : String
  visibility : Double
  evolution : Double
  label : LabelOffset?
  strategy : String?
  inertia : Bool
}

///|
priv struct AstLink {
  from : String
  from_port : String?
  arrow : String?
  to : String
  to_port : String?
  link_label : String?
}

///|
priv struct AstPipelineComponent {
  name : String
  evolution : Double
  label : LabelOffset?
}

///|
priv struct AstPipeline {
  parent : String
  components : Array[AstPipelineComponent]
}

///|
priv struct AstAnnotation {
  number : Double
  x : Double
  y : Double
  text : String
}

///|
/// The syntax tree, statement kind by statement kind: the database is
/// filled in that order, not in the order of the source.
priv struct Ast {
  mut size : (Double, Double)?
  mut evolution : Array[AstStage]?
  anchors : Array[AstPoint]
  components : Array[AstComponent]
  links : Array[AstLink]
  evolves : Array[(String, Double)]
  pipelines : Array[AstPipeline]
  notes : Array[AstPoint]
  annotations : Array[(Double, Double)]
  annotation : Array[AstAnnotation]
  accelerators : Array[AstPoint]
  deaccelerators : Array[AstPoint]
}

///|
/// The grammar's `EOL`: line breaks, or the end of the input.
fn eol(tokens : @langium.TokenStream) -> Unit raise @langium.ParseError {
  if tokens.at("EOF") {
    return
  }
  tokens.expect("NEWLINE") |> ignore
  while tokens.accept("NEWLINE") is Some(_) {

  }
}

///|
/// A name: `STRING | ID | NAME_WITH_SPACES`, as its value converter
/// leaves it.
fn name(tokens : @langium.TokenStream) -> String raise @langium.ParseError {
  match tokens.peek() {
    "STRING" => {
      let text = tokens.expect("STRING").text
      @langium.Lexer::new(text).string().unwrap_or("")
    }
    "ID" => tokens.expect("ID").text
    "NAME_WITH_SPACES" => tokens.expect("NAME_WITH_SPACES").text
    _ => tokens.fail("Expecting a name")
  }
}

///|
/// The quoted text of a note or an annotation.
fn string(tokens : @langium.TokenStream) -> String raise @langium.ParseError {
  let text = tokens.expect("STRING").text
  @langium.Lexer::new(text).string().unwrap_or("")
}

///|
/// A terminal that is a number: `Number(text)`.
fn number(
  tokens : @langium.TokenStream,
  kind : String,
) -> Double raise @langium.ParseError {
  let text = tokens.expect(kind).text
  @string.parse_double(text) catch {
    _ => tokens.fail("Expecting a number")
  }
}

///|
/// `CoordinateValue`: a decimal or an integer.
fn coordinate(
  tokens : @langium.TokenStream,
) -> Double raise @langium.ParseError {
  if tokens.at("INT") {
    number(tokens, "INT")
  } else {
    number(tokens, "WARDLEY_NUMBER")
  }
}

///|
/// `'[' WARDLEY_NUMBER ',' WARDLEY_NUMBER ']'`
fn decimal_pair(
  tokens : @langium.TokenStream,
) -> (Double, Double) raise @langium.ParseError {
  tokens.expect("[") |> ignore
  let first = number(tokens, "WARDLEY_NUMBER")
  tokens.expect(",") |> ignore
  let second = number(tokens, "WARDLEY_NUMBER")
  tokens.expect("]") |> ignore
  (first, second)
}

///|
/// `'[' CoordinateValue ',' CoordinateValue ']'`
fn coordinate_pair(
  tokens : @langium.TokenStream,
) -> (Double, Double) raise @langium.ParseError {
  tokens.expect("[") |> ignore
  let first = coordinate(tokens)
  tokens.expect(",") |> ignore
  let second = coordinate(tokens)
  tokens.expect("]") |> ignore
  (first, second)
}

///|
/// The grammar's `Label`, if one follows:
/// `KW_LABEL '[' '-'? INT ',' '-'? INT ']'`.
fn label(
  tokens : @langium.TokenStream,
) -> LabelOffset? raise @langium.ParseError {
  guard tokens.accept("KW_LABEL") is Some(_) else { return None }
  tokens.expect("[") |> ignore
  let signed = () => {
    let sign = if tokens.accept("-") is Some(_) { -1.0 } else { 1.0 }
    sign * number(tokens, "INT")
  }
  let x = signed()
  tokens.expect(",") |> ignore
  let y = signed()
  tokens.expect("]") |> ignore
  Some({ x, y, })
}

///|
/// The grammar's `EvolutionStage`:
/// `name ('@' WARDLEY_NUMBER)? ('/' name)?`.
fn stage(tokens : @langium.TokenStream) -> AstStage raise @langium.ParseError {
  let first_name = name(tokens)
  let boundary = if tokens.accept("@") is Some(_) {
    Some(number(tokens, "WARDLEY_NUMBER"))
  } else {
    None
  }
  let second_name = if tokens.accept("/") is Some(_) {
    Some(name(tokens))
  } else {
    None
  }
  { name: first_name, boundary, second_name, }
}

///|
/// A named point: `name '[' WARDLEY_NUMBER ',' WARDLEY_NUMBER ']' EOL`.
fn point(tokens : @langium.TokenStream) -> AstPoint raise @langium.ParseError {
  let name = name(tokens)
  let (visibility, evolution) = decimal_pair(tokens)
  eol(tokens)
  { name, visibility, evolution, }
}

///|
/// The grammar's `Component`, after its keyword:
///
/// ```text
/// name '[' WARDLEY_NUMBER ',' WARDLEY_NUMBER ']' Label? ('(' STRATEGY ')')?
///   (KW_INERTIA | '(' KW_INERTIA ')')? EOL
/// ```
fn component(
  tokens : @langium.TokenStream,
) -> AstComponent raise @langium.ParseError {
  let name = name(tokens)
  let (visibility, evolution) = decimal_pair(tokens)
  let label = label(tokens)
  let strategy = if tokens.at("(") && tokens.peek(ahead=1) == "STRATEGY" {
    tokens.expect("(") |> ignore
    let strategy = tokens.expect("STRATEGY").text
    tokens.expect(")") |> ignore
    Some(strategy)
  } else {
    None
  }
  let inertia = if tokens.accept("KW_INERTIA") is Some(_) {
    true
  } else if tokens.accept("(") is Some(_) {
    tokens.expect("KW_INERTIA") |> ignore
    tokens.expect(")") |> ignore
    true
  } else {
    false
  }
  eol(tokens)
  { name, visibility, evolution, label, strategy, inertia, }
}

///|
/// The grammar's `Link`:
/// `name LINK_PORT? (LINK_ARROW | ARROW)? name LINK_PORT? LINK_LABEL? EOL`.
fn link(tokens : @langium.TokenStream) -> AstLink raise @langium.ParseError {
  let from = name(tokens)
  let from_port = tokens.accept("LINK_PORT").map(token => token.text)
  let arrow = match tokens.accept("LINK_ARROW") {
    Some(token) => Some(token.text)
    None => tokens.accept("ARROW").map(token => token.text)
  }
  let to = name(tokens)
  let to_port = tokens.accept("LINK_PORT").map(token => token.text)
  // The value converter drops the semicolon and trims.
  let link_label = tokens
    .accept("LINK_LABEL")
    .map(token => js_trim(token.text[1:]))
  eol(tokens)
  { from, from_port, arrow, to, to_port, link_label, }
}

///|
/// The grammar's `Pipeline`, after its keyword:
///
/// ```text
/// name '{' NEWLINE+
///   (KW_COMPONENT name '[' WARDLEY_NUMBER ']' Label? EOL)+
/// '}' EOL
/// ```
fn pipeline(
  tokens : @langium.TokenStream,
) -> AstPipeline raise @langium.ParseError {
  let parent = name(tokens)
  tokens.expect("{") |> ignore
  tokens.expect("NEWLINE") |> ignore
  while tokens.accept("NEWLINE") is Some(_) {

  }
  let components = []
  while true {
    tokens.expect("KW_COMPONENT") |> ignore
    let name = name(tokens)
    tokens.expect("[") |> ignore
    let evolution = number(tokens, "WARDLEY_NUMBER")
    tokens.expect("]") |> ignore
    let label = label(tokens)
    eol(tokens)
    components.push({ name, evolution, label, })
    guard tokens.at("KW_COMPONENT") else { break }
  }
  tokens.expect("}") |> ignore
  eol(tokens)
  { parent, components, }
}

///|
/// `String.prototype.trim`.
fn js_trim(text : StringView) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && @diagram.is_js_space(chars[start]) {
    start += 1
  }
  while end > start && @diagram.is_js_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
/// A position given as a fraction (up to 1) or as a percentage, as a
/// percentage: upstream's `toPercent`.
fn to_percent(value : Double, context : String) -> Double raise WardleyError {
  let normalized = if value <= 1.0 { value * 100.0 } else { value }
  if normalized < 0.0 || normalized > 100.0 {
    raise Invalid(
      "\{context} must be between 0-1 (decimal) or 0-100 (percentage). Received: \{@dom.number(value)}",
    )
  }
  normalized
}

///|
/// Upstream's `toCoordinates`: `(x, y)` from visibility and evolution.
/// The evolution is checked first.
fn to_coordinates(
  visibility : Double,
  evolution : Double,
  context : String,
) -> (Double, Double) raise WardleyError {
  let x = to_percent(evolution, "\{context} evolution")
  let y = to_percent(visibility, "\{context} visibility")
  (x, y)
}

///|
/// The flow a port (`+>`, `+<`, `+<>`) gives a link.
fn flow_from_port(port : String?) -> Flow? {
  match port {
    Some("+<>") => Some(Bidirectional)
    Some("+<") => Some(Backward)
    Some("+>") => Some(Forward)
    _ => None
  }
}

///|
/// The flow and the label of an arrow such as `+'text'>`: upstream's
/// `extractFlowFromArrow`.
fn flow_from_arrow(arrow : String?) -> (Flow?, String?) {
  guard arrow is Some(arrow) && arrow.has_prefix("+") else {
    return (None, None)
  }
  // `/^\+'([^']*)'/`
  let chars = arrow.to_array()
  let flow_label = if chars.length() > 1 && chars[1] == '\'' {
    let mut end = 2
    while end < chars.length() && chars[end] != '\'' {
      end += 1
    }
    if end < chars.length() {
      Some(String::from_array(chars[2:end]))
    } else {
      None
    }
  } else {
    None
  }
  let flow = if arrow.contains("<>") {
    Some(Bidirectional)
  } else if arrow.contains("<") {
    Some(Backward)
  } else if arrow.contains(">") {
    Some(Forward)
  } else {
    None
  }
  (flow, flow_label)
}

///|
/// Parse the source into its syntax tree, following the Langium grammar:
///
/// ```text
/// Wardley: NEWLINE* KW_WARDLEY (NEWLINE | TitleAndAccessibilities | Statement)*
/// Statement: Size | Evolution | Anchor | Component | Link | Evolve | Pipeline
///          | Note | Annotations | Annotation | Accelerator | Deaccelerator
/// ```
fn parse_ast(source : String, map : Wardley) -> Ast raise {
  let tokens = @langium.TokenStream::new(
    @langium.tokenize(source, token_types),
    source.length(),
  )
  while tokens.accept("NEWLINE") is Some(_) {

  }
  tokens.expect("KW_WARDLEY") |> ignore
  let ast : Ast = {
    size: None,
    evolution: None,
    anchors: [],
    components: [],
    links: [],
    evolves: [],
    pipelines: [],
    notes: [],
    annotations: [],
    annotation: [],
    accelerators: [],
    deaccelerators: [],
  }
  while !tokens.at("EOF") {
    match tokens.peek() {
      "NEWLINE" => tokens.expect("NEWLINE") |> ignore
      "ACC_DESCR" | "ACC_TITLE" | "TITLE" as kind => {
        let text = tokens.expect(kind).text
        let lexer = @langium.Lexer::new(text)
        match kind {
          "ACC_DESCR" => map.acc_description = lexer.acc_descr().unwrap_or("")
          "ACC_TITLE" => map.acc_title = lexer.acc_title().unwrap_or("")
          _ => map.title = lexer.title().unwrap_or("")
        }
        eol(tokens)
      }
      "KW_SIZE" => {
        tokens.expect("KW_SIZE") |> ignore
        tokens.expect("[") |> ignore
        let width = number(tokens, "INT")
        tokens.expect(",") |> ignore
        let height = number(tokens, "INT")
        tokens.expect("]") |> ignore
        eol(tokens)
        ast.size = Some((width, height))
      }
      "KW_EVOLUTION" => {
        tokens.expect("KW_EVOLUTION") |> ignore
        let stages = [stage(tokens)]
        tokens.expect("ARROW") |> ignore
        stages.push(stage(tokens))
        while tokens.accept("ARROW") is Some(_) {
          stages.push(stage(tokens))
        }
        eol(tokens)
        ast.evolution = Some(stages)
      }
      "KW_ANCHOR" => {
        tokens.expect("KW_ANCHOR") |> ignore
        ast.anchors.push(point(tokens))
      }
      "KW_COMPONENT" => {
        tokens.expect("KW_COMPONENT") |> ignore
        ast.components.push(component(tokens))
      }
      "STRING" | "ID" | "NAME_WITH_SPACES" => ast.links.push(link(tokens))
      "KW_EVOLVE" => {
        tokens.expect("KW_EVOLVE") |> ignore
        let component = name(tokens)
        let target = number(tokens, "WARDLEY_NUMBER")
        eol(tokens)
        ast.evolves.push((component, target))
      }
      "KW_PIPELINE" => {
        tokens.expect("KW_PIPELINE") |> ignore
        ast.pipelines.push(pipeline(tokens))
      }
      "KW_NOTE" => {
        tokens.expect("KW_NOTE") |> ignore
        let text = string(tokens)
        let (visibility, evolution) = decimal_pair(tokens)
        eol(tokens)
        ast.notes.push({ name: text, visibility, evolution, })
      }
      "KW_ANNOTATIONS" => {
        tokens.expect("KW_ANNOTATIONS") |> ignore
        let pair = coordinate_pair(tokens)
        eol(tokens)
        ast.annotations.push(pair)
      }
      "KW_ANNOTATION" => {
        tokens.expect("KW_ANNOTATION") |> ignore
        let number = number(tokens, "INT")
        tokens.expect(",") |> ignore
        let (x, y) = coordinate_pair(tokens)
        let text = string(tokens)
        eol(tokens)
        ast.annotation.push({ number, x, y, text, })
      }
      "KW_ACCELERATOR" => {
        tokens.expect("KW_ACCELERATOR") |> ignore
        ast.accelerators.push(point(tokens))
      }
      "KW_DEACCELERATOR" => {
        tokens.expect("KW_DEACCELERATOR") |> ignore
        ast.deaccelerators.push(point(tokens))
      }
      _ => tokens.fail("Expecting a statement")
    }
  }
  ast
}

///|
/// Parse the source of a Wardley map and fill its database: upstream's
/// `populateDb`.
pub fn parse(source : String) -> Wardley raise {
  let map = Wardley::new()
  let ast = parse_ast(source, map)
  // What `sanitizeText` would do to markup is not ported.
  let common = (text : String, name : String) => {
    if text.contains("<") {
      raise Unsupported("markup in the \{name} of a Wardley map: \{text}")
    }
  }
  common(map.title, "title")
  common(map.acc_title, "accessible title")
  common(map.acc_description, "accessible description")
  map.size = ast.size
  if ast.evolution is Some(stages) {
    map.stages = stages.map(stage => {
      match stage.second_name {
        // A stage with two names, like "Genesis / Concept".
        Some(second) if second != "" =>
          "\{js_trim(stage.name)} / \{js_trim(second)}"
        _ => js_trim(stage.name)
      }
    })
    map.stage_boundaries = Some(stages.filter_map(stage => stage.boundary))
  }
  for anchor in ast.anchors {
    let (x, y) = to_coordinates(
      anchor.visibility,
      anchor.evolution,
      "Anchor \"\{anchor.name}\"",
    )
    map.add_node(anchor.name, anchor.name, x, y, "anchor")
  }
  for component in ast.components {
    let (x, y) = to_coordinates(
      component.visibility,
      component.evolution,
      "Component \"\{component.name}\"",
    )
    map.add_node(
      component.name,
      component.name,
      x,
      y,
      "component",
      label_offset_x=component.label.map(label => label.x),
      label_offset_y=component.label.map(label => label.y),
      inertia=component.inertia,
      source_strategy=component.strategy,
    )
  }
  for note in ast.notes {
    let (x, y) = to_coordinates(
      note.visibility,
      note.evolution,
      "Note \"\{note.name}\"",
    )
    map.notes.push({ text: note.name, x, y, })
  }
  for pipeline in ast.pipelines {
    guard map.node(pipeline.parent) is Some(parent) else {
      raise Invalid(
        "Pipeline \"\{pipeline.parent}\" must reference an existing component with coordinates.",
      )
    }
    let parent_y = parent.y
    map.start_pipeline(pipeline.parent)
    for component in pipeline.components {
      // The components of a pipeline get an id of their own.
      let id = "\{pipeline.parent}_\{component.name}"
      let x = to_percent(
        component.evolution,
        "Pipeline component \"\{component.name}\" evolution",
      )
      map.add_node(
        id,
        component.name,
        x,
        parent_y,
        "pipeline-component",
        label_offset_x=component.label.map(label => label.x),
        label_offset_y=component.label.map(label => label.y),
      )
      map.add_pipeline_component(pipeline.parent, id)
    }
  }
  for link in ast.links {
    let dashed = match link.arrow {
      Some(arrow) => arrow.contains("-.->") || arrow.contains(".-.")
      None => false
    }
    let (arrow_flow, flow_label) = flow_from_arrow(link.arrow)
    let flow = match flow_from_port(link.from_port) {
      Some(flow) => Some(flow)
      None =>
        match flow_from_port(link.to_port) {
          Some(flow) => Some(flow)
          None => arrow_flow
        }
    }
    let label = match flow_label {
      Some(label) => Some(label)
      None => link.link_label
    }
    map.links.push({
      source: map.resolve_node_id(link.from),
      target: map.resolve_node_id(link.to),
      dashed,
      label,
      flow,
    })
  }
  for evolve in ast.evolves {
    let (component, target) = evolve
    if map.node(component) is Some(node) {
      let target = to_percent(target, "Evolve target for \"\{component}\"")
      map.add_trend(component, target, node.y)
    }
  }
  if ast.annotations.length() > 0 {
    let (first, second) = ast.annotations[0]
    map.annotations_box = Some(to_coordinates(first, second, "Annotations box"))
  }
  for annotation in ast.annotation {
    let (x, y) = to_coordinates(
      annotation.x,
      annotation.y,
      "Annotation \{@dom.number(annotation.number)}",
    )
    map.annotations.push({
      number: annotation.number,
      x,
      y,
      text: annotation.text,
    })
  }
  for accelerator in ast.accelerators {
    let (x, y) = to_coordinates(
      accelerator.visibility,
      accelerator.evolution,
      "Accelerator \"\{accelerator.name}\"",
    )
    map.accelerators.push({ text: accelerator.name, x, y, })
  }
  for deaccelerator in ast.deaccelerators {
    let (x, y) = to_coordinates(
      deaccelerator.visibility,
      deaccelerator.evolution,
      "Deaccelerator \"\{deaccelerator.name}\"",
    )
    map.deaccelerators.push({ text: deaccelerator.name, x, y, })
  }
  map
}
