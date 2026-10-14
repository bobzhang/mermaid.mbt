// The database of a block diagram: mermaid's `blockDB.ts`.

///|
/// A block diagram that cannot be built from its source.
pub(all) suberror BlockError {
  BlockError(String)
} derive(Eq, Debug)

///|
/// Everything the parser collects.
pub struct BlockDb {
  priv config : @config.Config
  /// Every block by id, in the order first seen. The key `None` is
  /// JavaScript's `undefined`.
  priv blocks : Map[String?, Block]
  priv root : Block
  priv edges : Array[Block]
  /// How many edges share an id, to tell them apart.
  priv edge_count : Map[String, Int32]
  classes : Map[String, ClassDef]
  priv mut next_color_index : Int32
  priv mut generated_ids : Int32
  /// The id of the `<svg>` element, which prefixes the ids inside it.
  priv mut diagram_id : String
}

///|
fn BlockDb::new(config : @config.Config) -> BlockDb {
  let root = Block::new(id="root", type_="composite", columns=-1.0)
  {
    config,
    blocks: Map([(Some("root"), root)]),
    root,
    edges: [],
    edge_count: Map([]),
    classes: Map([]),
    next_color_index: 0,
    generated_ids: 0,
    diagram_id: "",
  }
}

///|
/// The id of a block the text does not name: a `space`, or a composite
/// opened with a bare `block`. Upstream draws it from `Math.random()` and
/// counts over the lifetime of the page,
/// `'id-' + Math.random().toString(36).substr(2, 12) + '-' + cnt`; the
/// port takes every draw to be 0.5, whose base 36 digits are `i`, and
/// counts per diagram (see `testdata/block/oracle-prelude.js`).
fn BlockDb::generate_id(self : BlockDb) -> String {
  self.generated_ids += 1
  "id-i-\{self.generated_ids}"
}

///|
/// Markup DOMPurify removes or rewrites rather than keeps: elements it
/// drops with their content, event handlers, script addresses.
let unsafe_markup : @jsregex.Regex = try! @jsregex.Regex::compile(
  "<\\/?(script|style|iframe|object|embed|noscript|template|svg|math|video|audio|link|meta|base|form|input|textarea|select|button|title|frame|frameset|applet|xmp|plaintext|noembed|noframes)\\b|<[^>]*\\son\\w+\\s*=|javascript:",
  flags="i",
)

///|
/// mermaid's `sanitizeText`: DOMPurify leaves text without `<` alone and
/// otherwise parses it as HTML and writes it back, so that `<`, `>` and
/// `&` in plain text come out as character references. Markup it would
/// take out is refused instead.
fn sanitize_text(text : String) -> String raise BlockError {
  if !text.contains("<") {
    return text
  }
  if unsafe_markup.exec(text) is Some(_) {
    raise BlockError("Markup that is sanitized away is not supported: \{text}")
  }
  let holder = @dom.Element::new("div")
  holder.set_inner_html(text)
  let html = holder.to_html()
  guard html.strip_prefix("<div>") is Some(rest) &&
    rest.strip_suffix("</div>") is Some(inner) else {
    return text
  }
  inner.to_owned()
}

///|
/// `attrib.replace(/([^;]*);/, '$1').trim()`: drop the first semicolon.
fn drop_first_semicolon(attribute : String) -> String {
  attribute.replace(old=";", new="").trim().to_owned()
}

///|
/// Define a style class or add to it: `classDef my-style fill:#f96;`.
fn BlockDb::add_style_class(
  self : BlockDb,
  id : String,
  style_attributes : String,
) -> Unit {
  let found = match self.classes.get(id) {
    Some(found) => found
    None => {
      let found = { id, styles: [], text_styles: [], }
      self.classes[id] = found
      found
    }
  }
  for attribute in style_attributes.split(",") {
    let attribute = attribute.to_owned()
    let fixed = drop_first_semicolon(attribute)
    if attribute.contains("color") {
      found.text_styles.push(
        fixed.replace(old="fill", new="bgFill").replace(old="color", new="fill"),
      )
    }
    found.styles.push(fixed)
  }
}

///|
/// Style one block: `style my-block-id fill:#f96;`.
fn BlockDb::add_style_to_node(
  self : BlockDb,
  id : String,
  styles : String,
) -> Unit raise BlockError {
  guard self.blocks.get(Some(id)) is Some(found) else {
    // Upstream fails on the block it did not find.
    raise BlockError("Cannot set properties of undefined (setting 'styles')")
  }
  found.styles = styles.split(",").map(style => style.to_owned()).collect()
}

///|
/// Give the blocks named in `item_ids` a class. A name that is not a
/// block's becomes one, in the database but not in the diagram.
fn BlockDb::set_css_class(
  self : BlockDb,
  item_ids : String,
  class_name : String,
) -> Unit {
  for id in item_ids.split(",") {
    let id = id.to_owned()
    let found = match self.blocks.get(Some(id)) {
      Some(found) => found
      None => {
        let trimmed = js_trim(id)
        let found = Block::new(id=trimmed, type_="na")
        self.blocks[Some(trimmed)] = found
        found
      }
    }
    found.classes.push(class_name)
  }
}

///|
/// A copy of a block that shares nothing mutable with it, as lodash's
/// shallow `clone` of a `space` block.
fn Block::clone_as(self : Block, id : String) -> Block {
  {
    ..self,
    id: Some(id),
    classes: self.classes.copy(),
    styles: self.styles.copy(),
  }
}

///|
/// Sort the statements of one level into the database and return what
/// that level draws: mermaid's `populateBlockDatabase`, which assigns the
/// result to `parent.children`.
fn BlockDb::populate(
  self : BlockDb,
  block_list : Array[Block],
  parent : Block,
) -> Unit raise BlockError {
  let children = []
  for block in block_list {
    if block.label is Some(label) && label != "" {
      block.label = Some(sanitize_text(label))
    }
    match block.type_ {
      Some("classDef") => {
        self.add_style_class(block.id_text(), block.css)
        continue
      }
      Some("applyClass") => {
        self.set_css_class(block.id_text(), block.style_class)
        continue
      }
      Some("applyStyles") => {
        if block.styles_str != "" {
          self.add_style_to_node(block.id_text(), block.styles_str)
        }
        continue
      }
      Some("column-setting") => {
        parent.columns = Some(block.columns.unwrap_or(-1.0))
        continue
      }
      Some("edge") => {
        let id = block.id_text()
        let count = self.edge_count.get(id).unwrap_or(0) + 1
        self.edge_count[id] = count
        block.id = Some("\{count}-\{id}")
        self.edges.push(block)
        continue
      }
      _ => ()
    }
    if block.label is (None | Some("")) {
      block.label = if block.type_ == Some("composite") {
        Some("")
      } else {
        block.id
      }
    }
    let existing = self.blocks.get(block.id)
    match existing {
      None => {
        // Before the children, so that an outer composite takes a lower
        // slot than any composite inside it.
        if block.type_ == Some("composite") {
          block.color_index = Some(self.next_color_index)
          self.next_color_index += 1
        }
        self.blocks[block.id] = block
      }
      Some(existing) => {
        // Add newer relevant data to the aggregated block.
        if block.type_ != Some("na") {
          existing.type_ = block.type_
        }
        if block.label != block.id {
          existing.label = block.label
        }
      }
    }
    // Only composites and spaces have children to sort; for any other
    // block this leaves none, as before.
    self.populate(block.children, block)
    if block.type_ == Some("space") {
      let width = block.space_width.unwrap_or(1.0)
      let mut j = 0
      while j.to_double() < width {
        let clone = block.clone_as("\{block.id_text()}-\{j}")
        self.blocks[clone.id] = clone
        children.push(clone)
        j += 1
      }
    } else if existing is None {
      children.push(block)
    }
  }
  parent.children = children
}

///|
/// Take the statements of the diagram: mermaid's `setHierarchy`.
fn BlockDb::set_hierarchy(
  self : BlockDb,
  blocks : Array[Block],
) -> Unit raise BlockError {
  self.root.children = blocks
  self.populate(blocks, self.root)
}

///|
fn BlockDb::get_block(self : BlockDb, id : String?) -> Block? {
  self.blocks.get(id)
}

///|
/// `'[]'`, `'()'`, ... to the type of block the brackets draw.
fn type_of_brackets(type_str : String?) -> String {
  match type_str {
    Some("[]") => "square"
    Some("()") => "round"
    Some("(())") => "circle"
    Some(">]") => "rect_left_inv_arrow"
    Some("{}") => "diamond"
    Some("{{}}") => "hexagon"
    Some("([])") => "stadium"
    Some("[[]]") => "subroutine"
    Some("[()]") => "cylinder"
    Some("((()))") => "doublecircle"
    Some("[//]") => "lean_right"
    Some("[\\\\]") => "lean_left"
    Some("[/\\]") => "trapezoid"
    Some("[\\/]") => "inv_trapezoid"
    Some("<[]>") => "block_arrow"
    _ => "na"
  }
}

///|
/// JavaScript's `String.prototype.trim`.
fn js_trim(text : String) -> String {
  text
  .trim(
    chars=" \t\n\r\u{000b}\u{000c}\u{00a0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}",
  )
  .to_owned()
}

///|
/// The arrow at the end of a link, from its last character.
fn edge_end_type(link : String) -> String {
  let link = js_trim(link)
  match link.get_char(link.length() - 1) {
    Some('x') => "arrow_cross"
    Some('o') => "arrow_circle"
    Some('>') => "arrow_point"
    _ => ""
  }
}

///|
/// The arrow at the start of a link, from its first character.
fn edge_start_type(link : String) -> String {
  match js_trim(link).get_char(0) {
    Some('x') => "arrow_cross"
    Some('o') => "arrow_circle"
    Some('<') => "arrow_point"
    _ => "arrow_open"
  }
}

///|
fn edge_thickness(link : String) -> String {
  if link.contains("==") {
    "thick"
  } else {
    "normal"
  }
}

///|
fn edge_pattern(link : String) -> String {
  if link.contains(".-") {
    "dotted"
  } else {
    "solid"
  }
}
