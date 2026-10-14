// The layout: rows of shapes inside boundaries, boundaries side by side.
// Upstream's `c4Renderer`.

///|
/// What drawing a diagram keeps track of.
priv struct Renderer {
  db : C4Db
  config : @config.Config
  conf : Conf
  svg : @dom.Element
  id : String
  painter : @rendering.Painter
  /// The far corner of everything drawn so far.
  mut max_x : Double
  mut max_y : Double
}

///|
/// Draw one element, centred on `(x, y)`, with the unified shape that
/// stands for it. Elements start out as wide as the configuration says.
fn Renderer::draw_node(
  self : Renderer,
  parent : @dom.Element,
  shape : Element,
  x : Double,
  y : Double,
) -> (@rendering.Node, @dom.Element) raise {
  let node = build_node(shape, self.config, self.conf, self.id).placed(
    x~,
    y~,
    width=self.conf.width,
    label_style="",
  )
  let element = self.painter.draw_shape(parent, node) catch {
    @rendering.LayoutError(message) => raise Unsupported(message)
  }
  (node, element)
}

///|
/// upstream's `drawC4ShapeArray`: measure the shapes, place them on the
/// grid, and draw each where it was placed.
fn Renderer::draw_shapes(
  self : Renderer,
  bounds : Bounds,
  shapes : Array[Element],
) -> Unit raise {
  let conf = self.conf
  // Measure: every shape sizes itself around its label.
  for shape in shapes {
    let (node, element) = self.draw_node(self.svg, shape, 0.0, 0.0)
    shape.width = node.width.unwrap_or(conf.width)
    shape.height = node.height.unwrap_or(conf.height)
    element.remove()
  }
  for shape in shapes {
    let (x, y) = bounds.insert(
      shape.width,
      shape.height,
      conf.shape_margin,
      conf,
      self.db.shape_in_row,
    )
    shape.x = x
    shape.y = y
  }
  // Draw: the shapes are centred on the origin of their group.
  let n = @dom.number
  for shape in shapes {
    let x = shape.x + shape.width / 2.0
    let y = shape.y + shape.height / 2.0
    let positioned = self.svg
      .append("g")
      .attr("transform", "translate(\{n(x)}, \{n(y)})")
    let (node, _) = self.draw_node(positioned, shape, x, y)
    // A line that does not cross the outline ends at the centre.
    shape.intersect = Some(point => node.leaves_at(point).unwrap_or({ x, y, }))
  }
  bounds.bump_last_margin(conf.shape_margin)
}

///|
/// upstream's `drawInsideBoundary`: lay out the boundaries inside one
/// parent side by side, each with its shapes and then its own boundaries,
/// and frame them.
fn Renderer::draw_inside_boundary(
  self : Renderer,
  parent : Bounds,
  boundaries : Array[Element],
) -> Unit raise {
  let conf = self.conf
  let in_row = self.db.boundary_in_row
  let current = Bounds::new()
  current.width_limit = parent.width_limit /
    in_row.min(boundaries.length()).to_double()
  for index, boundary in boundaries {
    let props = boundary.props
    // A sprite takes 48 pixels above the label.
    let mut y = if truthy(props, "sprite") { 48.0 } else { 0.0 }
    let wrap = truthy(props, "wrap") && conf.wrap
    let font = conf.boundary_font
    guard text_of(props, "label") is Some(label_text) else {
      raise Unsupported("C4: a boundary without a label")
    }
    let label = measure_text(
      label_text,
      wrap,
      { ..font, size: font.size + 2.0, weight: "bold", },
      current.width_limit,
    )
    label.y = y + 8.0
    y = label.y + label.height
    let kind = match props.get("type") {
      None | Some(Null) => None
      Some(Object({ "text": String(text), .. })) =>
        if text == "" {
          None
        } else {
          let kind = measure_text(
            "[" + text + "]",
            wrap,
            font,
            current.width_limit,
          )
          kind.y = y + 5.0
          y = kind.y + kind.height
          Some(kind)
        }
      Some(_) => raise Unsupported("C4: a boundary type that is not a text")
    }
    let description = match props.get("descr") {
      None | Some(Null) => None
      Some(Object({ "text": String(text), .. })) =>
        if text == "" {
          None
        } else {
          let description = measure_text(
            text,
            wrap,
            { ..font, size: font.size - 2.0, },
            current.width_limit,
          )
          description.y = y + 20.0
          y = description.y + description.height
          Some(description)
        }
      Some(_) =>
        raise Unsupported("C4: a boundary description that is not a text")
    }
    if index == 0 || index % in_row == 0 {
      // A new row of boundaries, below everything drawn so far.
      let x = parent.startx + conf.diagram_margin_x
      let top = parent.stopy + conf.diagram_margin_y + y
      current.set_data(x, x, top, top)
    } else {
      // Right of the previous boundary.
      let x = if current.stopx != current.startx {
        current.stopx + conf.diagram_margin_x
      } else {
        current.startx
      }
      let top = current.starty
      current.set_data(x, x, top, top)
    }
    let shapes = self.db.shapes_in(boundary.name())
    if !shapes.is_empty() {
      self.draw_shapes(current, shapes)
    }
    let inner = self.db.boundaries_in(boundary.name())
    if !inner.is_empty() {
      self.draw_inside_boundary(current, inner)
    }
    if boundary.name() != "global" {
      boundary.x = current.startx
      boundary.y = current.starty
      boundary.width = current.stopx - current.startx
      boundary.height = current.stopy - current.starty
      // A boundary can be the end of a relationship; its outline is its
      // frame.
      boundary.intersect = Some(point => {
        @rendering.intersect_box(
          x=boundary.x + boundary.width / 2.0,
          y=boundary.y + boundary.height / 2.0,
          width=boundary.width,
          height=boundary.height,
          point,
        )
      })
      draw_boundary_frame(
        self.svg,
        boundary,
        { label, kind, description, },
        conf,
      )
    }
    parent.stopy = (current.stopy + conf.shape_margin).max(parent.stopy)
    parent.stopx = (current.stopx + conf.shape_margin).max(parent.stopx)
    self.max_x = self.max_x.max(parent.stopx)
    self.max_y = self.max_y.max(parent.stopy)
  }
}

///|
/// Where the line between the centres of two elements leaves the first.
fn intersection(from : Element, to : Element) -> @rendering.Point raise C4Error {
  guard from.intersect is Some(intersect) else {
    raise C4Error(
      "C4 element \"\{from.name()}\" has no intersect function. Please report this to https://github.com/mermaid-js/mermaid/issues",
    )
  }
  intersect({ x: to.x + to.width / 2.0, y: to.y + to.height / 2.0, })
}

///|
/// upstream's `drawRels`: measure the texts of the relationships and clip
/// their lines against the elements they join.
fn Renderer::draw_rels(self : Renderer) -> Unit raise {
  let conf = self.conf
  let font = conf.message_font
  let lines = []
  for index, rel in self.db.rels {
    let props = rel.props
    let wrap = truthy(props, "wrap") && conf.wrap
    let text = (field : String) => {
      match props.get(field) {
        None | Some(Null) => None
        Some(Object({ "text": String(text), .. })) =>
          if text == "" {
            None
          } else {
            Some(text)
          }
        Some(_) =>
          raise Unsupported("C4: a relationship \{field} that is not a text")
      }
    }
    guard text_of(props, "label") is Some(label_text) else {
      raise Unsupported("C4: a relationship without a label")
    }
    // A dynamic diagram numbers its relationships.
    let label_text = if self.db.c4_type == "C4Dynamic" {
      "\{index + 1}: \{label_text}"
    } else {
      label_text
    }
    let measure = (text : String) => {
      measure_text(text, wrap, font, text_width(text, font))
    }
    let label = measure(label_text)
    let technology = match text("techn") {
      Some(text) => Some(measure(text))
      None => None
    }
    // The description is measured and not shown.
    if text("descr") is Some(text) {
      measure(text) |> ignore
    }
    guard self.db.element(rel.from()) is Some(from) &&
      self.db.element(rel.to()) is Some(to) else {
      raise C4Error(
        "C4 rel \"\{rel.from()}\" -> \"\{rel.to()}\" references an unknown shape or boundary",
      )
    }
    let start = intersection(from, to)
    let end = intersection(to, from)
    lines.push({ rel, start, end, label, technology, })
  }
  draw_rel_lines(self.svg, lines, conf, self.id)
}

///|
/// Draw the diagram into the `<svg>` element of `context`.
pub fn draw(db : C4Db, context : @diagram.Context) -> Unit raise {
  let config = context.config
  let conf = Conf::new(config)
  let svg = context.svg
  let id = context.id
  insert_icons(svg, id)
  let screen = Bounds::new()
  screen.set_data(
    conf.diagram_margin_x,
    conf.diagram_margin_x,
    conf.diagram_margin_y,
    conf.diagram_margin_y,
  )
  // Rows wrap at the width of the screen.
  screen.width_limit = context.page.screen_width
  let renderer = {
    db,
    config,
    conf,
    svg,
    id,
    painter: @rendering.Painter::new(config, diagram_type="c4", diagram_id=id),
    max_x: conf.diagram_margin_x,
    max_y: conf.diagram_margin_y,
  }
  renderer.draw_inside_boundary(screen, db.boundaries_in(""))
  insert_markers(svg, id)
  renderer.draw_rels()
  let box_height = renderer.max_y - screen.starty
  let height = box_height + 2.0 * conf.diagram_margin_y
  let box_width = renderer.max_x - screen.startx
  let width = box_width + 2.0 * conf.diagram_margin_x
  if db.title != "" {
    svg
    .append("text")
    .text(db.title)
    .attr_number("x", box_width / 2.0 - 4.0 * conf.diagram_margin_x)
    .attr_number("y", screen.starty + conf.diagram_margin_y)
    |> ignore
  }
  @diagram.configure_svg_size(svg, height, width, conf.use_max_width)
  let extra = if db.title != "" { 60.0 } else { 0.0 }
  let n = @dom.number
  svg.attr(
    "viewBox",
    "\{n(screen.startx - conf.diagram_margin_x)} -\{n(conf.diagram_margin_y + extra)} \{n(width)} \{n(height + extra)}",
  )
  |> ignore
}
