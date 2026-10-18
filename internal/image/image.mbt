// The natural size of an image as Chrome reports it for an `<img>`
// (`naturalWidth` and `naturalHeight` once `decode()` has resolved), from
// the image's bytes. mermaid's `imageSquare` shape loads its image to
// learn that size.
//
// Raster images are recognised by their signature whatever type they were
// served as, as Blink sniffs them; an SVG image is one served as
// `image/svg+xml`. Only the headers are read: an image whose headers are
// sound but whose pixel data is corrupt counts as decodable, where Chrome
// would fail on it.

///|
/// What loading an image tells about its natural size.
pub(all) enum Decoded {
  /// The natural width and height, in CSS pixels.
  Size(Int32, Int32)
  /// Chrome cannot decode it: `img.decode()` rejects with "The source
  /// image cannot be decoded."
  Undecodable
  /// An image the port cannot size, and why: a format it does not read,
  /// or an SVG image whose size depends on what the port does not
  /// evaluate.
  Unknown(String)
} derive(Eq, Debug)

///|
/// The message of the error `img.decode()` rejects with.
pub const UNDECODABLE_MESSAGE : String = "The source image cannot be decoded."

///|
/// The essence of the MIME type of SVG images.
const SVG_MIME : String = "image/svg+xml"

///|
/// The natural size of the image in `data`.
///
/// `mime` is the essence of the type it was served as (lower case, without
/// parameters). An image served as `image/svg+xml` is read as SVG only;
/// otherwise it must be one of the raster formats, recognised by its
/// signature. Without a type, bytes in no raster format are read as SVG,
/// as if served with the right type.
pub fn natural_size(data : Bytes, mime? : String) -> Decoded {
  if mime == Some(SVG_MIME) {
    return svg_size(data)
  }
  if has_prefix(data, b"\x89PNG\r\n\x1a\n") {
    png_size(data)
  } else if has_prefix(data, b"GIF8") {
    gif_size(data)
  } else if has_prefix(data, b"\xff\xd8\xff") {
    jpeg_size(data)
  } else if has_prefix(data, b"RIFF") &&
    data.length() >= 14 &&
    data[8:14] == b"WEBPVP"[:] {
    webp_size(data)
  } else if has_prefix(data, b"BM") {
    Unknown("BMP images are not read")
  } else if has_prefix(data, b"\x00\x00\x01\x00") ||
    has_prefix(data, b"\x00\x00\x02\x00") {
    Unknown("ICO and CUR images are not read")
  } else if data.length() >= 12 && data[4:8] == b"ftyp"[:] {
    Unknown("AVIF images are not read")
  } else if mime is None {
    svg_size(data)
  } else {
    Undecodable
  }
}

///|
fn has_prefix(data : Bytes, prefix : Bytes) -> Bool {
  data.length() >= prefix.length() && data[:prefix.length()] == prefix[:]
}

///|
/// The byte at `at`, as an integer.
fn byte(data : BytesView, at : Int32) -> Int32 {
  data[at].to_int()
}

///|
fn be16(data : BytesView, at : Int32) -> Int32 {
  (byte(data, at) << 8) | byte(data, at + 1)
}

///|
fn le16(data : BytesView, at : Int32) -> Int32 {
  byte(data, at) | (byte(data, at + 1) << 8)
}

///|
/// A big-endian 32-bit unsigned number, which may exceed `Int`.
fn be32(data : BytesView, at : Int32) -> Int64 {
  (be16(data, at).to_int64() << 16) | be16(data, at + 2).to_int64()
}

///|
fn le32(data : BytesView, at : Int32) -> Int64 {
  (le16(data, at + 2).to_int64() << 16) | le16(data, at).to_int64()
}

///|
/// A size seen through the image's EXIF orientation: the orientations
/// that turn the image a quarter swap its sides, as `naturalWidth` does
/// (`image-orientation: from-image`).
fn oriented(width : Int32, height : Int32, orientation : Int32) -> Decoded {
  if orientation >= 5 && orientation <= 8 {
    Size(height, width)
  } else {
    Size(width, height)
  }
}
