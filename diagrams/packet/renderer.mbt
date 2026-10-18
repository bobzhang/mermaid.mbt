///|
/// Draw the packet diagram into the context's `<svg>` element.
pub fn draw(packet : Packet, context : @diagram.Context) -> Unit {
  let n = @dom.number
  let config = context.config
  let setting = (name : String, default : Double) => {
    config.number("packet.\{name}").unwrap_or(default)
  }
  let row_height = setting("rowHeight", 32.0)
  let padding_x = setting("paddingX", 5.0)
  let show_bits = config.flag("packet.showBits")
  // Bit numbers sit in the gap above each row.
  let padding_y = setting("paddingY", 5.0) +
    (if show_bits { 10.0 } else { 0.0 })
  let bit_width = setting("bitWidth", 32.0)
  let bits_per_row = setting("bitsPerRow", 32.0)
  let descending = config.text("packet.bitOrder") is Some("descending")
  let total_row_height = row_height + padding_y
  let svg_height = total_row_height * (packet.rows.length() + 1).to_double() -
    (if packet.title != "" { 0.0 } else { row_height })
  let svg_width = bit_width * bits_per_row + 2.0
  let svg = context.svg
  svg.attr("viewBox", "0 0 \{n(svg_width)} \{n(svg_height)}") |> ignore
  @diagram.configure_svg_size(
    svg,
    svg_height,
    svg_width,
    config.flag("packet.useMaxWidth"),
  )
  for row_number, word in packet.rows {
    let group = svg.append("g")
    let word_y = row_number.to_double() * total_row_height + padding_y
    for block in word {
      let bits = block.end - block.start + 1.0
      // `descending` mirrors the row, so it reads from its highest bit
      // down to its lowest, as hardware registers are drawn.
      let first_column = block.start % bits_per_row
      let column = if descending {
        bits_per_row - first_column - bits
      } else {
        first_column
      }
      let block_x = column * bit_width + 1.0
      let width = bits * bit_width - padding_x
      group
      .append("rect")
      .attr_number("x", block_x)
      .attr_number("y", word_y)
      .attr_number("width", width)
      .attr_number("height", row_height)
      .attr("class", "packetBlock")
      |> ignore
      group
      .append("text")
      .attr_number("x", block_x + width / 2.0)
      .attr_number("y", word_y + row_height / 2.0)
      .attr("class", "packetLabel")
      .attr("dominant-baseline", "middle")
      .attr("text-anchor", "middle")
      .text(block.label)
      |> ignore
      if !show_bits {
        continue
      }
      let (leading, trailing) = if descending {
        (block.end, block.start)
      } else {
        (block.start, block.end)
      }
      let single = bits == 1.0
      let bit_number_y = word_y - 2.0
      group
      .append("text")
      .attr_number("x", block_x + (if single { width / 2.0 } else { 0.0 }))
      .attr_number("y", bit_number_y)
      .attr("class", "packetByte start")
      .attr("dominant-baseline", "auto")
      .attr("text-anchor", if single { "middle" } else { "start" })
      .text(n(leading))
      |> ignore
      if !single {
        group
        .append("text")
        .attr_number("x", block_x + width)
        .attr_number("y", bit_number_y)
        .attr("class", "packetByte end")
        .attr("dominant-baseline", "auto")
        .attr("text-anchor", "end")
        .text(n(trailing))
        |> ignore
      }
    }
  }
  svg
  .append("text")
  .text(packet.title)
  .attr_number("x", svg_width / 2.0)
  .attr_number("y", svg_height - total_row_height / 2.0)
  .attr("dominant-baseline", "middle")
  .attr("text-anchor", "middle")
  .attr("class", "packetTitle")
  |> ignore
}
