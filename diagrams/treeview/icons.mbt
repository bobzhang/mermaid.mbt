// Which icon a node gets (`icons.ts`) and the markup of the icons the port
// can draw: the two built-in ones and the question mark upstream draws for
// an icon it does not know. Icon packs are registered through mermaid's
// JavaScript API, which has no counterpart here, so every other reference
// is unknown, as it is in a page that registered none.

///|
/// The prefix of the built-in icon pack.
const ICON_PREFIX : String = "mermaid-treeview"

///|
const FOLDER_BODY : String =
  #|<path fill="currentColor" d="M10.59 4.59A2 2 0 0 0 9.17 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.17z"></path>

///|
const FILE_BODY : String =
  #|<path fill="currentColor" fill-rule="evenodd" d="M6 2a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8.83a2 2 0 0 0-.59-1.42l-4.82-4.82A2 2 0 0 0 13.17 2H6Zm7.5 1.9l4.6 4.6h-3.6a1 1 0 0 1-1-1V3.9Z" clip-rule="evenodd"></path>

///|
/// The body of mermaid's `unknownIcon`, on an 80 by 80 canvas.
const UNKNOWN_BODY : String =
  #|<g><rect width="80" height="80" style="fill: #087ebf; stroke-width: 0px;"></rect><text transform="translate(21.16 64.67)" style="fill: #fff; font-family: ArialMT, Arial; font-size: 67.75px;"><tspan x="0" y="0">?</tspan></text></g>

///|
/// The names every JavaScript object answers to. Upstream looks icons up
/// in plain objects, where these find a function instead of an icon.
let object_prototype_names : Array[String] = [
  "constructor", "__proto__", "__defineGetter__", "__defineSetter__", "__lookupGetter__",
  "__lookupSetter__", "hasOwnProperty", "isPrototypeOf", "propertyIsEnumerable",
  "toString", "valueOf", "toLocaleString",
]

///|
/// The icon for a fully qualified reference, 14 pixels square, as it
/// leaves the sanitizer.
fn icon_svg(reference : String) -> @dom.Element raise TreeViewError {
  let (size, body) = match reference.strip_prefix(ICON_PREFIX + ":") {
    Some("folder") => (24, FOLDER_BODY)
    Some("file") => (24, FILE_BODY)
    // The lookup finds `Object`, which has no body to draw.
    Some("constructor") =>
      raise TreeViewError(
        "Cannot read properties of undefined (reading 'indexOf')",
      )
    _ => (80, UNKNOWN_BODY)
  }
  let svg = @dom.Element::new("svg")
    .attr("xmlns", "http://www.w3.org/2000/svg")
    .attr("width", "14")
    .attr("height", "14")
    .attr("viewBox", "0 0 \{size} \{size}")
  svg.set_inner_html(body)
  svg
}

///|
/// Qualify an icon reference without a pack: built-in icons win, then the
/// `defaultIconPack`.
fn qualify_icon(icon : String, default_pack : String) -> String {
  if icon.contains(":") {
    icon
  } else if icon is ("folder" | "file") ||
    object_prototype_names.contains(icon) ||
    default_pack == "" {
    "\{ICON_PREFIX}:\{icon}"
  } else {
    "\{default_pack}:\{icon}"
  }
}

///|
/// What the renderer needs of the `treeView` configuration to pick icons.
priv struct IconConfig {
  show_icons : Bool
  default_pack : String
  /// Exact file name to icon.
  filename_icons : Json
  /// Extension, in lower case and with or without its dot, to icon.
  extension_icons : Json
}

///|
/// A property of a configuration dictionary as JavaScript reads it: absent
/// (`None`) or a string. Looking up a name every object has finds a
/// function, which upstream then fails on.
fn lookup(dictionary : Json, key : String) -> String? raise {
  guard dictionary is Object(entries) else { return None }
  match entries.get(key) {
    Some(String(icon)) => Some(icon)
    Some(Null) | None =>
      if object_prototype_names.contains(key) {
        raise TreeViewError("icon.includes is not a function")
      } else {
        None
      }
    Some(_) => raise Unsupported("an icon that is not a string, for \{key}")
  }
}

///|
/// The icon configured for a file name: an exact match of the name first,
/// then of its extension.
fn detect_icon(name : String, config : IconConfig) -> String? raise {
  if lookup(config.filename_icons, name) is Some(icon) && icon != "" {
    return Some(icon)
  }
  guard name.rev_find(".") is Some(dot) && dot > 0 else { return None }
  let extension = name[dot:].to_owned()
  if config.extension_icons is Object(entries) &&
    entries.length() > 0 &&
    extension.iter().any(c => c.to_int() > 0x7f) {
    raise Unsupported(
      "matching an extension outside ASCII against extensionIcons: \{extension}",
    )
  }
  let extension = extension.to_lower()
  match lookup(config.extension_icons, extension) {
    Some(icon) => Some(icon)
    None => lookup(config.extension_icons, extension[1:].to_owned())
  }
}

///|
/// The fully qualified icon to draw for a node, if any. An `icon()`
/// annotation always wins (`none` hides the icon); otherwise, with
/// `showIcons`, files are matched against the configured maps and fall
/// back to the built-in file and folder icons.
fn node_icon(node : Node, config : IconConfig) -> String? raise {
  match node.icon {
    Some("none") => return None
    Some(icon) if icon != "" =>
      return Some(qualify_icon(icon, config.default_pack))
    _ => ()
  }
  if !config.show_icons {
    return None
  }
  if !node.directory {
    match detect_icon(node.name, config) {
      Some("none") => return None
      Some(icon) if icon != "" =>
        return Some(qualify_icon(icon, config.default_pack))
      _ => ()
    }
  }
  Some("\{ICON_PREFIX}:\{if node.directory { "folder" } else { "file" }}")
}
