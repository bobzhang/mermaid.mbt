// Commits without an `id:` get a generated one upstream:
// `<sequence number>-<seven random hex digits>`, the digits drawn from
// `Math.random()`. Nothing in mermaid's configuration seeds that, so two
// renders of one diagram never agree upstream.
//
// The port draws the digits from a fixed-seed generator instead: ids have
// upstream's form and a diagram always renders to the same SVG. The
// generator is mulberry32, small enough to install as `Math.random` in the
// reference browser, which is how output with generated ids is compared
// (`testdata/gitgraph/generated-ids/oracle-prelude.js`).

///|
/// The source of the hex digits of generated commit ids.
priv struct IdSource {
  mut state : UInt32
}

///|
fn IdSource::new() -> IdSource {
  { state: 0, }
}

///|
/// The next mulberry32 output.
fn IdSource::next(self : IdSource) -> UInt32 {
  self.state = self.state + 0x6D2B79F5
  let s = self.state
  let t = (s ^ (s >> 15)) * (s | 1)
  let t = (t + (t ^ (t >> 7)) * (t | 61)) ^ t
  t ^ (t >> 14)
}

///|
/// mermaid's `random({ length: 7 })`: each digit is
/// `floor(Math.random() * 16)`, the top four bits of one output.
fn IdSource::hex(self : IdSource, length : Int32) -> String {
  let digits = "0123456789abcdef"
  let out = StringBuilder()
  for _ in 0..<length {
    let digit = (self.next() >> 28).reinterpret_as_int()
    out.write_view(digits[digit:digit + 1])
  }
  out.to_string()
}
