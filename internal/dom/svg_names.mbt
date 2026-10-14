// The case of SVG names, which the HTML parser lowercases and then puts
// back for elements in the SVG namespace: the "adjust SVG attributes" and
// SVG tag name tables of the HTML standard.

///|
let svg_attribute_names : Map[String, String] = {
  let map : Map[String, String] = Map([])
  for
    name in [
      "attributeName", "attributeType", "baseFrequency", "baseProfile", "calcMode",
      "clipPathUnits", "diffuseConstant", "edgeMode", "filterUnits", "glyphRef",
      "gradientTransform", "gradientUnits", "kernelMatrix", "kernelUnitLength", "keyPoints",
      "keySplines", "keyTimes", "lengthAdjust", "limitingConeAngle", "markerHeight",
      "markerUnits", "markerWidth", "maskContentUnits", "maskUnits", "numOctaves",
      "pathLength", "patternContentUnits", "patternTransform", "patternUnits", "pointsAtX",
      "pointsAtY", "pointsAtZ", "preserveAlpha", "preserveAspectRatio", "primitiveUnits",
      "refX", "refY", "repeatCount", "repeatDur", "requiredExtensions", "requiredFeatures",
      "specularConstant", "specularExponent", "spreadMethod", "startOffset", "stdDeviation",
      "stitchTiles", "surfaceScale", "systemLanguage", "tableValues", "targetX",
      "targetY", "textLength", "viewBox", "viewTarget", "xChannelSelector", "yChannelSelector",
      "zoomAndPan",
    ] {
    map[name.to_lower()] = name
  }
  map
}

///|
let svg_tag_names : Map[String, String] = {
  let map : Map[String, String] = Map([])
  for
    name in [
      "altGlyph", "altGlyphDef", "altGlyphItem", "animateColor", "animateMotion",
      "animateTransform", "clipPath", "feBlend", "feColorMatrix", "feComponentTransfer",
      "feComposite", "feConvolveMatrix", "feDiffuseLighting", "feDisplacementMap",
      "feDistantLight", "feDropShadow", "feFlood", "feFuncA", "feFuncB", "feFuncG",
      "feFuncR", "feGaussianBlur", "feImage", "feMerge", "feMergeNode", "feMorphology",
      "feOffset", "fePointLight", "feSpecularLighting", "feSpotLight", "feTile",
      "feTurbulence", "foreignObject", "glyphRef", "linearGradient", "radialGradient",
      "textPath",
    ] {
    map[name.to_lower()] = name
  }
  map
}

///|
/// Whether children parsed into `parent` are SVG elements: below an `<svg>`
/// and not inside a `foreignObject`, whose content is HTML again.
fn children_in_svg(parent : Element) -> Bool {
  let mut current = Some(parent)
  while current is Some(element) {
    match element.tag {
      "svg" => return true
      "foreignObject" | "foreignobject" => return false
      _ => current = element.parent
    }
  }
  false
}

///|
/// The name of a lowercased tag as the parser leaves it: `svg` and what
/// is below it in their SVG case.
fn adjusted_tag(name : String, svg : Bool) -> String {
  if svg {
    svg_tag_names.get(name).unwrap_or(name)
  } else {
    name
  }
}

///|
/// The name of a lowercased attribute of an SVG element in its SVG case.
fn adjusted_attribute(name : String, svg : Bool) -> String {
  if svg {
    svg_attribute_names.get(name).unwrap_or(name)
  } else {
    name
  }
}
