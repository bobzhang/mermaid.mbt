// PNG: the size is that of the IHDR chunk, turned by the orientation of an
// eXIf chunk (Chrome applies the orientation of a PNG, not its EXIF
// resolution). The image decodes when IHDR is sound and the chunks up to
// the first IDAT are complete, those Chrome cannot skip with intact CRCs.

///|
/// The CRC-32 of PNG chunks (ISO 3309), one entry per byte value.
let crc_table : FixedArray[UInt32] = {
  let table = FixedArray::make(256, 0U)
  for n in 0..<256 {
    let mut c = n.reinterpret_as_uint()
    for _ in 0..<8 {
      c = if (c & 1U) != 0U { 0xedb88320U ^ (c >> 1) } else { c >> 1 }
    }
    table[n] = c
  }
  table
}

///|
fn crc32(data : BytesView) -> UInt32 {
  let mut c = 0xffffffffU
  for b in data {
    c = crc_table[((c ^ b.to_uint()) & 0xffU).reinterpret_as_int()] ^ (c >> 8)
  }
  c ^ 0xffffffffU
}

///|
/// Whether a bit depth suits a PNG colour type.
fn png_depth_valid(color_type : Int32, depth : Int32) -> Bool {
  match color_type {
    0 => depth is (1 | 2 | 4 | 8 | 16)
    3 => depth is (1 | 2 | 4 | 8)
    2 | 4 | 6 => depth is (8 | 16)
    _ => false
  }
}

///|
fn png_size(data : Bytes) -> Decoded {
  let view = data[:]
  // The signature, then IHDR: length, type, 13 bytes of data, CRC.
  guard data.length() >= 33 &&
    be32(view, 8) == 13L &&
    view[12:16] == b"IHDR"[:] &&
    crc32(view[12:29]).to_int64() == be32(view, 29) else {
    return Undecodable
  }
  let width = be32(view, 16)
  let height = be32(view, 20)
  let depth = byte(view, 24)
  let color_type = byte(view, 25)
  guard width > 0L &&
    width <= 0x7fffffffL &&
    height > 0L &&
    height <= 0x7fffffffL &&
    png_depth_valid(color_type, depth) &&
    byte(view, 26) == 0 &&
    byte(view, 27) == 0 &&
    byte(view, 28) <= 1 else {
    return Undecodable
  }
  let mut orientation = 1
  let mut at = 33
  while true {
    guard at + 12 <= data.length() else { return Undecodable }
    let length = be32(view, at)
    guard length <= (data.length() - at - 12).to_int64() else {
      return Undecodable
    }
    let end = at + 8 + length.to_int()
    let kind = view[at + 4:at + 8]
    let intact = crc32(view[at + 4:end]).to_int64() == be32(view, end)
    // A critical chunk (upper-case first letter) with a broken CRC stops
    // the decoder; an ancillary one is skipped.
    let critical = byte(kind, 0) < 0x61
    guard intact || !critical else { return Undecodable }
    if kind == b"IDAT"[:] {
      break
    } else if kind == b"IEND"[:] {
      return Undecodable
    } else if kind == b"eXIf"[:] && intact {
      orientation = parse_exif(view[at + 8:end]).orientation
    }
    at = end + 4
  }
  oriented(width.to_int(), height.to_int(), orientation)
}
