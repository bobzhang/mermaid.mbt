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

Work in progress.

| Diagram | State |
| --- | --- |
| Pie | byte-identical |
| Packet | byte-identical |
| Info | byte-identical |
| everything else | not ported yet — `render` raises `Unsupported` |

Shared infrastructure that is in place: all eleven themes, configuration
resolution, frontmatter and directives, diagram type detection, the
stylesheet compiler, and text measurement.

## How "byte-identical" is checked

Mermaid sizes and positions everything from the browser's measurements, so
its output depends on the browser and fonts. The reference here is the
published `mermaid@12.2.0` bundle running in headless Chrome on macOS, with
the default font stack resolving to Trebuchet MS.

- `scripts/oracle.py` renders a diagram with that reference.
- `scripts/compare.py` keeps a reference SVG next to every
  `testdata/**/*.mmd` and diffs the port against it.
- `moon test --target native` runs the same comparison from `tests/`.

To match, the port reproduces a number of browser behaviors: Blink's text
shaping arithmetic (`internal/font`), V8's `Math.sin`/`Math.cos` results
(`internal/jsmath`), CSSOM serialization of inline styles and colors
(`internal/dom`), and the stylis CSS compiler (`internal/css`).

Known limits: text outside the embedded faces (Trebuchet MS, Verdana, Arial;
Latin and common symbols) is measured approximately, and fractional font
sizes that are not multiples of 1/64 px can differ in the last float bit of
an ink overhang.

## Layout

| Package | Role |
| --- | --- |
| `bobzhang/mermaid` | `render` |
| `config`, `theme` | configuration and theme variables |
| `diagram` | the context renderers draw into |
| `diagrams/*` | one package per diagram type |
| `internal/*` | color math, CSS, DOM, d3 helpers, fonts, math, preprocessing |
| `cmd/mermaid` | native CLI: `mermaid render file.mmd` |

Generated sources (`theme/gen_*.mbt`, `config/gen_defaults.mbt`,
`internal/font/gen_*.mbt`) come from the scripts in `scripts/`; rerun them
against a newer upstream checkout in `.repos/mermaid`.
