// Drawing a use case diagram: mermaid's `usecaseRenderer.ts`.

///|
/// Families known to be missing in the reference environment, which the
/// browser skips; the rest of a list must name a face the port measures.
fn check_font_family(family : String) -> Unit raise UsecaseError {
  for name in family.split(",") {
    let name = name.trim(chars=" \t\n\"'").to_owned().to_lower()
    match name {
      "open sans" | "recursive variable" => continue
      "trebuchet ms"
      | "verdana"
      | "arial"
      | "helvetica"
      | "sans-serif"
      | "times"
      | "serif"
      | "georgia" => return
      _ =>
        raise Unsupported(
          "The font family \{name} cannot be measured: only Trebuchet MS, Verdana, Arial, Helvetica, Times and Georgia are known.",
        )
    }
  }
  raise Unsupported("The font family list \{family} names no known face.")
}

///|
/// A font size from the configuration, in pixels.
fn font_size(
  config : @config.Config,
  key : String,
) -> Double raise UsecaseError {
  match config.get(key) {
    Number(size, ..) => size
    other =>
      raise Unsupported("The font size \{other.stringify()} is not a number.")
  }
}

///|
/// Whether a CSS font weight picks the bold face.
fn is_bold(weight : String) -> Bool raise UsecaseError {
  match weight {
    "normal" | "lighter" => false
    "bold" | "bolder" => true
    other => {
      let value = @string.parse_double(other) catch {
        _ => raise Unsupported("The font weight \{other} is not understood.")
      }
      value > 500.0
    }
  }
}

///|
/// The font settings of the diagram, as `applyUsecaseFonts` writes them on
/// the `<svg>` element and the label fonts they stand for.
priv struct Fonts {
  actor_size : Double
  actor_family : String
  actor_weight : String
  usecase_size : Double
  usecase_family : String
  usecase_weight : String
}

///|
fn Fonts::from_config(config : @config.Config) -> Fonts raise UsecaseError {
  let text = (key : String) => {
    match config.get(key) {
      String(value) => value
      Number(value, ..) => @dom.number(value)
      other => other.stringify()
    }
  }
  {
    actor_size: font_size(config, "usecase.actorFontSize"),
    actor_family: text("usecase.actorFontFamily"),
    actor_weight: text("usecase.actorFontWeight"),
    usecase_size: font_size(config, "usecase.usecaseFontSize"),
    usecase_family: text("usecase.usecaseFontFamily"),
    usecase_weight: text("usecase.usecaseFontWeight"),
  }
}

///|
/// `applyUsecaseFonts`
fn Fonts::apply(self : Fonts, svg : @dom.Element) -> Unit {
  let n = @dom.number
  svg
  .style("--mermaid-usecase-actor-font-size", "\{n(self.actor_size)}px")
  .style("--mermaid-usecase-actor-font-family", self.actor_family)
  .style("--mermaid-usecase-actor-font-weight", self.actor_weight)
  .style("--mermaid-usecase-font-size", "\{n(self.usecase_size)}px")
  .style("--mermaid-usecase-font-family", self.usecase_family)
  .style("--mermaid-usecase-font-weight", self.usecase_weight)
  |> ignore
}

///|
/// The kind an element is annotated with.
fn element_kind(node : LayoutNode) -> String {
  if node.is_group {
    "boundary"
  } else if node.actor_type is Some(_) {
    "actor"
  } else if node.shape == "note" {
    "note"
  } else if node.shape == "usecaseJsonTable" {
    "json"
  } else {
    "usecase"
  }
}

///|
/// How many layout roots (`g.root`) an element is drawn in.
fn root_depth(element : @dom.Element) -> Int32 {
  let mut depth = 0
  let mut current = element.parent()
  while current is Some(ancestor) {
    if ancestor.get_attr("class").unwrap_or("").split(" ").any(c => c == "root") {
      depth += 1
    }
    current = ancestor.parent()
  }
  depth
}

///|
/// Mark the drawn elements with their model ids and accessible names:
/// `annotateUsecaseElements`.
fn annotate(
  svg : @dom.Element,
  diagram_id : String,
  nodes : Array[LayoutNode],
  dom_ids : Map[String, String],
  edges : Array[LayoutEdge],
  dagre~ : Bool,
) -> Unit {
  for node in nodes {
    let dom_id = dom_ids.get(node.id).unwrap_or(node.id)
    guard svg.find_by_id(dom_id) is Some(element) else { continue }
    element
    .attr("data-usecase-id", node.id)
    .attr("data-usecase-kind", element_kind(node))
    .attr("role", "img")
    .attr("aria-label", node.accessible_name)
    |> ignore
    // The sanitizer drops a name that looks like the end of markup.
    if !@dom.is_safe_for_xml(node.accessible_name) {
      element.remove_attr("aria-label") |> ignore
    }
    // The first line of the label is the stereotype. Drawing with ELK
    // renamed the shape of a rectangle to `squareRect`, which upstream
    // does not look for here: then only ellipses get the stereotype
    // marked. Dagre draws copies of the nodes and leaves the shape alone.
    if node.folded_stereotype &&
      (node.shape == "usecaseEllipse" || (dagre && node.shape == "rect")) {
      match
        element
        .descendants(["span"])
        .filter(span => {
          span
          .get_attr("class")
          .unwrap_or("")
          .split(" ")
          .any(c => c == "nodeLabel")
        }) {
        [label, ..] => {
          let container = match label.descendants(["p"]) {
            [p, ..] => p
            [] => label
          }
          if container.take_first_text() is Some(text) {
            container
            .insert_first("span")
            .attr("class", "usecase-stereotype")
            .text(text)
            |> ignore
          }
        }
        [] =>
          // SVG text: `.label tspan tspan, .label tspan` finds the first
          // of either in document order, which is the line.
          match element.descendants(["tspan"]) {
            [line, ..] => {
              let classes = line.get_attr("class").unwrap_or("")
              line.attr("class", "\{classes} usecase-stereotype") |> ignore
            }
            [] => ()
          }
      }
    }
  }
  let by_id : Map[String, LayoutEdge] = Map([])
  for edge in edges {
    by_id[edge.id] = edge
  }
  for path in svg.descendants(["path"]) {
    guard path.get_attr("data-et") == Some("edge") else { continue }
    // Edges dagre drew inside a group it laid out on its own are not
    // among the diagram's edges once it is done: those are the edges of
    // the outermost graph.
    if root_depth(path) > 1 {
      continue
    }
    let id = path.get_attr("data-id").unwrap_or("")
    // Dagre draws a self loop as three edges it adds to the diagram's,
    // which are annotated too, with their ids for names.
    guard by_id.get(id) is Some(edge) else {
      if id.contains("-cyclic-special-") {
        path
        .attr("id", "usecase-\{safe_id(diagram_id)}-\{safe_id(id)}")
        .attr("data-usecase-id", id)
        .attr("data-usecase-kind", "relationship")
        .attr("role", "img")
        .attr("aria-label", id)
        |> ignore
      }
      continue
    }
    path
    .attr("id", "usecase-\{safe_id(diagram_id)}-\{safe_id(edge.id)}")
    .attr("data-usecase-id", edge.id)
    .attr(
      "data-usecase-kind",
      if edge.internal {
        "note-connector"
      } else {
        "relationship"
      },
    )
    |> ignore
    if edge.internal {
      path.attr("aria-hidden", "true") |> ignore
    } else {
      path.attr("role", "img").attr("aria-label", edge.accessible_name)
      |> ignore
      if !@dom.is_safe_for_xml(edge.accessible_name) {
        path.remove_attr("aria-label") |> ignore
      }
    }
  }
}

///|
/// Refuse text the port cannot measure: characters none of the embedded
/// faces of the diagram's fonts has, which the browser takes from some
/// other system font.
fn check_measurable(
  texts : Array[String],
  families : Array[String],
) -> Unit raise UsecaseError {
  let stacks = []
  for family in families {
    stacks.push(@font.Stack::for_family(family))
    stacks.push(@font.Stack::for_family(family, bold=true))
    stacks.push(@font.Stack::for_family(family, italic=true))
  }
  for text in texts {
    // What the label shows: entities resolved, lines apart.
    // White space collapses to spaces.
    let shown = @dom.sanitized_text(@dom.placeholders_to_references(text))
      .replace_all(old="\t", new=" ")
      .replace_all(old="\r", new=" ")
      .replace_all(old="\u{0c}", new=" ")
    for line in shown.split("\n") {
      for stack in stacks {
        if stack.first_uncovered(line) is Some(c) {
          raise Unsupported(
            "The character \{c} cannot be measured: no embedded font has it.",
          )
        }
      }
    }
  }
}

///|
/// Draw the diagram into the context's `<svg>` element.
pub fn draw(
  db : UsecaseDb,
  context : @diagram.Context,
) -> Unit raise UsecaseError {
  let config = context.config
  // Only `elk` names the layered ELK layout; every other name, known or
  // not, ends in another engine upstream.
  let layout = config.text("layout").unwrap_or("elk")
  if layout != "elk" &&
    layout != "swimlane" &&
    !@rendering.is_dagre_layout(layout) {
    raise Unsupported("The \{layout} layout is not supported yet.")
  }
  let look = config.text("look").unwrap_or("neo")
  let fonts = Fonts::from_config(config)
  check_font_family(fonts.actor_family)
  check_font_family(fonts.usecase_family)
  check_font_family(config.theme().text("fontFamily"))
  let actor_font : @rendering.UsecaseFont = {
    family: fonts.actor_family,
    size: fonts.actor_size,
    bold: is_bold(fonts.actor_weight),
  }
  let usecase_font : @rendering.UsecaseFont = {
    family: fonts.usecase_family,
    size: fonts.usecase_size,
    bold: is_bold(fonts.usecase_weight),
  }
  let (nodes, edges) = db.layout_data()
  prepare_layout_data(nodes, edges)
  let texts = []
  for node in nodes {
    texts.push(node.label)
    if node.stereotype is Some(stereotype) {
      texts.push("«\{stereotype}»")
    }
    for row in node.json_rows {
      texts.push(row.key)
      texts.push(row.value)
    }
  }
  for edge in edges {
    if edge.label is Some(label) {
      texts.push(label)
    }
  }
  check_measurable(texts, [
    config.theme().text("fontFamily"),
    fonts.actor_family,
    fonts.usecase_family,
  ])
  let svg = context.svg
  fonts.apply(svg)
  // The browser writes the declarations out as the `style` attribute
  // before the viewport is set up, which places it before `class`.
  svg.get_attr("style") |> ignore
  let layout_nodes = nodes.map(node => {
    @rendering.Node::new(
      id=node.id,
      label=node.label,
      label_type=node.label_type,
      parent_id?=node.parent_id,
      padding=node.padding,
      css_styles=node.css_styles,
      css_compiled_styles=node.css_compiled_styles,
      css_classes=node.css_classes,
      dom_id="usecase-\{safe_id(node.id)}",
      look~,
      is_group=node.is_group,
      shape=node.shape,
      min_width?=node.min_width,
      color_index?=node.color_index,
      wrapping_width=node.wrapping_width,
      spread_ports=node.spread_ports,
      data=Usecase(
        font=if node.actor_type is Some(_) {
          Some(actor_font)
        } else if element_kind(node) == "usecase" {
          Some(usecase_font)
        } else {
          None
        },
        business=node.business,
        stereotype=node.stereotype,
        icon=node.icon,
        rows=node.json_rows.map(row => (row.key, row.value)),
        boundary_type=node.boundary_type.unwrap_or(""),
      ),
    )
  })
  let layout_edges = edges.map(edge => {
    @rendering.Edge::new(
      id=edge.id,
      start=edge.source,
      end=edge.target,
      label=edge.label.unwrap_or(""),
      label_type=edge.label_type.unwrap_or("text"),
      thickness="normal",
      pattern=edge.pattern,
      classes=edge.classes,
      arrow_type_start=edge.arrow_type_start,
      arrow_type_end=edge.arrow_type_end,
      css_compiled_styles=edge.css_compiled_styles,
      style=edge.style,
      look~,
      animate=edge.animate,
      animation?=edge.animation,
      minlen=edge.minlen.to_double(),
      labelpos="c",
    )
  })
  let data : @rendering.LayoutData = {
    nodes: layout_nodes,
    edges: layout_edges,
    config,
    diagram_type: "usecase",
    diagram_id: context.id,
    direction: db.direction,
    markers: ["point", "circle", "cross", "extension"],
  }
  @rendering.render(data, svg) catch {
    // Upstream fails the same way: under dagre an empty boundary is drawn
    // as a node, and no node shape draws a boundary.
    @rendering.LayoutError(message) if message.has_prefix("No such shape") =>
      raise Invalid(message)
    @rendering.LayoutError(message) => raise Unsupported(message)
  }
  let dom_ids : Map[String, String] = Map([])
  for node in layout_nodes {
    dom_ids[node.id] = node.dom_id
  }
  annotate(
    svg,
    context.id,
    nodes,
    dom_ids,
    edges,
    dagre=@rendering.is_dagre_layout(layout),
  )
  @rendering.setup_viewport(
    svg,
    config.number("usecase.diagramPadding").unwrap_or(20.0),
    "usecaseDiagram",
    match config.get("usecase.useMaxWidth") {
      Null => true
      value => @config.evaluate(value)
    },
  )
  fonts.apply(svg)
}
