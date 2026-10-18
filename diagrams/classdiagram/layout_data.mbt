///|
/// The marker a relation end is drawn with: `getArrowMarker`.
fn arrow_marker(kind : Int32?) -> String {
  match kind {
    Some(0) => "aggregation"
    Some(1) => "extension"
    Some(2) => "composition"
    Some(3) => "dependency"
    Some(4) => "lollipop"
    _ => "none"
  }
}

///|
/// The nearest namespace at or above `id` that the source declares, for
/// the compact rendering of namespaces: `resolveExplicitAncestor`.
fn ClassDb::explicit_ancestor(self : ClassDb, id : String?) -> String? {
  let mut current = id
  while current is Some(id) {
    guard self.namespaces.get(id) is Some(found) else { return None }
    if found.explicit {
      return current
    }
    current = found.parent
  }
  None
}

///|
/// The nodes and edges to lay out: mermaid's `ClassDB.getData`.
fn ClassDb::layout_data(
  self : ClassDb,
) -> (Array[@rendering.Node], Array[@rendering.Edge]) raise ClassError {
  let config = self.config
  let look = config.text("look").unwrap_or("default")
  let theme = config.theme()
  // `hierarchicalNamespaces ?? true`, then taken for its truthiness.
  let hierarchical = config.get("class.hierarchicalNamespaces") is Null ||
    config.flag("class.hierarchicalNamespaces")
  let parent_of = (parent : String?) => {
    if hierarchical {
      parent
    } else {
      self.explicit_ancestor(parent)
    }
  }
  let nodes : Array[@rendering.Node] = []
  let edges : Array[@rendering.Edge] = []
  for _, found in self.namespaces {
    if !hierarchical && !found.explicit {
      continue
    }
    nodes.push(
      @rendering.Node::new(
        id=found.id,
        label=if hierarchical { found.label } else { found.id },
        padding=config.number("class.padding").unwrap_or(16.0),
        // The node has no classes, and its frame says so.
        css_classes="undefined",
        // A group must be one of the frame shapes.
        shape="rect",
        look~,
        is_group=true,
        parent_id?=if hierarchical { found.parent } else { None },
      ),
    )
  }
  // Only classes take a slot of the palette.
  let mut color_index = 0
  for _, node in self.classes {
    let lines = (members : Array[ClassMember]) => {
      members.map(line => {
        let line : @rendering.ClassBoxMember = {
          text: line.text,
          style: line.css_style(),
        }
        line
      })
    }
    nodes.push(
      @rendering.Node::new(
        id=node.id,
        label=node.label,
        parent_id?=parent_of(node.parent),
        // A class box takes its padding from the configuration.
        padding=0.0,
        css_styles=node.styles,
        css_classes=node.css_classes,
        dom_id=node.dom_id,
        look~,
        shape="classBox",
        color_index~,
        link?=node.link,
        link_target?=node.link_target,
        tooltip?=node.tooltip,
        have_callback=node.have_callback,
        data=ClassBox(
          text=node.text,
          annotations=node.annotations,
          members=lines(node.members),
          methods=lines(node.methods),
        ),
      ),
    )
    color_index += 1
  }
  for _, note in self.notes {
    // The text of a note reaches the sanitizer when its label is made.
    let decoded = @dom.placeholders_to_references(note.text)
    let label = if decoded.contains("<") {
      sanitize_text(decoded)
    } else {
      note.text
    }
    nodes.push(
      @rendering.Node::new(
        id=note.id,
        label~,
        label_type="markdown",
        parent_id?=parent_of(note.parent),
        padding=config.number("class.padding").unwrap_or(6.0),
        css_classes="undefined",
        css_styles=[
          "text-align: left",
          "white-space: nowrap",
          "fill: \{theme.text("noteBkgColor")}",
          "stroke: \{theme.text("noteBorderColor")}",
        ],
        look~,
        shape="note",
      ),
    )
    if note.class_ is Some(class_name) &&
      self.classes.get(class_name) is Some(target) {
      edges.push(
        @rendering.Edge::new(
          id="edgeNote\{note.index}",
          start=note.id,
          end=target.id,
          thickness="normal",
          classes="relation",
          style=["fill: none"],
          pattern="dotted",
          look~,
        ),
      )
    }
  }
  for interface in self.interfaces {
    nodes.push(
      @rendering.Node::new(
        id=interface.id,
        label=interface.label,
        padding=0.0,
        css_classes="undefined",
        css_styles=["opacity: 0;"],
        look~,
        shape="rect",
      ),
    )
  }
  for index, relation in self.relations {
    let terminal = (title : String) => if title == "none" { "" } else { title }
    edges.push(
      @rendering.Edge::new(
        id="id_\{relation.id1}_\{relation.id2}_\{index + 1}",
        start=relation.id1,
        end=relation.id2,
        label=relation.title.unwrap_or(""),
        label_type="markdown",
        thickness="normal",
        classes="relation",
        arrow_type_start=arrow_marker(relation.type1),
        arrow_type_end=arrow_marker(relation.type2),
        start_label_right=terminal(relation.title1),
        end_label_left=terminal(relation.title2),
        // The relation has no style of its own, and says so with an
        // empty text where other diagrams pass a list.
        style=[""],
        pattern=if relation.dotted { "dashed" } else { "solid" },
        look~,
        labelpos="c",
      ),
    )
  }
  (nodes, edges)
}
