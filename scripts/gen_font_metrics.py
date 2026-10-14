#!/usr/bin/env python3
"""Extract the font metrics the port needs to measure text like Chrome.

mermaid sizes boxes from the browser's text measurements, so byte-identical
output needs the metrics of the fonts the reference browser resolves the
default font stack to: `"trebuchet ms", verdana, arial, sans-serif` on
macOS. This script reads those TrueType files and writes, per face, the
advance width, ink bounds and kerning pairs of every mapped glyph to
`internal/font/gen_<face>.mbt`.

Times and Helvetica are there too: they are what the browser's generic
`serif` (and its default font) and `sans-serif` resolve to, and the sequence
diagram measures its text with both. They are AAT fonts, kerned by an
Apple-format `kern` table and with `fi`/`fl` ligatures in `morx`.

Only metrics are extracted — no outlines or hinting programs.

Usage: python3 scripts/gen_font_metrics.py && moon fmt
"""

import pathlib
import struct
import unicodedata
from fractions import Fraction

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT_DIR = pathlib.Path("/System/Library/Fonts/Supplemental")
SYSTEM_DIR = pathlib.Path("/System/Library/Fonts")

# (identifier, file[, index in the collection]). The identifier names the
# generated value.
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
    ("times_regular", SYSTEM_DIR / "Times.ttc", 0),
    ("times_bold", SYSTEM_DIR / "Times.ttc", 1),
    ("helvetica_regular", SYSTEM_DIR / "Helvetica.ttc", 0),
    ("helvetica_bold", SYSTEM_DIR / "Helvetica.ttc", 1),
]

# Code points kept from each face: Latin with its extensions, IPA, Greek and
# Cyrillic, general punctuation, super- and subscripts, currency, letterlike
# symbols, number forms, arrows, mathematical and technical symbols, box
# drawing and geometric shapes. Combining marks are left out, as are scripts
# that need shaping (Hebrew, Arabic): a face is only asked for what it can
# measure glyph by glyph. For anything else the reference browser falls back
# to other system fonts, which are not embedded.
RANGES = [
    (0x20, 0x2FF), (0x370, 0x52F), (0x1E00, 0x1FFF), (0xFB00, 0xFB06), (0x2000, 0x206F), (0x2070, 0x209F),
    (0x20A0, 0x20CF), (0x2100, 0x218F), (0x2190, 0x21FF), (0x2200, 0x23FF), (0x2500, 0x25FF),
]

class Font:
    def __init__(self, data, index=0):
        self.data = data
        # A collection starts with the offsets of its fonts.
        start = struct.unpack(">I", data[12 + 4 * index:16 + 4 * index])[0] if data[:4] == b"ttcf" else 0
        count = struct.unpack(">H", data[start + 4:start + 6])[0]
        self.tables = {}
        for i in range(count):
            tag, _, offset, length = struct.unpack(">4sIII", data[start + 12 + 16 * i:start + 28 + 16 * i])
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
        """Map code points to glyph ids from the Unicode BMP subtable: the
        Windows one, or the Unicode-platform one of Apple's own fonts."""
        table = self.table("cmap")
        count = struct.unpack(">H", table[2:4])[0]
        offset = None
        for i in range(count):
            platform, encoding, sub = struct.unpack(">HHI", table[4 + 8 * i:12 + 8 * i])
            if (platform, encoding) == (3, 1) or (platform, encoding) == (0, 3) and offset is None:
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

    def glyph_data(self, glyph):
        long_format = struct.unpack(">h", self.table("head")[50:52])[0]
        loca = self.table("loca")
        if long_format:
            start, end = struct.unpack(">II", loca[4 * glyph:4 * glyph + 8])
        else:
            start, end = (2 * v for v in struct.unpack(">HH", loca[2 * glyph:2 * glyph + 4]))
        return self.table("glyf")[start:end]

    def left_side_bearing(self, glyph):
        count = struct.unpack(">H", self.table("hhea")[34:36])[0]
        table = self.table("hmtx")
        if glyph < count:
            return struct.unpack(">h", table[4 * glyph + 2:4 * glyph + 4])[0]
        at = 4 * count + 2 * (glyph - count)
        return struct.unpack(">h", table[at:at + 2])[0]

    def contours(self, glyph):
        """The glyph's contours as lists of points, where the scaler puts them.

        A simple glyph is moved sideways so that the xMin of its header sits
        at the left side bearing `hmtx` gives it (they differ for the Euro
        sign of Times, for one). A composite is made of components placed
        that way; its own side bearing moves nothing.
        """
        data = self.glyph_data(glyph)
        if not data:
            return []
        count = struct.unpack(">h", data[:2])[0]
        if count >= 0:
            ends = struct.unpack(f">{count}H", data[10:10 + 2 * count])
            total = ends[-1] + 1 if count else 0
            at = 12 + 2 * count + struct.unpack(">H", data[10 + 2 * count:12 + 2 * count])[0]
            flags = []
            while len(flags) < total:
                flag = data[at]
                at += 1
                flags.append(flag)
                if flag & 8:
                    flags += [flag] * data[at]
                    at += 1
            coordinates = []
            for short, same in ((2, 16), (4, 32)):
                values, value = [], 0
                for flag in flags:
                    if flag & short:
                        value += data[at] if flag & same else -data[at]
                        at += 1
                    elif not flag & same:
                        value += struct.unpack(">h", data[at:at + 2])[0]
                        at += 2
                    values.append(value)
                coordinates.append(values)
            shift = self.left_side_bearing(glyph) - struct.unpack(">h", data[2:4])[0]
            contours, start = [], 0
            for end in ends:
                contours.append([(Fraction(coordinates[0][i] + shift), Fraction(coordinates[1][i]))
                                 for i in range(start, end + 1)])
                start = end + 1
            return contours
        contours, at = [], 10
        while True:
            flags, component = struct.unpack(">HH", data[at:at + 4])
            at += 4
            if flags & 1:
                dx, dy = struct.unpack(">hh", data[at:at + 4])
                at += 4
            else:
                dx, dy = struct.unpack(">bb", data[at:at + 2])
                at += 2
            if not flags & 2:
                raise ValueError("composite glyph placed by matching points")
            xx, xy, yx, yy = Fraction(1), Fraction(0), Fraction(0), Fraction(1)
            if flags & 0x08:
                xx = yy = Fraction(struct.unpack(">h", data[at:at + 2])[0], 16384)
                at += 2
            elif flags & 0x40:
                xx, yy = (Fraction(v, 16384) for v in struct.unpack(">hh", data[at:at + 4]))
                at += 4
            elif flags & 0x80:
                xx, xy, yx, yy = (Fraction(v, 16384) for v in struct.unpack(">hhhh", data[at:at + 8]))
                at += 8
            for contour in self.contours(component):
                contours.append([(xx * x + yx * y + dx, xy * x + yy * y + dy) for x, y in contour])
            if not flags & 0x20:
                break
        return contours

    def bounds(self, glyph):
        """The glyph's ink box (xMin, yMin, xMax, yMax), zero when empty.

        This is what CoreText reports and Skia passes on: the box around all
        outline points, control points included. A contour of a single point
        is an anchor for accents, not ink; the box in the glyph header counts
        those in, so it cannot be used. `None` when the box does not fall on
        whole units (a scaled component), which the tables cannot hold.
        """
        points = [point for contour in self.contours(glyph) if len(contour) >= 2 for point in contour]
        if not points:
            return (0, 0, 0, 0)
        box = (min(x for x, _ in points), min(y for _, y in points),
               max(x for x, _ in points), max(y for _, y in points))
        if any(value.denominator != 1 for value in box):
            return None
        return tuple(int(value) for value in box)

    def mark_glyphs(self):
        """Glyphs that GDEF classes as marks. HarfBuzz gives them no advance."""
        if "GDEF" not in self.tables:
            return set()
        table = self.table("GDEF")
        at = struct.unpack(">H", table[4:6])[0]
        if not at:
            return set()
        u16 = lambda where: struct.unpack(">H", table[where:where + 2])[0]
        marks = set()
        if u16(at) == 1:
            start = u16(at + 2)
            for i in range(u16(at + 4)):
                if u16(at + 6 + 2 * i) == 3:
                    marks.add(start + i)
        else:
            for i in range(u16(at + 2)):
                first, last, value = (u16(at + 4 + 6 * i + 2 * k) for k in range(3))
                if value == 3:
                    marks.update(range(first, last + 1))
        return marks

    def kerning(self):
        """Horizontal pair adjustments from format 0 `kern` subtables."""
        if "kern" not in self.tables:
            return {}
        table = self.table("kern")
        if struct.unpack(">H", table[:2])[0] == 1:
            return self.apple_kerning(table)
        count = struct.unpack(">H", table[2:4])[0]
        pairs, position = {}, 4
        for _ in range(count):
            _, length, coverage = struct.unpack(">HHH", table[position:position + 6])
            if coverage >> 8 == 0 and coverage & 1:
                n = struct.unpack(">H", table[position + 6:position + 8])[0]
                rows = [struct.unpack(">HHh", table[position + 14 + 6 * i:position + 20 + 6 * i]) for i in range(n)]
                self.add_pairs(pairs, rows)
            position += length
        return pairs

    @staticmethod
    def search_pair(rows, left, right):
        """Look a pair up the way HarfBuzz does: by binary search.

        The pairs are meant to be sorted. Where a font has one out of
        order (`v.` in Trebuchet MS Bold), the search never reaches it and
        the pair does not kern.
        """
        low, high = 0, len(rows) - 1
        while low <= high:
            middle = (low + high) // 2
            key = rows[middle][:2]
            if key < (left, right):
                low = middle + 1
            elif key > (left, right):
                high = middle - 1
            else:
                return rows[middle][2]
        return None

    @classmethod
    def add_pairs(cls, pairs, rows):
        """Add the pairs of one format 0 subtable that a search finds."""
        for left, right in {(left, right) for left, right, _ in rows}:
            value = cls.search_pair(rows, left, right)
            if value is not None:
                pairs[(left, right)] = pairs.get((left, right), 0) + value


    def apple_kerning(self, table):
        """Pairs of an Apple-format `kern` table (version 1.0)."""
        count = struct.unpack(">I", table[4:8])[0]
        pairs, position = {}, 8
        for _ in range(count):
            length, coverage, _ = struct.unpack(">IHH", table[position:position + 8])
            # Only plain horizontal pair lists: no vertical, cross-stream
            # or variation subtables, and format 0.
            if coverage != 0:
                raise ValueError("unsupported Apple kern subtable %#x" % coverage)
            n = struct.unpack(">H", table[position + 8:position + 10])[0]
            rows = [struct.unpack(">HHh", table[position + 16 + 6 * i:position + 22 + 6 * i]) for i in range(n)]
            self.add_pairs(pairs, rows)
            position += length
        return pairs

    def ligatures(self):
        """Two-glyph ligatures of the `morx` common-ligatures subtables.

        Returns {(left, right): ligature}. The state machines are run on
        every pair of the glyphs they classify, which finds `fi` and `fl`;
        the other default subtables only compose letters with combining
        marks, which are outside the ranges kept here.
        """
        if "morx" not in self.tables:
            return {}
        table = self.table("morx")
        glyph_count = struct.unpack(">H", self.table("maxp")[4:6])[0]
        chains = struct.unpack(">I", table[4:8])[0]
        found, position = {}, 8
        for _ in range(chains):
            defaults, length, feature_count, subtable_count = struct.unpack(">IIII", table[position:position + 16])
            common = 0
            for i in range(feature_count):
                kind, setting, enable, _ = struct.unpack(">HHII", table[position + 16 + 12 * i:position + 28 + 12 * i])
                if (kind, setting) == (1, 2):  # ligatures, common ligatures on
                    common |= enable
            at = position + 16 + 12 * feature_count
            for _ in range(subtable_count):
                size, coverage, flags = struct.unpack(">III", table[at:at + 12])
                if coverage & 0xFF == 2 and flags & common & defaults:
                    found.update(ligature_pairs(table[at + 12:at + size], glyph_count))
                at += size
            position += length
        return found


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


def aat_lookup(data, glyph_count):
    """An AAT lookup table as {glyph: value}."""
    fmt = struct.unpack(">H", data[:2])[0]
    values = {}
    if fmt == 0:
        for glyph in range(glyph_count):
            values[glyph] = struct.unpack(">H", data[2 + 2 * glyph:4 + 2 * glyph])[0]
    elif fmt in (2, 4, 6):
        unit, count = struct.unpack(">HH", data[2:6])
        for i in range(count):
            record = data[12 + unit * i:12 + unit * (i + 1)]
            if fmt == 6:
                glyph, value = struct.unpack(">HH", record[:4])
                if glyph != 0xFFFF:
                    values[glyph] = value
                continue
            last, first, value = struct.unpack(">HHH", record[:6])
            if last == 0xFFFF:
                continue
            for k, glyph in enumerate(range(first, last + 1)):
                values[glyph] = value if fmt == 2 else struct.unpack(">H", data[value + 2 * k:value + 2 * k + 2])[0]
    elif fmt == 8:
        first, count = struct.unpack(">HH", data[2:6])
        for k in range(count):
            values[first + k] = struct.unpack(">H", data[6 + 2 * k:8 + 2 * k])[0]
    else:
        raise ValueError("unsupported AAT lookup format %d" % fmt)
    return values


def ligature_pairs(subtable, glyph_count):
    """Run a `morx` ligature subtable on every pair of classified glyphs."""
    class_count, class_table, state_array, entry_table, actions, components, ligatures = struct.unpack(">7I", subtable[:28])
    classes = {glyph: value for glyph, value in aat_lookup(subtable[class_table:], glyph_count).items() if value >= 4}
    u16 = lambda at: struct.unpack(">H", subtable[at:at + 2])[0]

    def run(glyphs):
        buffer, state, stack, i = list(glyphs), 0, [], 0
        while i <= len(buffer):
            at_end = i == len(buffer)
            glyph_class = 0 if at_end else 2 if buffer[i] == 0xFFFF else classes.get(buffer[i], 1)
            entry = entry_table + 6 * u16(state_array + 2 * (state * class_count + glyph_class))
            state, flags, action = u16(entry), u16(entry + 2), u16(entry + 4)
            if flags & 0x8000 and not at_end:
                stack.append(i)
            if flags & 0x2000:
                pointer, index, cursor = actions + 4 * action, 0, len(stack)
                while cursor:
                    cursor -= 1
                    where = stack[cursor]
                    step = struct.unpack(">I", subtable[pointer:pointer + 4])[0]
                    offset = step & 0x3FFFFFFF
                    if offset & 0x20000000:
                        offset -= 0x40000000
                    index += u16(components + 2 * (buffer[where] + offset))
                    if step & 0xC0000000:
                        buffer[where] = u16(ligatures + 2 * index)
                        cursor += 1
                        index = 0
                    else:
                        buffer[where] = 0xFFFF
                    pointer += 4
                    if step & 0x80000000:
                        break
                del stack[cursor:]
            if at_end:
                break
            if not flags & 0x4000:
                i += 1
        return [glyph for glyph in buffer if glyph != 0xFFFF]

    pairs = {}
    for left in classes:
        for right in classes:
            result = run([left, right])
            if len(result) == 1:
                pairs[(left, right)] = result[0]
    return pairs


def decomposable(parts, cmap):
    """Whether a font shapes a base and a mark it has in place of a composed
    character it lacks (`decompose` in hb-ot-shape-normalize.cc)."""
    base, mark = parts
    if mark not in cmap:
        return False
    if base in cmap:
        return True
    inner = unicodedata.decomposition(chr(base)).split()
    if not inner or inner[0].startswith("<"):
        return False
    inner = [int(part, 16) for part in inner]
    return decomposable(inner, cmap) if len(inner) == 2 else inner[0] in cmap


def keep(code):
    return any(low <= code <= high for low, high in RANGES)


def emit(ident, filename, index=0):
    font = Font((FONT_DIR / filename).read_bytes(), index)
    filename = pathlib.Path(filename).name
    # Marks and glyphs whose box the tables cannot hold are left to the
    # "not covered" path rather than measured wrongly.
    marks = font.mark_glyphs()
    full = font.cmap()
    cmap = {code: glyph for code, glyph in full.items()
            if keep(code) and glyph not in marks and font.bounds(glyph) is not None}
    # HarfBuzz decomposes a character the font lacks when the font has the
    # pieces. A character that is canonically one other character simply
    # takes that one's glyph (the ohm sign is drawn as an omega). One that
    # splits into a base and a combining mark is drawn as the two, which
    # the tables here cannot place: such characters are listed, so that the
    # search for a glyph stops at this face instead of moving on to the
    # next one as if the browser did.
    composed = []
    for code in (code for low, high in RANGES for code in range(low, high + 1)):
        if code in full:
            continue
        parts = unicodedata.decomposition(chr(code)).split()
        if not parts or parts[0].startswith("<"):
            continue
        parts = [int(part, 16) for part in parts]
        if len(parts) == 1:
            if parts[0] in cmap:
                cmap[code] = cmap[parts[0]]
        elif decomposable(parts, full):
            composed.append(code)
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
    by_glyph = {glyph: code for code, glyph in sorted(cmap.items(), reverse=True)}
    ligature_rows = [
        f"    {left}, {right}, {by_glyph[ligature]},"
        for (left, right), ligature in sorted(font.ligatures().items())
        if left in kept and right in kept and ligature in by_glyph
    ]
    extras = []
    if composed:
        rows, row = [], "   "
        for code in composed:
            piece = f" {code},"
            if len(row) + len(piece) > 92:
                rows.append(row)
                row = "   "
            row += piece
        rows.append(row)
        extras += ["  // code points drawn as a base and a combining mark", "  composed=[", *rows, "  ],"]
    if ligature_rows:
        extras += ["  // left glyph id, right glyph id, code point of the ligature", "  ligatures=[", *ligature_rows, "  ],"]
    if family_name(font) in ("Times", "Helvetica", "Courier"):
        extras.append("  mac_ascent_adjustment=true,")
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
        *extras,
        ")",
        "",
    ]
    target = ROOT / "internal" / "font" / f"gen_{ident}.mbt"
    target.write_text("\n".join(lines))
    print(f"wrote {target.relative_to(ROOT)}: {len(glyph_rows)} glyphs, {len(kern_rows)} kerning pairs, "
          f"{len(ligature_rows)} ligatures")


def family_name(font):
    """The font's family name (name id 1), from its Macintosh record."""
    table = font.table("name")
    count, strings = struct.unpack(">HH", table[2:6])
    for i in range(count):
        platform, _, _, name, length, offset = struct.unpack(">6H", table[6 + 12 * i:18 + 12 * i])
        if (platform, name) == (1, 1):
            return table[strings + offset:strings + offset + length].decode("mac_roman")
    return ""


def main():
    for ident, filename, *index in FACES:
        emit(ident, filename, *index)


if __name__ == "__main__":
    main()
