///|
/// A movement between two domains, drawn as an arrow.
pub struct Transition {
  from : String
  to : String
  label : String?
}

///|
/// A parsed Cynefin diagram: the items of each domain and the transitions
/// between domains.
pub struct Cynefin {
  /// Domain name (`complex`, `complicated`, `clear`, `chaotic`,
  /// `confusion`) to the labels of its items. A domain declared again
  /// replaces its earlier block.
  domains : Map[String, Array[String]]
  transitions : Array[Transition]
  mut title : String
  mut acc_title : String
  mut acc_description : String
}

///|
fn Cynefin::new() -> Cynefin {
  {
    domains: Map([]),
    transitions: [],
    title: "",
    acc_title: "",
    acc_description: "",
  }
}

///|
fn Cynefin::set_domain(
  self : Cynefin,
  name : String,
  items : Array[String],
) -> Unit {
  self.domains[name] = items
}

///|
/// A transition from a domain to itself means nothing and is dropped; an
/// empty label is no label.
fn Cynefin::add_transition(
  self : Cynefin,
  from : String,
  to : String,
  label : String?,
) -> Unit {
  if from == to {
    return
  }
  self.transitions.push({ from, to, label: label.filter(text => text != ""), })
}

///|
/// The same diagram under another title.
pub fn Cynefin::set_title(
  self : Cynefin,
  title : String,
) -> Unit raise Unsupported {
  self.title = sanitized(title)
}
