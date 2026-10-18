// JPEG: the size of the frame header, corrected by the EXIF resolution and
// turned by the EXIF orientation of the first APP1 segment that holds
// EXIF data. The image decodes when its segments are complete up to the
// start of the scan.

///|
/// Whether a marker starts a frame (SOF0 to SOF15, which leave out DHT,
/// JPG and DAC).
fn is_frame_marker(marker : Int32) -> Bool {
  marker >= 0xc0 && marker <= 0xcf && !(marker is (0xc4 | 0xc8 | 0xcc))
}

///|
fn jpeg_size(data : Bytes) -> Decoded {
  let view = data[:]
  let mut at = 2
  let mut frame : (Int32, Int32)? = None
  let mut exif : Exif? = None
  while true {
    // libjpeg skips stray bytes before a marker, and fill bytes.
    while at < data.length() && byte(view, at) != 0xff {
      at += 1
    }
    while at < data.length() && byte(view, at) == 0xff {
      at += 1
    }
    guard at < data.length() else { return Undecodable }
    let marker = byte(view, at)
    at += 1
    // Markers without a segment.
    if marker is (0x01 | 0xd0..<=0xd7) {
      continue
    }
    guard !(marker is (0xd8 | 0xd9)) && at + 2 <= data.length() else {
      return Undecodable
    }
    let length = be16(view, at)
    guard length >= 2 && at + length <= data.length() else {
      return Undecodable
    }
    let segment = view[at + 2:at + length]
    at += length
    if marker == 0xda {
      break
    } else if marker == 0xe1 &&
      exif is None &&
      segment.length() >= 6 &&
      segment[:6] == b"Exif\x00\x00"[:] {
      exif = Some(parse_exif(segment[6:]))
    } else if is_frame_marker(marker) && frame is None {
      guard segment.length() >= 6 else { return Undecodable }
      // Baseline, extended and progressive frames; Chrome's libjpeg-turbo
      // may decode others, which the port does not presume.
      guard marker is (0xc0 | 0xc1 | 0xc2) else {
        return Unknown("JPEG frames of type SOF\{marker - 0xc0} are not read")
      }
      let height = be16(segment, 1)
      let width = be16(segment, 3)
      // A height of 0 defers it to a DNL marker, which libjpeg-turbo
      // refuses.
      guard width > 0 && height > 0 else { return Undecodable }
      frame = Some((width, height))
    }
  }
  guard frame is Some((width, height)) else { return Undecodable }
  let exif = exif.unwrap_or(no_exif)
  let (width, height) = density_corrected(width, height, exif)
  oriented(width, height, exif.orientation)
}
