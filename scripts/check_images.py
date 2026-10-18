#!/usr/bin/env python3
"""Check the natural sizes of images (`internal/image`) against Chrome.

Synthetic images of every format the port reads (PNG, GIF, JPEG, WebP, SVG),
sound and broken, with EXIF orientations and resolutions, odd SVG lengths
and view boxes, malformed XML, and `data:` URLs written every way, are
loaded in the oracle's Chrome as `<img>` sources (`naturalWidth` and
`naturalHeight` once `decode()` resolves) and sized by
`cmd/mermaid image-size`; every difference is reported. The port answers
`unknown` where it does not presume to know (BMP, font-relative SVG
lengths, `calc()`); those are listed apart. Nothing is loaded from the
network: every image is a `data:` URL.

Usage: python3 scripts/check_images.py [-v]
"""

import argparse
import base64
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import compare  # noqa: E402
import oracle  # noqa: E402

# Lossy and lossless WebP bitstreams come from Chrome's own encoder.
CANVAS = """(() => {
  const canvas = document.createElement("canvas");
  const out = {};
  for (const [name, width, height, quality] of [["lossy", 37, 23, 0.5], ["lossless", 5, 9, 1]]) {
    canvas.width = width; canvas.height = height;
    const context = canvas.getContext("2d");
    context.fillStyle = "#123"; context.fillRect(0, 0, width, height);
    out[name] = canvas.toDataURL("image/webp", quality).split(",")[1];
  }
  return out;
})()"""

SIZE = """(async () => {
  const out = [];
  for (const url of %s) {
    const image = new Image();
    image.src = url;
    try {
      await image.decode();
      out.push(image.naturalWidth + "x" + image.naturalHeight);
    } catch (error) {
      out.push(error.message === "The source image cannot be decoded." ? "undecodable" : "error " + error.message);
    }
  }
  return out;
})()"""


def b64(data): return base64.b64encode(data).decode()
def url(mime, data): return f"data:{mime};base64,{b64(data)}"

# PNG
def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)
def png(w, h, extra=b"", color=2, depth=8, ihdr_patch=None):
    ihdr = struct.pack(">IIBBBBB", w, h, depth, color, 0, 0, 0)
    if ihdr_patch: ihdr = ihdr_patch(ihdr)
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color] * depth // 8
    raw = b"".join(b"\0" + b"\0" * max(1, w * bpp) for _ in range(h))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + extra + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")

# EXIF (little-endian TIFF unless big)
def tiff(entries, sub=None, big=False):
    e = ">" if big else "<"
    out = bytearray(b"MM\0*" if big else b"II*\0") + struct.pack(e + "I", 8)
    allent = list(entries) + ([(0x8769, 4, 1, 0)] if sub else [])
    allent.sort()
    ifd_size = 2 + 12 * len(allent) + 4
    extra_at = 8 + ifd_size
    sub_at = extra_at
    sub_size = 2 + 12 * len(sub) + 4 if sub else 0
    extra_at += sub_size
    extra = bytearray()
    out += struct.pack(e + "H", len(allent))
    for tag, kind, count, value in allent:
        out += struct.pack(e + "HHI", tag, kind, count)
        if tag == 0x8769: out += struct.pack(e + "I", sub_at)
        elif kind == 5:
            out += struct.pack(e + "I", extra_at + len(extra)); extra += struct.pack(e + "II", *value)
        elif kind == 3: out += struct.pack(e + "HH", value, 0)
        else: out += struct.pack(e + "I", value)
    out += struct.pack(e + "I", 0)
    if sub:
        out += struct.pack(e + "H", len(sub))
        for tag, kind, count, value in sub:
            out += struct.pack(e + "HHI", tag, kind, count)
            out += struct.pack(e + "HH", value, 0) if kind == 3 else struct.pack(e + "I", value)
        out += struct.pack(e + "I", 0)
    return bytes(out + extra)

# A minimal baseline JPEG, one grey component, every block flat.
def segment(marker, data): return bytes([0xff, marker]) + struct.pack(">H", len(data) + 2) + data
def jpeg(w, h, app=b"", sof=0xc0, after_sof=b""):
    dqt = segment(0xdb, b"\x00" + b"\x01" * 64)
    sof_seg = segment(sof, struct.pack(">BHHB", 8, h, w, 1) + b"\x01\x11\x00")
    one_code = b"\x01" + b"\x00" * 15
    dht = segment(0xc4, b"\x00" + one_code + b"\x00") + segment(0xc4, b"\x10" + one_code + b"\x00")
    sos = segment(0xda, b"\x01\x01\x00\x00\x3f\x00")
    blocks = -(-w // 8) * -(-h // 8)
    bits = "00" * blocks
    bits += "1" * (-len(bits) % 8)
    data = bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))
    data = data.replace(b"\xff", b"\xff\x00")
    return b"\xff\xd8" + app + dqt + sof_seg + after_sof + dht + sos + data + b"\xff\xd9"
def app1(t): return segment(0xe1, b"Exif\0\0" + t)

# WebP from Chrome's canvas, without the VP8X and ICCP chunks.
def webp_chunks(data):
    out, at = [], 12
    while at + 8 <= len(data):
        kind = data[at:at + 4]; n = struct.unpack("<I", data[at + 4:at + 8])[0]
        out.append((kind, data[at + 8:at + 8 + n])); at += 8 + n + (n & 1)
    return out
def riff(chunks):
    body = b"WEBP"
    for kind, data in chunks:
        body += kind + struct.pack("<I", len(data)) + data + (b"\0" if len(data) & 1 else b"")
    return b"RIFF" + struct.pack("<I", len(body)) + body
def vp8x(flags, w, h): return (b"VP8X", bytes([flags, 0, 0, 0]) + (w - 1).to_bytes(3, "little") + (h - 1).to_bytes(3, "little"))

# GIF
def gif(sw, sh, frames=(), pre=b"", gct=True, trailer=True, version=b"89a"):
    out = b"GIF" + version + struct.pack("<HH", sw, sh) + (b"\x80\0\0" + b"\0\0\0\xff\xff\xff" if gct else b"\0\0\0")
    for fx, fy, fw, fh in frames:
        out += pre + b"\x2c" + struct.pack("<HHHH", fx, fy, fw, fh) + b"\0\x02\x02\x44\x01\0"
    return out + (b"\x3b" if trailer else b"")

S = 'xmlns="http://www.w3.org/2000/svg"'
def svg(text): return url("image/svg+xml", text.encode("utf-8"))



def build_cases(webp):
    lossy = [c for c in webp_chunks(base64.b64decode(webp["lossy"])) if c[0] == b"VP8 "]
    lossless = [c for c in webp_chunks(base64.b64decode(webp["lossless"])) if c[0] == b"VP8L"]
    cases = {}
    # PNG
    for w, h in [(37, 23), (1, 1), (151, 7), (3, 1000)]:
        cases[f"png {w}x{h}"] = url("image/png", png(w, h))
    cases["png palette 2-bit"] = url("image/png", png(9, 5, color=3, depth=2, extra=chunk(b"PLTE", b"\0\0\0\xff\xff\xff")))
    cases["png grey 16-bit"] = url("image/png", png(9, 5, color=0, depth=16))
    cases["png bad depth"] = url("image/png", png(9, 5, color=2, depth=4))
    cases["png zero width"] = url("image/png", png(0, 5))
    cases["png ihdr crc"] = url("image/png", (lambda d: d[:29] + bytes([d[29] ^ 1]) + d[30:])(png(9, 5)))
    cases["png truncated ihdr"] = url("image/png", png(9, 5)[:30])
    cases["png no idat"] = url("image/png", png(9, 5)[:33] + chunk(b"IEND", b""))
    cases["png no iend"] = url("image/png", png(9, 5)[:-12])
    cases["png ancillary crc"] = url("image/png", png(9, 5, extra=chunk(b"tEXt", b"a\0b")[:-1] + b"\0"))
    cases["png exif 6"] = url("image/png", png(9, 5, extra=chunk(b"eXIf", tiff([(0x112, 3, 1, 6)]))))
    cases["png exif 3"] = url("image/png", png(9, 5, extra=chunk(b"eXIf", tiff([(0x112, 3, 1, 3)]))))
    cases["png exif density"] = url("image/png", png(37, 23, extra=chunk(b"eXIf", tiff([(0x11a, 5, 1, (144, 1)), (0x11b, 5, 1, (144, 1)), (0x128, 3, 1, 2)], [(0xa002, 4, 1, 19), (0xa003, 4, 1, 12)]))))
    cases["png phys"] = url("image/png", png(9, 5, extra=chunk(b"pHYs", struct.pack(">IIB", 5669, 5669, 1))))
    cases["png served as text"] = url("text/plain", png(9, 5))
    cases["png served as svg"] = url("image/svg+xml", png(9, 5))
    # JPEG
    for w, h in [(37, 23), (1, 1), (8, 8), (9, 1000)]:
        cases[f"jpeg {w}x{h}"] = url("image/jpeg", jpeg(w, h))
    cases["jpeg progressive header"] = url("image/jpeg", jpeg(37, 23, sof=0xc2))
    for o in [1, 2, 3, 4, 5, 6, 7, 8, 0, 9]:
        cases[f"jpeg orientation {o}"] = url("image/jpeg", jpeg(37, 23, app=app1(tiff([(0x112, 3, 1, o)]))))
    cases["jpeg orientation 6 big-endian"] = url("image/jpeg", jpeg(37, 23, app=app1(tiff([(0x112, 3, 1, 6)], big=True))))
    cases["jpeg orientation after app0"] = url("image/jpeg", jpeg(37, 23, app=segment(0xe0, b"JFIF\0\x01\x01\0\0\x01\0\x01\0\0") + app1(tiff([(0x112, 3, 1, 6)]))))
    cases["jpeg first exif wins"] = url("image/jpeg", jpeg(37, 23, app=app1(tiff([(0x112, 3, 1, 1)])) + app1(tiff([(0x112, 3, 1, 6)]))))
    cases["jpeg xmp app1 first"] = url("image/jpeg", jpeg(37, 23, app=segment(0xe1, b"http://ns.adobe.com/xap/1.0/\0<x/>") + app1(tiff([(0x112, 3, 1, 6)]))))
    cases["jpeg exif after frame"] = url("image/jpeg", jpeg(37, 23, after_sof=app1(tiff([(0x112, 3, 1, 6)]))))
    def dens(xr, yr, unit, px, py, o=None, pxkind=4):
        ent = [(0x11a, 5, 1, xr if isinstance(xr, tuple) else (xr, 1)), (0x11b, 5, 1, yr if isinstance(yr, tuple) else (yr, 1))]
        if unit is not None: ent.append((0x128, 3, 1, unit))
        if o: ent.append((0x112, 3, 1, o))
        sub = [(0xa002, pxkind, 1, px), (0xa003, pxkind, 1, py)] if px is not None else None
        return url("image/jpeg", jpeg(37, 23, app=app1(tiff(ent, sub))))
    cases["jpeg density 144"] = dens(144, 144, 2, 19, 12)
    cases["jpeg density floor"] = dens(144, 144, 2, 18, 11)
    cases["jpeg density 144 orientation 6"] = dens(144, 144, 2, 19, 12, 6)
    cases["jpeg density turned dimensions"] = dens(144, 144, 2, 12, 19, 6)
    cases["jpeg density 36"] = dens(36, 36, 2, 74, 46)
    cases["jpeg density cm"] = dens(144, 144, 3, 19, 12)
    cases["jpeg density no unit"] = dens(144, 144, None, 19, 12)
    cases["jpeg density mixed"] = dens(144, 72, 2, 19, 23)
    cases["jpeg density rational"] = dens((288, 2), (288, 2), 2, 19, 12)
    cases["jpeg density short dimensions"] = dens(144, 144, 2, 19, 12, pxkind=3)
    cases["jpeg density zero"] = dens(0, 144, 2, 19, 12)
    cases["jpeg density zero denominator"] = dens((144, 0), 144, 2, 19, 12)
    cases["jpeg density no dimensions"] = dens(144, 144, 2, None, None)
    cases["jpeg density 100"] = dens(100, 100, 2, 27, 17)
    cases["jpeg no eoi"] = url("image/jpeg", jpeg(37, 23)[:-2])
    cases["jpeg no scan"] = url("image/jpeg", jpeg(37, 23).split(b"\xff\xda")[0])
    cases["jpeg zero height"] = url("image/jpeg", jpeg(37, 0))
    cases["jpeg served as text"] = url("text/plain", jpeg(5, 9))
    # WebP
    cases["webp lossy"] = url("image/webp", riff(lossy))
    cases["webp lossless"] = url("image/webp", riff(lossless))
    cases["webp extended"] = url("image/webp", riff([vp8x(0, 37, 23)] + lossy))
    cases["webp extended exif 6"] = url("image/webp", riff([vp8x(0x08, 37, 23)] + lossy + [(b"EXIF", tiff([(0x112, 3, 1, 6)]))]))
    cases["webp extended larger canvas"] = url("image/webp", riff([vp8x(0, 40, 23)] + lossy))
    cases["webp extended smaller canvas"] = url("image/webp", riff([vp8x(0, 5, 5)] + lossless))
    cases["webp extended no bitstream"] = url("image/webp", riff([vp8x(0, 37, 23)]))
    cases["webp truncated"] = url("image/webp", riff(lossy)[:-6])
    cases["webp extra bytes"] = url("image/webp", riff(lossless) + b"\0\0\0\0")
    cases["webp served as text"] = url("text/plain", riff(lossless))
    # GIF
    cases["gif 1x1"] = url("image/gif", gif(1, 1, [(0, 0, 1, 1)]))
    cases["gif frame beyond screen"] = url("image/gif", gif(1, 1, [(0, 0, 5, 7)]))
    cases["gif frame inside screen"] = url("image/gif", gif(9, 4, [(0, 0, 1, 1)]))
    cases["gif zero screen"] = url("image/gif", gif(0, 0, [(0, 0, 3, 2)]))
    cases["gif offset frame"] = url("image/gif", gif(4, 4, [(3, 3, 2, 2)]))
    cases["gif second frame larger"] = url("image/gif", gif(2, 2, [(0, 0, 1, 1), (0, 0, 6, 8)]))
    cases["gif extensions"] = url("image/gif", gif(2, 2, [(0, 0, 3, 3)], pre=b"\x21\xf9\x04\0\0\0\0\0\x21\xfe\x03abc\0"))
    cases["gif 87a"] = url("image/gif", gif(2, 3, [(0, 0, 2, 3)], version=b"87a"))
    cases["gif 88a"] = url("image/gif", gif(2, 3, [(0, 0, 2, 3)], version=b"88a"))
    cases["gif no frames"] = url("image/gif", gif(3, 4, gct=False))
    cases["gif no frames zero screen"] = url("image/gif", gif(0, 0, gct=False))
    cases["gif header only"] = url("image/gif", gif(3, 4, gct=False, trailer=False))
    cases["gif truncated colour table"] = url("image/gif", gif(2, 2, gct=True, trailer=False)[:16])
    cases["gif unknown block"] = url("image/gif", gif(2, 2, gct=False, trailer=False) + b"\x55\x3b")
    cases["gif descriptor only"] = url("image/gif", gif(2, 2, gct=False, trailer=False) + b"\x2c\0\0\0\0\x03\0\x03\0\0")
    cases["gif short descriptor"] = url("image/gif", gif(2, 2, gct=False, trailer=False) + b"\x2c\0\0\0\0\x03\0\x03\0")
    # Not images
    cases["text"] = url("image/png", b"not an image")
    cases["empty"] = url("image/png", b"")
    cases["bmp"] = "data:image/bmp;base64,Qk06AAAAAAAAADYAAAAoAAAAAQAAAAEAAAABABgAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wA="
    # data: URLs
    small = png(9, 5)
    cases["url base64 with spaces"] = "data:image/png;base64," + " ".join(b64(small)[i:i + 4] for i in range(0, len(b64(small)), 4))
    cases["url base64 without padding"] = "data:image/png;base64," + b64(small + b"\0").rstrip("=")
    cases["url base64 one padding"] = "data:image/png;base64," + b64(small + b"\0\0").rstrip("=") + "="
    cases["url base64 url-safe"] = "data:image/png;base64," + b64(small).replace("+", "-").replace("/", "_") + "-_"
    cases["url base64 junk"] = "data:image/png;base64," + b64(small) + "!!"
    cases["url base64 percent"] = "data:image/png;base64," + b64(small).replace("+", "%2B").replace("/", "%2F")
    cases["url base64 upper case"] = "data:image/png;BASE64," + b64(small)
    cases["url base64 space before"] = "data:image/png; base64," + b64(small)
    cases["url scheme upper case"] = "DATA:image/png;base64," + b64(small)
    cases["url no comma"] = "data:image/png;base64"
    cases["url leading space"] = "  data:image/png;base64," + b64(small)
    cases["url newline inside"] = "data:image/png;base64," + b64(small)[:10] + "\n" + b64(small)[10:]
    cases["url svg plain"] = "data:image/svg+xml," + f'<svg {S} width="12" height="13"/>'
    cases["url svg percent-encoded"] = "data:image/svg+xml," + "".join("%%%02X" % b for b in f'<svg {S} width="12" height="13"/>'.encode())
    cases["url svg fragment"] = "data:image/svg+xml," + f'<svg {S} width="12" height="13"><g fill="#fff"/></svg>'
    cases["url svg utf8 parameter"] = "data:image/svg+xml;utf8," + f'<svg {S} width="12" height="13"/>'
    cases["url svg charset"] = "data:image/svg+xml;charset=utf-8;base64," + b64(f'<svg {S} width="12" height="13"/>'.encode())
    cases["url svg type spaces"] = "data: image/svg+xml ;base64," + b64(f'<svg {S} width="12" height="13"/>'.encode())
    cases["url svg type upper case"] = "data:IMAGE/SVG+XML;base64," + b64(f'<svg {S} width="12" height="13"/>'.encode())
    cases["url svg as text"] = "data:text/plain;base64," + b64(f'<svg {S} width="12" height="13"/>'.encode())
    cases["url svg no type"] = "data:;base64," + b64(f'<svg {S} width="12" height="13"/>'.encode())
    cases["url svg non-ascii"] = "data:image/svg+xml," + f'<svg {S} width="12" height="13"><text>é</text></svg>'
    # SVG sizes
    def svgw(v): return svg(f'<svg {S} width="{v}" height="20"></svg>')
    for v in ["150", "10.5", "11.5", "0.5", "2.5", "0.49", "1.4999", "10.25", "0", "-5", "-0", "abc", "10px", "10PX", " 10 ", "\t12\t", "10 px", "1e1", "1E1", "1e+1", "1e-1", "+10", ".5", "10.", "10e", "10in", "1in ", "1cm", "10mm", "1q", "10Q", "10pt", "1pc", "2em", "1rem", "100em", "5ex", "2ch", "10lh", "10vw", "10vh", "10vmin", "10svw", "10cqw", "10%", "100%", "auto", "10x", "calc(10px + 5px)", "1e400", "1e7", "100000000", "33554431", " 12"]:
        cases[f"svg width {v!r}"] = svgw(v)
    for v in ["0 0 100 50", "0 0 50 100", "0 0 7 3", "0,0,7,3", "0, 0, 7, 3", "0 0 7.5 3", "0 0 3 7", "0 0 1000 1", "0 0 1 1000", "  0 0 10 5  ", "0 0 2 1", "0 0 2.0001 1", "0 0 1.9999 1", "-5 -5 30 10", "0 0 3e1 1e1", "0 0 0 10", "0 0 -1 10", "0 0 10", "1 2 3 4 5", "0 0 30 10 x", "none", "0,,0,7,3", "0 0 7 3,"]:
        cases[f"svg viewBox {v!r}"] = svg(f'<svg {S} viewBox="{v}"></svg>')
    for attrs in ['width="150" height="150"', '', 'width="40"', 'height="40"', 'width="40" viewBox="0 0 100 50"', 'height="40" viewBox="0 0 100 50"', 'width="50%" height="20" viewBox="0 0 100 50"', 'width="50%" height="50%" viewBox="0 0 30 10"', 'width="50%" height="50%"', 'width="0" viewBox="0 0 30 10"', 'width="33" viewBox="0 0 7 3"', 'height="33" viewBox="0 0 7 3"', 'width="33" viewBox="0 0 3 7"', 'height="33" viewBox="0 0 3 7"', 'width="33" viewBox="0 0 1000 1"', 'height="33" viewBox="0 0 1000 1"', 'height="1em" viewBox="0 0 30 10"', 'width="2em" height="2em" font-size="20"', 'width="2em" height="2em" style="font-size:30px"', 'width="2em" height="13" style="fill:red"', 'style="width: 50px; height: 60px"', 'style="width: 50px" width="12" height="13"', 'xmlns:q="urn:q" q:width="40" width="12" height="13"', 'viewBox="0 0 7 3" preserveAspectRatio="none"', 'viewBox="0 0 7 3" preserveAspectRatio=" none "', 'viewBox="0 0 7 3" preserveAspectRatio="none meet"', 'viewBox="0 0 7 3" preserveAspectRatio="none slice"', 'viewBox="0 0 7 3" preserveAspectRatio="defer none"', 'viewBox="0 0 7 3" preserveAspectRatio="xMinYMin slice"', 'viewBox="0 0 7 3" preserveAspectRatio="NONE"', 'viewBox="0 0 7 3" preserveAspectRatio="none garbage"', 'width="70" viewBox="0 0 7 3" preserveAspectRatio="none"', 'height="20" viewBox="0 0 7 3" preserveAspectRatio="none"', 'width="70" height="20" viewBox="0 0 7 3" preserveAspectRatio="none"', 'width="70" preserveAspectRatio="none"', 'width="70" height="20" preserveAspectRatio="none"']:
        cases[f"svg attributes {attrs!r}"] = svg(f'<svg {S} {attrs}></svg>')
    cases["svg style element em"] = svg(f'<svg {S} width="2em" height="13"><style>svg{{font-size:30px}}</style></svg>')
    # XML
    docs = {
        "prolog": f'<?xml version="1.0" encoding="UTF-8"?>\n<!-- c -->\n<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n<svg {S} width="12" height="13"/>',
        "standalone": f'<?xml version="1.0" standalone="yes"?><svg {S} width="12" height="13"/>',
        "standalone maybe": f'<?xml version="1.0" encoding="UTF-8" standalone="maybe"?><svg {S} width="12" height="13"/>',
        "version 1.1": f'<?xml version="1.1"?><svg {S} width="12" height="13"/>',
        "version 2.0": f'<?xml version="2.0"?><svg {S} width="12" height="13"/>',
        "declaration after space": f' <?xml version="1.0"?><svg {S} width="12" height="13"/>',
        "declaration without version": f'<?xml encoding="UTF-8"?><svg {S} width="12" height="13"/>',
        "stylesheet instruction first": f'<?xml-stylesheet href="a.css"?><svg {S} width="12" height="13"/>',
        "prefixed root": '<s:svg xmlns:s="http://www.w3.org/2000/svg" width="12" height="13"/>',
        "no namespace": '<svg width="10" height="10"></svg>',
        "wrong namespace": '<svg xmlns="http://www.w3.org/1999/xhtml" width="10" height="10"></svg>',
        "g root": f'<g {S} width="12" height="13"/>',
        "html root": '<html xmlns="http://www.w3.org/1999/xhtml"><body>x</body></html>',
        "unclosed": f'<svg {S} width="10" height="10"><g></svg>',
        "mismatched": f'<svg {S} width="12" height="13"><g></h></svg>',
        "not xml": 'hello',
        "empty document": '',
        "character reference": f'<svg {S} width="&#49;2" height="13"/>',
        "hex character reference": f'<svg {S} width="&#x31;2" height="13"/>',
        "null character reference": f'<svg {S} width="12" height="13"><text>&#0;</text></svg>',
        "duplicate attribute": f'<svg {S} width="12" width="14" height="13"/>',
        "undefined entity": f'<svg {S} width="12" height="13"><text>&nbsp;</text></svg>',
        "undefined entity with external subset": f'<!DOCTYPE svg SYSTEM "svg.dtd"><svg {S} width="12" height="13"><text>&nbsp;</text></svg>',
        "internal entity": f'<!DOCTYPE svg [<!ENTITY w "12">]><svg {S} width="&w;" height="13"/>',
        "internal entity namespace": '<!DOCTYPE svg [<!ENTITY ns_svg "http://www.w3.org/2000/svg"><!ELEMENT svg ANY><!ATTLIST svg width CDATA #IMPLIED>]><svg xmlns="&ns_svg;" width="12" height="13"/>',
        "text after root": f'<svg {S} width="12" height="13"/>junk',
        "two roots": f'<svg {S} width="12" height="13"/><svg {S}/>',
        "comment after root": f'<svg {S} width="12" height="13"/><!-- x -->\n',
        "doctype after root": f'<svg {S} width="12" height="13"/><!DOCTYPE svg>',
        "double hyphen in comment": f'<!-- a -- b --><svg {S} width="12" height="13"/>',
        "unquoted attribute": f'<svg {S} width=12 height="13"/>',
        "single quotes": f"<svg {S} width='12' height='13'/>",
        "spaces around equals": f'<svg {S} width = "12"  height=\n"13" />',
        "leading white space": f'  \n<svg {S} width="12" height="13"/>',
        "less-than in attribute": f'<svg {S} width="12" height="13" data-x="a<b"/>',
        "greater-than in attribute": f'<svg {S} width="12" height="13" data-x="a>b"/>',
        "bare ampersand": f'<svg {S} width="12" height="13"><text>a & b</text></svg>',
        "cdata": f'<svg {S} width="12" height="13"><![CDATA[ x < y ]]></svg>',
        "cdata end in text": f'<svg {S} width="12" height="13">a ]]> b</svg>',
        "instruction inside": f'<svg {S} width="12" height="13"><?foo bar?></svg>',
        "xml instruction inside": f'<svg {S} width="12" height="13"><?xml version="1.0"?></svg>',
        "digit name": f'<svg {S} width="12" height="13"><1a/></svg>',
        "non-ascii name": f'<svg {S} width="12" height="13"><é/></svg>',
        "control character": f'<svg {S} width="12" height="13">\x01</svg>',
        "undeclared prefix": f'<svg {S} width="12" height="13"><a:b/></svg>',
        "undeclared xlink": f'<svg {S} width="12" height="13"><use xlink:href="#a"/></svg>',
        "declared xlink": f'<svg {S} xmlns:xlink="http://www.w3.org/1999/xlink" width="12" height="13"><use xlink:href="#a"/></svg>',
        "empty default namespace": f'<svg {S} width="12" height="13"><g xmlns=""/></svg>',
        "xml prefix": f'<svg {S} width="12" height="13" xml:space="preserve"/>',
        "empty prefix binding": f'<svg {S} xmlns:a="" width="12" height="13"/>',
        "duplicate expanded attribute": f'<svg {S} xmlns:a="urn:x" xmlns:b="urn:x" a:c="1" b:c="2" width="12" height="13"/>',
        "two colons": f'<svg {S} width="12" height="13"><a:b:c xmlns:a="urn:x"/></svg>',
        "nested svg": f'<svg {S} width="12" height="13"><svg width="100" height="100"/></svg>',
        "newline in attribute": f'<svg {S} width="\n12\n" height="13"/>',
    }
    for name, text in docs.items():
        cases[f"xml {name}"] = svg(text)
    cases["xml bom"] = url("image/svg+xml", b"\xef\xbb\xbf" + f'<svg {S} width="12" height="13"/>'.encode())
    cases["xml utf-16le"] = url("image/svg+xml", b"\xff\xfe" + f'<svg {S} width="12" height="13"/>'.encode("utf-16-le"))
    cases["xml utf-16be"] = url("image/svg+xml", b"\xfe\xff" + f'<svg {S} width="12" height="13"/>'.encode("utf-16-be"))
    cases["xml latin-1 ascii"] = url("image/svg+xml", f'<?xml version="1.0" encoding="ISO-8859-1"?><svg {S} width="12" height="13"/>'.encode())
    cases["xml latin-1 non-ascii"] = url("image/svg+xml", f'<?xml version="1.0" encoding="ISO-8859-1"?><svg {S} width="12" height="13"><text>\xe9</text></svg>'.encode("latin-1"))
    cases["xml invalid utf-8"] = url("image/svg+xml", f'<svg {S} width="12" height="13"><text>\xe9</text></svg>'.encode("latin-1"))
    cases["xml crlf"] = url("image/svg+xml", f'<svg {S}\r\nwidth="12"\r\nheight="13"/>'.encode())
    return cases


def chrome_sizes(urls):
    """Chrome's answers, a page per dozen images."""
    sizes = []
    for start in range(0, len(urls), 12):
        batch = urls[start:start + 12]
        sizes += oracle.run([], {}, SIZE % json.dumps(batch))[0]["value"]
    return sizes


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-v", "--verbose", action="store_true", help="list the cases the port does not size")
    args = parser.parse_args()
    webp = oracle.run([], {}, CANVAS)[0]["value"]
    cases = build_cases(webp)
    names = list(cases)
    urls = [cases[name] for name in names]
    expected = chrome_sizes(urls)
    binary = compare.build()
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(urls, handle)
    actual = json.loads(subprocess.run([str(binary), "image-size", handle.name], capture_output=True, text=True,
                                       check=True).stdout)
    differ = unknown = 0
    for name, want, got in zip(names, expected, actual):
        if got == "unknown":
            unknown += 1
            if args.verbose:
                print(f"unknown   {name}: Chrome {want}")
        elif got != want:
            differ += 1
            print(f"differs   {name}: port {got}, Chrome {want}")
    print(f"{len(names) - differ - unknown}/{len(names)} images sized as Chrome does, {unknown} unknown to the port")
    return 1 if differ else 0


if __name__ == "__main__":
    sys.exit(main())
