// mermaid's `layoutArchitecture`: the cytoscape graph, the constraints
// derived from the sides edges leave their nodes by, and fcose run twice
// (the second time from where the first left the nodes, once the bent
// edges have been given the weights that put their bends at the corner).

///|
/// The configuration of an architecture diagram that the layout reads.
priv struct LayoutConfig {
  icon_size : Double
  font_size : Double
  padding : Double
  idealEdgeLengthMultiplier : Double
  edge_elasticity : Double
  num_iter : Int32
  seed : Double
  randomize : Bool
  node_separation : Double
}

///|
/// `getAlignments`: nodes on one row or column of the grid of a connected
/// part line up, unless they are in groups placed the other way; `align`
/// directives replace the lines their members are in.
fn alignments(
  db : Db,
  spatial_maps : Array[SpatialMap],
  group_alignments : Map[String, Alignment],
) -> (Array[Array[String]], Array[Array[String]]) {
  // `flattenAlignments`: the lines of one axis, by coordinate, as lists of
  // node ids (a list can name a node more than once).
  fn flatten(
    by_coordinate : Map[Int32, Map[String, Array[String]]],
    direction : Alignment,
  ) -> Array[Array[String]] {
    let flattened : Map[String, Array[String]] = Map([])
    for coordinate, by_group in by_coordinate {
      let dir = coordinate.to_string()
      let mut count = 0
      let entries = by_group.to_array()
      if entries.length() == 1 {
        flattened[dir] = entries[0].1
        continue
      }
      for i in 0..<(entries.length() - 1) {
        for j in (i + 1)..<entries.length() {
          let (a_group, a_ids) = entries[i]
          let (b_group, b_ids) = entries[j]
          let alignment = group_alignments.get(
            group_alignment_key(a_group, b_group),
          )
          if alignment == Some(direction) ||
            a_group == "default" ||
            b_group == "default" {
            let list = match flattened.get(dir) {
              Some(list) => list.copy()
              None => []
            }
            list.append(a_ids)
            list.append(b_ids)
            flattened[dir] = list
          } else {
            flattened["\{dir}-\{count}"] = a_ids
            count += 1
            flattened["\{dir}-\{count}"] = b_ids
            count += 1
          }
        }
      }
    }
    flattened.values().filter(list => list.length() > 1).collect()
  }

  let horizontal = []
  let vertical = []
  for map in spatial_maps {
    let horizontal_lines : Map[Int32, Map[String, Array[String]]] = Map([])
    let vertical_lines : Map[Int32, Map[String, Array[String]]] = Map([])
    for id in map.ids {
      let (x, y) = map.positions[id]
      let group = db.nodes
        .get(id)
        .bind(node => node.parent)
        .unwrap_or("default")
      if !horizontal_lines.contains(y) {
        horizontal_lines[y] = Map([])
      }
      if !vertical_lines.contains(x) {
        vertical_lines[x] = Map([])
      }
      for line in [horizontal_lines[y], vertical_lines[x]] {
        if !line.contains(group) {
          line[group] = []
        }
        line[group].push(id)
      }
    }
    horizontal.append(flatten(horizontal_lines, Horizontal))
    vertical.append(flatten(vertical_lines, Vertical))
  }
  let declared : Map[String, Unit] = Map([])
  for hint in db.layout_hints {
    for id in hint.members {
      declared[id] = ()
    }
  }
  let keep = (lines : Array[Array[String]]) => {
    lines.filter(line => !line.iter().any(id => declared.contains(id)))
  }
  let horizontal = keep(horizontal)
  let vertical = keep(vertical)
  for hint in db.layout_hints {
    if hint.members.length() < 2 {
      continue
    }
    match hint.direction {
      Row => horizontal.push(hint.members.copy())
      Column => vertical.push(hint.members.copy())
    }
  }
  (horizontal, vertical)
}

///|
/// `getRelativeConstraints`: neighbours on the grid keep their order, a
/// gap apart; `align` directives place their members in the order given.
fn relative_constraints(
  db : Db,
  spatial_maps : Array[SpatialMap],
  config : LayoutConfig,
) -> Array[@fcose.Relative] {
  let gap = config.idealEdgeLengthMultiplier * config.icon_size
  let constraints = []
  let declared_pairs : Map[String, Unit] = Map([])
  for hint in db.layout_hints {
    for i in 0..<(hint.members.length() - 1) {
      let a = hint.members[i]
      let b = hint.members[i + 1]
      declared_pairs["\{a}|\{b}"] = ()
      declared_pairs["\{b}|\{a}"] = ()
      match hint.direction {
        Row => constraints.push(@fcose.Horizontal(left=a, right=b, gap~))
        Column => constraints.push(@fcose.Vertical(top=a, bottom=b, gap~))
      }
    }
  }
  let key = (x : Int32, y : Int32) => "\{x},\{y}"
  for map in spatial_maps {
    // A position names the last node put there.
    let at : Map[String, String] = Map([])
    for id in map.ids {
      let (x, y) = map.positions[id]
      at[key(x, y)] = id
    }
    let queue = [(0, 0)]
    let visited : Map[String, Unit] = Map([])
    let mut next = 0
    while next < queue.length() {
      let (cx, cy) = queue[next]
      next += 1
      visited[key(cx, cy)] = ()
      guard at.get(key(cx, cy)) is Some(current) else { continue }
      // `Object.entries(directions)`: L, R, T, B.
      for entry in [(L, -1, 0), (R, 1, 0), (T, 0, 1), (B, 0, -1)] {
        let (dir, dx, dy) = entry
        let (nx, ny) = (cx + dx, cy + dy)
        guard at.get(key(nx, ny)) is Some(neighbor) &&
          !visited.contains(key(nx, ny)) else {
          continue
        }
        queue.push((nx, ny))
        if declared_pairs.contains("\{current}|\{neighbor}") {
          continue
        }
        // `{[name(dir)]: neighbor, [name(opposite)]: current, gap}`
        constraints.push(
          match dir {
            L => @fcose.Horizontal(left=neighbor, right=current, gap~)
            R => @fcose.Horizontal(left=current, right=neighbor, gap~)
            T => @fcose.Vertical(top=neighbor, bottom=current, gap~)
            B => @fcose.Vertical(top=current, bottom=neighbor, gap~)
          },
        )
      }
    }
  }
  constraints
}

///|
/// The cytoscape graph of a diagram, every node at the origin: groups,
/// services, junctions and edges, in that order.
fn build_cy(db : Db, config : LayoutConfig) -> Cy raise ArchitectureError {
  let cy : Cy = {
    nodes: [],
    by_id: Map([]),
    edges: [],
    icon_size: config.icon_size,
    font_size: config.font_size,
    padding: config.padding,
  }
  let add = (id : String, kind : CyKind, parent : String?, label : String) => {
    let index = cy.nodes.length()
    cy.nodes.push({
      id,
      kind,
      parent,
      children: [],
      label,
      x: 0.0,
      y: 0.0,
      auto_width: 0.0,
      auto_height: 0.0,
    })
    cy.by_id[id] = index
    if parent is Some(parent) && cy.by_id.get(parent) is Some(owner) {
      cy.nodes[owner].children.push(index)
    }
  }
  for _, group in db.groups {
    add(group.id, CyGroup, group.parent, "")
  }
  for node in db.services() {
    guard node.kind is Service(title~, ..) else { continue }
    add(node.id, CyLeaf, node.parent, title.unwrap_or(""))
  }
  for node in db.junctions() {
    add(node.id, CyLeaf, node.parent, "")
  }
  for edge in db.edges {
    let id = "\{edge.lhs_id}-\{edge.rhs_id}"
    // cytoscape refuses a second element with an id.
    if cy.edges.iter().any(e => e.id == id) {
      raise Invalid("Can not create second element with ID `\{id}`")
    }
    cy.edges.push({
      id,
      edge,
      source: cy.by_id[edge.lhs_id],
      target: cy.by_id[edge.rhs_id],
      segments: is_xy(edge.lhs_dir, edge.rhs_dir),
      weights: 0.0,
      distances: 0.5,
    })
  }
  cy
}

///|
/// The nodes of the cytoscape graph as fcose builds its own: the top-level
/// nodes with what is inside them, each where cytoscape has it.
fn fcose_nodes(cy : Cy, indexes : Array[Int32]) -> Array[@fcose.Node] {
  indexes.map(index => {
    let node = cy.nodes[index]
    // `layoutDimensions`: the outer size, 1 where it would be 0.
    let mut w = cy.outer_width(node)
    let mut h = cy.outer_height(node)
    if w == 0.0 || h == 0.0 {
      w = 1.0
      h = 1.0
    }
    {
      id: node.id,
      x: node.x - w / 2.0,
      y: node.y - h / 2.0,
      width: w,
      height: h,
      // `parseInt(node.css("padding"))`
      padding: cy.node_padding(node).to_int().to_double(),
      repulsion: 4500.0,
      children: fcose_nodes(cy, node.children),
    }
  })
}

///|
/// One run of fcose (`layout.run()`) from where the nodes are: the result
/// moved to the centre of what was there before, and the nodes put there.
fn run_fcose(
  cy : Cy,
  edges : Array[@fcose.Edge],
  constraints : @fcose.Constraints,
  config : LayoutConfig,
  tracer : RunTracer?,
) -> Unit raise ArchitectureError {
  let box = cy.bounding_box()
  let center_x = box.x1 + box.w / 2.0
  let center_y = box.y1 + box.h / 2.0
  let roots = []
  for index, node in cy.nodes {
    if node.parent is None {
      roots.push(index)
    }
  }
  let fcose_tracer = tracer.map(t => t.fcose)
  let random = @fcose.SeededRandom::new(to_uint32(config.seed))
  let nodes = if config.randomize {
    let spectral = @fcose.spectral_layout(
      spectral_graph(cy),
      random,
      config.node_separation,
    )
    spectral_nodes(cy, roots, spectral)
  } else {
    fcose_nodes(cy, roots)
  }
  let placed = @fcose.layout(
    nodes,
    edges,
    constraints,
    { num_iter: config.num_iter, seed: to_uint32(config.seed), },
    tracer?=fcose_tracer,
    random~,
    transform=config.randomize,
  ) catch {
    @fcose.Unsupported(message) => raise Unsupported(message)
    @fcose.InvalidArrayLength => raise Invalid(layout_failure)
  }
  if tracer is Some(t) {
    (t.center)(center_x, center_y, box)
  }
  // `relocateComponent`: the box of every node, compound ones included.
  let mut min_x = @double.infinity
  let mut max_x = @double.neg_infinity
  let mut min_y = @double.infinity
  let mut max_y = @double.neg_infinity
  for node in placed {
    let left = node.x
    let right = node.x + node.width
    let top = node.y
    let bottom = node.y + node.height
    if left < min_x {
      min_x = left
    }
    if right > max_x {
      max_x = right
    }
    if top < min_y {
      min_y = top
    }
    if bottom > max_y {
      max_y = bottom
    }
  }
  let diff_x = center_x - (max_x + min_x) / 2.0
  let diff_y = center_y - (max_y + min_y) / 2.0
  for node in placed {
    // `setCenter(getCenterX() + diff, ...)`, then `getCenterX()`.
    let x = node.x + node.width / 2.0 + diff_x - node.width / 2.0
    let y = node.y + node.height / 2.0 + diff_y - node.height / 2.0
    let index = cy.by_id[node.id]
    let cy_node = cy.nodes[index]
    if !cy.is_parent(cy_node) {
      cy_node.x = x + node.width / 2.0
      cy_node.y = y + node.height / 2.0
    }
  }
  cy.update_all_compound_bounds()
}

///|
/// mermaid's message when the constraints contradict each other.
let layout_failure = "Architecture layout failed: a declared `align row|column` directive likely contradicts the edge directions, or two declared alignments overlap on a shared node. Check that the order of members in each `align` chain is consistent with the edges between them, and that no node appears in two `align` directives along the same axis."

///|
/// The handler mermaid runs when the first layout stops: every edge whose
/// ends are on neither a row nor a column gets the weight and distance
/// that put a bend at the corner of its endpoints (`getSegmentWeights`).
fn bend_edges(cy : Cy) -> Unit raise ArchitectureError {
  for edge in cy.edges {
    let source = cy.nodes[edge.source]
    let target = cy.nodes[edge.target]
    if source.x == target.x || source.y == target.y {
      continue
    }
    let geometry = cy.edge_geometry(edge)
    let (sx, sy) = (geometry.start_x, geometry.start_y)
    let (tx, ty) = (geometry.end_x, geometry.end_y)
    let (point_x, point_y) = if !edge.edge.lhs_dir.is_x() {
      (sx, ty)
    } else {
      (tx, sy)
    }
    let square = (x : Double) => x * x
    let mut d = (point_y - sy + (sx - point_x) * (sy - ty) / (sx - tx)) /
      (1.0 + square((sy - ty) / (sx - tx))).sqrt()
    let mut w = (square(point_y - sy) + square(point_x - sx) - square(d)).sqrt()
    let dist_ab = (square(tx - sx) + square(ty - sy)).sqrt()
    w = w / dist_ab
    let delta1 = (tx - sx) * (point_y - sy) - (ty - sy) * (point_x - sx)
    let delta1 = if delta1 >= 0.0 {
      1.0
    } else if delta1 < 0.0 {
      -1.0
    } else {
      delta1
    }
    let delta2 = (tx - sx) * (point_x - sx) + (ty - sy) * (point_y - sy)
    let delta2 = if delta2 >= 0.0 {
      1.0
    } else if delta2 < 0.0 {
      -1.0
    } else {
      delta2
    }
    d = d.abs() * delta1
    w = w * delta2
    // cytoscape's style parser refuses a number that is not one, and fails
    // reading what it refused.
    if d.is_nan() || w.is_nan() {
      raise Invalid("Cannot read properties of null (reading 'value')")
    }
    edge.distances = d
    edge.weights = w
  }
}

///|
/// Told what each run of fcose did, to compare with upstream.
priv struct RunTracer {
  fcose : @fcose.Tracer
  /// The centre the run moved its result to, and the box it came from.
  center : (Double, Double, Box) -> Unit
}

///|
/// Lay out a diagram: the cytoscape graph with its nodes and edges where
/// mermaid reads them from.
fn layout(
  db : Db,
  config : LayoutConfig,
  tracer? : RunTracer,
) -> Cy raise ArchitectureError {
  let cy = build_cy(db, config)
  let { spatial_maps, group_alignments, } = db.data_structures()
  let (horizontal, vertical) = alignments(db, spatial_maps, group_alignments)
  let relative = relative_constraints(db, spatial_maps, config)
  if config.seed == 0.0 && (config.randomize || !relative.is_empty()) {
    raise Unsupported("architecture.seed 0: Math.random")
  }
  // fcose forgets empty lists of constraints.
  let constraints : @fcose.Constraints = {
    vertical: if vertical.is_empty() {
      None
    } else {
      Some(vertical)
    },
    horizontal: if horizontal.is_empty() {
      None
    } else {
      Some(horizontal)
    },
    relative: if relative.is_empty() {
      None
    } else {
      Some(relative)
    },
  }
  let same_group_ideal_length = config.idealEdgeLengthMultiplier *
    config.icon_size
  let cross_group_ideal_length = 0.5 * config.icon_size
  let edges = cy.edges.map(edge => {
    let a = cy.nodes[edge.source].parent
    let b = cy.nodes[edge.target].parent
    let same = a == b
    @fcose.Edge::{
      id: edge.id,
      source: cy.nodes[edge.source].id,
      target: cy.nodes[edge.target].id,
      ideal_length: if same {
        same_group_ideal_length
      } else {
        cross_group_ideal_length
      },
      elasticity: if same {
        config.edge_elasticity
      } else {
        1.0e-3
      },
    }
  })
  cy.update_all_compound_bounds()
  run_fcose(cy, edges, constraints, config, tracer)
  bend_edges(cy)
  run_fcose(cy, edges, constraints, config, tracer)
  cy
}

///|
/// `ToUint32`: `seed >>> 0`.
fn to_uint32(x : Double) -> UInt32 {
  if x.is_nan() || x.is_inf() {
    return 0
  }
  let t = if x < 0.0 { (-x).floor() * -1.0 } else { x.floor() }
  let m = t - (t / 4294967296.0).floor() * 4294967296.0
  m.to_uint64().to_uint()
}

///|
/// The configuration the layout reads, from the diagram's.
fn layout_config(config : @config.Config) -> LayoutConfig {
  let number = (name : String, default : Double) => {
    config.number("architecture.\{name}").unwrap_or(default)
  }
  {
    icon_size: number("iconSize", 80.0),
    font_size: number("fontSize", 16.0),
    padding: number("padding", 40.0),
    idealEdgeLengthMultiplier: number("idealEdgeLengthMultiplier", 1.5),
    edge_elasticity: number("edgeElasticity", 0.45),
    num_iter: number("numIter", 2500.0).to_int(),
    seed: number("seed", 1.0),
    randomize: config.flag("architecture.randomize"),
    node_separation: number("nodeSeparation", 75.0),
  }
}

///|
fn point_json(x : Double, y : Double) -> Json {
  { "x": Json::number(x), "y": Json::number(y) }
}

///|
fn placed_json(nodes : Array[@fcose.Placed]) -> Json {
  Json::array(
    nodes.map(node => {
      "id": Json::string(node.id),
      "x": Json::number(node.x),
      "y": Json::number(node.y),
      "width": Json::number(node.width),
      "height": Json::number(node.height),
    }),
  )
}

///|
/// What the renderer reads from cytoscape once the layout is done, as
/// scripts/fcose_oracle.js reports it: node positions, group boxes, edge
/// endpoints and midpoints; with `trace`, every run of fcose step by step.
pub fn layout_report(
  source : String,
  config : @config.Config,
  trace~ : Bool = false,
) -> Json raise {
  let db = parse(source)
  let runs : Array[Map[String, Json]] = []
  let tracer : RunTracer = {
    fcose: {
      start: nodes => runs.push({ "start": placed_json(nodes), "ticks": [] }),
      enforced: nodes => {
        runs[runs.length() - 1]["enforced"] = placed_json(nodes)
      },
      tick: nodes => {
        if runs[runs.length() - 1].get("ticks") is Some(Array(ticks)) {
          ticks.push(placed_json(nodes))
        }
      },
    },
    center: (x, y, _) => runs[runs.length() - 1]["center"] = point_json(x, y),
  }
  let cy = layout(db, layout_config(config), tracer~)
  let nodes = cy.nodes.map(node => {
    let out : Map[String, Json] = {
      "id": Json::string(node.id),
      "x": Json::number(node.x),
      "y": Json::number(node.y),
    }
    if node.kind is CyGroup {
      let box = cy.node_box(node)
      out["x1"] = Json::number(box.x1)
      out["y1"] = Json::number(box.y1)
      out["w"] = Json::number(box.w)
      out["h"] = Json::number(box.h)
    }
    Json::object(out)
  })
  let edges = cy.edges.map(edge => {
    let geometry = cy.edge_geometry(edge)
    let out : Json = {
      "id": Json::string(edge.id),
      "source": point_json(geometry.start_x, geometry.start_y),
      "mid": point_json(geometry.mid_x, geometry.mid_y),
      "target": point_json(geometry.end_x, geometry.end_y),
    }
    out
  })
  let report : Map[String, Json] = {
    "nodes": Json::array(nodes),
    "edges": Json::array(edges),
  }
  if trace {
    for run in runs {
      // The trace keeps the final positions, as upstream's does.
      if run.get("ticks") is Some(Array(ticks)) && ticks.length() > 0 {
        run["final"] = ticks[ticks.length() - 1]
      }
    }
    report["runs"] = Json::array(runs.map(Json::object))
  }
  Json::object(report)
}

///|
/// The cytoscape graph as the spectral layout reads it.
fn spectral_graph(cy : Cy) -> @fcose.SpectralGraph {
  let edges = cy.edges.map(edge => (edge.source, edge.target))
  {
    nodes: cy.nodes.map(node => {
      let index = cy.by_id[node.id]
      let connected = []
      for i, edge in edges {
        if edge.0 == index || edge.1 == index {
          connected.push(i)
        }
      }
      {
        id: node.id,
        parent: node.parent.map(parent => cy.by_id[parent]),
        children: node.children,
        x: node.x,
        y: node.y,
        width: cy.width(node),
        height: cy.height(node),
        outer_width: cy.outer_width(node),
        edges: connected,
      }
    }),
    edges,
  }
}

///|
/// The nodes as fcose builds them from a spectral layout: the leaves
/// around their spectral positions, compound nodes around their leaves
/// (`calcBoundingBox`, by their inner sizes).
fn spectral_nodes(
  cy : Cy,
  indexes : Array[Int32],
  spectral : @fcose.SpectralResult,
) -> Array[@fcose.Node] {
  let leaves_of = (index : Int32) => {
    let out = []
    fn add(children : Array[Int32]) -> Unit {
      for child in children {
        if !cy.is_parent(cy.nodes[child]) {
          out.push(child)
        }
        add(cy.nodes[child].children)
      }
    }

    add(cy.nodes[index].children)
    out
  }
  let coordinate = (coords : Array[Double], id : String) => {
    match spectral.indexes.get(id) {
      Some(i) => coords[i]
      None => @double.not_a_number
    }
  }
  indexes.map(index => {
    let node = cy.nodes[index]
    let mut w = cy.outer_width(node)
    let mut h = cy.outer_height(node)
    if w == 0.0 || h == 0.0 {
      w = 1.0
      h = 1.0
    }
    let (x, y, width, height) = if cy.is_parent(node) {
      let mut left = 9007199254740991.0
      let mut right = -9007199254740991.0
      let mut top = 9007199254740991.0
      let mut bottom = -9007199254740991.0
      for leaf in leaves_of(index) {
        let n = cy.nodes[leaf]
        let x = coordinate(spectral.x, n.id)
        let y = coordinate(spectral.y, n.id)
        let node_left = x - cy.width(n) / 2.0
        let node_right = x + cy.width(n) / 2.0
        let node_top = y - cy.height(n) / 2.0
        let node_bottom = y + cy.height(n) / 2.0
        if left > node_left {
          left = node_left
        }
        if right < node_right {
          right = node_right
        }
        if top > node_top {
          top = node_top
        }
        if bottom < node_bottom {
          bottom = node_bottom
        }
      }
      (left, top, right - left, bottom - top)
    } else {
      (
        coordinate(spectral.x, node.id) - w / 2.0,
        coordinate(spectral.y, node.id) - h / 2.0,
        w,
        h,
      )
    }
    @fcose.Node::{
      id: node.id,
      x,
      y,
      width,
      height,
      padding: cy.node_padding(node).to_int().to_double(),
      repulsion: 4500.0,
      children: spectral_nodes(cy, node.children, spectral),
    }
  })
}
