///|
/// A run of bits with one label, on one row.
/// Bit positions are JavaScript numbers, as upstream's: a fractional
/// `bitsPerRow` cuts rows at fractional bits.
pub struct Block {
  start : Double
  end : Double
  label : String
} derive(Debug)

///|
/// A parsed packet diagram: its blocks laid out in rows.
pub struct Packet {
  rows : Array[Array[Block]]
  title : String
  acc_title : String
  acc_description : String
}

///|
/// The same diagram under another title.
pub fn Packet::with_title(self : Packet, title : String) -> Packet {
  { ..self, title, }
}

///|
/// Rows beyond this are dropped rather than laid out.
const MAX_PACKET_SIZE : Int32 = 10000

///|
/// Parse a packet diagram and split its blocks into rows of the configured
/// `packet.bitsPerRow`:
///
/// ```text
/// Packet: NEWLINE* ("packet" | "packet-beta")
///         (TitleAndAccessibilities | PacketBlock | NEWLINE)*
/// PacketBlock: (INT ("-" INT)? | "+" INT) ":" STRING EOL
/// ```
pub fn parse(
  source : String,
  config : @config.Config,
) -> Packet raise @langium.ParseError {
  let n = @dom.number
  let lexer = @langium.Lexer::new(source)
  while lexer.newline() {

  }
  if !(lexer.symbol("packet-beta") || lexer.keyword("packet")) {
    lexer.fail("Expecting keyword 'packet'")
  }
  let bits_per_row = config.number("packet.bitsPerRow").unwrap_or(32.0)
  let rows : Array[Array[Block]] = []
  let mut word : Array[Block] = []
  let mut row = 1.0
  let mut last_bit = -1.0
  let mut title = ""
  let mut acc_title = ""
  let mut acc_description = ""
  while !lexer.at_end() {
    if lexer.newline() {
      continue
    }
    if lexer.acc_descr() is Some(text) {
      acc_description = text
    } else if lexer.acc_title() is Some(text) {
      acc_title = text
    } else if lexer.title() is Some(text) {
      title = text
    } else {
      // `start`, `start-end` or `+bits`.
      let mut start : Double? = None
      let mut end : Double? = None
      let mut bits : Double? = None
      if lexer.symbol("+") {
        guard lexer.int() is Some(count) else {
          lexer.fail("Expecting a bit count")
        }
        bits = Some(count)
      } else {
        guard lexer.int() is Some(first) else {
          lexer.fail("Expecting a block, title or accessibility statement")
        }
        start = Some(first)
        if lexer.symbol("-") {
          guard lexer.int() is Some(last) else {
            lexer.fail("Expecting the last bit of the block")
          }
          end = Some(last)
        }
      }
      if !lexer.symbol(":") {
        lexer.fail("Expecting token of type ':'")
      }
      guard lexer.string() is Some(label) else {
        lexer.fail("Expecting a quoted label")
      }
      if start is Some(first) && end is Some(last) && last < first {
        lexer.fail(
          "Packet block \{n(first)} - \{n(last)} is invalid. End must be greater than start.",
        )
      }
      let first = start.unwrap_or(last_bit + 1.0)
      if first != last_bit + 1.0 {
        lexer.fail(
          "Packet block \{n(first)} - \{n(end.unwrap_or(first))} is not contiguous. It should start from \{n(last_bit + 1.0)}.",
        )
      }
      if bits is Some(0.0) {
        lexer.fail(
          "Packet block \{n(first)} is invalid. Cannot have a zero bit field.",
        )
      }
      let last = end.unwrap_or(first + bits.unwrap_or(1.0) - 1.0)
      last_bit = last
      // Cut the block at row boundaries.
      let mut piece_start = first
      while word.length().to_double() <= bits_per_row + 1.0 &&
            rows.length() < MAX_PACKET_SIZE {
        let fits = last + 1.0 <= row * bits_per_row
        // The rest of the block starts this row's end, computed before the
        // row advances, as upstream's `getNextFittingBlock` does.
        let next_start = row * bits_per_row
        let piece_end = if fits { last } else { row * bits_per_row - 1.0 }
        word.push({ start: piece_start, end: piece_end, label, })
        if piece_end + 1.0 == row * bits_per_row {
          rows.push(word)
          word = []
          row += 1.0
        }
        if fits {
          break
        }
        piece_start = next_start
      }
    }
    if !lexer.eol() {
      lexer.fail("Expecting end of line")
    }
  }
  if word.length() > 0 {
    rows.push(word)
  }
  { rows, title, acc_title, acc_description, }
}
