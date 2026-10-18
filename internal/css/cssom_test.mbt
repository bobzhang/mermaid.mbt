// Style sheets through `replaceSync` and `cssText` in Chrome (the corpus
// is scripts/cssom_corpus.txt; scripts/check_cssom.py compares it anew).

///|
/// The style sheets whose rules the port serializes otherwise than Chrome.
fn cssom_differences(cases : Array[(String, Array[String])]) -> Array[String] {
  let failed = []
  for case in cases {
    let (sheet, expected) = case
    let actual = @css.serialize_style_sheet(sheet) catch {
      CssUnsupported(what) => ["unported: \{what}"]
    }
    if actual != expected {
      failed.push(sheet)
    }
  }
  failed
}

///|
test "style sheets as Chrome serializes them (1)" {
  let cases : Array[(String, Array[String])] = [
    ("#item36 { fill: CadetBlue }", ["#item36 { fill: cadetblue; }"]),
    (
      "text[id^=workaround] { fill: red; y: 100%; font-size: 15px;}",
      ["text[id^=\"workaround\"] { fill: red; y: 100%; font-size: 15px; }"],
    ),
    ("// x \\n #item36 { fill: CadetBlue }", []),
    (
      "DIV.Foo#Bar > SPAN + a ~ b  c { color: RED }",
      ["div.Foo#Bar > span + a ~ b c { color: red; }"],
    ),
    (
      "rect[ID=\"x\" i], [data-look=neo] { stroke: #F00; fill: #abc8 }",
      [
        "rect[id=\"x\" i], [data-look=\"neo\"] { stroke: rgb(255, 0, 0); fill: rgba(170, 187, 204, 0.533); }",
      ],
    ),
    (
      "a:HOVER, a::Before, a:before, a:not(.x, .y), a:nth-child(odd), a:nth-child(2N + 1 of .x), a:nth-child( -n+3 ), :is(a,b) :where(c) {color: blue}",
      [
        "a:hover, a::before, a::before, a:not(.x, .y), a:nth-child(2n+1), a:nth-child(2n+1 of .x), a:nth-child(-n+3), :is(a, b) :where(c) { color: blue; }",
      ],
    ),
    ("svg|rect { fill: red }", []),
    ("*|rect, |rect, * { fill: red }", ["rect, |rect, * { fill: red; }"]),
    (
      ".a{fill:none;stroke:currentColor;opacity:.5;stroke-width:0;stroke-dasharray:3 4,5;transform:translate(9px, 25px);height:calc(100% - 50px);y:0;width:1.5px}",
      [
        ".a { fill: none; stroke: currentcolor; opacity: 0.5; stroke-width: 0; stroke-dasharray: 3, 4, 5; transform: translate(9px, 25px); height: calc(100% - 50px); y: 0; width: 1.5px; }",
      ],
    ),
    (
      ".b{margin:0;padding:1px 2px 1px 2px;border:1px solid red;font-family:Trebuchet MS, \"Arial\", sans-serif;font-weight:BOLD;display:NONE;--x:  Foo  Bar ;x:10;font-size:Large}",
      [
        ".b { margin: 0px; padding: 1px 2px; border: 1px solid red; font-family: \"Trebuchet MS\", Arial, sans-serif; font-weight: bold; display: none; --x: Foo  Bar; x: 10; font-size: large; }",
      ],
    ),
    (
      ".c{color:rgb(10 20 30 / 50%);fill:hsl(120, 100%, 50%);stroke:transparent;color:rgba(1,2,3,0.333)}",
      [
        ".c { fill: rgb(0, 255, 0); stroke: transparent; color: rgba(1, 2, 3, 0.333); }",
      ],
    ),
    (
      ".d{fill:red !important;fill:blue;unknown-prop:1;stroke:}",
      [".d { fill: red !important; }"],
    ),
    (
      "@media screen and (min-width:100px){.e{fill:red}}",
      ["@media screen and (min-width: 100px) {\n  .e { fill: red; }\n}"],
    ),
    (
      "@keyframes k{from{opacity:0}TO{opacity:1}50%{opacity:.5}}",
      [
        "@keyframes k { \n  0% { opacity: 0; }\n  100% { opacity: 1; }\n  50% { opacity: 0.5; }\n}",
      ],
    ),
    (".f{}", [".f { }"]),
    (".g{fill:red;;fill:blue}", [".g { fill: blue; }"]),
    (
      ".h{height:calc(10px + 5px);width:calc(50px + 100%);x:calc(2 * 3px)}",
      [".h { height: calc(15px); width: calc(100% + 50px); x: calc(6px); }"],
    ),
    (
      ".i{opacity:50%;stroke-opacity:1.0;fill-opacity:2}",
      [".i { opacity: 0.5; stroke-opacity: 1; fill-opacity: 2; }"],
    ),
    (
      ".j{transform:rotate(45DEG) scale(2,2) translateX(0)}",
      [".j { transform: rotate(45deg) scale(2, 2) translateX(0px); }"],
    ),
    (
      "a::after, ::selection, :root, :host, :lang(en), :checked { color: red }",
      [
        "a::after, ::selection, :root, :host, :lang(en), :checked { color: red; }",
      ],
    ),
    (
      "a:unknown-pseudo { color: red } b { color: blue }",
      ["b { color: blue; }"],
    ),
    (
      "foreignObject, linearGradient, FOREIGNOBJECT, Rect, svg rect {fill:red}",
      [
        "foreignobject, lineargradient, foreignobject, rect, svg rect { fill: red; }",
      ],
    ),
    (
      ".x{x:10;y:1.5;cx:0;r:2;rx:3;stroke-width:2;stroke-dashoffset:1;width:10;height:0;font-size:10;margin:1;letter-spacing:2;top:0;line-height:2;opacity:1}",
      [
        ".x { x: 10; y: 1.5; cx: 0; r: 2; rx: 3; stroke-width: 2; stroke-dashoffset: 1; height: 0px; top: 0px; line-height: 2; opacity: 1; }",
      ],
    ),
    (
      ".x{width:10PX;height:1E2px;x:+5px;y:-0px;r:.50em;rx:1.234567890px;ry:123456789px;stroke-width:0.0000001px;cy:1e-7px}",
      [
        ".x { width: 10px; height: 100px; x: 5px; y: 0px; r: 0.5em; rx: 1.23457px; ry: 1.23457e+08px; stroke-width: 1e-07px; cy: 1e-07px; }",
      ],
    ),
    (
      ".x{width:1in;height:2.54cm;x:10mm;y:1q;r:1pt;rx:1pc;ry:1vw;cx:1rem;cy:1ex;stroke-width:1ch}",
      [
        ".x { width: 1in; height: 2.54cm; x: 10mm; y: 1q; r: 1pt; rx: 1pc; ry: 1vw; cx: 1rem; cy: 1ex; stroke-width: 1ch; }",
      ],
    ),
    (
      ".x{height:calc(1in + 1px);width:calc(1in);x:calc(100%);y:calc(1em + 2px + 1em);r:calc((10px + 5%) * 2);rx:calc(10px / 2);ry:calc(-1 * 5px);cx:calc(1px - 1px);cy:calc(2em - 50%)}",
      [
        ".x { height: calc(97px); width: calc(96px); x: calc(100%); y: calc(2em + 2px); r: calc(10% + 20px); rx: calc(5px); ry: calc(-5px); cx: calc(0px); cy: calc(-50% + 2em); }",
      ],
    ),
    (
      ".x{color:Canvas;fill:ButtonText;stroke:CURRENTCOLOR;stop-color:Transparent}",
      [
        ".x { color: canvas; fill: buttontext; stroke: currentcolor; stop-color: transparent; }",
      ],
    ),
    (
      ".x{color:#ABCDEF;fill:#abcdef80;stroke:#0000;stop-color:#fff;flood-color:rgb(300,0,-5);lighting-color:rgba(10%,20%,30%,.5)}",
      [
        ".x { color: rgb(171, 205, 239); fill: rgba(171, 205, 239, 0.5); stroke: rgba(0, 0, 0, 0); stop-color: rgb(255, 255, 255); flood-color: rgb(255, 0, 0); lighting-color: rgba(26, 51, 77, 0.5); }",
      ],
    ),
    (
      ".x{color:rgb(10,20,30,0.5);fill:rgb(10 20 30);stroke:hsl(30deg 50% 50% / 25%);stop-color:hsla(400,50%,50%,1);flood-color:rgb(1.5, 2.5, 3.5)}",
      [
        ".x { color: rgba(10, 20, 30, 0.5); fill: rgb(10, 20, 30); stroke: rgba(191, 128, 64, 0.25); stop-color: rgb(191, 149, 64); flood-color: rgb(2, 3, 4); }",
      ],
    ),
    (
      ".x{color:rgb(10,20 30);fill:rgb();stroke:#ggg;stop-color:redd}",
      [".x { }"],
    ),
    (
      ".x{fill:url(#a);stroke:url(\"#b\") red;color:none}",
      [".x { fill: url(\"#a\"); stroke: url(\"#b\") red; }"],
    ),
    (
      ".x{fill:none !IMPORTANT;stroke: red ! important;color:red!important}",
      [
        ".x { fill: none !important; stroke: red !important; color: red !important; }",
      ],
    ),
    (
      ".x{display:Block;visibility:HIDDEN;text-anchor:Middle;dominant-baseline:central;stroke-linecap:ROUND;font-style:Italic;font-weight:700;font-weight:Bolder}",
      [
        ".x { display: block; visibility: hidden; text-anchor: middle; dominant-baseline: central; stroke-linecap: round; font-style: italic; font-weight: bolder; }",
      ],
    ),
    (
      ".x{font-family:serif;font-family:\"Times New Roman\";font-family:Arial Black,  monospace;font-family:'single'}",
      [".x { font-family: single; }"],
    ),
    (
      ".x{font-family:\"sans-serif\";font-family:\"inherit\"}",
      [".x { font-family: \"inherit\"; }"],
    ),
    (
      ".x{font-family:a b c, \"d e\"}",
      [".x { font-family: \"a b c\", \"d e\"; }"],
    ),
    (
      ".x{transform:translate(0);transform:translate(10px,0);transform:matrix(1,0,0,1,0,0);transform:rotate(0.5turn);transform:skewX(10deg) translateY(1EM);transform:none;transform:scale(1.5)}",
      [".x { transform: scale(1.5); }"],
    ),
    (
      ".x{stroke-dasharray:none;stroke-dasharray:1px 2%;stroke-dasharray:5;stroke-dasharray:1,2 , 3}",
      [".x { stroke-dasharray: 1, 2, 3; }"],
    ),
    (
      ".x{margin:1px 2px 3px;margin:1px 2px 1px;padding:1px 1px 1px 1px;padding:auto;margin:auto 0}",
      [".x { padding: 1px; margin: auto 0px; }"],
    ),
    (".x{border:2px dashed;border:Red;border:solid}", [".x { border: solid; }"]),
    (
      ".x{color:red;COLOR:blue;Fill:green}",
      [".x { color: blue; fill: green; }"],
    ),
    (
      ".x{--Foo:  a  ;  --bar:{x};--baz:}",
      [".x { --Foo: a; --bar: {x}; --baz: ; }"],
    ),
    (
      "*.a, *|*, |*, *, *#b, *[c] {fill:red}",
      [".a, *, |*, *, #b, [c] { fill: red; }"],
    ),
    ("& {fill:red}", ["& { fill: red; }"]),
    ("& .a, .a & {fill:red}", ["& .a, .a & { fill: red; }"]),
    (
      ":nth-child(2n-1), :nth-child(2n- 1), :nth-child(2n - 1), :nth-child(-n-1), :nth-child(+n+1), :nth-child(n), :nth-child(0n+5), :nth-child(3), :nth-child(-3), :nth-child(2n+0), :nth-child(even), :nth-child(ODD), :nth-of-type(n+2), :nth-last-child(1n) {fill:red}",
      [
        ":nth-child(2n-1), :nth-child(2n-1), :nth-child(2n-1), :nth-child(-n-1), :nth-child(n+1), :nth-child(n), :nth-child(5), :nth-child(3), :nth-child(-3), :nth-child(2n), :nth-child(2n), :nth-child(2n+1), :nth-of-type(n+2), :nth-last-child(n) { fill: red; }",
      ],
    ),
    (":nth-child(+ n) {fill:red}", []),
    (":nth-of-type(2n of .a) {fill:red}", []),
    (
      ":not(.a b), :not(:not(.c)) {fill:red}",
      [":not(.a b), :not(:not(.c)) { fill: red; }"],
    ),
    (":not(.a, :bogus) {fill:red}", []),
    (
      ":is(.a, :bogus), :where(:bogus), :is() {fill:red}",
      [":is(.a), :where(), :is() { fill: red; }"],
    ),
    (":lang(en, \"fr-CA\", de-*), :dir(RTL) {fill:red}", []),
    (
      "[A], [b|=x], [c~=y], [d$=\"z\"], [e*=w], [f=\"a\\\"b\"], [g=\"a\\\\b\" S], [h='x' I] {fill:red}",
      [],
    ),
    (
      ".a\\:b, #\\31 23, .\\31 a, .\\-, .--x, ._y, .\u{e9}, .a\\ b {fill:red}",
      [
        ".a\\:b, #\\31 23, .\\31 a, .\\-, .--x, ._y, .\u{e9}, .a\\ b { fill: red; }",
      ],
    ),
    ("a:hover::before, a::before:hover, a::before b, a::BEFORE {fill:red}", []),
    (
      "a::marker, a::placeholder, a::backdrop, a::-webkit-scrollbar, a::first-line, a:first-letter {fill:red}",
      [
        "a::marker, a::placeholder, a::backdrop, a::-webkit-scrollbar, a::first-line, a::first-letter { fill: red; }",
      ],
    ),
    (
      "a  >  b,a>b,a+b,a~b, a\tb {fill:red}",
      ["a > b, a > b, a + b, a ~ b, a b { fill: red; }"],
    ),
    ("a>, >a {fill:red}", []),
    ("a,,b {fill:red}", []),
    (
      ":hover:focus:active:visited:link:first-child:last-child:only-child:empty:root:target:enabled:disabled:checked:focus-visible:focus-within:any-link:first-of-type:last-of-type:only-of-type:placeholder-shown:read-only:read-write:required:optional:valid:invalid:indeterminate:default:defined:scope {fill:red}",
      [
        ":hover:focus:active:visited:link:first-child:last-child:only-child:empty:root:target:enabled:disabled:checked:focus-visible:focus-within:any-link:first-of-type:last-of-type:only-of-type:placeholder-shown:read-only:read-write:required:optional:valid:invalid:indeterminate:default:defined:scope { fill: red; }",
      ],
    ),
  ]
  json_inspect(cssom_differences(cases), content=[])
}

///|
test "style sheets as Chrome serializes them (2)" {
  let cases : Array[(String, Array[String])] = [
    (
      ":nth-child(2n of .a, .b) {fill:red}",
      [":nth-child(2n of .a, .b) { fill: red; }"],
    ),
    (
      ":nth-last-child(n of a b) {fill:red}",
      [":nth-last-child(n of a b) { fill: red; }"],
    ),
    (":lang(en) {fill:red}", [":lang(en) { fill: red; }"]),
    (":lang(\"fr-CA\") {fill:red}", []),
    (":lang(de-*) {fill:red}", []),
    (":lang(en, fr) {fill:red}", []),
    (":dir(RTL) {fill:red}", [":dir(RTL) { fill: red; }"]),
    (":dir(ltr) {fill:red}", [":dir(ltr) { fill: red; }"]),
    ("[A] {fill:red}", ["[a] { fill: red; }"]),
    ("[b|=x] {fill:red}", ["[b|=\"x\"] { fill: red; }"]),
    ("[c~=y] {fill:red}", ["[c~=\"y\"] { fill: red; }"]),
    ("[d$=\"z\"] {fill:red}", ["[d$=\"z\"] { fill: red; }"]),
    ("[e*=w] {fill:red}", ["[e*=\"w\"] { fill: red; }"]),
    ("[f=\"a\\\"b\"] {fill:red}", ["[f=\"a\\\"b\"] { fill: red; }"]),
    ("[g=\"a\\\\b\" S] {fill:red}", []),
    ("[h='x' I] {fill:red}", ["[h=\"x\" i] { fill: red; }"]),
    ("[ i ] {fill:red}", ["[i] { fill: red; }"]),
    ("[j = k] {fill:red}", ["[j=\"k\"] { fill: red; }"]),
    ("[k=1] {fill:red}", []),
    ("[l=-x] {fill:red}", ["[l=\"-x\"] { fill: red; }"]),
    ("[*|m] {fill:red}", ["[*|m] { fill: red; }"]),
    ("[|n] {fill:red}", ["[n] { fill: red; }"]),
    ("a:hover::before {fill:red}", ["a:hover::before { fill: red; }"]),
    ("a::before:hover {fill:red}", []),
    ("a::before b {fill:red}", []),
    ("a::BEFORE {fill:red}", ["a::before { fill: red; }"]),
    ("a::before.x {fill:red}", []),
    ("a::before::after {fill:red}", []),
    ("::before {fill:red}", ["::before { fill: red; }"]),
    (":BEFORE {fill:red}", ["::before { fill: red; }"]),
    (":Hover {fill:red}", [":hover { fill: red; }"]),
    (":HOVER {fill:red}", [":hover { fill: red; }"]),
    ("A:Not(.B) {fill:red}", ["a:not(.B) { fill: red; }"]),
    (":IS(a) {fill:red}", [":is(a) { fill: red; }"]),
    (":nth-child(N) {fill:red}", [":nth-child(n) { fill: red; }"]),
    (":nth-child( 2n + 1 ) {fill:red}", [":nth-child(2n+1) { fill: red; }"]),
    (":nth-child(-2n+3) {fill:red}", [":nth-child(-2n+3) { fill: red; }"]),
    (":nth-child(+5) {fill:red}", [":nth-child(5) { fill: red; }"]),
    (":nth-child(- n) {fill:red}", []),
    (":nth-child(n-0) {fill:red}", [":nth-child(n) { fill: red; }"]),
    (":nth-child(1N-1) {fill:red}", [":nth-child(n-1) { fill: red; }"]),
    (":nth-child(2n+ 1) {fill:red}", [":nth-child(2n+1) { fill: red; }"]),
    (":not() {fill:red}", []),
    (":where(a, :bogus, b) {fill:red}", [":where(a, b) { fill: red; }"]),
    (":is(a::before) {fill:red}", [":is() { fill: red; }"]),
    (":not(a::before) {fill:red}", []),
    ("a:is(.x)b {fill:red}", []),
    ("a.b.c#d#e {fill:red}", ["a.b.c#d#e { fill: red; }"]),
    ("#a#a {fill:red}", ["#a#a { fill: red; }"]),
    (".a.a {fill:red}", [".a.a { fill: red; }"]),
    ("[x].a[y] {fill:red}", ["[x].a[y] { fill: red; }"]),
    ("a|b {fill:red}", []),
    ("*|a.x {fill:red}", ["a.x { fill: red; }"]),
    ("svg|* {fill:red}", []),
    (
      ":focus-visible:is(.a) {fill:red}",
      [":focus-visible:is(.a) { fill: red; }"],
    ),
    (":-webkit-foo {fill:red}", []),
    (":-moz-any(a) {fill:red}", []),
    ("::cue {fill:red}", ["::cue { fill: red; }"]),
    (":popover-open {fill:red}", [":popover-open { fill: red; }"]),
    (":open {fill:red}", [":open { fill: red; }"]),
  ]
  json_inspect(cssom_differences(cases), content=[])
}

///|
test "style sheets as Chrome serializes them (3)" {
  let cases : Array[(String, Array[String])] = [
    (":modal {fill:red}", [":modal { fill: red; }"]),
    (":fullscreen {fill:red}", [":fullscreen { fill: red; }"]),
    (":picture-in-picture {fill:red}", [":picture-in-picture { fill: red; }"]),
    (":autofill {fill:red}", [":autofill { fill: red; }"]),
    (":user-invalid {fill:red}", [":user-invalid { fill: red; }"]),
    (":playing {fill:red}", []),
    (":muted {fill:red}", []),
    (".a{r:-1}", [".a { }"]),
    (".a{rx:-1px}", [".a { }"]),
    (".a{x:-1}", [".a { x: -1; }"]),
    (".a{stroke-width:-1}", [".a { }"]),
    (".a{width:-1px}", [".a { }"]),
    (".a{margin-top:-1px}", [".a { margin-top: -1px; }"]),
    (".a{padding-top:-1px}", [".a { }"]),
    (".a{font-size:-1px}", [".a { }"]),
    (".a{line-height:-1}", [".a { }"]),
    (".a{opacity:-1}", [".a { opacity: -1; }"]),
    (".a{opacity:2}", [".a { opacity: 2; }"]),
    (".a{fill-opacity:-50%}", [".a { fill-opacity: -0.5; }"]),
    (".a{stroke-miterlimit:0.5}", [".a { stroke-miterlimit: 0.5; }"]),
    (".a{stroke-miterlimit:-1}", [".a { }"]),
    (".a{z-index:1.0}", [".a { }"]),
    (".a{z-index:-3}", [".a { z-index: -3; }"]),
    (".a{rx:auto}", [".a { rx: auto; }"]),
    (".a{rx:AUTO}", [".a { rx: auto; }"]),
    (".a{x:calc(10)}", [".a { x: calc(10); }"]),
    (".a{opacity:calc(0.5)}", [".a { opacity: calc(0.5); }"]),
    (".a{opacity:calc(50%)}", [".a { opacity: calc(50%); }"]),
    (".a{width:calc(10% + 1px - 1px)}", [".a { width: calc(10% + 0px); }"]),
    (".a{width:calc(0% + 5px)}", [".a { width: calc(0% + 5px); }"]),
    (".a{width:calc(5px + 0%)}", [".a { width: calc(0% + 5px); }"]),
    (".a{border:1px currentcolor}", [".a { border: 1px; }"]),
    (".a{border:red 1px solid}", [".a { border: 1px solid red; }"]),
    (".a{border:2px dashed}", [".a { border: 2px dashed; }"]),
    (".a{border:red}", [".a { border: red; }"]),
    (".a{border-top:1px solid}", [".a { border-top: 1px solid; }"]),
    (".a{border-width:1px 2px}", [".a { border-width: 1px 2px; }"]),
    (".a{border-color:red blue red blue}", [".a { border-color: red blue; }"]),
    (".a{border-style:solid none}", [".a { border-style: solid none; }"]),
    (".a{display:-webkit-flex}", [".a { display: -webkit-flex; }"]),
    (".a{display:inline flow-root}", [".a { display: inline-block; }"]),
    (".a{display:block flow}", [".a { display: block; }"]),
    (".a{display:-webkit-box}", [".a { display: -webkit-box; }"]),
    (".a{display:inline-list-item}", [".a { }"]),
    (".a{display:flow}", [".a { display: block; }"]),
    (".a{font-family:SERIF}", [".a { font-family: serif; }"]),
    (".a{font-family:\"serif\"}", [".a { font-family: \"serif\"; }"]),
    (
      ".a{font-family:Sans-Serif, system-UI}",
      [".a { font-family: sans-serif, system-ui; }"],
    ),
    (".a{font-family:\"a b\"  ,  c}", [".a { font-family: \"a b\", c; }"]),
    (".a{font-family:\"1a\"}", [".a { font-family: \"1a\"; }"]),
    (".a{font-family:\"-x\"}", [".a { font-family: -x; }"]),
    (".a{font-family:default}", [".a { }"]),
    (".a{font-family:\"\"}", [".a { font-family: \"\"; }"]),
    (".a{font-family:a,}", [".a { }"]),
    (
      ".a{font-family:\"Trebuchet MS\",verdana,arial,sans-serif}",
      [".a { font-family: \"Trebuchet MS\", verdana, arial, sans-serif; }"],
    ),
    (".a{transform:translate(0)}", [".a { transform: translate(0px); }"]),
    (
      ".a{transform:translate(10px,0)}",
      [".a { transform: translate(10px, 0px); }"],
    ),
    (
      ".a{transform:matrix(1,0,0,1,0,0)}",
      [".a { transform: matrix(1, 0, 0, 1, 0, 0); }"],
    ),
    (".a{transform:rotate(0.5turn)}", [".a { transform: rotate(0.5turn); }"]),
    (
      ".a{transform:skewX(10deg) translateY(1EM)}",
      [".a { transform: skewX(10deg) translateY(1em); }"],
    ),
  ]
  json_inspect(cssom_differences(cases), content=[])
}

///|
test "style sheets as Chrome serializes them (4)" {
  let cases : Array[(String, Array[String])] = [
    (".a{transform:none}", [".a { transform: none; }"]),
    (".a{transform:scale(50%)}", [".a { transform: scale(0.5); }"]),
    (".a{transform:rotate(0)}", [".a { transform: rotate(0deg); }"]),
    (".a{transform:TRANSLATEX(1px)}", [".a { transform: translateX(1px); }"]),
    (".a{transform:translate(1px 2px)}", [".a { }"]),
    (
      ".a{transform:translate(1px,2px)rotate(1deg)}",
      [".a { transform: translate(1px, 2px) rotate(1deg); }"],
    ),
    (".a{transform:scale(1,2)}", [".a { transform: scale(1, 2); }"]),
    (".a{transform:skew(1deg,2deg)}", [".a { transform: skew(1deg, 2deg); }"]),
    (".a{transform:translateZ(1px)}", [".a { transform: translateZ(1px); }"]),
    (".a{transform:scaleX(2)}", [".a { transform: scaleX(2); }"]),
    (".a{stroke-dasharray:none}", [".a { stroke-dasharray: none; }"]),
    (".a{stroke-dasharray:1px 2%}", [".a { stroke-dasharray: 1px, 2%; }"]),
    (".a{stroke-dasharray:5}", [".a { stroke-dasharray: 5; }"]),
    (".a{stroke-dasharray:-1}", [".a { }"]),
    (".a{stroke-dasharray:1,,2}", [".a { }"]),
    (".a{stroke-dasharray:0}", [".a { stroke-dasharray: 0; }"]),
    (".a{fill:red !important}", [".a { fill: red !important; }"]),
    (".a{fill:INHERIT}", [".a { fill: inherit; }"]),
    (".a{fill:inherit red}", [".a { }"]),
    (".a{fill:revert-layer}", [".a { fill: revert-layer; }"]),
    (".a{fill:context-fill}", [".a { fill: context-fill; }"]),
    (".a{fill:url(#a) none}", [".a { fill: url(\"#a\") none; }"]),
    (".a{fill:url( 'x' )}", [".a { fill: url(\"x\"); }"]),
    (".a{marker-end:url(#m)}", [".a { marker-end: url(\"#m\"); }"]),
    (".a{fill:none red}", [".a { }"]),
    (".a{font-weight:1000}", [".a { font-weight: 1000; }"]),
    (".a{font-weight:1001}", [".a { }"]),
    (".a{font-weight:0}", [".a { }"]),
    (".a{font-weight:400.5}", [".a { font-weight: 400.5; }"]),
    (".a{font-size:LARGER}", [".a { font-size: larger; }"]),
    (".a{font-size:10%}", [".a { font-size: 10%; }"]),
    (".a{line-height:NORMAL}", [".a { line-height: normal; }"]),
    (".a{line-height:1.50}", [".a { line-height: 1.5; }"]),
    (".a{line-height:0}", [".a { line-height: 0; }"]),
    (".a{letter-spacing:NORMAL}", [".a { letter-spacing: normal; }"]),
    (".a{letter-spacing:0}", [".a { letter-spacing: 0px; }"]),
    (".a{vertical-align:middle}", [".a { vertical-align: middle; }"]),
    (".a{vertical-align:-2px}", [".a { vertical-align: -2px; }"]),
    (".a{width:AUTO}", [".a { width: auto; }"]),
    (".a{width:fit-content}", [".a { width: fit-content; }"]),
    (".a{width:-webkit-fit-content}", [".a { width: -webkit-fit-content; }"]),
    (".a{max-width:none}", [".a { max-width: none; }"]),
    (".a{min-width:auto}", [".a { min-width: auto; }"]),
    (".a{height:stretch}", [".a { height: stretch; }"]),
    (".a{cursor:POINTER}", [".a { cursor: pointer; }"]),
    (
      ".a{pointer-events:visiblePainted}",
      [".a { pointer-events: visiblepainted; }"],
    ),
    (
      ".a{fill:red;fill:blue !important;fill:green}",
      [".a { fill: blue !important; }"],
    ),
    (
      ".a{fill:red !important;fill:blue !important}",
      [".a { fill: blue !important; }"],
    ),
    (
      "@media (prefers-color-scheme: dark) { .a { fill: white } }",
      ["@media (prefers-color-scheme: dark) {\n  .a { fill: white; }\n}"],
    ),
    (
      "@media screen, print { .a { fill: red } .b { stroke: blue } }",
      ["@media screen, print {\n  .a { fill: red; }\n  .b { stroke: blue; }\n}"],
    ),
    (
      "@media SCREEN AND (MAX-WIDTH: 600PX) { .a { fill: red } }",
      ["@media screen and (max-width: 600px) {\n  .a { fill: red; }\n}"],
    ),
    (
      "@media not print { .a { fill: red } }",
      ["@media not print {\n  .a { fill: red; }\n}"],
    ),
    (
      "@media only screen { .a { fill: red } }",
      ["@media only screen {\n  .a { fill: red; }\n}"],
    ),
    (
      "@media (min-width: 10em) and (max-width: 20.50em) { .a { fill: red } }",
      [
        "@media (min-width: 10em) and (max-width: 20.5em) {\n  .a { fill: red; }\n}",
      ],
    ),
    (
      "@media (orientation: landscape) { }",
      ["@media (orientation: landscape) {\n}"],
    ),
    (
      "@media (min-resolution: 2dppx) { .a { fill: red } }",
      ["@media (min-resolution: 2dppx) {\n  .a { fill: red; }\n}"],
    ),
    (
      "@media (bogus-feature: 1) { .a { fill: red } }",
      ["@media (bogus-feature: 1) {\n  .a { fill: red; }\n}"],
    ),
    (
      "@media screen { .a { fill: red } @media print { .b { fill: blue } } }",
      [
        "@media screen {\n  .a { fill: red; }\n  @media print {\n  .b { fill: blue; }\n}\n}",
      ],
    ),
    (
      "@keyframes spin { from { transform: rotate(0deg) } to { transform: rotate(360deg) } }",
      [
        "@keyframes spin { \n  0% { transform: rotate(0deg); }\n  100% { transform: rotate(360deg); }\n}",
      ],
    ),
    (
      "@keyframes \"quoted\" { 0% { opacity: 0 } }",
      ["@keyframes quoted { \n  0% { opacity: 0; }\n}"],
    ),
  ]
  json_inspect(cssom_differences(cases), content=[])
}

///|
test "style sheets as Chrome serializes them (5)" {
  let cases : Array[(String, Array[String])] = [
    (
      "@keyframes k { 0%, 100% { opacity: 1 } 50% { opacity: 0.5 !important; fill: red } }",
      ["@keyframes k { \n  0%, 100% { opacity: 1; }\n  50% { fill: red; }\n}"],
    ),
    (
      "@keyframes k { 120% { opacity: 1 } from { opacity: 0 } }",
      ["@keyframes k { \n  0% { opacity: 0; }\n}"],
    ),
    ("@keyframes none { from { opacity: 0 } }", []),
    ("@keyframes k { }", ["@keyframes k { \n}"]),
    (
      "@-webkit-keyframes k { from { opacity: 0 } }",
      ["@-webkit-keyframes k { \n  0% { opacity: 0; }\n}"],
    ),
    ("@import url(a.css); .a { fill: red }", [".a { fill: red; }"]),
    ("@charset \"utf-8\"; .a { fill: red }", [".a { fill: red; }"]),
    (
      "@unknown foo { .a { fill: red } } .b { fill: blue }",
      [".b { fill: blue; }"],
    ),
    ("<!-- .a { fill: red } -->", [".a { fill: red; }"]),
    (
      ".a { fill: red } garbage .b { fill: blue }",
      [".a { fill: red; }", "garbage .b { fill: blue; }"],
    ),
    (".a { fill: red", [".a { fill: red; }"]),
    (".a { fill: red; } }  .b { fill: blue }", [".a { fill: red; }"]),
    (
      "/* comment */ .a /* c */ { /* c */ fill /* c */ : /* c */ red /* c */ }",
      [".a { fill: red; }"],
    ),
    (
      ".a { --x: a /* c */  b; --y:   ; --z: {a:b}; --W: 1 }",
      [".a { --x: a /* c */  b; --y: ; --z: {a:b}; --W: 1; }"],
    ),
    (".a { --x: \\41 }", [".a { --x: \\41; }"]),
    (
      ".a { x: 1.0; y: 0.10; cx: 100.000; cy: 1e3; r: 1.5e-3 }",
      [".a { x: 1; y: 0.1; cx: 100; cy: 1000; r: 0.0015; }"],
    ),
    (
      ".a { x: 123456.7; y: 1234567; cx: 0.000012345; cy: -0.5 }",
      [".a { x: 123457; y: 1.23457e+06; cx: 1.2345e-05; cy: -0.5; }"],
    ),
    (
      ".a { width: 33.333333%; height: 66.66666666px }",
      [".a { width: 33.3333%; height: 66.6667px; }"],
    ),
    (
      ".a { x: 1PX; y: 2Em; cx: 3Rem; cy: 4VW; r: 5Cm }",
      [".a { x: 1px; y: 2em; cx: 3rem; cy: 4vw; r: 5cm; }"],
    ),
    (
      ".a { font-size: 12px; font-size: 1.2em; font-size: 120%; font-size: x-large }",
      [".a { font-size: x-large; }"],
    ),
    (".a { font-size: 12 }", [".a { }"]),
    (
      ".a { stroke-width: 2.5px; stroke-width: .5 }",
      [".a { stroke-width: 0.5; }"],
    ),
    (
      ".a { width: calc(1em + 1rem + 1px + 1% + 1vw) }",
      [".a { width: calc(1% + 1em + 1px + 1rem + 1vw); }"],
    ),
    (".a { width: calc(1px + 1in - 1cm) }", [".a { width: calc(59.2047px); }"]),
    (".a { width: calc(100% / 3) }", [".a { width: calc(33.3333%); }"]),
    (".a { width: calc(100%/3) }", [".a { width: calc(33.3333%); }"]),
    (".a { width: calc(100%-3px) }", [".a { }"]),
    (".a { width: calc((100%)) }", [".a { width: calc(100%); }"]),
    (".a { width: calc(calc(1px + 2px) * 2) }", [".a { width: calc(6px); }"]),
    (".a { width: calc(2 * 3 * 1px) }", [".a { width: calc(6px); }"]),
    (".a { width: calc(1px * 0) }", [".a { width: calc(0px); }"]),
    (".a { width: calc(-1px) }", [".a { width: calc(-1px); }"]),
    (".a { width: calc( 1px ) }", [".a { width: calc(1px); }"]),
    (
      ".a { transform: rotate(calc(1turn / 4)) }",
      [".a { transform: rotate(calc(90deg)); }"],
    ),
    (".a { opacity: calc(1 / 3) }", [".a { opacity: calc(0.333333); }"]),
    (".a { width: CALC(1px + 2px) }", [".a { width: calc(3px); }"]),
    (
      ".a { margin: calc(1px + 1%) auto }",
      [".a { margin: calc(1% + 1px) auto; }"],
    ),
    (
      ".a { fill: #FFF; stroke: #ffffff; color: #FFFFFF80; stop-color: #12345678 }",
      [
        ".a { fill: rgb(255, 255, 255); stroke: rgb(255, 255, 255); color: rgba(255, 255, 255, 0.5); stop-color: rgba(18, 52, 86, 0.47); }",
      ],
    ),
    (
      ".a { fill: rgb(255, 128, 0); stroke: rgb(100%, 50%, 0%); color: rgba(255, 0, 0, 0.5) }",
      [
        ".a { fill: rgb(255, 128, 0); stroke: rgb(255, 128, 0); color: rgba(255, 0, 0, 0.5); }",
      ],
    ),
    (
      ".a { fill: rgb(255 128 0 / 0.25); stroke: rgb(0 0 0 / 0); color: rgba(0, 0, 0, 1) }",
      [
        ".a { fill: rgba(255, 128, 0, 0.25); stroke: rgba(0, 0, 0, 0); color: rgb(0, 0, 0); }",
      ],
    ),
    (
      ".a { fill: hsl(0, 100%, 50%); stroke: hsl(120deg 100% 25%); color: hsla(240, 100%, 50%, .3) }",
      [
        ".a { fill: rgb(255, 0, 0); stroke: rgb(0, 128, 0); color: rgba(0, 0, 255, 0.3); }",
      ],
    ),
    (
      ".a { fill: hsl(0.5turn 50% 50%); stroke: hsl(3.14rad, 50%, 50%) }",
      [".a { fill: rgb(64, 191, 191); stroke: rgb(64, 191, 191); }"],
    ),
    (".a { fill: rgb(10, 20%, 30) }", [".a { }"]),
    (".a { fill: rgb(10 20 30 40) }", [".a { }"]),
    (".a { fill: rgba(10, 20, 30) }", [".a { fill: rgb(10, 20, 30); }"]),
    (".a { fill: RGB(1, 2, 3) }", [".a { fill: rgb(1, 2, 3); }"]),
    (".a { fill: rgb(1e1, 2, 3) }", [".a { fill: rgb(10, 2, 3); }"]),
    (
      ".a { fill: rgb(10, 20, 30, 50%) }",
      [".a { fill: rgba(10, 20, 30, 0.5); }"],
    ),
    (".a { fill: rgb(-10, 300, 128.4) }", [".a { fill: rgb(0, 255, 128); }"]),
    (
      ".a { fill: #0f08; stroke: #0f0f }",
      [".a { fill: rgba(0, 255, 0, 0.533); stroke: rgb(0, 255, 0); }"],
    ),
    (
      ".a { fill: Red; stroke: REBECCAPURPLE; color: DarkSlateGray; stop-color: grey }",
      [
        ".a { fill: red; stroke: rebeccapurple; color: darkslategray; stop-color: grey; }",
      ],
    ),
    (
      ".a { fill: currentColor; stroke: Transparent }",
      [".a { fill: currentcolor; stroke: transparent; }"],
    ),
    (".a { fill: notacolor }", [".a { }"]),
    (".a { fill: #12345 }", [".a { }"]),
    (
      ".a { background-color: lightblue; border-top-color: navy }",
      [".a { background-color: lightblue; border-top-color: navy; }"],
    ),
    (
      ".a { fill: url(\"a b\"); stroke: url('#x') }",
      [".a { fill: url(\"a b\"); stroke: url(\"#x\"); }"],
    ),
    (".a { fill: url(a\\)b) }", [".a { fill: url(\"a)b\"); }"]),
    (".a { fill: url(\"#a\") blue }", [".a { fill: url(\"#a\") blue; }"]),
    (
      ".a { font-family: \"Trebuchet MS\", Verdana, Arial, Sans-Serif }",
      [".a { font-family: \"Trebuchet MS\", Verdana, Arial, sans-serif; }"],
    ),
    (
      ".a { font-family: 'Open Sans', sans-serif }",
      [".a { font-family: \"Open Sans\", sans-serif; }"],
    ),
  ]
  json_inspect(cssom_differences(cases), content=[])
}

///|
test "style sheets as Chrome serializes them (6)" {
  let cases : Array[(String, Array[String])] = [
    (".a { font-family: Open Sans }", [".a { font-family: \"Open Sans\"; }"]),
    (
      ".a { font-family: \"font\\\"x\" }",
      [".a { font-family: \"font\\\"x\"; }"],
    ),
    (
      ".a { font-family: monospace, MONOSPACE }",
      [".a { font-family: monospace, monospace; }"],
    ),
    (
      ".a { font-family: \"Arial\", \"Helvetica Neue\" }",
      [".a { font-family: Arial, \"Helvetica Neue\"; }"],
    ),
    (".a { font-family: arial 3 }", [".a { }"]),
    (".a { font-family: inherit }", [".a { font-family: inherit; }"]),
    (
      ".a { font-family: \"Recursive Variable\", arial, sans-serif }",
      [".a { font-family: \"Recursive Variable\", arial, sans-serif; }"],
    ),
    (
      ".a { display: none; visibility: visible; cursor: default }",
      [".a { display: none; visibility: visible; cursor: default; }"],
    ),
    (
      ".a { text-anchor: END; dominant-baseline: Middle; alignment-baseline: BASELINE }",
      [
        ".a { text-anchor: end; dominant-baseline: middle; alignment-baseline: baseline; }",
      ],
    ),
    (
      ".a { stroke-linejoin: Bevel; fill-rule: EvenOdd; clip-rule: nonzero }",
      [".a { stroke-linejoin: bevel; fill-rule: evenodd; clip-rule: nonzero; }"],
    ),
    (
      ".a { pointer-events: NONE; position: Absolute; box-sizing: Border-Box }",
      [
        ".a { pointer-events: none; position: absolute; box-sizing: border-box; }",
      ],
    ),
    (
      ".a { text-transform: uppercase; text-align: Center; vertical-align: Top }",
      [
        ".a { text-transform: uppercase; text-align: center; vertical-align: top; }",
      ],
    ),
    (
      ".a { display: inline flex; display: flex inline }",
      [".a { display: inline-flex; }"],
    ),
    (".a { visibility: bogus }", [".a { }"]),
    (
      ".a { fill: red !important; stroke: blue ! IMPORTANT }",
      [".a { fill: red !important; stroke: blue !important; }"],
    ),
    (".a { fill: red !important !important }", [".a { }"]),
    (".a { fill: red important }", [".a { }"]),
    (
      ".a { fill: red; stroke: blue; fill: green }",
      [".a { stroke: blue; fill: green; }"],
    ),
    (
      ".a { fill: red !important; fill: green; stroke: blue }",
      [".a { stroke: blue; fill: red !important; }"],
    ),
    (".a { fill: red; fill: bogus }", [".a { fill: red; }"]),
    (
      ".a { FILL: Red; Stroke-Width: 2PX }",
      [".a { fill: red; stroke-width: 2px; }"],
    ),
    (".a { -webkit-unknown: 1; fill: red }", [".a { fill: red; }"]),
    (".a { fill red; stroke: blue }", [".a { stroke: blue; }"]),
    (".a { : red; stroke: blue }", [".a { stroke: blue; }"]),
    (".a { fill: ; stroke: blue }", [".a { stroke: blue; }"]),
    (".a { margin: 1px 2px 3px 4px }", [".a { margin: 1px 2px 3px 4px; }"]),
    (".a { margin: 1px 2px 3px 2px }", [".a { margin: 1px 2px 3px; }"]),
    (".a { margin: 1px 1px 1px 1px }", [".a { margin: 1px; }"]),
    (".a { margin: 0 auto }", [".a { margin: 0px auto; }"]),
    (".a { margin: 1px 2px 3px 4px 5px }", [".a { }"]),
    (".a { padding: 0 }", [".a { padding: 0px; }"]),
    (".a { padding: 5% 10px }", [".a { padding: 5% 10px; }"]),
    (
      ".a { border: 1px solid #000 }",
      [".a { border: 1px solid rgb(0, 0, 0); }"],
    ),
    (
      ".a { border: thick double rgb(0 0 0) }",
      [".a { border: thick double rgb(0, 0, 0); }"],
    ),
    (".a { border: solid 2px }", [".a { border: 2px solid; }"]),
    (".a { border: 1px solid red blue }", [".a { }"]),
    (
      ".a { border-top: 2px dotted; border-bottom: 1px solid }",
      [".a { border-top: 2px dotted; border-bottom: 1px solid; }"],
    ),
    (
      ".a { border-width: thin medium; border-style: none solid dotted }",
      [".a { border-width: thin medium; border-style: none solid dotted; }"],
    ),
    (".a { margin: 1px; padding: 2px }", [".a { margin: 1px; padding: 2px; }"]),
    (
      ".a { margin-top: 1px; margin-left: 2px }",
      [".a { margin-top: 1px; margin-left: 2px; }"],
    ),
    (".a .b > .c + .d ~ .e {fill:red}", [".a .b > .c + .d ~ .e { fill: red; }"]),
    (
      "svg .node rect, svg .node circle {fill:red}",
      ["svg .node rect, svg .node circle { fill: red; }"],
    ),
    (
      "#mermaid-1 .node:hover rect {fill:red}",
      ["#mermaid-1 .node:hover rect { fill: red; }"],
    ),
    ("g.classGroup text {fill:red}", ["g.classGroup text { fill: red; }"]),
    (".edgePath .path {stroke:red}", [".edgePath .path { stroke: red; }"]),
    (
      "[data-look=\"neo\"].node rect {fill:red}",
      ["[data-look=\"neo\"].node rect { fill: red; }"],
    ),
    (
      "text[id^=workaround] {fill:red}",
      ["text[id^=\"workaround\"] { fill: red; }"],
    ),
    ("rect[id$=\"-bar\" i] {fill:red}", ["rect[id$=\"-bar\" i] { fill: red; }"]),
    (
      ".A\\.B, .a\\#b, #a\\:b {fill:red}",
      [".A\\.B, .a\\#b, #a\\:b { fill: red; }"],
    ),
    (".\\31 23, #\\32 {fill:red}", [".\\31 23, #\\32  { fill: red; }"]),
    (".a:not(.b):hover {fill:red}", [".a:not(.b):hover { fill: red; }"]),
    (".a::after, .b:after {fill:red}", [".a::after, .b::after { fill: red; }"]),
    (
      "a:nth-child(2n+1 of .x, .y) {fill:red}",
      ["a:nth-child(2n+1 of .x, .y) { fill: red; }"],
    ),
    ("li:nth-of-type(3n) {fill:red}", ["li:nth-of-type(3n) { fill: red; }"]),
    (":root {--x:1}", [":root { --x: 1; }"]),
    (".a, {fill:red}", []),
    (".a .b, .c:bogus {fill:red}", []),
    ("* {fill:red}", ["* { fill: red; }"]),
    ("*.a *.b {fill:red}", [".a .b { fill: red; }"]),
    ("a * b {fill:red}", ["a * b { fill: red; }"]),
  ]
  json_inspect(cssom_differences(cases), content=[])
}

///|
test "style sheets as Chrome serializes them (7)" {
  let cases : Array[(String, Array[String])] = [
    (
      "rect#a.b[c=\"d\"]:hover {fill:red}",
      ["rect#a.b[c=\"d\"]:hover { fill: red; }"],
    ),
    ("RECT.Node {fill:red}", ["rect.Node { fill: red; }"]),
    (":is(svg, g) > rect {fill:red}", [":is(svg, g) > rect { fill: red; }"]),
    (":where(.a .b, .c) {fill:red}", [":where(.a .b, .c) { fill: red; }"]),
    (":not(.a):not(.b) {fill:red}", [":not(.a):not(.b) { fill: red; }"]),
  ]
  json_inspect(cssom_differences(cases), content=[])
}

///|
test "style sheets the port does not serialize" {
  let cases : Array[(String, Array[String])] = [
    (".x{width:min(1px, 2%);height:calc(10px * 2px)}", ["unported: min()"]),
    (
      ":-webkit-any(a, b), :host(.a), :host-context(.b), ::slotted(span), ::part(x) {fill:red}",
      ["unported: the pseudo-class :-webkit-any()"],
    ),
    (
      ":has(> a), :has(+ b, .c) {fill:red}",
      ["unported: the pseudo-class :has()"],
    ),
    (
      "@namespace svg url(http://www.w3.org/2000/svg); svg|rect {fill:red}",
      ["unported: @namespace rules"],
    ),
    (":has(a) {fill:red}", ["unported: the pseudo-class :has()"]),
    (":has(:has(a)) {fill:red}", ["unported: the pseudo-class :has()"]),
    ("::-webkit-foo {fill:red}", ["unported: the pseudo-element ::-webkit-foo"]),
    ("::cue(b) {fill:red}", ["unported: the pseudo-element ::cue()"]),
    (":state(x) {fill:red}", ["unported: the pseudo-class :state()"]),
    (".a{border:medium}", ["unported: a border at its initial values"]),
    (".a{border:none}", ["unported: a border at its initial values"]),
    (".a{border:currentcolor}", ["unported: a border at its initial values"]),
    (
      ".a{border:medium none currentcolor}",
      ["unported: a border at its initial values"],
    ),
    (
      ".a{margin-top:1px;margin-right:1px;margin-bottom:1px;margin-left:1px}",
      ["unported: the longhands of margin together"],
    ),
    (
      ".a{margin:1px;margin-top:2px}",
      ["unported: the longhands of margin together"],
    ),
    (
      ".a{top:1px;right:1px;bottom:1px;left:1px}",
      ["unported: the longhands of inset together"],
    ),
    (
      ".a{overflow-x:hidden;overflow-y:hidden}",
      ["unported: the longhands of overflow together"],
    ),
    (
      ".a{marker-start:none;marker-mid:none;marker-end:none}",
      ["unported: the longhands of marker together"],
    ),
    (
      ".a{text-decoration-line:underline overline}",
      ["unported: the property text-decoration-line"],
    ),
    (
      "@media (min-aspect-ratio: 16/9) { .a { fill: red } }",
      ["unported: this media feature"],
    ),
    ("@media { .a { fill: red } }", ["unported: an empty media query"]),
    (
      "@font-face { font-family: x; src: url(x.woff) }",
      ["unported: @font-face rules"],
    ),
    (
      "@supports (display: grid) { .a { fill: red } }",
      ["unported: @supports rules"],
    ),
    (".a { fill: red; .b { fill: blue } }", ["unported: nested rules"]),
    (".a { & .b { fill: blue } }", ["unported: nested rules"]),
    (".a { fill: lab(50% 0 0) }", ["unported: lab() colors"]),
    (
      ".a { fill: color-mix(in srgb, red, blue) }",
      ["unported: color-mix() colors"],
    ),
    (
      ".a { marker-start: url(#s); marker-mid: none; marker-end: URL(#e) }",
      ["unported: the longhands of marker together"],
    ),
    (".a { display: block math }", ["unported: display: block math"]),
    (".a { display: list-item block }", ["unported: display: list-item block"]),
    (".a { white-space: nowrap }", ["unported: the property white-space"]),
    (".a { font: 12px serif }", ["unported: the property font"]),
    (
      ".a { text-decoration: underline }",
      ["unported: the property text-decoration"],
    ),
    (
      ".a { filter: drop-shadow(1px 1px 1px red) }",
      ["unported: the property filter"],
    ),
  ]
  json_inspect(cssom_differences(cases), content=[])
}
