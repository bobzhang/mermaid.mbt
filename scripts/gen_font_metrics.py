#!/usr/bin/env python3
"""Extract the font metrics the port needs to measure text like Chrome.

mermaid sizes boxes from the browser's text measurements, so byte-identical
output needs the metrics of the fonts the reference browser resolves the
default font stack to: `"trebuchet ms", verdana, arial, sans-serif` on
macOS. This script reads those TrueType files and writes, per face, the
advance width, ink bounds and kerning pairs of every mapped glyph to
`internal/font/gen_<face>.mbt`.

Only metrics are extracted — no outlines or hinting programs.

Usage: python3 scripts/gen_font_metrics.py && moon fmt
"""

import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT_DIR = pathlib.Path("/System/Library/Fonts/Supplemental")

# (identifier, file). The identifier names the generated value.
FACES = [
    ("trebuchet_regular", "Trebuchet MS.ttf"),
    ("trebuchet_bold", "Trebuchet MS Bold.ttf"),
    ("trebuchet_italic", "Trebuchet MS Italic.ttf"),
    ("trebuchet_bold_italic", "Trebuchet MS Bold Italic.ttf"),
    ("verdana_regular", "Verdana.ttf"),
    ("verdana_bold", "Verdana Bold.ttf"),
    ("arial_regular", "Arial.ttf"),
    ("arial_bold", "Arial Bold.ttf"),
    ("arial_italic", "Arial Italic.ttf"),
    ("arial_bold_italic", "Arial Bold Italic.ttf"),
]

# Code points kept from each face: Basic Latin through Latin Extended-A,
# general punctuation, currency, arrows and common symbols. Scripts outside
# these ranges are not measured from these faces by the reference browser
# either; it falls back to other system fonts.
RANGES = [(0x20, 0x17F), (0xFB00, 0xFB06), (0x2000, 0x206F), (0x20A0, 0x20BF), (0x2100, 0x214F), (0x2190, 0x21FF), (0x2200, 0x22FF), (0x25A0, 0x25FF)]


class Font:
    def __init__(self, data):
        self.data = data
        count = struct.unpack(">H", data[4:6])[0]
        self.tables = {}
        for i in range(count):
            tag, _, offset, length = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
            self.tables[tag.decode()] = (offset, length)

    def table(self, tag):
        offset, length = self.tables[tag]
        return self.data[offset:offset + length]

    def units_per_em(self):
        return struct.unpack(">H", self.table("head")[18:20])[0]

    def vertical_metrics(self):
        ascent, descent = struct.unpack(">hh", self.table("hhea")[4:8])
        return ascent, -descent

    def line_gap(self):
        return struct.unpack(">h", self.table("hhea")[8:10])[0]

    def cmap(self):
        """Map code points to glyph ids from the Windows Unicode BMP subtable."""
        table = self.table("cmap")
        count = struct.unpack(">H", table[2:4])[0]
        offset = None
        for i in range(count):
            platform, encoding, sub = struct.unpack(">HHI", table[4 + 8 * i:12 + 8 * i])
            if (platform, encoding) == (3, 1):
                offset = sub
        if offset is None or struct.unpack(">H", table[offset:offset + 2])[0] != 4:
            raise ValueError("no format 4 Unicode cmap")
        seg_count = struct.unpack(">H", table[offset + 6:offset + 8])[0] // 2
        base = offset + 14
        ends = struct.unpack(f">{seg_count}H", table[base:base + 2 * seg_count])
        base += 2 * seg_count + 2
        starts = struct.unpack(f">{seg_count}H", table[base:base + 2 * seg_count])
        base += 2 * seg_count
        deltas = struct.unpack(f">{seg_count}h", table[base:base + 2 * seg_count])
        base += 2 * seg_count
        range_offsets = struct.unpack(f">{seg_count}H", table[base:base + 2 * seg_count])
        mapping = {}
        for i in range(seg_count):
            for code in range(starts[i], ends[i] + 1):
                if code == 0xFFFF:
                    continue
                if range_offsets[i] == 0:
                    glyph = (code + deltas[i]) & 0xFFFF
                else:
                    position = base + 2 * i + range_offsets[i] + 2 * (code - starts[i])
                    glyph = struct.unpack(">H", table[position:position + 2])[0]
                    if glyph:
                        glyph = (glyph + deltas[i]) & 0xFFFF
                if glyph:
                    mapping[code] = glyph
        return mapping

    def advances(self):
        count = struct.unpack(">H", self.table("hhea")[34:36])[0]
        table = self.table("hmtx")
        widths = [struct.unpack(">H", table[4 * i:4 * i + 2])[0] for i in range(count)]
        glyphs = struct.unpack(">H", self.table("maxp")[4:6])[0]
        return widths + [widths[-1]] * (glyphs - count)

    def bounds(self, glyph):
        """The glyph's ink box (xMin, yMin, xMax, yMax), zero when empty."""
        long_format = struct.unpack(">h", self.table("head")[50:52])[0]
        loca = self.table("loca")
        if long_format:
            start, end = struct.unpack(">II", loca[4 * glyph:4 * glyph + 8])
        else:
            start, end = (2 * v for v in struct.unpack(">HH", loca[2 * glyph:2 * glyph + 4]))
        if start == end:
            return (0, 0, 0, 0)
        return struct.unpack(">hhhh", self.table("glyf")[start + 2:start + 10])

    def kerning(self):
        """Horizontal pair adjustments from format 0 `kern` subtables."""
        if "kern" not in self.tables:
            return {}
        table = self.table("kern")
        count = struct.unpack(">H", table[2:4])[0]
        pairs, position = {}, 4
        for _ in range(count):
            _, length, coverage = struct.unpack(">HHH", table[position:position + 6])
            if coverage >> 8 == 0 and coverage & 1:
                n = struct.unpack(">H", table[position + 6:position + 8])[0]
                for i in range(n):
                    left, right, value = struct.unpack(">HHh", table[position + 14 + 6 * i:position + 20 + 6 * i])
                    pairs[(left, right)] = pairs.get((left, right), 0) + value
            position += length
        return pairs


    def gpos_kerning(self):
        """Pair adjustments of the GPOS `kern` feature, or None without one.

        HarfBuzz prefers these over the legacy `kern` table. Only the
        advance of the first glyph is read, which is all Latin kerning uses.
        """
        if "GPOS" not in self.tables:
            return None
        table = self.table("GPOS")
        u16 = lambda at: struct.unpack(">H", table[at:at + 2])[0]
        s16 = lambda at: struct.unpack(">h", table[at:at + 2])[0]
        feature_list, lookup_list = u16(6), u16(8)
        lookups = set()
        for i in range(u16(feature_list)):
            record = feature_list + 2 + 6 * i
            if table[record:record + 4] == b"kern":
                feature = feature_list + u16(record + 4)
                lookups.update(u16(feature + 4 + 2 * j) for j in range(u16(feature + 2)))
        if not lookups:
            return None

        def coverage(at):
            if u16(at) == 1:
                return [u16(at + 4 + 2 * i) for i in range(u16(at + 2))]
            glyphs = []
            for i in range(u16(at + 2)):
                start, end = u16(at + 4 + 6 * i), u16(at + 6 + 6 * i)
                glyphs += range(start, end + 1)
            return glyphs

        def class_def(at):
            classes = {}
            if u16(at) == 1:
                start = u16(at + 2)
                for i in range(u16(at + 4)):
                    classes[start + i] = u16(at + 6 + 2 * i)
            else:
                for i in range(u16(at + 2)):
                    start, end, value = (u16(at + 4 + 6 * i + 2 * k) for k in range(3))
                    for glyph in range(start, end + 1):
                        classes[glyph] = value
            return classes

        def value_size(fmt):
            return 2 * bin(fmt).count("1")

        def x_advance(at, fmt):
            # XPlacement (1) and YPlacement (2) precede XAdvance (4).
            if not fmt & 4:
                return 0
            return s16(at + 2 * bin(fmt & 3).count("1"))

        pairs = {}

        def pair_pos(at):
            fmt, cover, f1, f2 = u16(at), coverage(at + u16(at + 2)), u16(at + 4), u16(at + 6)
            size = 2 + value_size(f1) + value_size(f2)
            if fmt == 1:
                for i, first in enumerate(cover):
                    pair_set = at + u16(at + 10 + 2 * i)
                    for j in range(u16(pair_set)):
                        record = pair_set + 2 + size * j
                        pairs.setdefault((first, u16(record)), x_advance(record + 2, f1))
            elif fmt == 2:
                classes1, classes2 = class_def(at + u16(at + 8)), class_def(at + u16(at + 10))
                count1, count2 = u16(at + 12), u16(at + 14)
                record_size = value_size(f1) + value_size(f2)
                by_class2 = {}
                for glyph, value in classes2.items():
                    by_class2.setdefault(value, []).append(glyph)
                for first in cover:
                    row = at + 16 + classes1.get(first, 0) * count2 * record_size
                    for c2 in range(1, count2):
                        value = x_advance(row + c2 * record_size, f1)
                        if value:
                            for second in by_class2.get(c2, []):
                                pairs.setdefault((first, second), value)

        for index in sorted(lookups):
            lookup = lookup_list + u16(lookup_list + 2 + 2 * index)
            kind = u16(lookup)
            for i in range(u16(lookup + 4)):
                subtable = lookup + u16(lookup + 6 + 2 * i)
                if kind == 9:  # extension
                    kind_here = u16(subtable + 2)
                    subtable += struct.unpack(">I", table[subtable + 4:subtable + 8])[0]
                else:
                    kind_here = kind
                if kind_here == 2:
                    pair_pos(subtable)
        return pairs


def keep(code):
    return any(low <= code <= high for low, high in RANGES)


def emit(ident, filename):
    font = Font((FONT_DIR / filename).read_bytes())
    cmap = {code: glyph for code, glyph in font.cmap().items() if keep(code)}
    advances = font.advances()
    ascent, descent = font.vertical_metrics()
    kept = set(cmap.values())
    glyph_rows = []
    for code in sorted(cmap):
        glyph = cmap[code]
        x_min, y_min, x_max, y_max = font.bounds(glyph)
        glyph_rows.append(f"    {code}, {glyph}, {advances[glyph]}, {x_min}, {y_min}, {x_max}, {y_max},")
    kern_rows = [
        f"    {left}, {right}, {value},"
        for (left, right), value in sorted((font.gpos_kerning() or font.kerning()).items())
        if left in kept and right in kept and value
    ]
    lines = [
        f"// Generated by scripts/gen_font_metrics.py from {filename}.",
        "// Do not edit by hand.",
        "",
        "///|",
        f"let {ident} : Face = Face::new(",
        f"  units_per_em={font.units_per_em()},",
        f"  ascent={ascent},",
        f"  descent={descent},",
        f"  line_gap={font.line_gap()},",
        "  // code point, glyph id, advance, xMin, yMin, xMax, yMax",
        "  glyphs=[",
        *glyph_rows,
        "  ],",
        "  // left glyph id, right glyph id, adjustment",
        "  kerning=[",
        *kern_rows,
        "  ],",
        ")",
        "",
    ]
    target = ROOT / "internal" / "font" / f"gen_{ident}.mbt"
    target.write_text("\n".join(lines))
    print(f"wrote {target.relative_to(ROOT)}: {len(glyph_rows)} glyphs, {len(kern_rows)} kerning pairs")


def main():
    for ident, filename in FACES:
        emit(ident, filename)


if __name__ == "__main__":
    main()
