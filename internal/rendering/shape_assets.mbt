// Nodes drawn as an icon or an image: mermaid's `icon`, `iconCircle`,
// `iconRounded`, `iconSquare` and `imageSquare` shapes, which a flowchart
// node gets from `@{ icon: ... }` or `@{ img: ... }`.
//
// Icon packs are registered through mermaid's JavaScript API, which has no
// counterpart here, so every icon is the question mark upstream draws for
// an icon it does not know, as in a page that registered none. An image is
// loaded to learn its natural size; the port knows the size of images in
// `data:` URLs (PNG and GIF) only, and draws any other image only when the
// node gives both its width and its height and no constraint.

///|
/// The body of mermaid's `unknownIcon`, on an 80 by 80 canvas.
const UNKNOWN_ICON_BODY : String =
  #|<g><rect width="80" height="80" style="fill: #087ebf; stroke-width: 0px;"></rect><text transform="translate(21.16 64.67)" style="fill: #fff; font-family: ArialMT, Arial; font-size: 67.75px;"><tspan x="0" y="0">?</tspan></text></g>

///|
/// The padding of the paragraphs of HTML labels in these shapes:
/// `.icon-shape p, .image-shape p { padding: 2px }` in the flowchart
/// stylesheet.
const ASSET_PARAGRAPH_PADDING : Double = 2.0

///|
/// What `@{ ... }` asked of an icon or image node.
priv struct AssetData {
  icon : String?
  img : String?
  top_label : Bool
  constraint : String?
  asset_width : Double?
  asset_height : Double?
}

///|
fn asset_data(node : Node) -> AssetData {
  match node.data {
    Asset(icon~, img~, pos~, constraint~, asset_width~, asset_height~) =>
      {
        icon,
        img,
        top_label: pos == Some("t"),
        constraint,
        asset_width,
        asset_height,
      }
    _ =>
      {
        icon: None,
        img: None,
        top_label: false,
        constraint: None,
        asset_width: None,
        asset_height: None,
      }
  }
}

///|
/// The node's styles by property, label styles included: `compileStyles`.
fn compiled_styles_map(node : Node) -> Map[String, String] {
  let styles = [..node.css_compiled_styles, ..node.css_styles]
  for style in node.label_style.split(";") {
    let style = style.trim().to_owned()
    if style != "" {
      styles.push(style)
    }
  }
  styles_map(styles)
}

///|
/// Put `<g>${getIconSVG(name, { width: size, height: size })}</g>` for an
/// icon no pack provides into `group`, as the shapes do: the box of the
/// group is then the viewport of the icon.
fn fill_unknown_icon(group : @dom.Element, size : Double) -> Unit {
  let n = @dom.number
  let svg = group
    .append("g")
    .append("svg")
    .attr("xmlns", "http://www.w3.org/2000/svg")
    .attr("width", n(size))
    .attr("height", n(size))
    .attr("viewBox", "0 0 80 80")
  svg.set_inner_html(UNKNOWN_ICON_BODY)
}

///|
/// The outline edges meet on an icon or image node with a label: the
/// asset and the label stacked. Upstream halves the label's half width
/// once more on one corner when the label is below.
fn asset_outline(
  node : Node,
  label : LabelBox,
  width : Double,
  height : Double,
  label_padding : Double,
  top_label : Bool,
) -> Array[Point] {
  let dx = node.x
  let dy = node.y
  let node_height = node.height.unwrap_or(0.0)
  if top_label {
    [
      { x: dx - label.width / 2.0, y: dy - node_height / 2.0, },
      { x: dx + label.width / 2.0, y: dy - node_height / 2.0, },
      {
        x: dx + label.width / 2.0,
        y: dy - node_height / 2.0 + label.height + label_padding,
      },
      {
        x: dx + width / 2.0,
        y: dy - node_height / 2.0 + label.height + label_padding,
      },
      { x: dx + width / 2.0, y: dy + node_height / 2.0, },
      { x: dx - width / 2.0, y: dy + node_height / 2.0, },
      {
        x: dx - width / 2.0,
        y: dy - node_height / 2.0 + label.height + label_padding,
      },
      {
        x: dx - label.width / 2.0,
        y: dy - node_height / 2.0 + label.height + label_padding,
      },
    ]
  } else {
    [
      { x: dx - width / 2.0, y: dy - node_height / 2.0, },
      { x: dx + width / 2.0, y: dy - node_height / 2.0, },
      { x: dx + width / 2.0, y: dy - node_height / 2.0 + height, },
      { x: dx + label.width / 2.0, y: dy - node_height / 2.0 + height, },
      { x: dx + label.width / 2.0 / 2.0, y: dy + node_height / 2.0, },
      { x: dx - label.width / 2.0, y: dy + node_height / 2.0, },
      { x: dx - label.width / 2.0, y: dy - node_height / 2.0 + height, },
      { x: dx - width / 2.0, y: dy - node_height / 2.0 + height, },
    ]
  }
}

///|
/// Where edges meet an icon or image node: its box without a label, else
/// the outline of asset and label.
fn asset_intersect(
  node : Node,
  label : LabelBox,
  width : Double,
  height : Double,
  label_padding : Double,
  top_label : Bool,
) -> (Point) -> Point {
  point => {
    if node.label == "" {
      return intersect_rect(
        node.x,
        node.y,
        node.width.unwrap_or(0.0),
        node.height.unwrap_or(0.0),
        point,
      )
    }
    let outline = asset_outline(
      node, label, width, height, label_padding, top_label,
    )
    intersect_polygon(node, outline, point)
  }
}

///|
/// An icon, alone or in a circle, a rounded or a square frame, with its
/// label above or below: `handler` is the shape's name.
fn icon_shape(
  parent : @dom.Element,
  node : Node,
  env : Env,
  handler : String,
) -> @dom.Element {
  shape_styles(node) |> ignore
  let asset = asset_data(node)
  let theme = env.config.theme()
  let icon_size = asset.asset_height
    .unwrap_or(48.0)
    .max(asset.asset_width.unwrap_or(48.0))
  let default_width = env.config.number("flowchart.wrappingWidth")
  node.width = Some(icon_size.max(default_width.unwrap_or(0.0)))
  let labelled = label_helper(
    parent,
    node,
    "icon-shape default",
    env,
    add_background=asset.icon is Some(_) || asset.img is Some(_),
    paragraph_padding=ASSET_PARAGRAPH_PADDING,
  )
  let shape_svg = labelled.shape_svg
  let box = labelled.bbox
  let top_label = asset.top_label
  let label_padding = if node.label != "" { 8.0 } else { 0.0 }
  let half_padding = node.padding / 2.0
  let styles = compiled_styles_map(node)
  let options = rough_options(node, env)
  let n = @dom.number
  // The circle sizes itself by the icon, which it measures first.
  let circle_icon = if handler == "iconCircle" {
    let group = shape_svg.append("g")
    if asset.icon is Some(_) {
      fill_unknown_icon(group, icon_size)
    }
    Some(group)
  } else {
    None
  }
  let (width, height, frame) = match handler {
    "iconCircle" => {
      options.stroke = styles.get("fill").unwrap_or(theme.text("mainBkg"))
      let icon_box = circle_icon
        .map(group => group.bbox())
        .unwrap_or({ x: 0.0, y: 0.0, width: 0.0, height: 0.0, })
      let diameter = icon_box.width.max(icon_box.height) * 2.0.sqrt() +
        20.0 * 2.0
      (diameter, diameter, @rough.circle(0.0, 0.0, diameter, options))
    }
    "iconRounded" | "iconSquare" => {
      options.stroke = styles.get("fill").unwrap_or(theme.text("mainBkg"))
      let size = icon_size + half_padding * 2.0
      let radius = if handler == "iconRounded" { 5.0 } else { 0.1 }
      let frame = @rough.path(
        rounded_rect_path(-size / 2.0, -size / 2.0, size, size, radius),
        options,
      )
      (size, size, frame)
    }
    _ => {
      options.stroke = "none"
      options.fill = "none"
      let frame = @rough.rectangle(
        -icon_size / 2.0,
        -icon_size / 2.0,
        icon_size,
        icon_size,
        options,
      )
      (icon_size, icon_size, frame)
    }
  }
  let outer_width = width.max(box.width)
  let outer_height = height + box.height + label_padding
  let outer_options = options.copy()
  outer_options.fill = "transparent"
  outer_options.stroke = "none"
  let outer = @rough.rectangle(
    -outer_width / 2.0,
    -outer_height / 2.0,
    outer_width,
    outer_height,
    outer_options,
  )
  prepend(shape_svg, frame)
  if handler == "iconRounded" {
    frame.attr("class", "icon-shape2") |> ignore
  }
  shape_svg.append_child(outer)
  let icon_group = match circle_icon {
    Some(group) => Some(group)
    None =>
      if asset.icon is Some(_) {
        let group = shape_svg.append("g")
        fill_unknown_icon(group, icon_size)
        Some(group)
      } else {
        None
      }
  }
  if icon_group is Some(group) {
    let icon_box = group.bbox()
    let y = if top_label {
      box.height / 2.0 +
      label_padding / 2.0 -
      icon_box.height / 2.0 -
      icon_box.y
    } else {
      -box.height / 2.0 -
      label_padding / 2.0 -
      icon_box.height / 2.0 -
      icon_box.y
    }
    group
    .attr(
      "transform",
      "translate(\{n(-icon_box.width / 2.0 - icon_box.x)},\{n(y)})",
    )
    .attr(
      "style",
      "color: \{styles.get("stroke").unwrap_or(theme.text("nodeBorder"))};",
    )
    |> ignore
  }
  let label_y = if top_label {
    -outer_height / 2.0
  } else {
    outer_height / 2.0 - box.height
  }
  labelled.label.attr(
    "transform",
    "translate(\{n(-box.width / 2.0 - labelled.offset_x)},\{n(label_y)})",
  )
  |> ignore
  let frame_y = if top_label {
    box.height / 2.0 + label_padding / 2.0
  } else {
    -box.height / 2.0 - label_padding / 2.0
  }
  frame.attr("transform", "translate(0,\{n(frame_y)})") |> ignore
  update_node_bounds(node, outer)
  node.intersect = Some(
    if handler == "iconCircle" {
      node_intersect_rect(node)
    } else {
      asset_intersect(node, box, width, height, label_padding, top_label)
    },
  )
  shape_svg
}

///|
/// The natural size of an image the port can know without loading it:
/// a PNG or GIF in a base64 `data:` URL, read from its header.
fn image_natural_size(url : String) -> (Double, Double)? {
  guard url.strip_prefix("data:") is Some(rest) &&
    rest.find(";base64,") is Some(at) else {
    return None
  }
  let bytes = base64_prefix(rest[at + 8:].to_owned(), 32)
  let byte = (i : Int32) => bytes[i].to_int()
  if bytes.length() >= 24 &&
    byte(0) == 0x89 &&
    byte(1) == 0x50 &&
    byte(2) == 0x4e &&
    byte(3) == 0x47 &&
    byte(12) == 0x49 &&
    byte(13) == 0x48 &&
    byte(14) == 0x44 &&
    byte(15) == 0x52 {
    // PNG: the IHDR chunk comes first, big-endian.
    let be = (i : Int32) => {
      (byte(i) << 24) | (byte(i + 1) << 16) | (byte(i + 2) << 8) | byte(i + 3)
    }
    let width = be(16)
    let height = be(20)
    guard width > 0 && height > 0 else { return None }
    Some((width.to_double(), height.to_double()))
  } else if bytes.length() >= 10 &&
    byte(0) == 0x47 &&
    byte(1) == 0x49 &&
    byte(2) == 0x46 {
    // GIF: the logical screen, little-endian.
    let width = byte(6) | (byte(7) << 8)
    let height = byte(8) | (byte(9) << 8)
    guard width > 0 && height > 0 else { return None }
    Some((width.to_double(), height.to_double()))
  } else {
    None
  }
}

///|
/// The first `count` bytes base64 text decodes to (fewer if it is
/// shorter or stops being base64).
fn base64_prefix(text : String, count : Int32) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut buffer = 0
  let mut bits = 0
  for c in text {
    if out.length() >= count {
      break
    }
    let value = match c {
      'A'..<='Z' => c.to_int() - 'A'.to_int()
      'a'..<='z' => c.to_int() - 'a'.to_int() + 26
      '0'..<='9' => c.to_int() - '0'.to_int() + 52
      '+' | '-' => 62
      '/' | '_' => 63
      _ => break
    }
    buffer = (buffer << 6) | value
    bits += 6
    if bits >= 8 {
      bits -= 8
      out.push(((buffer >> bits) & 0xff).to_byte())
    }
  }
  out
}

///|
/// An image with its label above or below: mermaid's `imageSquare`. The
/// image is loaded first, for its natural size, so the node's group comes
/// after those of the nodes that need not wait (see `order_image_nodes`).
fn image_square(
  parent : @dom.Element,
  node : Node,
  env : Env,
) -> @dom.Element raise LayoutError {
  let asset = asset_data(node)
  let url = asset.img.unwrap_or("")
  let constrained = asset.constraint == Some("on")
  // What upstream takes from the image itself, when it needs it.
  let fixed = !constrained &&
    asset.asset_width is Some(_) &&
    asset.asset_height is Some(_)
  let (natural_width, natural_height) = match image_natural_size(url) {
    Some(size) => size
    None if fixed => (0.0, 0.0)
    None =>
      raise LayoutError(
        "The natural size of the image \{url} is not known to the port; give the node both w and h, without a constraint.",
      )
  }
  let ratio = natural_width / natural_height
  shape_styles(node) |> ignore
  let default_width = env.config.number("flowchart.wrappingWidth")
  let raw_width = (if node.label != "" {
    default_width.unwrap_or(0.0)
  } else {
    0.0
  }).max(asset.asset_width.unwrap_or(natural_width))
  let image_width = if constrained {
    match asset.asset_height {
      Some(height) if height != 0.0 => height * ratio
      _ => raw_width
    }
  } else {
    raw_width
  }
  let image_height = if constrained {
    image_width / ratio
  } else {
    asset.asset_height.unwrap_or(natural_height)
  }
  node.width = Some(image_width.max(default_width.unwrap_or(0.0)))
  let labelled = label_helper(
    parent,
    node,
    "image-shape default",
    env,
    add_background=true,
    paragraph_padding=ASSET_PARAGRAPH_PADDING,
  )
  let shape_svg = labelled.shape_svg
  let box = labelled.bbox
  let top_label = asset.top_label
  let label_padding = if node.label != "" { 8.0 } else { 0.0 }
  let options = rough_options(node, env)
  let frame = @rough.rectangle(
    -image_width / 2.0,
    -image_height / 2.0,
    image_width,
    image_height,
    options,
  )
  let outer_width = image_width.max(box.width)
  let outer_height = image_height + box.height + label_padding
  let outer_options = options.copy()
  outer_options.fill = "none"
  outer_options.stroke = "none"
  let outer = @rough.rectangle(
    -outer_width / 2.0,
    -outer_height / 2.0,
    outer_width,
    outer_height,
    outer_options,
  )
  prepend(shape_svg, frame)
  shape_svg.append_child(outer)
  let n = @dom.number
  if url != "" {
    let image = shape_svg.append("image")
    // The sanitizer keeps a `data:` address on an image.
    if @dom.is_allowed_uri(url) || url.has_prefix("data:") {
      image.attr("href", url) |> ignore
    }
    let image_y = if top_label {
      outer_height / 2.0 - image_height
    } else {
      -outer_height / 2.0
    }
    image
    .attr_number("width", image_width)
    .attr_number("height", image_height)
    .attr("preserveAspectRatio", "none")
    .attr("transform", "translate(\{n(-image_width / 2.0)},\{n(image_y)})")
    |> ignore
  }
  let label_y = if top_label {
    -image_height / 2.0 - box.height / 2.0 - label_padding / 2.0
  } else {
    image_height / 2.0 - box.height / 2.0 + label_padding / 2.0
  }
  labelled.label.attr(
    "transform",
    "translate(\{n(-box.width / 2.0 - labelled.offset_x)},\{n(label_y)})",
  )
  |> ignore
  let frame_y = if top_label {
    box.height / 2.0 + label_padding / 2.0
  } else {
    -box.height / 2.0 - label_padding / 2.0
  }
  frame.attr("transform", "translate(0,\{n(frame_y)})") |> ignore
  update_node_bounds(node, outer)
  node.intersect = Some(
    asset_intersect(
      node, box, image_width, image_height, label_padding, top_label,
    ),
  )
  shape_svg
}

///|
/// Put the groups of image nodes after the other nodes of their group:
/// upstream draws all nodes at once and an image node waits for its image
/// before it makes its group. Images in `data:` URLs are taken to arrive
/// first, in node order, then the others, in node order; upstream's order
/// of the latter is that of the network.
pub fn order_image_nodes(svg : @dom.Element) -> Unit {
  let images = svg
    .descendants(["g"])
    .filter(element => {
      element.get_attr("class").unwrap_or("").has_prefix("image-shape ") &&
      element.parent().bind(parent => parent.get_attr("class")) == Some("nodes")
    })
  let inline = (image : @dom.Element) => {
    image
    .child_elements()
    .any(child => {
      child.tag == "image" &&
      child.get_attr("href").unwrap_or("").has_prefix("data:")
    })
  }
  for remote in [false, true] {
    for image in images {
      guard inline(image) != remote && image.parent() is Some(parent) else {
        continue
      }
      image.remove()
      parent.append_child(image)
    }
  }
}
