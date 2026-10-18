// WebP: the size of the bitstream of a simple file (VP8 or VP8L), or the
// canvas of an extended one (VP8X), whose bitstream must then have the
// canvas's size unless the image is animated. Chrome applies neither the
// EXIF orientation nor the resolution of a WebP image. The RIFF container
// must be complete.

///|
/// The size a VP8 (lossy) key frame header gives.
fn vp8_size(chunk : BytesView) -> (Int32, Int32)? {
  guard chunk.length() >= 10 else { return None }
  let tag = byte(chunk, 0) | (byte(chunk, 1) << 8) | (byte(chunk, 2) << 16)
  let key_frame = (tag & 1) == 0
  let profile = (tag >> 1) & 7
  let shown = ((tag >> 4) & 1) == 1
  guard key_frame && profile <= 3 && shown && chunk[3:6] == b"\x9d\x01\x2a"[:] else {
    return None
  }
  // The top two bits of each are a scale, which the size ignores.
  let width = le16(chunk, 6) & 0x3fff
  let height = le16(chunk, 8) & 0x3fff
  guard width > 0 && height > 0 else { return None }
  Some((width, height))
}

///|
/// The size a VP8L (lossless) header gives.
fn vp8l_size(chunk : BytesView) -> (Int32, Int32)? {
  guard chunk.length() >= 5 && byte(chunk, 0) == 0x2f else { return None }
  let bits = le32(chunk, 1)
  // The version, in the top three bits, is 0.
  guard bits >> 29 == 0L else { return None }
  let width = (bits & 0x3fffL).to_int() + 1
  let height = ((bits >> 14) & 0x3fffL).to_int() + 1
  Some((width, height))
}

///|
fn webp_size(data : Bytes) -> Decoded {
  let view = data[:]
  let riff_size = le32(view, 4)
  guard riff_size >= 12L && riff_size + 8L <= data.length().to_int64() else {
    return Undecodable
  }
  let end = riff_size.to_int() + 8
  // The chunks: four-character code, little-endian length, data padded to
  // an even length.
  let chunks : Array[(BytesView, BytesView)] = []
  let mut at = 12
  while at + 8 <= end {
    let length = le32(view, at + 4)
    guard length <= (end - at - 8).to_int64() else { return Undecodable }
    chunks.push((view[at:at + 4], view[at + 8:at + 8 + length.to_int()]))
    at += 8 + length.to_int() + (length.to_int() & 1)
  }
  let bitstream = (kind : BytesView, chunk : BytesView) => {
    if kind == b"VP8 "[:] {
      vp8_size(chunk)
    } else if kind == b"VP8L"[:] {
      vp8l_size(chunk)
    } else {
      None
    }
  }
  guard chunks is [(first, first_data), ..] else { return Undecodable }
  if first != b"VP8X"[:] {
    return match bitstream(first, first_data) {
      Some((width, height)) => Size(width, height)
      None => Undecodable
    }
  }
  guard first_data.length() >= 10 else { return Undecodable }
  let flags = byte(first_data, 0)
  let width = (
      byte(first_data, 4) |
      (byte(first_data, 5) << 8) |
      (byte(first_data, 6) << 16)
    ) +
    1
  let height = (
      byte(first_data, 7) |
      (byte(first_data, 8) << 8) |
      (byte(first_data, 9) << 16)
    ) +
    1
  // An animation: the canvas, whatever its frames.
  if (flags & 0x02) != 0 {
    return Size(width, height)
  }
  for chunk in chunks[1:] {
    let (kind, chunk_data) = chunk
    if kind == b"VP8 "[:] || kind == b"VP8L"[:] {
      return match bitstream(kind, chunk_data) {
        Some(size) if size == (width, height) => Size(width, height)
        _ => Undecodable
      }
    }
  }
  Undecodable
}
