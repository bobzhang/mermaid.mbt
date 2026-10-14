///|
/// The nodes and edges of the database as the unified renderer takes
/// them: mermaid's `getData`.
fn StateDb::layout_data(
  self : StateDb,
) -> (Array[@rendering.Node], Array[@rendering.Edge]) {
  let config = self.config
  let look = config.text("look").unwrap_or("classic")
  let wrapping_width = config.number("state.wrappingWidth")
  let min_width = config.number("state.minNodeWidth")
  let nodes = self.nodes.map(node => {
    let radius : Double? = if node.rounded { Some(10.0) } else { None }
    // A group draws nothing with its styles; they only tell how the rules
    // of its classes set its title, where the class defined last wins.
    let compiled = if node.is_group {
      let names = node.css_classes
        .split(" ")
        .map(name => name.to_owned())
        .collect()
      let styles = []
      for id, style_class in self.classes {
        if names.contains(id) {
          styles.append(style_class.styles)
        }
      }
      styles
    } else {
      node.css_compiled_styles
    }
    @rendering.Node::new(
      id=node.id,
      label=match node.label {
        One(text) => text
        _ => ""
      },
      label_type=node.label_type.unwrap_or("text"),
      parent_id?=node.parent_id,
      padding=node.padding.unwrap_or(0.0),
      css_styles=node.css_styles,
      css_compiled_styles=compiled,
      css_classes=node.css_classes,
      dir?=node.dir,
      dom_id=node.dom_id,
      look~,
      is_group=node.is_group,
      shape=node.shape,
      min_width?=if node.is_group { None } else { min_width },
      color_index?=node.color_index,
      rx?=radius,
      ry?=radius,
      center_label=node.center_label,
      wrapping_width?,
      description=node.description,
    )
  })
  let edges = self.edges.map(edge => {
    @rendering.Edge::new(
      id=edge.id,
      start=edge.start,
      end=edge.end,
      label=edge.label,
      label_type="markdown",
      thickness="normal",
      pattern=edge.pattern.unwrap_or("solid"),
      classes=edge.classes,
      arrow_type_end=edge.arrow_type_end,
      style=["fill:none"],
      look~,
      labelpos="c",
    )
  })
  (nodes, edges)
}

///|
/// Draw the state diagram into the context's `<svg>` element: mermaid's
/// `stateRenderer-v3-unified`.
pub fn draw(
  db : StateDb,
  context : @diagram.Context,
) -> Unit raise @rendering.LayoutError {
  let config = context.config
  // What the port cannot draw yet is refused rather than drawn differently.
  let layout = config.text("layout").unwrap_or("elk")
  if layout != "elk" && !@rendering.is_dagre_layout(layout) {
    raise @rendering.LayoutError("The \{layout} layout is not supported yet.")
  }
  let look = config.text("look").unwrap_or("classic")
  // Relative font sizes compound over the elements of a label.
  for node in db.nodes {
    for style in [..node.css_compiled_styles, ..node.css_styles] {
      let style = style.replace_all(old=" ", new="")
      if style.has_prefix("font-size:") &&
        !style.replace_all(old="!important", new="").has_suffix("px") {
        raise @rendering.LayoutError(
          "Font sizes in units other than px are not supported yet.",
        )
      }
    }
  }
  let (nodes, edges) = db.layout_data()
  let data : @rendering.LayoutData = {
    nodes,
    edges,
    config,
    diagram_type: "stateDiagram",
    diagram_id: context.id,
    direction: document_direction(Some(db.root_doc)),
    markers: [if look == "neo" { "barbNeo" } else { "barb" }],
  }
  @rendering.render(data, context.svg)
  db.insert_links(data.nodes, context.svg)
  insert_title(db.title, context)
  @rendering.setup_viewport(
    context.svg,
    8.0,
    "statediagram",
    config.get("state.useMaxWidth") is (True | Null),
  )
}

///|
/// The diagram title, centred above the chart: mermaid's `insertTitle`.
fn insert_title(title : String, context : @diagram.Context) -> Unit {
  if title == "" {
    return
  }
  let config = context.config
  let svg = context.svg
  let bounds = svg.bbox()
  let margin = config.number("state.titleTopMargin").unwrap_or(25.0)
  let x = bounds.x + bounds.width / 2.0
  let y = -margin
  let text = svg
    .append("text")
    .text(title)
    .attr("text-anchor", "middle")
    .attr_number("x", x)
    .attr_number("y", y)
    .attr("class", "statediagramTitleText")
  // The stylesheet sets titles at 18px in the diagram's font.
  let font = @font.Stack::for_family(config.theme().text("fontFamily"))
  let size = 18.0
  let box = font.bbox(title, size)
  // Anchored in the middle of its advance, which is whole layout units.
  text.set_text_box({
    x: x - font.advance(title, size) / 2.0 + box.x,
    y: y + box.y,
    width: box.width,
    height: box.height,
  })
}

///|
/// `text.replace(/^"+|"+$/g, '')`
fn strip_quotes(text : String) -> String {
  text.trim(chars="\"").to_owned()
}

///|
/// Wrap the node of every state a `click` names in a link: the end of
/// mermaid's `draw`. A state is found by its element's id or, failing
/// that, by its text; the last node that matches is taken.
fn StateDb::insert_links(
  self : StateDb,
  nodes : Array[@rendering.Node],
  svg : @dom.Element,
) -> Unit {
  for link in self.links {
    guard link.id != "" else { continue }
    let dom_id = nodes
      .search_by(node => node.id == link.id)
      .map(index => nodes[index].dom_id)
    let mut matched : @dom.Element? = None
    for group in svg.descendants(["g"]) {
      let classes = group.get_attr("class").unwrap_or("")
      guard classes
        .split(" ")
        .any(name => name == "node" || name == "rough-node") else {
        continue
      }
      if (dom_id is Some(_) && group.get_attr("id") == dom_id) ||
        trim(group.text_content()) == link.id {
        matched = Some(group)
      }
    }
    guard matched is Some(element) && element.parent() is Some(parent) else {
      continue
    }
    // Upstream also sets `target`, which the final sanitizing pass strips
    // from SVG anchors again.
    let anchor = @dom.Element::new("a").attr(
      "xlink:href",
      strip_quotes(link.url),
    )
    if link.tooltip != "" {
      let tooltip = strip_quotes(link.tooltip)
      anchor.attr("title", tooltip) |> ignore
      element.attr("title", tooltip) |> ignore
    }
    parent.insert_before(anchor, element)
    element.remove()
    anchor.append_child(element)
  }
}
