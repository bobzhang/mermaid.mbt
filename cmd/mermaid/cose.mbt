///|
/// `cose [--trace] <graph.json>...`: lay out each graph with the port of
/// cose-bilkent and print the positions of the nodes and the points of the
/// edges, one JSON document a line, in the format of
/// `scripts/cose_oracle.js` and `scripts/cose_corpus.py`; with `--trace`
/// also the corners of the nodes after every iteration.
fn cose(paths : ArrayView[String]) -> Unit raise CliError {
  let (trace, paths) = match paths {
    ["--trace", .. rest] => (true, rest)
    _ => (false, paths)
  }
  for path in paths {
    guard read_json(path)
      is { "nodes": Array(nodes), "edges": Array(edges), .. } else {
      raise CliError("\{path}: expected nodes and edges", status=2)
    }
    let ids : Map[String, Int32] = Map([])
    let sizes = []
    for node in nodes {
      guard node
        is {
          "id": String(id),
          "width": Number(width, ..),
          "height": Number(height, ..),
          ..
        } else {
        raise CliError("\{path}: a node needs id, width and height", status=2)
      }
      ids[id] = sizes.length()
      sizes.push((width, height))
    }
    let pairs = []
    let edge_ids = []
    for edge in edges {
      guard edge
        is {
          "id": String(id),
          "source": String(source),
          "target": String(target),
          ..
        } &&
        ids.get(source) is Some(source) &&
        ids.get(target) is Some(target) else {
        raise CliError("\{path}: an edge needs id, source and target", status=2)
      }
      pairs.push((source, target))
      edge_ids.push(id)
    }
    let ticks = []
    let on_tick = if trace {
      Some((corners : Array[(Double, Double)]) => {
        ticks.push(
          Json::array(
            corners.map(corner => {
              Json::array([Json::number(corner.0), Json::number(corner.1)])
            }),
          ),
        )
      })
    } else {
      None
    }
    let positions = @cose.layout(sizes, pairs, on_tick?) catch {
      Unsupported(message) => raise CliError("\{path}: \{message}", status=1)
    }
    let out_nodes = []
    for id, index in ids {
      out_nodes.push(
        Json::object({
          "id": Json::string(id),
          "x": Json::number(positions[index].0),
          "y": Json::number(positions[index].1),
        }),
      )
    }
    let out_edges = []
    for i, pair in pairs {
      let object : Map[String, Json] = { "id": Json::string(edge_ids[i]) }
      if @cose.straight_edge(positions[pair.0], positions[pair.1])
        is Some([start, mid, end]) {
        object["startX"] = Json::number(start.0)
        object["startY"] = Json::number(start.1)
        object["midX"] = Json::number(mid.0)
        object["midY"] = Json::number(mid.1)
        object["endX"] = Json::number(end.0)
        object["endY"] = Json::number(end.1)
      }
      out_edges.push(Json::object(object))
    }
    let out : Map[String, Json] = {
      "nodes": Json::array(out_nodes),
      "edges": Json::array(out_edges),
    }
    if trace {
      out["ticks"] = Json::array(ticks)
    }
    println(Json::object(out).stringify())
  }
}
