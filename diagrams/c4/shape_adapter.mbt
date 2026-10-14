// From a C4 element to a node the unified shapes draw: upstream's
// `c4ShapeAdapter`.

///|
/// The element types that have fonts and colours of their own in the
/// configuration: upstream's `C4_ELEMENT_TYPES`.
let element_types : Array[String] = {
  let types = []
  for
    kind in [
      "person", "system", "system_db", "system_queue", "container", "container_db",
      "container_queue", "component", "component_db", "component_queue",
    ] {
    types.push(kind)
    types.push("external_" + kind)
  }
  types
}

///|
/// The shape a Structurizr-style keyword stands for, in `$shape`,
/// `$sprite` or `$tags`.
fn keyword_shape(value : String?) -> String? raise C4Error {
  guard value is Some(value) && value != "" else { return None }
  match value.to_lower() {
    "person" => Some("person")
    "box" | "rounded" => Some("rounded")
    "cylinder" | "database" | "db" => Some("cylinder")
    "queue" | "pipe" => Some("h-cyl")
    "component" => Some("fr-rect")
    // Upstream looks the keyword up in a plain object and finds what
    // every object inherits.
    "constructor" =>
      raise C4Error(
        "C4: no shape handler for \"function Object() { [native code] }\"",
      )
    "__proto__" => raise C4Error("C4: no shape handler for \"[object Object]\"")
    _ => None
  }
}

///|
/// The shape that draws an element: an explicit `$shape` or `$sprite`,
/// then a tag that names a shape, then the element type.
fn resolve_node_shape(
  props : Map[String, Json],
  kind : String,
) -> String raise C4Error {
  if keyword_shape(string_of_prop(props, "shape")) is Some(shape) {
    return shape
  }
  if keyword_shape(string_of_prop(props, "sprite")) is Some(shape) {
    return shape
  }
  if string_of_prop(props, "tags") is Some(tags) {
    for tag in tags.split(",") {
      if keyword_shape(Some(js_trim(tag.to_owned()))) is Some(shape) {
        return shape
      }
    }
  }
  if kind is ("person" | "external_person") {
    "person"
  } else if kind.has_suffix("_db") {
    "cylinder"
  } else if kind.has_suffix("_queue") {
    "h-cyl"
  } else {
    "rounded"
  }
}

///|
/// The type line of an element, Structurizr style: `[Container: Node.js]`.
fn stereotype_text(props : Map[String, Json], kind : String) -> String {
  let base = kind
    .strip_prefix("external_")
    .map(rest => rest.to_owned())
    .unwrap_or(kind)
  let base = match base {
    [.. rest, .. "_db"] => rest.to_owned()
    [.. rest, .. "_queue"] => rest.to_owned()
    _ => base
  }
  let stereotype = match base {
    "person" => "Person"
    "system" => "Software System"
    "container" => "Container"
    "component" => "Component"
    other => other.replace_all(old="_", new=" ")
  }
  match text_of(props, "techn") {
    Some(techn) if techn != "" => "[\{stereotype}: \{techn}]"
    _ => "[\{stereotype}]"
  }
}

///|
/// The inline styles of an element: the fill and border of its type from
/// the configuration unless the element has its own (`UpdateElementStyle`),
/// and the colour of its text, white unless given.
fn element_css_styles(
  props : Map[String, Json],
  kind : String,
  config : @config.Config,
) -> Array[String] {
  let colour = (own : String, configured : String) => {
    match props.get(own) {
      Some(String(value)) => value
      Some(Null) | None =>
        if element_types.contains(kind) {
          match config.get("c4.\{kind}_\{configured}") {
            String(value) => value
            _ => ""
          }
        } else {
          ""
        }
      Some(_) => ""
    }
  }
  let styles = []
  let fill = colour("bgColor", "bg_color")
  if fill != "" {
    styles.push("fill:\{fill}")
  }
  let stroke = colour("borderColor", "border_color")
  if stroke != "" {
    styles.push("stroke:\{stroke}")
  }
  styles.push(
    "color:" + string_of_prop(props, "fontColor").unwrap_or("#FFFFFF"),
  )
  styles
}

///|
/// The font the label of an element is set in.
priv struct ElementFont {
  /// A CSS `font-family` list.
  family : String
  /// The size in pixels.
  size : Double
  bold : Bool
}

///|
/// The font the stylesheet sets the label of an element type in: the
/// three `<type>Font...` keys of the configuration, each falling back to
/// what the diagram inherits when it is not configured.
fn element_font(
  config : @config.Config,
  kind : String,
) -> ElementFont raise Unsupported {
  let theme = config.theme()
  let configured = element_types.contains(kind)
  let family = match config.get("c4.\{kind}FontFamily") {
    String(family) if configured && family != "" =>
      match serialize_font_family(family) {
        Some(family) => family
        None => raise Unsupported("C4: c4.\{kind}FontFamily \{family}")
      }
    _ => theme.text("fontFamily")
  }
  let inherited_size = match theme.get("fontSize") {
    Number(size, ..) => Some(size)
    other => font_size_px(other)
  }
  let size = match config.get("c4.\{kind}FontSize") {
    Null | False => inherited_size
    Number(size, ..) if size == 0.0 => inherited_size
    String("") => inherited_size
    value if configured => font_size_px(value)
    _ => inherited_size
  }
  guard size is Some(size) else {
    raise Unsupported("C4: the font size of \{kind}")
  }
  let weight = match config.get("c4.\{kind}FontWeight") {
    Null | False | String("") => "normal"
    Number(weight, ..) if weight == 0.0 => "normal"
    value if configured =>
      match serialize_font_weight(value) {
        Some(weight) => weight
        None =>
          raise Unsupported("C4: c4.\{kind}FontWeight \{value.stringify()}")
      }
    _ => "normal"
  }
  guard measurable_family(family, weight) else {
    raise Unsupported(
      "C4: text in the font family \{family} at weight \{weight}",
    )
  }
  let bold = is_bold(weight)
  { family, size, bold, }
}

///|
/// upstream's `buildC4Node`: the node the unified shapes draw for an
/// element. Layout stays with the grid; only the drawing is theirs.
fn build_node(
  shape : Element,
  config : @config.Config,
  conf : Conf,
  diagram_id : String,
) -> @rendering.Node raise {
  let props = shape.props
  guard text_of(props, "typeC4Shape") is Some(kind) else {
    raise Unsupported("C4: an element without a type")
  }
  guard text_of(props, "label") is Some(label) else {
    raise Unsupported("C4: an element without a label")
  }
  let classes = ["c4-shape", "c4-\{kind}"]
  if kind.has_prefix("external_") {
    classes.push("c4-external")
  }
  let node_shape = resolve_node_shape(props, kind)
  let styles = element_css_styles(props, kind, config)
  if node_shape is ("rounded" | "fr-rect") {
    // Inline, so that it wins over the corner radius of the shape.
    styles.push("rx:12px")
    styles.push("ry:12px")
  }
  let description = match text_of(props, "descr") {
    Some(text) if text != "" => [text]
    _ => []
  }
  let stereotype = stereotype_text(props, kind)
  // The label helper sanitizes and measures each text; make sure it can.
  let font = element_font(config, kind)
  let stack = @font.Stack::for_family(font.family)
  for text in [label, stereotype, ..description] {
    let text = @dom.placeholders_to_references(text)
    sanitize_text(text, config, "a label") |> ignore
    guard stack.covers(collapse_spaces(text)) else {
      raise Unsupported("C4: text the embedded fonts do not cover: \{text}")
    }
  }
  @rendering.Node::new(
    id=shape.name(),
    label~,
    label_type="string",
    padding=conf.shape_padding,
    css_styles=styles,
    css_classes=classes.join(" "),
    dom_id="\{diagram_id}-\{shape.name()}",
    look=config.text("look").unwrap_or("classic"),
    shape=node_shape,
    data=C4(
      stereotype~,
      font_family=font.family,
      font_size=font.size,
      bold=font.bold,
    ),
    description~,
  )
}
