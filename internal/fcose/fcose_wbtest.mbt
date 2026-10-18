///|
test "the seeded Math.random of mermaid's withSeededRandom" {
  let random : Random = { state: 1, }
  inspect(random.next(), content="0.6270739405881613")
  inspect(random.next(), content="0.002735721180215478")
  inspect(random.next(), content="0.5274470399599522")
}

///|
test "a relative placement holds after the layout" {
  let node = (id : String) => {
    id,
    x: -40.0,
    y: -40.0,
    width: 80.0,
    height: 80.0,
    padding: 0.0,
    repulsion: 4500.0,
    children: [],
  }
  let placed = layout(
    [node("a"), node("b")],
    [
      {
        id: "a-b",
        source: "a",
        target: "b",
        ideal_length: 120.0,
        elasticity: 0.45,
      },
    ],
    {
      vertical: None,
      horizontal: Some([["a", "b"]]),
      relative: Some([Horizontal(left="a", right="b", gap=120.0)]),
    },
    { num_iter: 2500.0, seed: 1, },
  )
  let a = placed[0]
  let b = placed[1]
  assert_true(b.x - a.x >= 120.0)
  assert_eq(a.y, b.y)
}

///|
test "the singular values of a small matrix" {
  let decomposition = svd([[3.0, 0.0], [0.0, 4.0]])
  assert_eq(decomposition.s[0], 4.0)
  assert_eq(decomposition.s[1], 3.0)
}
