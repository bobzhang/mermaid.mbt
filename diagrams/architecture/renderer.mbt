// mermaid's `architectureRenderer.ts` `draw` and `svgDraw.ts`: services,
// junctions, the layout, edges, groups, and the view box.

///|
/// What the drawing reads of the configuration.
priv struct DrawConfig {
  layout : LayoutConfig
  use_max_width : Bool
  /// The font size of the page's text, which `-webkit-line-clamp` of icon
  /// text is computed from; `None` for a setting the port does not resolve.
  text_font_size : Double?
}

///|
/// `drawServices`: each service is a group with its label below and its
/// icon (an icon, text on a blank icon, or a rounded box).
fn draw_services(
  db : Db,
  parent : @dom.Element,
  context : @diagram.Context,
  config : DrawConfig,
  icon_ids : Ref[Int32],
  elements : Map[String, @dom.Element],
) -> Unit raise ArchitectureError {
  let icon_size = config.layout.icon_size
  let n = @dom.number
  for service in db.services() {
    guard service.kind is Service(icon~, icon_text~, title~) else { continue }
    let service_elem = parent.append("g")
    if title is Some(title) && title != "" {
      let text_elem = service_elem.append("g")
      @rendering.create_svg_text(
        text_elem,
        title,
        context.config,
        context.id,
        width=icon_size * 1.5,
        anchor_middle=true,
        baseline=Middle,
      )
      |> ignore
      text_elem
      .attr("dy", "1em")
      .attr("alignment-baseline", "middle")
      .attr("dominant-baseline", "middle")
      .attr("text-anchor", "middle")
      .attr("transform", "translate(\{n(icon_size / 2.0)}, \{n(icon_size)})")
      |> ignore
    }
    let bkg_elem = service_elem.append("g")
    // Upstream tests both for truthiness: an empty one is none.
    let nonempty = (text : String?) => text.filter(text => text != "")
    match (nonempty(icon), nonempty(icon_text)) {
      (Some(icon), _) =>
        bkg_elem.set_inner_html("<g>\{icon_svg(icon, icon_size, icon_ids)}</g>")
      (None, Some(text)) => {
        bkg_elem.set_inner_html(
          "<g>\{icon_svg("blank", icon_size, icon_ids)}</g>",
        )
        let container = bkg_elem.append("g")
        let foreign_object = container
          .append("foreignObject")
          .attr("width", n(icon_size))
          .attr("height", n(icon_size))
        let outer = foreign_object
          .append("div")
          .attr("class", "node-icon-text")
          .attr("style", "height: \{n(icon_size)}px;")
          .attr("xmlns", "http://www.w3.org/1999/xhtml")
        let div = outer.append("div")
        let source = @dom.placeholders_to_references(text)
        if source.contains("<") || source.contains("&") {
          raise Unsupported("markup in the text of an icon: \{text}")
        }
        div.text(source) |> ignore
        guard config.text_font_size is Some(font_size) else {
          raise Unsupported(
            "the font size of icon text: \{context.theme().get("fontSize").stringify()}",
          )
        }
        let lines = ((icon_size - 2.0) / font_size).floor()
        div.attr("style", "-webkit-line-clamp: \{n(lines)};") |> ignore
      }
      (None, None) =>
        bkg_elem
        .append("path")
        .attr("class", "node-bkg")
        .attr("id", "\{context.id}-node-\{service.id}")
        .attr(
          "d",
          "M0,\{n(icon_size)} V5 Q0,0 5,0 H\{n(icon_size - 5.0)} Q\{n(icon_size)},0 \{n(icon_size)},5 V\{n(icon_size)} Z",
        )
        |> ignore
    }
    service_elem
    .attr("id", "\{context.id}-service-\{service.id}")
    .attr("class", "architecture-service")
    |> ignore
    elements[service.id] = service_elem
  }
}

///|
/// `drawJunctions`: an invisible square.
fn draw_junctions(
  db : Db,
  parent : @dom.Element,
  context : @diagram.Context,
  config : DrawConfig,
  elements : Map[String, @dom.Element],
) -> Unit {
  let n = @dom.number
  for junction in db.junctions() {
    let junction_elem = parent.append("g")
    junction_elem
    .append("g")
    .append("rect")
    .attr("id", "\{context.id}-node-\{junction.id}")
    .attr("fill-opacity", "0")
    .attr("width", n(config.layout.icon_size))
    .attr("height", n(config.layout.icon_size))
    |> ignore
    junction_elem.attr("class", "architecture-junction") |> ignore
    elements[junction.id] = junction_elem
  }
}

///|
/// `ArchitectureDirectionArrow`: the points of an arrow head.
fn arrow_points(side : Direction, scale : Double) -> String {
  let n = @dom.number
  let s = n(scale)
  let half = n(scale / 2.0)
  match side {
    L => "\{s},\{half} 0,\{s} 0,0"
    R => "0,\{half} \{s},0 \{s},\{s}"
    T => "0,0 \{s},0 \{half},\{s}"
    B => "\{half},0 \{s},\{s} 0,\{s}"
  }
}

///|
/// `ArchitectureDirectionArrowShift`.
fn arrow_shift(side : Direction, orig : Double, arrow_size : Double) -> Double {
  match side {
    L | T => orig - arrow_size + 2.0
    R | B => orig - 2.0
  }
}

///|
/// `drawEdges`: a path through the edge's midpoint, arrow heads, and a
/// label along it.
fn draw_edges(
  db : Db,
  parent : @dom.Element,
  cy : Cy,
  context : @diagram.Context,
  config : DrawConfig,
) -> Unit {
  let padding = config.layout.padding
  let icon_size = config.layout.icon_size
  let half_icon_size = icon_size / 2.0
  let arrow_size = icon_size / 6.0
  let half_arrow_size = arrow_size / 2.0
  let n = @dom.number
  for cy_edge in cy.edges {
    let edge = cy_edge.edge
    let geometry = cy.edge_geometry(cy_edge)
    let mut start_x = geometry.start_x
    let mut start_y = geometry.start_y
    let mid_x = geometry.mid_x
    let mid_y = geometry.mid_y
    let mut end_x = geometry.end_x
    let mut end_y = geometry.end_y
    let group_edge_shift = padding + 4.0
    if edge.lhs_group {
      if edge.lhs_dir.is_x() {
        start_x += if edge.lhs_dir == L {
          -group_edge_shift
        } else {
          group_edge_shift
        }
      } else {
        start_y += if edge.lhs_dir == T {
          -group_edge_shift
        } else {
          group_edge_shift + 18.0
        }
      }
    }
    if edge.rhs_group {
      if edge.rhs_dir.is_x() {
        end_x += if edge.rhs_dir == L {
          -group_edge_shift
        } else {
          group_edge_shift
        }
      } else {
        end_y += if edge.rhs_dir == T {
          -group_edge_shift
        } else {
          group_edge_shift + 18.0
        }
      }
    }
    let is_junction = (id : String) => {
      db.nodes.get(id) is Some({ kind: Junction, .. })
    }
    if !edge.lhs_group && is_junction(edge.lhs_id) {
      if edge.lhs_dir.is_x() {
        start_x += if edge.lhs_dir == L {
          half_icon_size
        } else {
          -half_icon_size
        }
      } else {
        start_y += if edge.lhs_dir == T {
          half_icon_size
        } else {
          -half_icon_size
        }
      }
    }
    if !edge.rhs_group && is_junction(edge.rhs_id) {
      if edge.rhs_dir.is_x() {
        end_x += if edge.rhs_dir == L {
          half_icon_size
        } else {
          -half_icon_size
        }
      } else {
        end_y += if edge.rhs_dir == T {
          half_icon_size
        } else {
          -half_icon_size
        }
      }
    }
    let g = parent.append("g")
    g
    .append("path")
    .attr(
      "d",
      "M \{n(start_x)},\{n(start_y)} L \{n(mid_x)},\{n(mid_y)} L\{n(end_x)},\{n(end_y)} ",
    )
    .attr("class", "edge")
    .attr("id", "\{context.id}-L_\{edge.lhs_id}_\{edge.rhs_id}_0")
    |> ignore
    let arrow = (side : Direction, x : Double, y : Double) => {
      let x_shift = if side.is_x() {
        arrow_shift(side, x, arrow_size)
      } else {
        x - half_arrow_size
      }
      let y_shift = if !side.is_x() {
        arrow_shift(side, y, arrow_size)
      } else {
        y - half_arrow_size
      }
      g
      .append("polygon")
      .attr("points", arrow_points(side, arrow_size))
      .attr("transform", "translate(\{n(x_shift)},\{n(y_shift)})")
      .attr("class", "arrow")
      |> ignore
    }
    if edge.lhs_into {
      arrow(edge.lhs_dir, start_x, start_y)
    }
    if edge.rhs_into {
      arrow(edge.rhs_dir, end_x, end_y)
    }
    if edge.title is Some(label) && label != "" {
      let axis = if is_xy(edge.lhs_dir, edge.rhs_dir) {
        None
      } else {
        Some(edge.lhs_dir.is_x())
      }
      let width = match axis {
        Some(true) => (start_x - end_x).abs()
        Some(false) => (start_y - end_y).abs() / 1.5
        None => (start_x - end_x).abs() / 2.0
      }
      let text_elem = g.append("g")
      let middle = @rendering.create_svg_text(
        text_elem,
        label,
        context.config,
        context.id,
        width~,
        anchor_middle=true,
        baseline=Middle,
      )
      text_elem
      .attr("dy", "1em")
      .attr("alignment-baseline", "middle")
      .attr("dominant-baseline", "middle")
      .attr("text-anchor", "middle")
      |> ignore
      let translate = "translate(" + n(mid_x) + ", " + n(mid_y) + ")"
      match axis {
        Some(true) => text_elem.attr("transform", translate) |> ignore
        Some(false) =>
          text_elem.attr("transform", translate + " rotate(-90)") |> ignore
        None => {
          // `getArchitectureDirectionXYFactors`
          let (fx, fy) = match (edge.lhs_dir, edge.rhs_dir) {
            (L, T) | (T, L) => (1.0, 1.0)
            (B, L) | (L, B) => (1.0, -1.0)
            (B, R) | (R, B) => (-1.0, -1.0)
            _ => (-1.0, 1.0)
          }
          let angle = -1.0 * fx * fy * 45.0
          let original = client_rect(middle.box, 0.0)
          // On the alphabetic baseline once `dominant-baseline` is `auto`.
          let alphabetic = @rendering.create_svg_text(
            @dom.Element::new("g"),
            label,
            context.config,
            context.id,
            width~,
            anchor_middle=true,
          )
          middle.text.set_text_box(alphabetic.box)
          let rotated = client_rect(alphabetic.box, angle)
          text_elem
          .attr("dominant-baseline", "auto")
          .attr(
            "transform",
            "translate(\{n(mid_x)}, \{n(mid_y - original.1 / 2.0)})\n                translate(\{n(fx * rotated.0 / 2.0)}, \{n(fy * rotated.1 / 2.0)})\n                rotate(\{n(angle)}, 0, \{n(original.1 / 2.0)})",
          )
          |> ignore
        }
      }
    }
  }
}

///|
/// The width and height `getBoundingClientRect()` reports for a label
/// whose text has the box `box`, turned by `angle` degrees: the corners
/// turned and rounded to single precision, then moved by where the
/// `<svg>` sits in the oracle's page (the body's margin of 8px), and the
/// size of the box around them.
fn client_rect(box : @dom.Rect, angle : Double) -> (Double, Double) {
  let f = Float::from_double
  let page = f(8.0)
  let radians = angle * @math.PI / 180.0
  let cos = @jsmath.cos(radians)
  let sin = @jsmath.sin(radians)
  let corners = [
    (box.x, box.y),
    (box.x + box.width, box.y),
    (box.x, box.y + box.height),
    (box.x + box.width, box.y + box.height),
  ]
  let xs = corners.map(corner => {
    let (x, y) = corner
    let turned = if angle == 0.0 { x } else { x * cos + y * -sin }
    f(turned) + page
  })
  let ys = corners.map(corner => {
    let (x, y) = corner
    let turned = if angle == 0.0 { y } else { x * sin + y * cos }
    f(turned) + page
  })
  let min = (values : Array[Float]) => {
    values.fold(init=values[0], (a, b) => if b < a { b } else { a })
  }
  let max = (values : Array[Float]) => {
    values.fold(init=values[0], (a, b) => if b > a { b } else { a })
  }
  ((max(xs) - min(xs)).to_double(), (max(ys) - min(ys)).to_double())
}

///|
/// `drawGroups`: a dashed box around every group, with its icon and title
/// in the top left corner.
fn draw_groups(
  db : Db,
  parent : @dom.Element,
  cy : Cy,
  context : @diagram.Context,
  config : DrawConfig,
  icon_ids : Ref[Int32],
) -> Unit raise ArchitectureError {
  let padding = config.layout.padding
  let group_icon_size = padding * 0.75
  let font_size = config.layout.font_size
  let half_icon_size = config.layout.icon_size / 2.0
  let n = @dom.number
  for node in cy.nodes {
    guard node.kind is CyGroup else { continue }
    guard db.groups.get(node.id) is Some(group) else { continue }
    let box = cy.node_box(node)
    parent
    .append("rect")
    .attr("id", "\{context.id}-group-\{node.id}")
    .attr("x", n(box.x1 + half_icon_size))
    .attr("y", n(box.y1 + half_icon_size))
    .attr("width", n(box.w))
    .attr("height", n(box.h))
    .attr("class", "node-bkg")
    |> ignore
    let container = parent.append("g")
    let mut shifted_x1 = box.x1
    let mut shifted_y1 = box.y1
    if group.icon is Some(icon) {
      let bkg_elem = container.append("g")
      bkg_elem.set_inner_html(
        "<g>\{icon_svg(icon, group_icon_size, icon_ids)}</g>",
      )
      bkg_elem.attr(
        "transform",
        "translate(" +
        n(shifted_x1 + half_icon_size + 1.0) +
        ", " +
        n(shifted_y1 + half_icon_size + 1.0) +
        ")",
      )
      |> ignore
      shifted_x1 += group_icon_size
      shifted_y1 += font_size / 2.0 - 1.0 - 2.0
    }
    if group.title is Some(title) && title != "" {
      let text_elem = container.append("g")
      @rendering.create_svg_text(
        text_elem,
        title,
        context.config,
        context.id,
        width=box.w,
      )
      |> ignore
      text_elem
      .attr("dy", "1em")
      .attr("alignment-baseline", "middle")
      .attr("dominant-baseline", "start")
      .attr("text-anchor", "start")
      .attr(
        "transform",
        "translate(" +
        n(shifted_x1 + half_icon_size + 4.0) +
        ", " +
        n(shifted_y1 + half_icon_size + 2.0) +
        ")",
      )
      |> ignore
    }
  }
}

///|
/// Draw an architecture diagram into `context.svg`.
pub fn draw(
  db : Db,
  context : @diagram.Context,
) -> Unit raise ArchitectureError {
  let config : DrawConfig = {
    layout: layout_config(context.config),
    // `setupGraphViewbox` takes the setting for its truthiness.
    use_max_width: context.config.get("architecture.useMaxWidth") is Null ||
    context.config.flag("architecture.useMaxWidth"),
    text_font_size: computed_font_size(context.theme().get("fontSize")),
  }
  let svg = context.svg
  let edges_elem = svg.append("g").attr("class", "architecture-edges")
  let services_elem = svg.append("g").attr("class", "architecture-services")
  let groups_elem = svg.append("g").attr("class", "architecture-groups")
  let elements : Map[String, @dom.Element] = Map([])
  let icon_ids = Ref(0)
  draw_services(db, services_elem, context, config, icon_ids, elements)
  draw_junctions(db, services_elem, context, config, elements)
  let cy = layout(db, config.layout)
  draw_edges(db, edges_elem, cy, context, config)
  draw_groups(db, groups_elem, cy, context, config, icon_ids)
  // `positionNodes`
  let n = @dom.number
  for node in cy.nodes {
    if node.kind is CyGroup {
      continue
    }
    if elements.get(node.id) is Some(element) {
      element.attr(
        "transform",
        "translate(" + n(node.x) + "," + n(node.y) + ")",
      )
      |> ignore
    }
  }
  // `setupGraphViewbox`
  let padding = config.layout.padding
  let bounds = svg.bbox()
  let width = bounds.width + padding * 2.0
  let height = bounds.height + padding * 2.0
  @diagram.configure_svg_size(svg, height, width, config.use_max_width)
  svg.attr(
    "viewBox",
    "\{n(bounds.x - padding)} \{n(bounds.y - padding)} \{n(bounds.width + 2.0 * padding)} \{n(bounds.height + 2.0 * padding)}",
  )
  |> ignore
}
