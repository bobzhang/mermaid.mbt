// GIF: the logical screen, grown to hold the first frame where the frame
// reaches beyond it. A file without frames decodes as its screen, as long
// as it reaches the trailer.

///|
fn gif_size(data : Bytes) -> Decoded {
  let view = data[:]
  guard data.length() >= 13 &&
    (view[:6] == b"GIF87a"[:] || view[:6] == b"GIF89a"[:]) else {
    return Undecodable
  }
  let mut width = le16(view, 6)
  let mut height = le16(view, 8)
  let flags = byte(view, 10)
  let mut at = 13
  // The global colour table.
  if (flags & 0x80) != 0 {
    at += 3 * (1 << ((flags & 7) + 1))
  }
  while true {
    guard at < data.length() else { return Undecodable }
    match byte(view, at) {
      // An extension: its label, then data sub-blocks up to an empty one.
      0x21 => {
        at += 2
        while true {
          guard at < data.length() else { return Undecodable }
          let length = byte(view, at)
          at += 1 + length
          if length == 0 {
            break
          }
        }
      }
      // The first frame's descriptor: left, top, width, height (what
      // follows may be missing).
      0x2c => {
        guard at + 9 <= data.length() else { return Undecodable }
        width = width.max(le16(view, at + 1) + le16(view, at + 5))
        height = height.max(le16(view, at + 3) + le16(view, at + 7))
        break
      }
      // The trailer, or a block no GIF has: the end of the file.
      _ => break
    }
  }
  guard width > 0 && height > 0 else { return Undecodable }
  Size(width, height)
}
