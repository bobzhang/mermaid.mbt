// EXIF metadata (a TIFF structure), for what Chrome takes from it: the
// orientation, and the resolution and pixel dimensions that correct the
// size of a JPEG image.

///|
/// What an EXIF block says about the image's geometry.
priv struct Exif {
  /// 1 to 8; 1, the upright default, when absent or out of range.
  orientation : Int32
  /// `ResolutionUnit`: 2 for inches, 3 for centimetres.
  resolution_unit : Int32?
  x_resolution : Float?
  y_resolution : Float?
  /// `PixelXDimension` and `PixelYDimension` of the EXIF sub-directory.
  pixel_width : Int32?
  pixel_height : Int32?
}

///|
let no_exif : Exif = {
  orientation: 1,
  resolution_unit: None,
  x_resolution: None,
  y_resolution: None,
  pixel_width: None,
  pixel_height: None,
}

///|
/// The tags of the TIFF directories Chrome reads.
const TAG_ORIENTATION : Int32 = 0x0112

///|
const TAG_X_RESOLUTION : Int32 = 0x011a

///|
const TAG_Y_RESOLUTION : Int32 = 0x011b

///|
const TAG_RESOLUTION_UNIT : Int32 = 0x0128

///|
const TAG_EXIF_DIRECTORY : Int32 = 0x8769

///|
const TAG_PIXEL_X_DIMENSION : Int32 = 0xa002

///|
const TAG_PIXEL_Y_DIMENSION : Int32 = 0xa003

///|
/// A TIFF structure of either byte order.
priv struct Tiff {
  data : BytesView
  little_endian : Bool
}

///|
fn Tiff::u16(self : Tiff, at : Int32) -> Int32? {
  guard at >= 0 && at + 2 <= self.data.length() else { return None }
  Some(
    if self.little_endian {
      le16(self.data, at)
    } else {
      be16(self.data, at)
    },
  )
}

///|
fn Tiff::u32(self : Tiff, at : Int32) -> Int64? {
  guard at >= 0 && at + 4 <= self.data.length() else { return None }
  Some(
    if self.little_endian {
      le32(self.data, at)
    } else {
      be32(self.data, at)
    },
  )
}

///|
/// The entries of the directory at `offset`: tag, type, and the offset of
/// the entry's value field.
fn Tiff::directory(self : Tiff, offset : Int64) -> Array[(Int32, Int32, Int32)] {
  let entries = []
  guard offset >= 0L && offset < self.data.length().to_int64() else {
    return entries
  }
  let start = offset.to_int()
  guard self.u16(start) is Some(count) else { return entries }
  for i in 0..<count {
    let at = start + 2 + i * 12
    guard self.u16(at) is Some(tag) &&
      self.u16(at + 2) is Some(kind) &&
      at + 12 <= self.data.length() else {
      break
    }
    entries.push((tag, kind, at + 8))
  }
  entries
}

///|
/// An unsigned integer value (SHORT or LONG).
fn Tiff::integer(self : Tiff, kind : Int32, at : Int32) -> Int64? {
  match kind {
    3 => self.u16(at).map(value => value.to_int64())
    4 => self.u32(at)
    _ => None
  }
}

///|
/// A RATIONAL value, which lives at the offset in the value field.
fn Tiff::rational(self : Tiff, kind : Int32, at : Int32) -> Float? {
  guard kind == 5 &&
    self.u32(at) is Some(offset) &&
    offset <= 0x7fffffffL &&
    self.u32(offset.to_int()) is Some(numerator) &&
    self.u32(offset.to_int() + 4) is Some(denominator) &&
    denominator != 0L else {
    return None
  }
  Some(
    Float::from_double(numerator.to_double()) /
    Float::from_double(denominator.to_double()),
  )
}

///|
/// Read an EXIF block that starts with its TIFF header (what follows
/// `Exif\0\0` in a JPEG APP1 segment, or a PNG eXIf chunk).
fn parse_exif(data : BytesView) -> Exif {
  guard data.length() >= 8 else { return no_exif }
  let little_endian = match (byte(data, 0), byte(data, 1)) {
    (0x49, 0x49) => true
    (0x4d, 0x4d) => false
    _ => return no_exif
  }
  let tiff = { data, little_endian, }
  guard tiff.u16(2) == Some(42) && tiff.u32(4) is Some(first) else {
    return no_exif
  }
  let mut exif = no_exif
  for entry in tiff.directory(first) {
    let (tag, kind, at) = entry
    match tag {
      TAG_ORIENTATION =>
        if tiff.integer(kind, at) is Some(value) && value >= 1L && value <= 8L {
          exif = { ..exif, orientation: value.to_int(), }
        }
      TAG_RESOLUTION_UNIT =>
        exif = {
          ..exif,
          resolution_unit: tiff.integer(kind, at).map(value => value.to_int()),
        }
      TAG_X_RESOLUTION =>
        exif = { ..exif, x_resolution: tiff.rational(kind, at), }
      TAG_Y_RESOLUTION =>
        exif = { ..exif, y_resolution: tiff.rational(kind, at), }
      TAG_EXIF_DIRECTORY =>
        if tiff.integer(kind, at) is Some(offset) {
          for sub in tiff.directory(offset) {
            let (tag, kind, at) = sub
            let value = tiff
              .integer(kind, at)
              .filter(value => value <= 0x7fffffffL)
              .map(value => value.to_int())
            if tag == TAG_PIXEL_X_DIMENSION {
              exif = { ..exif, pixel_width: value, }
            } else if tag == TAG_PIXEL_Y_DIMENSION {
              exif = { ..exif, pixel_height: value, }
            }
          }
        }
      _ => ()
    }
  }
  exif
}

///|
/// Blink's density-corrected size of a JPEG image: the EXIF pixel
/// dimensions, when they are what the physical size comes to at the EXIF
/// resolution in dots per inch, taking 72 as one CSS pixel per dot.
fn density_corrected(
  width : Int32,
  height : Int32,
  exif : Exif,
) -> (Int32, Int32) {
  guard exif.resolution_unit == Some(2) &&
    exif.x_resolution is Some(x_resolution) &&
    exif.y_resolution is Some(y_resolution) &&
    x_resolution > 0.0 &&
    y_resolution > 0.0 &&
    exif.pixel_width is Some(pixel_width) &&
    exif.pixel_height is Some(pixel_height) &&
    pixel_width > 0 &&
    pixel_height > 0 else {
    return (width, height)
  }
  // gfx::SizeF arithmetic, then gfx::ToRoundedSize.
  let corrected = (pixels : Int32, resolution : Float) => {
    let size = Float::from_int(pixels * 72) / resolution
    (size.to_double() + 0.5).floor()
  }
  if corrected(width, x_resolution) == pixel_width.to_double() &&
    corrected(height, y_resolution) == pixel_height.to_double() {
    (pixel_width, pixel_height)
  } else {
    (width, height)
  }
}
