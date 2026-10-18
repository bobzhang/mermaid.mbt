// Images loaded through the caller's loader, against the oracle's
// renderings of the same images in `data:` URLs: an image at a remote URL
// whose loader gives the bytes of the `data:` URL must draw as that
// `data:` URL does, but for the address on the `<image>`.

///|
/// The fixture an image comes from, as a remote URL.
const REMOTE : String = "https://mermaid.js.org/favicon.svg"

///|
/// The bytes of base64 text.
fn base64_bytes(text : StringView) -> Bytes {
  let out : Array[Byte] = []
  let mut buffer = 0
  let mut bits = 0
  for c in text {
    let value = match c {
      'A'..<='Z' => c.to_int() - 'A'.to_int()
      'a'..<='z' => c.to_int() - 'a'.to_int() + 26
      '0'..<='9' => c.to_int() - '0'.to_int() + 52
      '+' => 62
      '/' => 63
      _ => continue
    }
    buffer = ((buffer << 6) | value) & 0xffffff
    bits += 6
    if bits >= 8 {
      bits -= 8
      out.push(((buffer >> bits) & 0xff).to_byte())
    }
  }
  Bytes::from_array(out)
}

///|
/// The fixture's diagram with its image at `REMOTE`, the bytes of the
/// image, and the oracle's rendering with the `<image>` pointing there.
fn remote_fixture(name : String) -> (String, Bytes, String) raise {
  let root = "testdata/flowchart/icons"
  let source = @fs.read_file_to_string("\{root}/\{name}.mmd")
  let expected = @fs.read_file_to_string("\{root}/\{name}.svg")
  guard source.find("img: \"data:") is Some(start) &&
    source[start + 6:].find("\"") is Some(length) else {
    fail("\{name} has no data: URL")
  }
  let url = source[start + 6:start + 6 + length].to_owned()
  guard url.find(",") is Some(comma) else { fail("\{url} has no data") }
  let data = if url[:comma].has_suffix(";base64") {
    base64_bytes(url[comma + 1:])
  } else {
    @utf8.encode(url[comma + 1:])
  }
  guard expected.find("<image href=\"") is Some(href) &&
    expected[href + 13:].find("\"") is Some(href_length) else {
    fail("\{name}.svg has no image")
  }
  let expected = expected[:href + 13].to_owned() +
    REMOTE +
    expected[href + 13 + href_length:].to_owned()
  (source.replace(old=url, new=REMOTE), data, expected)
}

///|
test "remote images of every format draw as in data: URLs" {
  let failed = []
  for
    name in [
      "images-loaded", "images-jpeg", "images-webp", "images-svg-view-box", "images-png-constrained",
    ] {
    let (source, data, expected) = remote_fixture(name)
    let requested = []
    let loader = (url : String) => {
      requested.push(url)
      if url == REMOTE {
        Some(data)
      } else {
        None
      }
    }
    let actual = @mermaid.render(source, image_loader=loader) catch {
      error => {
        failed.push("\{name}: \{Repr(error)}")
        continue
      }
    }
    if actual != expected || requested != [REMOTE] {
      failed.push(name)
    }
  }
  json_inspect(failed, content=[])
}

///|
test "remote images the loader does not give" {
  let (source, _, _) = remote_fixture("images-loaded")
  let render = (loader : (String) -> Bytes?) => {
    try @mermaid.render(source, image_loader=loader) catch {
      error => Repr(error).to_string()
    } noraise {
      _ => "rendered"
    }
  }
  // No bytes: the size is not known, as without a loader.
  let unknown = render(_ => None)
  assert_true(unknown.has_prefix("Unsupported("))
  assert_eq(
    try @mermaid.render(source) catch {
      error => Repr(error).to_string()
    } noraise {
      _ => "rendered"
    },
    unknown,
  )
  // Bytes that are no image: upstream's `img.decode()` rejects.
  inspect(
    render(_ => Some(@utf8.encode("<html><body>Not found</body></html>"))),
    content=(
      #|Render("The source image cannot be decoded.")
    ),
  )
  inspect(
    render(_ => Some(b"\x89PNG\r\n\x1a\n")),
    content=(
      #|Render("The source image cannot be decoded.")
    ),
  )
}

///|
test "synthetic images through a loader" {
  // The node's size follows the image's: a 150 by 150 SVG, PNGs of odd
  // sizes, an SVG sized by its view box alone.
  let png = (width : Int32, height : Int32) => {
    // IHDR with a valid CRC is all that is read before IDAT.
    let header : Array[Byte] = [
      b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1a', b'\n', b'\x00', b'\x00',
      b'\x00', b'\x0d', b'I', b'H', b'D', b'R',
    ]
    for value in [width, height] {
      for shift in [24, 16, 8, 0] {
        header.push(((value >> shift) & 0xff).to_byte())
      }
    }
    for b in [b'\x08', b'\x02', b'\x00', b'\x00', b'\x00'] {
      header.push(b)
    }
    // The CRC of type and data, then an empty IDAT.
    let mut crc = 0xffffffffU
    for b in header[12:] {
      crc = crc ^ b.to_uint()
      for _ in 0..<8 {
        crc = if (crc & 1U) != 0U { 0xedb88320U ^ (crc >> 1) } else { crc >> 1 }
      }
    }
    crc = crc ^ 0xffffffffU
    for shift in [24, 16, 8, 0] {
      header.push(((crc >> shift) & 0xffU).reinterpret_as_int().to_byte())
    }
    for b in b"\x00\x00\x00\x00IDAT\x35\xaf\x06\x1e" {
      header.push(b)
    }
    Bytes::from_array(header)
  }
  let size = (data : Bytes) => {
    let source =
      #|flowchart TD
      #|  A@{ img: "https://example.com/a", label: "Image", constraint: "on", h: 30 }
    let svg = @mermaid.render(source, image_loader=_ => Some(data)) catch {
      error => return Repr(error).to_string()
    }
    guard svg.find("<image ") is Some(at) &&
      svg[at:].find(">") is Some(end) &&
      svg[at:at + end].find("width=\"") is Some(width) &&
      svg[at + width + 7:].find("\"") is Some(width_end) &&
      svg[at:at + end].find("height=\"") is Some(height) &&
      svg[at + height + 8:].find("\"") is Some(height_end) else {
      return "no image"
    }
    "\{svg[at + width + 7:at + width + 7 + width_end]}x\{svg[at + height + 8:at + height + 8 + height_end]}"
  }
  let svg = (attributes : String) => {
    @utf8.encode(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" \{attributes}></svg>",
    )
  }
  // Constrained to a height of 30, the width keeps the proportions.
  inspect(size(svg("width=\"150\" height=\"150\"")), content="30x30")
  inspect(
    size(png(151, 7)),
    content=(
      #|647.1428571428572x30
    ),
  )
  inspect(size(png(3, 1000)), content="0.09x30")
  inspect(
    size(svg("viewBox=\"0 0 7 3\"")),
    content=(
      #|69.76744186046513x30.000000000000004
    ),
  )
}
