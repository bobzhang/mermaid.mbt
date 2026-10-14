///|
/// A feature the port does not reproduce exactly.
pub(all) suberror Unsupported {
  Unsupported(String)
} derive(Eq, Debug)

///|
/// The effect or one of its causes.
pub struct Node {
  text : String
  children : Array[Node]
}

///|
/// A parsed Ishikawa (fishbone) diagram: the effect — the first line of
/// the text — with the tree of its causes.
pub struct Ishikawa {
  /// Nothing when the text holds no line but the keyword's.
  mut root : Node?
  /// The path from the root to the node added last, with levels.
  priv mut stack : Array[(Int32, Node)]
  /// The indentation of the first cause, which the others are relative to.
  priv mut base_level : Int32?
}

///|
fn Ishikawa::new() -> Ishikawa {
  { root: None, stack: [], base_level: None, }
}

///|
/// Add the effect, or a cause under the closest cause before it that is
/// indented less.
fn Ishikawa::add_node(
  self : Ishikawa,
  raw_level : Int32,
  text : String,
) -> Unit raise {
  let label = @journeycommon.sanitize_text(text) catch {
    @journeycommon.SanitizeError(message) => raise Unsupported(message)
  }
  guard self.root is Some(_) else {
    let root = { text: label, children: [], }
    self.root = Some(root)
    self.stack = [(0, root)]
    return
  }
  // The level of the first cause counts as 1 however the effect's line is
  // indented, so that causes keep their indentation relative to it.
  let base_level = match self.base_level {
    Some(level) => level
    None => {
      self.base_level = Some(raw_level)
      raw_level
    }
  }
  let mut level = raw_level - base_level + 1
  if level <= 0 {
    level = 1
  }
  while self.stack.length() > 1 &&
        self.stack[self.stack.length() - 1].0 >= level {
    self.stack.pop() |> ignore
  }
  let node = { text: label, children: [], }
  self.stack[self.stack.length() - 1].1.children.push(node)
  self.stack.push((level, node))
}
