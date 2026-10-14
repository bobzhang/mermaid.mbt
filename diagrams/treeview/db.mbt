///|
/// A file or a directory of the tree.
pub struct Node {
  /// Its number in document order; the root is 0.
  id : Int32
  /// The width of its indentation, which is all that decides its parent.
  level : Int32
  name : String
  directory : Bool
  /// An icon reference from `icon(...)`: `pack:name`, a built-in icon
  /// (`file`, `folder`), or `none`.
  icon : String?
  css_class : String?
  description : String?
  children : Array[Node]
}

///|
/// A parsed tree view. The root `/` is not in the text but is drawn.
pub struct TreeView {
  root : Node
  /// The path from the root to the node added last.
  priv stack : Array[Node]
  priv mut count : Int32
  mut acc_title : String
  mut acc_description : String
}

///|
fn TreeView::new() -> TreeView {
  let root = {
    id: 0,
    level: -1,
    name: "/",
    directory: true,
    icon: None,
    css_class: None,
    description: None,
    children: [],
  }
  { root, stack: [root], count: 1, acc_title: "", acc_description: "", }
}

///|
/// Hang a node under the closest node before it that is indented less.
fn TreeView::add_node(
  self : TreeView,
  level : Int32,
  name : String,
  directory : Bool,
  css_class : String?,
  icon : String?,
  description : String?,
) -> Unit {
  while level <= self.stack[self.stack.length() - 1].level {
    self.stack.pop() |> ignore
  }
  let node = {
    id: self.count,
    level,
    name,
    directory,
    icon,
    css_class,
    description,
    children: [],
  }
  self.count += 1
  self.stack[self.stack.length() - 1].children.push(node)
  self.stack.push(node)
}
