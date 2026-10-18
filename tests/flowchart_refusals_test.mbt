///|
test "flowcharts the port refuses rather than draw differently" {
  // Label styles that change how the text lays out, and so the size of
  // the node upstream measures with them.
  inspect(
    refusal("flowchart TD\nA((AA))\nstyle A letter-spacing:10px\n"),
    content="Unsupported: the label style `letter-spacing:10px` changes the label's size, which is not ported",
  )
  inspect(
    refusal("flowchart TD\nA((AA))\nstyle A font-size:2em\n"),
    content="Unsupported: the label style `font-size:2em` changes the label's size, which is not ported",
  )
  inspect(
    refusal("flowchart TD\nclassDef c text-transform:uppercase\nA:::c --> B\n"),
    content="Unsupported: the label style `text-transform:uppercase` changes the label's size, which is not ported",
  )
  inspect(
    refusal("flowchart TD\nA -->|x| B\nlinkStyle 0 word-spacing:4px\n"),
    content="Unsupported: the label style `word-spacing:4px` changes the label's size, which is not ported",
  )
}
