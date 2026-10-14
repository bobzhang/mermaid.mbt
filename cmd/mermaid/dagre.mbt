///|
/// Lay out the graphs of each file (one graph, or an array of them) and
/// print one result a line, like scripts/dagre_oracle.js.
fn dagre(paths : ArrayView[String]) -> Unit raise CliError {
  for path in paths {
    let graphs = match read_json(path) {
      Array(graphs) => graphs
      graph => [graph]
    }
    for graph in graphs {
      let result = @dagre.layout_json(graph) catch {
        @dagre.LayoutError(message) => {
          let report : Json = { "error": message }
          report
        }
      }
      println(result.stringify())
    }
  }
}
