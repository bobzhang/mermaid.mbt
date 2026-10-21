# mermaid.mbt

A port of [Mermaid](https://github.com/mermaid-js/mermaid) — the text-to-diagram
toolkit — to [MoonBit](https://www.moonbitlang.com).

The port is pure MoonBit: no DOM and no JavaScript. It renders diagram text
straight to SVG on every backend, and its goal is output that is **byte for
byte** what mermaid 12.2.0 produces in a browser.

```mbt check
///|
test {
  let svg = @mermaid.render(
    (
      #|pie title Pets adopted by volunteers
      #|    "Dogs" : 386
      #|    "Cats" : 85
      #|    "Rats" : 15
    ),
  )
  assert_true(svg.has_prefix("<svg id=\"mermaid-svg\""))
  assert_true(svg.contains("Pets adopted by volunteers"))
}
```

`render` takes the same inputs as `mermaid.render(id, text)`: an optional
`id` for the `<svg>` element and an optional site `config` (what you would
pass to `mermaid.initialize`). Frontmatter and `%%{init}%%` directives in the
diagram are honored.

## Status

Every diagram type of mermaid 12.2.0 is ported. Of the 598 examples in
upstream's documentation, 597 render byte for byte as upstream does; the
one left needs the metrics of Apple Color Emoji (tree view). One of the
597 shows an image from the network, which the port measures when the
caller supplies the image: `render(image_loader=...)`, or `mermaid render
--fetch-images` on the command line. Input the port cannot reproduce
exactly raises `Unsupported` rather than rendering something close.

| Diagram | State |
| --- | --- |
| Pie | byte-identical |
| Packet | byte-identical |
| Info | byte-identical |
| Flowchart | byte-identical with the ELK and dagre layouts; see below |
| Git graph | byte-identical, all orientations and options; upstream's documentation examples match |
| Entity relationship | byte-identical with the ELK and dagre layouts |
| Requirement | byte-identical with the ELK and dagre layouts |
| State | byte-identical with the ELK and dagre layouts, `stateDiagram` and `stateDiagram-v2` |
| Class | byte-identical with the ELK and dagre layouts, including cardinalities, namespaces and notes |
| User journey | byte-identical, all `journey:` options |
| Timeline | byte-identical, horizontal and vertical, both looks |
| Gantt | byte-identical; see the note on time below |
| Sequence | byte-identical: all participant kinds and arrow types, both looks; KaTeX is not ported |
| Sankey | byte-identical, all `sankey:` options |
| Radar | byte-identical |
| Treemap | byte-identical; depends on the page like Gantt charts |
| Block | byte-identical: grid layout, block arrows, all edge curves |
| C4 | byte-identical: all five kinds, boundaries, relationships, style updates |
| Quadrant chart | byte-identical |
| XY chart | byte-identical, both orientations; depends on the page like Gantt charts |
| Tree view | byte-identical; emoji labels are refused |
| Ishikawa | byte-identical, including the hand-drawn look with a seed |
| Cynefin | byte-identical |
| Railroad | byte-identical, all four front ends (railroad, EBNF, ABNF, PEG) |
| Event modeling | byte-identical |
| Wardley map | byte-identical |
| Agentflow | byte-identical with the ELK and dagre layouts, including collapsed containers |
| Kanban | byte-identical, including the hand-drawn look |
| Use case | byte-identical with the ELK and dagre layouts |
| Mindmap | byte-identical with its default cose-bilkent layout (`internal/cose`) and with dagre |
| Swimlanes | byte-identical, with the swimlane layout engine (`internal/swimlane`) |
| Architecture | byte-identical, with the fcose layout (`internal/fcose`) |
| Venn | byte-identical, including the hand-drawn look; the layout optimiser of venn.js is transcribed step by step |

Git graphs name commits at random upstream (`Math.random`), so a graph
whose commits have no explicit `id:` differs from render to render there;
the fixtures seed the generator (`testdata/gitgraph/oracle-prelude.js`) and
the port draws the same sequence. State diagrams have one such name too:
the last region of a composite state split by `--` is called
`id-<random>-<count>` upstream. The port writes `id-i-<count>`, and
`scripts/oracle.py` renames the reference's regions the same way.
Block diagrams name `space` blocks and anonymous composites likewise;
their fixtures give the reference the port's generator
(`testdata/block/oracle-prelude.js`).

Shared infrastructure that is in place: all eleven themes, configuration
resolution, frontmatter and directives, diagram type detection, the
stylesheet compiler, text measurement, and a runtime for the nineteen
grammars mermaid writes in jison (`internal/jison`, with the tables taken
from mermaid's own build by `scripts/extract_jison.js` and
`scripts/gen_jison.py`).

### Gantt charts and time

A Gantt chart depends on three things outside its text, and `render` takes
each as an argument that defaults to the reference page's value:

- the time zone, which is that of the reference machine (Asia/Shanghai,
  with its historical offsets) — `@jsdate.Zone::reference()` is the one
  place that chooses it;
- the present, for the today marker and for dates that leave parts out:
  `now`, in milliseconds, defaulting to the system clock;
- the page the diagram sits in, whose width the chart takes and whose
  scrollbar changes how labels measure: `page`.

### Flowcharts and the unified renderer

Flowcharts, state, class, entity relationship, requirement, use case,
agentflow, block, C4, kanban, mindmap and swimlane diagrams draw through a
port of mermaid's unified renderer (`internal/rendering`): HTML labels and
SVG-text labels, every node shape (the classic ones, those of the
`@{ shape: ... }` syntax, icons and images), group frames, edges with
markers, rounded corners and line hops, class and link styling, the
classic, neo and hand-drawn looks.

Layouts, each a transcription checked against upstream's own code:

- ELK, the default, computed by
  [moonbit-community/elk](https://github.com/moonbit-community/moon_elk),
  which matches elkjs 0.9.3;
- dagre (`internal/dagre`), for `layout: dagre` and for layout names mermaid
  does not register;
- the swimlane engine (`internal/swimlane`), for `layout: swimlane`;
- cose-bilkent (`internal/cose`), the default of mindmaps.

Limits:

- rough.js places the control points of every line at random. With
  `handDrawnSeed` set, the port (`internal/rough`) reproduces upstream
  exactly; without a seed upstream's own output differs from render to
  render, and the port's is merely equivalent. Upstream draws some shapes
  (stadium, flag, documents, ...) through rough.js even in the classic look.
- Icon packs cannot be registered: every icon is drawn as mermaid's unknown
  icon, which is also what upstream draws without packs.
- Images take their size from the image. `render` never touches the
  network: it reads `data:` URLs itself and asks the caller's optional
  `image_loader` for other addresses (PNG, GIF, JPEG, WebP and SVG sizes are
  decoded as Chrome decodes them). Without a loader it draws such an image
  only when the node gives `w` and `h` without a `constraint`, and raises
  `Unsupported` otherwise. The CLI's `--fetch-images` is such a loader.
- Markdown labels cover paragraphs, emphasis, strikethrough, escapes, HTML
  blocks and inline HTML; other markdown blocks pass through as text.
- Line breaking inside labels knows Blink's rules for ASCII text; other
  scripts break at spaces only.

## How "byte-identical" is checked

Mermaid sizes and positions everything from the browser's measurements, so
its output depends on the browser and fonts. The reference here is the
published `mermaid@12.2.0` bundle running in headless Chrome on macOS, with
the default font stack resolving to Trebuchet MS.

- `scripts/oracle.py` renders a diagram with that reference.
- `scripts/compare.py` keeps a reference SVG next to every
  `testdata/**/*.mmd` and diffs the port against it.
- `moon test --target native` runs the same comparison from `tests/`.
- `scripts/check_examples.py` does it for the examples in upstream's own
  documentation.

To match, the port reproduces a number of browser behaviors: Blink's text
shaping arithmetic (`internal/font`), V8's results for `Math.sin`, `cos`, `tan`,
`asin`, `acos`, `atan`, `atan2` and `hypot` (`internal/jsmath`), CSSOM serialization of
inline styles and colors, `getBBox` and `getTotalLength` in Blink's
single-precision arithmetic (`internal/dom`), the stylis CSS compiler
(`internal/css`), and the single-precision `sinf`, `cosf`, `tanf` and
`atan2f` of macOS on arm64 (`internal/libm`), which Skia shapes arcs with
and which are not correctly rounded.

Known limits: the embedded faces are Trebuchet MS, Verdana, Arial, Times,
Helvetica and Georgia, with Latin, Greek, Cyrillic and common symbols. Text outside
them (CJK, emoji, Hebrew, Arabic, ...) falls to other system fonts in the
browser, which are not embedded: the newer diagram ports refuse such text
with `Unsupported`, the older ones (flowchart, pie) measure it
approximately.

## Layout

| Package | Role |
| --- | --- |
| `bobzhang/mermaid` | `render` |
| `config`, `theme` | configuration and theme variables |
| `diagram` | the context renderers draw into |
| `diagrams/*` | one package per diagram type |
| `internal/rendering` | the unified renderer for diagrams of nodes, edges and groups |
| `internal/rough` | the part of rough.js mermaid draws shapes with |
| `internal/*` | color math, CSS, DOM, d3 helpers, fonts, math, regex, parser runtimes, preprocessing |
| `cmd/mermaid` | native CLI: `mermaid render file.mmd` |

Generated sources (`theme/gen_*.mbt`, `config/gen_defaults.mbt`,
`internal/font/gen_*.mbt`) come from the scripts in `scripts/`; rerun them
against a newer upstream checkout in `.repos/mermaid`.
