// The layouts of whole graphs are checked against dagre itself by
// scripts/check_dagre.py over the corpus in testdata/dagre; the graph here
// pins one of them: a compound node, a labelled edge, a cycle and a self
// edge.

///|
test "a graph with a compound node, a cycle and a self edge" {
  let input : Json = {
    "graph": {
      "rankdir": "TB",
      "nodesep": 50,
      "ranksep": 50,
      "marginx": 8,
      "marginy": 8,
    },
    "nodes": [
      { "id": "a", "width": 100, "height": 40 },
      { "id": "b", "width": 80, "height": 40 },
      { "id": "c", "width": 60, "height": 30, "parent": "p" },
      { "id": "p" },
    ],
    "edges": [
      {
        "v": "a",
        "w": "b",
        "name": "e1",
        "minlen": 1,
        "width": 20,
        "height": 10,
        "labelpos": "c",
      },
      { "v": "a", "w": "c", "name": "e2" },
      { "v": "c", "w": "a", "name": "e3" },
      { "v": "b", "w": "b", "name": "e4" },
    ],
  }
  json_inspect(@dagre.layout_json(input), content={
    "width": 311,
    "height": 206,
    "nodes": [
      { "id": "a", "x": 205.5, "y": 28, "width": 100, "height": 40 },
      { "id": "b", "x": 48, "y": 153, "width": 80, "height": 40 },
      { "id": "c", "x": 218, "y": 153, "width": 60, "height": 30 },
      { "id": "p", "x": 218, "y": 153, "width": 130, "height": 90 },
    ],
    "edges": [
      {
        "v": "a",
        "w": "b",
        "name": "e1",
        "points": [
          { "x": 155.5, "y": 43.87301587301587 },
          { "x": 48, "y": 78 },
          { "x": 48, "y": 108 },
          { "x": 48, "y": 133 },
        ],
        "x": 48,
        "y": 78,
      },
      {
        "v": "a",
        "w": "c",
        "name": "e2",
        "points": [
          { "x": 205.5, "y": 48 },
          { "x": 205.5, "y": 78 },
          { "x": 205.5, "y": 108 },
          { "x": 213.83333333333334, "y": 138 },
        ],
      },
      {
        "v": "c",
        "w": "a",
        "name": "e3",
        "points": [
          { "x": 225.5, "y": 138 },
          { "x": 240.5, "y": 108 },
          { "x": 240.5, "y": 78 },
          { "x": 219.5, "y": 48 },
        ],
      },
      {
        "v": "b",
        "w": "b",
        "name": "e4",
        "points": [
          { "x": 88, "y": 141 },
          { "x": 114.66666666666666, "y": 133 },
          { "x": 121.33333333333334, "y": 133 },
          { "x": 128, "y": 153 },
          { "x": 121.33333333333334, "y": 173 },
          { "x": 114.66666666666666, "y": 173 },
          { "x": 88, "y": 165 },
        ],
        "x": 138,
        "y": 153,
      },
    ],
  })
}

///|
test "an edge at a node that has children fails" {
  let input : Json = {
    "nodes": [{ "id": "a" }, { "id": "c", "parent": "p" }, { "id": "p" }],
    "edges": [{ "v": "a", "w": "p" }],
  }
  try @dagre.layout_json(input) catch {
    @dagre.LayoutError(message) =>
      inspect(
        message,
        content="the edge from a to p is at a node that has children",
      )
  } noraise {
    _ => fail("expected an error")
  }
}
