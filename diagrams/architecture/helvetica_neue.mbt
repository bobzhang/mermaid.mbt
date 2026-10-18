///|
/// The advance widths of Helvetica Neue (regular), in thousandths of an em,
/// for the printable ASCII characters from the space on: what Chrome's
/// canvas measures cytoscape's labels with. Read off the oracle's Chrome
/// (`measureText` of every character at 16px, whose 16.16 widths give
/// the units back exactly).
let helvetica_neue_advances : FixedArray[Int32] = [
  278, 259, 426, 556, 556, 1000, 630, 278, 259, 259, 352, 600, 278, 389, 278, 333,
  556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 600, 600, 600, 556,
  800, 648, 685, 722, 704, 611, 574, 759, 722, 259, 519, 667, 556, 871, 722, 760,
  648, 760, 685, 648, 574, 722, 611, 926, 611, 648, 611, 259, 333, 259, 600, 500,
  222, 537, 593, 537, 593, 537, 296, 574, 556, 222, 222, 519, 222, 853, 556, 574,
  593, 593, 333, 500, 315, 556, 500, 758, 518, 500, 480, 333, 222, 333, 600,
]

///|
/// The same for U+00A0 to U+017F: Latin-1 and Latin Extended-A.
let helvetica_neue_latin_advances : FixedArray[Int32] = [
  278, 259, 556, 556, 556, 556, 222, 556, 222, 800, 378, 463, 600, 0, 800, 222, 400,
  600, 333, 333, 222, 556, 600, 278, 222, 333, 384, 463, 834, 834, 834, 556, 648,
  648, 648, 648, 648, 648, 926, 722, 611, 611, 611, 611, 259, 259, 259, 259, 704,
  722, 760, 760, 760, 760, 760, 600, 760, 722, 722, 722, 722, 648, 648, 556, 537,
  537, 537, 537, 537, 537, 870, 537, 537, 537, 537, 537, 222, 222, 222, 222, 574,
  556, 574, 574, 574, 574, 574, 600, 574, 556, 556, 556, 556, 500, 593, 500, 648,
  537, 648, 537, 648, 537, 722, 537, 722, 537, 722, 537, 722, 537, 704, 593, 704,
  598, 611, 537, 611, 537, 611, 537, 611, 537, 611, 537, 759, 574, 759, 574, 759,
  574, 759, 574, 722, 556, 722, 561, 259, 222, 259, 222, 259, 222, 259, 222, 259,
  222, 770, 438, 519, 222, 667, 519, 514, 556, 222, 556, 222, 556, 302, 556, 342,
  556, 222, 722, 556, 722, 556, 722, 556, 663, 722, 556, 760, 574, 760, 574, 760,
  574, 1074, 891, 685, 333, 685, 333, 685, 333, 648, 500, 648, 500, 648, 500, 648,
  500, 574, 315, 574, 315, 574, 315, 722, 556, 722, 556, 722, 556, 722, 556, 722,
  556, 722, 556, 926, 758, 648, 500, 648, 611, 480, 611, 480, 611, 480, 278,
]

///|
/// The kerning pairs of Helvetica Neue between the characters measured,
/// in thousandths of an em, measured as the advances were. `f` kerns with
/// nothing; the ligatures `ff`, `fi`, `fl`, `ffi` and `ffl` take its
/// place where they apply.
let helvetica_neue_kerning : Map[String, Int32] = {
  "AT": -92,
  "AV": -46,
  "AW": -24,
  "AY": -74,
  "Av": -18,
  "Aw": -18,
  "Ay": -18,
  "F,": -157,
  "F.": -157,
  "FA": -55,
  "LT": -92,
  "LV": -92,
  "LW": -55,
  "LY": -111,
  "Ly": -37,
  "P,": -179,
  "P.": -179,
  "PA": -74,
  "RT": -18,
  "RV": -18,
  "RW": -18,
  "RY": -37,
  "T,": -111,
  "T-": -129,
  "T.": -111,
  "T:": -111,
  "T;": -111,
  "TA": -92,
  "Ta": -111,
  "Tc": -111,
  "Te": -111,
  "To": -111,
  "Tr": -92,
  "Ts": -111,
  "Tu": -92,
  "Tw": -111,
  "Ty": -111,
  "V,": -129,
  "V-": -55,
  "V.": -129,
  "V:": -46,
  "V;": -46,
  "VA": -46,
  "Va": -55,
  "Ve": -55,
  "Vi": -18,
  "Vo": -55,
  "Vr": -37,
  "Vu": -37,
  "Vy": -18,
  "W,": -74,
  "W.": -74,
  "W:": -18,
  "W;": -18,
  "WA": -24,
  "Wa": -37,
  "We": -57,
  "Wo": -57,
  "Wr": -18,
  "Wu": -18,
  "Y,": -139,
  "Y-": -111,
  "Y.": -139,
  "Y:": -92,
  "Y;": -92,
  "YA": -74,
  "Ya": -92,
  "Ye": -111,
  "Yi": -37,
  "Yo": -111,
  "Yp": -74,
  "Yq": -92,
  "Yu": -74,
  "Yv": -55,
  "r,": -92,
  "r-": -55,
  "r.": -92,
  "rc": -18,
  "rd": -18,
  "re": -18,
  "rg": -28,
  "rn": 18,
  "ro": -18,
  "rq": -18,
  "v,": -74,
  "v.": -74,
  "w,": -55,
  "w.": -55,
  "y,": -74,
  "y.": -74,
  "ď#": 56,
  "ď;": 52,
  "ď^": 74,
  "ďd": 77,
  "ďg": 72,
  "ďh": 72,
  "ľ#": 55,
  "ľ;": 51,
  "ľ^": 73,
  "ľd": 76,
  "ľg": 71,
  "ľh": 71,
  "ť#": 5,
  "ť;": 1,
  "ť^": 23,
  "ťd": 26,
  "ťg": 21,
  "ťh": 21,
}

///|
/// The ligatures of Helvetica Neue that Chrome's shaping forms, longest
/// first, with their advances in thousandths of an em.
let helvetica_neue_ligatures : Array[(String, Int32)] = [
  ("ffi", 799),
  ("ffl", 799),
  ("ff", 577),
  ("fi", 518),
  ("fl", 518),
]

///|
/// What a canvas `measureText` reports for a line of text in Helvetica Neue
/// at an integer size in pixels: the glyph advances, each truncated to
/// 16.16 fixed point after a trip through single precision, and the
/// kerning between them, scaled as HarfBuzz scales positions. Ligatures
/// take the place of their letters and kern with nothing.
fn canvas_text_width(
  text : String,
  size : Double,
) -> Double raise ArchitectureError {
  guard size == size.floor() && size > 0.0 else {
    raise Unsupported("labels measured at \{size}px")
  }
  let chars = text.to_array()
  // HarfBuzz's `em_mult` for 1000 units per em.
  let scale = size.to_int64() * 65536L
  let mult = scale * 65536L / 1000L
  let kern = (units : Int32) => (units.to_int64() * mult + 32768L) >> 16
  let advance = (units : Int32) => {
    let px = Float::from_double(units.to_double() * size / 1000.0).to_double()
    (px * 65536.0).to_int64()
  }
  let mut total = 0L
  let mut previous : Char? = None
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let code = c.to_int()
    let units = if code >= 32 && code < 127 {
      helvetica_neue_advances[code - 32]
    } else if code >= 0xa0 && code < 0x180 {
      helvetica_neue_latin_advances[code - 0xa0]
    } else {
      raise Unsupported(
        "a label measured in Helvetica Neue with the character \{c}",
      )
    }
    let ligature = if c == 'f' {
      helvetica_neue_ligatures.search_by(entry => {
        let (letters, _) = entry
        let n = letters.length()
        i + n <= chars.length() && String::from_array(chars[i:i + n]) == letters
      })
    } else {
      None
    }
    match ligature {
      Some(index) => {
        let (letters, units) = helvetica_neue_ligatures[index]
        total += advance(units)
        previous = None
        i += letters.length()
      }
      None => {
        total += advance(units)
        if previous is Some(p) &&
          helvetica_neue_kerning.get("\{p}\{c}") is Some(units) {
          total += kern(units)
        }
        previous = Some(c)
        i += 1
      }
    }
  }
  total.to_double() / 65536.0
}
