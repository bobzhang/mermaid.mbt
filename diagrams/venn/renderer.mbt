///|
/// Upstream's `ensurePairwiseSubsets`: the layout needs the overlap of
/// every two sets of a union of three or more, so those not declared are
/// added — a quarter of the smaller set, or 2.5 when a size is unknown.
fn ensure_pairwise_subsets(subsets : Array[Subset]) -> Array[Area] {
  let existing_keys : Map[String, Unit] = Map([])
  let individual_sizes : Map[String, Double] = Map([])
  for subset in subsets {
    existing_keys[sorted_copy(subset.sets).join("|")] = ()
    if subset.sets.length() == 1 {
      individual_sizes[subset.sets[0]] = subset.size
    }
  }
  let areas : Array[Area] = subsets.map(subset => {
    sets: subset.sets,
    size: subset.size,
    label: subset.label,
  })
  for subset in subsets {
    if subset.sets.length() < 3 {
      continue
    }
    let members = sorted_copy(subset.sets)
    for i in 0..<(members.length() - 1) {
      for j in (i + 1)..<members.length() {
        let key = "\{members[i]}|\{members[j]}"
        if !existing_keys.contains(key) {
          existing_keys[key] = ()
          let size = match
            (individual_sizes.get(members[i]), individual_sizes.get(members[j])) {
            (Some(a), Some(b)) => js_min(a, b) / 4.0
            _ => 2.5
          }
          areas.push({ sets: [members[i], members[j]], size, label: Some(""), })
        }
      }
    }
  }
  areas
}

///|
/// `[...sets].sort()`
fn sorted_copy(sets : Array[String]) -> Array[String] {
  let copy = sets.copy()
  @d3.js_sort(copy, (a, b) => compare_code_units(a, b).to_double())
  copy
}

///|
/// The styles of the `style` statements by what they style: upstream's
/// `buildStyleByKey`. Later statements for the same target add to and
/// replace the properties of earlier ones.
fn style_by_key(
  entries : Array[StyleEntry],
) -> Map[String, Map[String, String]] {
  let map : Map[String, Map[String, String]] = Map([])
  for entry in entries {
    let key = entry.targets.join("|")
    let styles = match map.get(key) {
      Some(styles) => styles
      None => {
        let styles = Map([])
        map[key] = styles
        styles
      }
    }
    for name, value in entry.styles {
      styles[name] = value
    }
  }
  map
}

///|
/// A variable as a template literal writes it; `None` when it is not
/// set.
fn variable(theme : @theme.Theme, name : String) -> String? {
  match theme.get(name) {
    String(text) => Some(text)
    Number(number, ..) => Some(@dom.number(number))
    _ => None
  }
}

///|
/// Whether text is a number as the grammar's `NUMERIC` writes one.
fn is_plain_number(text : String) -> Bool {
  let chars = text.to_array()
  let mut i = 0
  if i < chars.length() && chars[i] is ('+' | '-') {
    i += 1
  }
  let mut digits = 0
  while i < chars.length() && chars[i] is ('0'..<='9') {
    i += 1
    digits += 1
  }
  if i < chars.length() && chars[i] == '.' {
    i += 1
    let mut fraction = 0
    while i < chars.length() && chars[i] is ('0'..<='9') {
      i += 1
      fraction += 1
    }
    if fraction == 0 {
      return false
    }
    digits += fraction
  }
  digits > 0 && i == chars.length()
}

///|
/// A color of a `style` statement, if the port knows what the browser
/// makes of it: a keyword, a hexadecimal color or `rgb()`/`rgba()` of
/// plain numbers. Anything else might be dropped by the browser or mean
/// something the port cannot compute with.
fn checked_color(value : String, property : String) -> String raise VennError {
  let lower = value.to_lower()
  let refuse = () => {
    raise Unsupported("the \{property} \"\{value}\" of a style statement")
  }
  let chars = lower.to_array()
  if lower.has_prefix("#") {
    let hex = chars.length() - 1
    if !(hex is (3 | 4 | 6 | 8)) ||
      !chars[1:].iter().all(c => c is ('0'..<='9' | 'a'..<='f')) {
      refuse()
    }
  } else if lower.has_prefix("rgb(") || lower.has_prefix("rgba(") {
    guard lower.has_suffix(")") else { refuse() }
    let open = if lower.has_prefix("rgba(") { 5 } else { 4 }
    let parts = String::from_array(chars[open:chars.length() - 1])
      .split(",")
      .map(part => js_trim(part))
      .collect()
    if parts.length() != open - 1 ||
      !parts.iter().all(part => is_plain_number(part) && !part.has_prefix("-")) {
      refuse()
    }
  } else if chars.length() == 0 || !chars.iter().all(c => c is ('a'..<='z')) {
    refuse()
  }
  // What is left must be a color khroma knows, as the browser does.
  let known = try {
    @color.Channels::parse(value) |> ignore
    true
  } catch {
    _ => false
  }
  if !known {
    refuse()
  }
  value
}

///|
/// A number of a `style` statement (`fill-opacity`, `stroke-width`) as
/// the browser stores it.
fn checked_number(value : String, property : String) -> String raise VennError {
  let pixels = value.has_suffix("px") && property == "stroke-width"
  let digits = if pixels {
    value[:value.length() - 2].to_owned()
  } else {
    value
  }
  if !is_plain_number(digits) {
    raise Unsupported("the \{property} \"\{value}\" of a style statement")
  }
  let number = @dom.css_number_text(@diagram.parse_float(digits))
  if pixels {
    number + "px"
  } else {
    number
  }
}

///|
/// The property of a style, checked; nothing when it is not given or
/// empty.
fn style_color(
  styles : Map[String, String]?,
  property : String,
) -> String? raise VennError {
  match styles {
    Some(styles) =>
      match styles.get(property) {
        Some(value) if value != "" => Some(checked_color(value, property))
        _ => None
      }
    None => None
  }
}

///|
/// The size of the diagram and the padding around its circles, from the
/// `venn` section of the configuration.
priv struct Settings {
  width : Double
  height : Double
  padding : Double
  use_max_width : Bool
  use_debug_layout : Bool
}

///|
fn Settings::new(config : @config.Config) -> Settings raise VennError {
  // `config?.name ?? default`, the section merged over its defaults.
  let number = (name : String, default : Double) => {
    match config.get("venn." + name) {
      Null => default
      Number(value, ..) => value
      _ => raise Unsupported("venn.\{name} is not a number")
    }
  }
  let flag = (name : String, default : Bool) => {
    match config.get("venn." + name) {
      Null => default
      _ => config.flag("venn." + name)
    }
  }
  {
    width: number("width", 800.0),
    height: number("height", 450.0),
    padding: number("padding", 15.0),
    use_max_width: flag("useMaxWidth", true),
    use_debug_layout: flag("useDebugLayout", false),
  }
}

///|
/// Draw the Venn diagram into the context's `<svg>` element.
pub fn draw(venn : Venn, context : @diagram.Context) -> Unit raise VennError {
  let n = @dom.number
  let config = context.config
  let theme = context.theme()
  let svg = context.svg
  let settings = Settings::new(config)
  if config.text("look") == Some("handDrawn") {
    raise Unsupported("the hand-drawn look of a Venn diagram")
  }
  for subset in venn.subsets {
    for set in subset.sets {
      if inherited_names.contains(set) {
        raise Unsupported("a set named \{set}")
      }
    }
  }
  let theme_colors = []
  for i in 1..<9 {
    if variable(theme, "venn\{i}") is Some(color) && color != "" {
      theme_colors.push(color)
    }
  }
  let styles = style_by_key(venn.style_entries)
  let render_sets = ensure_pairwise_subsets(venn.subsets)
  let svg_width = settings.width
  let svg_height = settings.height
  let scale = svg_width / 1600.0
  let title_height = if venn.title != "" { 48.0 * scale } else { 0.0 }
  let default_text_color = match variable(theme, "primaryTextColor") {
    Some(color) => color
    None => variable(theme, "textColor").unwrap_or("")
  }
  svg.attr("viewBox", "0 0 \{n(svg_width)} \{n(svg_height)}") |> ignore
  if venn.title != "" {
    let fill = match variable(theme, "vennTitleTextColor") {
      Some(color) if color != "" => color
      _ => variable(theme, "titleColor").unwrap_or("")
    }
    svg
    .append("text")
    .text(venn.title)
    .attr("class", "venn-title")
    .attr("font-size", "\{n(32.0 * scale)}px")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "middle")
    .attr("x", "50%")
    .attr("y", n(32.0 * scale))
    .style("fill", fill)
    |> ignore
  }
  // The chart is laid out twice upstream: once to draw it, and again,
  // with the configured padding, to place the text nodes.
  let random = Random::new()
  let (dummy_svg, nodes) = chart(
    render_sets,
    svg_width,
    svg_height - title_height,
    random,
  )
  let layout = solve(
    render_sets,
    svg_width,
    svg_height - title_height,
    settings.padding,
    random,
  )
  if venn.text_nodes.length() > 0 {
    draw_text_nodes(
      venn, settings, layout, render_sets, dummy_svg, scale, styles,
    )
  }
  let theme_dark = @color.is_dark(
    match variable(theme, "background") {
      Some(color) if color != "" => color
      _ => "#f4f4f4"
    },
  ) catch {
    _ => raise Unsupported("the background of the theme")
  }
  let font_size = "\{n(48.0 * scale)}px"
  let mut i = 0
  for node in nodes {
    guard node.area.sets.length() == 1 else { continue }
    let custom = styles.get(sorted_copy(node.area.sets).join("|"))
    let palette_color = if theme_colors.length() > 0 {
      Some(theme_colors[i % theme_colors.length()])
    } else {
      None
    }
    let base_color = match style_color(custom, "fill") {
      Some(color) => color
      None =>
        match palette_color {
          Some(color) => color
          None => variable(theme, "primaryColor").unwrap_or("")
        }
    }
    node.group.attr(
      "class",
      node.group.get_attr("class").unwrap_or("") + " venn-set-\{i % 8}",
    )
    |> ignore
    let fill_opacity = match custom.map(styles => styles.get("fill-opacity")) {
      Some(Some(value)) => {
        if value == "" {
          raise Unsupported("an empty fill-opacity in a style statement")
        }
        checked_number(value, "fill-opacity")
      }
      _ => "0.1"
    }
    let stroke_color = style_color(custom, "stroke").unwrap_or(base_color)
    let stroke_width = match custom.map(styles => styles.get("stroke-width")) {
      Some(Some(value)) if value != "" => checked_number(value, "stroke-width")
      _ => @dom.css_number_text(5.0 * scale)
    }
    node.path
    .style("fill", base_color)
    .style("fill-opacity", fill_opacity)
    .style("stroke", stroke_color)
    .style("stroke-width", stroke_width)
    .style("stroke-opacity", "0.95")
    |> ignore
    // The label in the color of the set, blended towards black on a
    // light background and towards white on a dark one.
    let text_color = match style_color(custom, "color") {
      Some(color) => color
      None =>
        try {
          if theme_dark {
            @color.lighten(base_color, 30.0)
          } else {
            @color.darken(base_color, 30.0)
          }
        } catch {
          _ => raise Invalid("Unsupported color format: \"\{base_color}\"")
        }
    }
    node.text.style("font-size", font_size).style("fill", text_color) |> ignore
    i += 1
  }
  for node in nodes {
    guard node.area.sets.length() != 1 else { continue }
    let custom = styles.get(sorted_copy(node.area.sets).join("|"))
    let fill = match custom.map(styles => styles.get("color")) {
      Some(Some(value)) => {
        if value == "" {
          raise Unsupported("an empty color in a style statement")
        }
        checked_color(value, "color")
      }
      _ =>
        match variable(theme, "vennSetTextColor") {
          Some(color) => color
          None => default_text_color
        }
    }
    node.text.style("font-size", font_size).style("fill", fill) |> ignore
  }
  for node in nodes {
    guard node.area.sets.length() != 1 else { continue }
    let custom = styles.get(sorted_copy(node.area.sets).join("|"))
    match custom.map(styles => styles.get("fill")) {
      Some(Some(value)) => {
        if value == "" {
          raise Unsupported("an empty fill in a style statement")
        }
        node.path
        .style("fill-opacity", "1")
        .style("fill", checked_color(value, "fill"))
        |> ignore
      }
      _ =>
        node.path.style("fill-opacity", "0").style("fill", "transparent")
        |> ignore
    }
  }
  // The contents of the chart move into the diagram, below the title.
  let group = svg
    .append("g")
    .attr("transform", "translate(0, \{n(title_height)})")
  for child in dummy_svg.child_elements() {
    child.remove()
    group.append_child(child)
  }
  @diagram.configure_svg_size(
    svg,
    svg_height,
    svg_width,
    settings.use_max_width,
  )
}
