// The hand-drawn look draws each entity twice: first a copy in the
// background colour, then the entity itself once that copy is done.
// Upstream inserts all nodes at once (`Promise.all`), so every copy comes
// first, and the entities follow in the order their copies finish: the
// fewer attributes a copy has to lay out, the sooner.

///|
/// Put the entities of the hand-drawn look in the order upstream's
/// concurrent drawing leaves them in: everything drawn at once (the
/// background copies, the label nodes of self-loops, the nested drawing of
/// a subgraph under dagre) in node order, then the entities by their
/// number of attributes, ties in node order.
fn order_hand_drawn_entities(svg : @dom.Element) -> Unit {
  for group in groups_of_class(svg, "nodes") {
    let children = group.child_elements()
    let first = []
    let entities = []
    for child in children {
      let class_name = child.get_attr("class").unwrap_or("")
      if class_name.has_prefix("rough-node ") {
        entities.push((attribute_count(child), entities.length(), child))
      } else {
        first.push(child)
      }
    }
    entities.sort_by((a, b) => {
      let by_count = a.0.compare(b.0)
      if by_count != 0 {
        by_count
      } else {
        a.1.compare(b.1)
      }
    })
    for child in children {
      child.remove()
    }
    for child in first {
      group.append_child(child)
    }
    for entity in entities {
      group.append_child(entity.2)
    }
  }
}

///|
/// How many attributes an entity's group shows: one type label each.
fn attribute_count(entity : @dom.Element) -> Int32 {
  entity
  .child_elements()
  .filter(child => {
    child.get_attr("class").unwrap_or("").contains("attribute-type")
  })
  .length()
}

///|
/// The `<g>` elements of a class, at any depth.
fn groups_of_class(
  root : @dom.Element,
  class_name : String,
) -> Array[@dom.Element] {
  root
  .descendants(["g"])
  .filter(element => {
    element.get_attr("class").unwrap_or("").split(" ").any(c => c == class_name)
  })
}
