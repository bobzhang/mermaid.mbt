// The hand-drawn look draws each entity twice: first a copy in the
// background colour, then the entity itself once that copy is done.
// Upstream inserts all nodes at once (`Promise.all`), so every copy comes
// first, and the entities follow in the order their copies finish: the
// fewer attributes a copy has to lay out, the sooner.

///|
/// Put the entities of the hand-drawn look in the order upstream's
/// concurrent drawing leaves them in: the background copies in node order,
/// then the entities by their number of attributes, ties in node order.
fn order_hand_drawn_entities(svg : @dom.Element) -> Unit {
  for group in groups_of_class(svg, "nodes") {
    // Other children (the nested drawing of a subgraph under dagre)
    // keep their places.
    let children = group.child_elements()
    let slots = []
    let copies = []
    let entities = []
    for index, child in children {
      let class_name = child.get_attr("class").unwrap_or("")
      guard class_name.has_prefix("node ") ||
        class_name.has_prefix("rough-node ") else {
        continue
      }
      slots.push(index)
      if child.get_attr("id").unwrap_or("").contains("-background") {
        copies.push(child)
      } else {
        entities.push((attribute_count(child), entities.length(), child))
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
    let ordered = [..copies, ..entities.map(entity => entity.2)]
    for child in children {
      child.remove()
    }
    let mut next = 0
    for index, child in children {
      if next < slots.length() && slots[next] == index {
        group.append_child(ordered[next])
        next += 1
      } else {
        group.append_child(child)
      }
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
