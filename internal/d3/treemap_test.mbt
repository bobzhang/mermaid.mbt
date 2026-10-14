///|
/// A tree as nested arrays: a leaf is its value.
priv enum Tree {
  Leaf(Double)
  Branch(Array[Tree])
}

///|
/// The boxes of all nodes, level by level, laid out as mermaid's treemap
/// diagram does: 1000 by 400, sections with a header.
fn boxes(tree : Tree) -> Array[Array[Double]] {
  let root = @d3.hierarchy(tree, node => {
    match node {
      Leaf(_) => []
      Branch(children) => children
    }
  })
  root.sum(node => {
    match node {
      Leaf(value) => value
      Branch(_) => 0.0
    }
  })
  root.sort((a, b) => b.value - a.value)
  let layout : @d3.TreemapLayout[Tree] = {
    width: 1000.0,
    height: 400.0,
    padding_inner: _ => 10.0,
    padding_top: _ => 35.0,
    padding_right: _ => 10.0,
    padding_bottom: _ => 10.0,
    padding_left: _ => 10.0,
    round: true,
  }
  layout.layout(root)
  root.descendants().map(node => [node.x0, node.y0, node.x1, node.y1])
}

///|
test "squarified treemap with paddings, as upstream lays out two sections" {
  // Category A (10, 20) and Category B (15, 25): the heavier comes first.
  json_inspect(
    boxes(
      Branch([
        Branch([Leaf(10.0), Leaf(20.0)]),
        Branch([Leaf(15.0), Leaf(25.0)]),
      ]),
    ),
    content=[
      [0, 0, 1000, 400],
      [10, 35, 566, 390],
      [576, 35, 990, 390],
      [20, 70, 351, 380],
      [361, 70, 556, 380],
      [586, 70, 845, 380],
      [855, 70, 980, 380],
    ],
  )
}

///|
test "values add up, depths and heights are set, leaves come in order" {
  let root = @d3.hierarchy(
    Branch([Leaf(1.0), Branch([Leaf(2.0), Leaf(0.5)]), Leaf(3.0)]),
    node => {
      match node {
        Leaf(_) => []
        Branch(children) => children
      }
    },
  )
  root.sum(node => {
    match node {
      Leaf(value) => value
      Branch(_) => 0.0
    }
  })
  inspect(root.value, content="6.5")
  inspect(root.height, content="2")
  json_inspect(root.descendants().map(node => node.depth), content=[
    0, 1, 1, 1, 2, 2,
  ])
  json_inspect(root.leaves().map(node => node.value), content=[1, 2, 0.5, 3])
}
