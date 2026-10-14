///|
/// The tree as an outline: one node per line, indented by depth, with its
/// annotations.
fn outline(source : String) -> String raise {
  let out = StringBuilder()
  fn visit(node : @treeview.Node, depth : Int32) -> Unit {
    out.write_string("  ".repeat(depth))
    out.write_string(node.name)
    if node.directory {
      out.write_string("/")
    }
    if node.css_class is Some(css_class) {
      out.write_string(" class=\{css_class}")
    }
    if node.icon is Some(icon) {
      out.write_string(" icon=\{icon}")
    }
    if node.description is Some(description) {
      out.write_string(" desc=\{description}")
    }
    out.write_string("\n")
    for child in node.children {
      visit(child, depth + 1)
    }
  }

  visit(@treeview.parse(source).root, 0)
  out.to_string()
}

///|
test "indentation alone decides the parent" {
  let source =
    #|treeView-beta
    #|    a/
    #|        b
    #|      c
    #|   d
    #|            e
    #|f
    #|
  inspect(
    outline(source),
    content=(
      #|//
      #|  a/
      #|    b
      #|    c
      #|  d
      #|    e
      #|  f
      #|
    ),
  )
}

///|
test "annotations in any order, the last of each kind counting" {
  let source =
    #|treeView-beta
    #|    "my file" icon(a:b) :::one :::two ## first ## second :::three
    #|    name with  spaces   icon()   ##   trimmed
    #|    dir/ icon(none)
    #|    'quoted/' ##
    #|
  inspect(
    outline(source),
    content=(
      #|//
      #|  my file class=two icon=a:b desc=first ## second :::three
      #|  name with  spaces icon=none desc=trimmed
      #|  dir/ icon=none
      #|  quoted/
      #|
    ),
  )
}

///|
test "box-drawing prefixes become indentation" {
  let source =
    #|treeView-beta
    #|├── src/
    #|│   ├── index.ts ## entry
    #|│
    #|│   └── utils.ts
    #|┣━━ package.json
    #|┗━━ docs/
    #|    ┗━━ guide.md
    #|top.txt
    #|
  inspect(
    outline(source),
    content=(
      #|//
      #|  src/
      #|    index.ts desc=entry
      #|    utils.ts
      #|  package.json
      #|  docs/
      #|    guide.md
      #|  top.txt
      #|
    ),
  )
}

///|
test "title and accessibility lines come before the nodes" {
  let tree = @treeview.parse(
    (
      #|treeView-beta
      #|    title Ignored   title
      #|    accTitle: The   title
      #|    accDescr {
      #|        Two lines
      #|          of   text
      #|    }
      #|    a
      #|
    ),
  )
  inspect(tree.acc_title, content="The title")
  inspect(tree.acc_description, content="Two lines\nof text")
  // `title` is a terminal of its own, so a name starting with it loses it.
  inspect(
    outline("treeView-beta\n    title.txt\n"),
    content=(
      #|//
      #|  .txt
      #|
    ),
  )
}

///|
test "what the lexer and the grammar refuse" {
  let rejected = (source : String) => {
    try @treeview.parse(source) catch {
      _ => true
    } noraise {
      _ => false
    }
  }
  // Blanks that no terminal swallows are an INDENTATION token, and two of
  // them cannot follow each other.
  inspect(rejected("treeView-beta\n    a\n    \n    b\n"), content="true")
  inspect(rejected("treeView-beta\n    \"a\" \n    b\n"), content="true")
  // The keyword must stand alone, and is not a name.
  inspect(rejected("treeView-beta   \n    a\n"), content="true")
  inspect(rejected("treeView-beta\n    treeView-beta\n"), content="true")
  inspect(rejected("treeView-beta\n    treeView-beta.md\n"), content="false")
  // Annotations need a name before them and a complete form.
  inspect(rejected("treeView-beta\n    ## alone\n"), content="true")
  inspect(rejected("treeView-beta\n    a icon(pack:)\n"), content="true")
  inspect(rejected("treeView-beta\n    a\n    title late\n"), content="true")
  // Box-drawing input: no indentation without a branch, no empty node.
  inspect(rejected("treeView-beta\n├── a/\n    b\n"), content="true")
  inspect(
    rejected("treeView-beta\n├── a/\n│   └── \n"),
    content="true",
  )
}
