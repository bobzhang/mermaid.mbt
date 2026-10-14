///|
/// Why a Venn diagram cannot be rendered.
pub(all) suberror VennError {
  /// The diagram is invalid, with upstream's message.
  Invalid(String)
  /// What the port cannot reproduce exactly and therefore refuses.
  Unsupported(String)
} derive(Eq, Debug)

///|
/// A set or the overlap of several: the sets it is made of, sorted, the
/// area it should cover and its label.
pub struct Subset {
  sets : Array[String]
  size : Double
  /// `None` where upstream has `undefined`; the pairs the renderer adds
  /// have an empty label instead.
  label : String?
} derive(Debug)

///|
/// A text placed inside a set or an overlap.
pub struct TextNode {
  sets : Array[String]
  id : String
  label : String?
} derive(Debug)

///|
/// A `style` statement: what it styles, sorted, and the properties.
pub struct StyleEntry {
  targets : Array[String]
  styles : Map[String, String]
} derive(Debug)

///|
/// A parsed Venn diagram: upstream's `vennDB`.
pub struct Venn {
  subsets : Array[Subset]
  text_nodes : Array[TextNode]
  style_entries : Array[StyleEntry]
  priv known_sets : Map[String, Unit]
  /// The sets of the last `set` or `union`, which indented `text` lines
  /// attach to.
  priv mut current_sets : Array[String]?
  /// Whether an indented `text` line continues the statement before it.
  priv mut indent_mode : Bool
  /// The lexer's `yy.consumeIndentText`: the `text` keyword after an
  /// indentation that was a token itself is dropped.
  priv mut consume_indent_text : Bool
  mut title : String
  acc_title : String
  acc_description : String
}

///|
fn Venn::new() -> Venn {
  {
    subsets: [],
    text_nodes: [],
    style_entries: [],
    known_sets: Map([]),
    current_sets: None,
    indent_mode: false,
    consume_indent_text: false,
    title: "",
    acc_title: "",
    acc_description: "",
  }
}

///|
/// Give the diagram a title, as its frontmatter does.
pub fn Venn::set_title(self : Venn, title : String) -> Unit {
  self.title = title
}

///|
/// `String.prototype.trim`.
fn js_trim(text : StringView) -> String {
  let chars = text.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && @diagram.is_js_space(chars[start]) {
    start += 1
  }
  while end > start && @diagram.is_js_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
/// Upstream's `normalizeText`: trimmed, and without the double quotes
/// around it if it has them.
fn normalize_text(text : String) -> String {
  let trimmed = js_trim(text)
  if trimmed.length() >= 2 &&
    trimmed.has_prefix("\"") &&
    trimmed.has_suffix("\"") {
    trimmed[1:trimmed.length() - 1].to_owned()
  } else {
    trimmed
  }
}

///|
/// The order of `Array.prototype.sort` without a comparator: by UTF-16
/// code units.
fn compare_code_units(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let x = a.code_unit_at(i).to_int()
    let y = b.code_unit_at(i).to_int()
    if x != y {
      return x - y
    }
  }
  a.length() - b.length()
}

///|
/// The identifiers normalized and sorted, as every statement stores them.
fn sorted_identifiers(identifiers : Array[String]) -> Array[String] {
  let sets = identifiers.map(normalize_text)
  @d3.js_sort(sets, (a, b) => compare_code_units(a, b).to_double())
  sets
}

///|
/// A label as the statements store it: nothing when it is empty.
fn normalized_label(label : String?) -> String? {
  match label {
    Some(label) if label != "" => Some(normalize_text(label))
    _ => None
  }
}

///|
/// `addSubsetData`: without a size a set covers 10, the overlap of two a
/// quarter of that, of three a ninth, ...
fn Venn::add_subset(
  self : Venn,
  identifiers : Array[String],
  label : String?,
  size : Double?,
) -> Unit {
  let sets = sorted_identifiers(identifiers)
  let count = identifiers.length().to_double()
  let size = size.unwrap_or(10.0 / (count * count))
  self.current_sets = Some(sets)
  if sets.length() == 1 {
    self.known_sets[sets[0]] = ()
  }
  self.subsets.push({ sets, size, label: normalized_label(label), })
}

///|
/// `addTextData`
fn Venn::add_text(
  self : Venn,
  identifiers : Array[String],
  id : String,
  label : String?,
) -> Unit {
  self.text_nodes.push({
    sets: sorted_identifiers(identifiers),
    id: normalize_text(id),
    label: normalized_label(label),
  })
}

///|
/// `addStyleData`: of a property given twice the last value stands.
fn Venn::add_style(
  self : Venn,
  identifiers : Array[String],
  fields : Array[(String, String)],
) -> Unit {
  let styles : Map[String, String] = Map([])
  for field in fields {
    let (key, value) = field
    // `normalizeStyleValue(value) ?? value`: an empty value stays empty.
    styles[key] = if value == "" { value } else { normalize_text(value) }
  }
  self.style_entries.push({ targets: sorted_identifiers(identifiers), styles, })
}

///|
/// `validateUnionIdentifiers`: a union is of sets declared before it.
fn Venn::validate_union(
  self : Venn,
  identifiers : Array[String],
) -> Unit raise VennError {
  let unknown = identifiers
    .map(normalize_text)
    .filter(identifier => !self.known_sets.contains(identifier))
  if unknown.length() > 0 {
    raise Invalid("unknown set identifier: \{unknown.join(", ")}")
  }
}
