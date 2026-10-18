///|
/// The icon wrapper of `architectureIcons.ts`: a blue square under the
/// icon's strokes.
fn wrap_icon(icon : String) -> String {
  "<g><rect width=\"80\" height=\"80\" style=\"fill: #087ebf; stroke-width: 0px;\"/>" +
  icon +
  "</g>"
}

///|
/// The icon drawn for one that cannot be found: a question mark on the
/// blue square (`unknownIcon` of `rendering-util/icons.ts`).
let unknown_icon : String =
  #|<g><rect width="80" height="80" style="fill: #087ebf; stroke-width: 0px;"/><text transform="translate(21.16 64.67)" style="fill: #fff; font-family: ArialMT, Arial; font-size: 67.75px;"><tspan x="0" y="0">?</tspan></text></g>

///|
/// The icons of mermaid's architecture icon pack (`mermaid-architecture`),
/// as `architectureIcons.ts` has them: 80 by 80 units.
let architecture_icons : Map[String, String] = {
  "database": wrap_icon(
    (
      #|<path id="b" data-name="4" d="m20,57.86c0,3.94,8.95,7.14,20,7.14s20-3.2,20-7.14" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><path id="c" data-name="3" d="m20,45.95c0,3.94,8.95,7.14,20,7.14s20-3.2,20-7.14" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><path id="d" data-name="2" d="m20,34.05c0,3.94,8.95,7.14,20,7.14s20-3.2,20-7.14" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><ellipse id="e" data-name="1" cx="40" cy="22.14" rx="20" ry="7.14" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><line x1="20" y1="57.86" x2="20" y2="22.14" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><line x1="60" y1="57.86" x2="60" y2="22.14" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/>
    ),
  ),
  "server": wrap_icon(
    (
      #|<rect x="17.5" y="17.5" width="45" height="45" rx="2" ry="2" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><line x1="17.5" y1="32.5" x2="62.5" y2="32.5" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><line x1="17.5" y1="47.5" x2="62.5" y2="47.5" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><g><path d="m56.25,25c0,.27-.45.5-1,.5h-10.5c-.55,0-1-.23-1-.5s.45-.5,1-.5h10.5c.55,0,1,.23,1,.5Z" style="fill: #fff; stroke-width: 0px;"/><path d="m56.25,25c0,.27-.45.5-1,.5h-10.5c-.55,0-1-.23-1-.5s.45-.5,1-.5h10.5c.55,0,1,.23,1,.5Z" style="fill: none; stroke: #fff; stroke-miterlimit: 10;"/></g><g><path d="m56.25,40c0,.27-.45.5-1,.5h-10.5c-.55,0-1-.23-1-.5s.45-.5,1-.5h10.5c.55,0,1,.23,1,.5Z" style="fill: #fff; stroke-width: 0px;"/><path d="m56.25,40c0,.27-.45.5-1,.5h-10.5c-.55,0-1-.23-1-.5s.45-.5,1-.5h10.5c.55,0,1,.23,1,.5Z" style="fill: none; stroke: #fff; stroke-miterlimit: 10;"/></g><g><path d="m56.25,55c0,.27-.45.5-1,.5h-10.5c-.55,0-1-.23-1-.5s.45-.5,1-.5h10.5c.55,0,1,.23,1,.5Z" style="fill: #fff; stroke-width: 0px;"/><path d="m56.25,55c0,.27-.45.5-1,.5h-10.5c-.55,0-1-.23-1-.5s.45-.5,1-.5h10.5c.55,0,1,.23,1,.5Z" style="fill: none; stroke: #fff; stroke-miterlimit: 10;"/></g><g><circle cx="32.5" cy="25" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/><circle cx="27.5" cy="25" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/><circle cx="22.5" cy="25" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/></g><g><circle cx="32.5" cy="40" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/><circle cx="27.5" cy="40" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/><circle cx="22.5" cy="40" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/></g><g><circle cx="32.5" cy="55" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/><circle cx="27.5" cy="55" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/><circle cx="22.5" cy="55" r=".75" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10;"/></g>
    ),
  ),
  "disk": wrap_icon(
    (
      #|<rect x="20" y="15" width="40" height="50" rx="1" ry="1" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><ellipse cx="24" cy="19.17" rx=".8" ry=".83" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><ellipse cx="56" cy="19.17" rx=".8" ry=".83" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><ellipse cx="24" cy="60.83" rx=".8" ry=".83" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><ellipse cx="56" cy="60.83" rx=".8" ry=".83" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><ellipse cx="40" cy="33.75" rx="14" ry="14.58" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><ellipse cx="40" cy="33.75" rx="4" ry="4.17" style="fill: #fff; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><path d="m37.51,42.52l-4.83,13.22c-.26.71-1.1,1.02-1.76.64l-4.18-2.42c-.66-.38-.81-1.26-.33-1.84l9.01-10.8c.88-1.05,2.56-.08,2.09,1.2Z" style="fill: #fff; stroke-width: 0px;"/>
    ),
  ),
  "internet": wrap_icon(
    (
      #|<circle cx="40" cy="40" r="22.5" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><line x1="40" y1="17.5" x2="40" y2="62.5" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><line x1="17.5" y1="40" x2="62.5" y2="40" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><path d="m39.99,17.51c-15.28,11.1-15.28,33.88,0,44.98" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><path d="m40.01,17.51c15.28,11.1,15.28,33.88,0,44.98" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><line x1="19.75" y1="30.1" x2="60.25" y2="30.1" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/><line x1="19.75" y1="49.9" x2="60.25" y2="49.9" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/>
    ),
  ),
  "cloud": wrap_icon(
    (
      #|<path d="m65,47.5c0,2.76-2.24,5-5,5H20c-2.76,0-5-2.24-5-5,0-1.87,1.03-3.51,2.56-4.36-.04-.21-.06-.42-.06-.64,0-2.6,2.48-4.74,5.65-4.97,1.65-4.51,6.34-7.76,11.85-7.76.86,0,1.69.08,2.5.23,2.09-1.57,4.69-2.5,7.5-2.5,6.1,0,11.19,4.38,12.28,10.17,2.14.56,3.72,2.51,3.72,4.83,0,.03,0,.07-.01.1,2.29.46,4.01,2.48,4.01,4.9Z" style="fill: none; stroke: #fff; stroke-miterlimit: 10; stroke-width: 2px;"/>
    ),
  ),
  "unknown": unknown_icon,
  "blank": wrap_icon(""),
}

///|
/// The prefix of the ids iconify gives an icon's elements:
/// `"IconifyId" + Date.now().toString(16) + (Math.random() * 16777216 | 0).toString(16)`,
/// drawn once per page. The port draws it as a page whose clock and random
/// numbers are at zero; scripts/oracle.py renames upstream's ids so.
const ICONIFY_PREFIX : String = "IconifyId00"

///|
/// What `Object.prototype` has, which iconify would find as icons.
let object_prototype_names : Array[String] = [
  "constructor", "__defineGetter__", "__defineSetter__", "hasOwnProperty", "__lookupGetter__",
  "__lookupSetter__", "isPrototypeOf", "propertyIsEnumerable", "toString", "valueOf",
  "__proto__", "toLocaleString",
]

///|
/// The body of an icon, as `getRegisteredIconData` finds it with the
/// architecture pack as the fallback (`stringToIcon` reads `pack:name`,
/// and a name with a dash as `pack-name`); the unknown icon for anything
/// else.
fn icon_body(name : String) -> String raise ArchitectureError {
  let parts = name.split(":").map(part => part.to_owned()).collect()
  let lookup = if parts.length() > 3 {
    None
  } else if parts.length() > 1 {
    let icon = parts[parts.length() - 1]
    let pack = parts[parts.length() - 2]
    if pack != "" && icon != "" && pack == "mermaid-architecture" {
      Some(icon)
    } else {
      None
    }
  } else if name.contains("-") {
    // A pack named before the first dash, which is not registered.
    None
  } else {
    Some(name)
  }
  guard lookup is Some(icon) else { return unknown_icon }
  if object_prototype_names.contains(icon) {
    raise Unsupported("an icon named \{icon}")
  }
  architecture_icons.get(icon).unwrap_or(unknown_icon)
}

///|
/// iconify's `replaceIDs`: every `id` of an icon gets a name unique in the
/// page, numbered on from the last icon's.
fn replace_ids(body : String, counter : Ref[Int32]) -> String {
  // `/\sid="(\S+)"/g`
  let ids = []
  let mut rest = body[:]
  while rest.find(" id=\"") is Some(at) {
    let value = rest[at + 5:]
    match value.find("\"") {
      Some(end) if end > 0 && !value[:end].contains(" ") => {
        ids.push(value[:end].to_owned())
        rest = value[end + 1:]
      }
      _ => rest = value
    }
  }
  let mut result = body
  for id in ids {
    let new_id = ICONIFY_PREFIX + counter.val.to_string()
    counter.val += 1
    // `([#;"])(id)([")]|\.[a-z])`, every occurrence.
    let out = StringBuilder()
    let chars = result.to_array()
    let id_chars = id.to_array()
    let mut i = 0
    while i < chars.length() {
      let c = chars[i]
      out.write_char(c)
      i += 1
      guard c is ('#' | ';' | '"') else { continue }
      let end = i + id_chars.length()
      guard end <= chars.length() &&
        chars[i:end].to_owned() == id_chars &&
        end < chars.length() else {
        continue
      }
      let next = chars[end]
      let follows = next is ('"' | ')') ||
        (
          next == '.' &&
          end + 1 < chars.length() &&
          chars[end + 1] >= 'a' &&
          chars[end + 1] <= 'z'
        )
      if follows {
        out.write_string(new_id)
        i = end
      }
    }
    result = out.to_string()
  }
  result
}

///|
/// `getIconSVG(name, { width: size, height: size, fallbackPrefix:
/// "mermaid-architecture" })`: the icon as an `<svg>` of that size around
/// the icon's 80 by 80 units.
fn icon_svg(
  name : String,
  size : Double,
  counter : Ref[Int32],
) -> String raise ArchitectureError {
  let body = replace_ids(icon_body(name), counter)
  let n = @dom.number(size)
  let xlink = if body.contains("xlink:") {
    " xmlns:xlink=\"http://www.w3.org/1999/xlink\""
  } else {
    ""
  }
  "<svg xmlns=\"http://www.w3.org/2000/svg\"\{xlink} width=\"\{n}\" height=\"\{n}\" viewBox=\"0 0 80 80\">\{body}</svg>"
}
