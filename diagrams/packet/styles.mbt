///|
/// The packet diagram's stylesheet. The theme's `packet` variable may
/// override any of the defaults.
pub fn styles(theme : @theme.Theme) -> String {
  let option = (name : String, default : String) => {
    match theme.nested("packet", name) {
      String(value) => value
      Number(value, ..) => @dom.number(value)
      _ => default
    }
  }
  (
    $|
    $|	.packetByte {
    $|		font-size: \{option("byteFontSize", "10px")};
    $|	}
    $|	.packetByte.start {
    $|		fill: \{option("startByteColor", "black")};
    $|	}
    $|	.packetByte.end {
    $|		fill: \{option("endByteColor", "black")};
    $|	}
    $|	.packetLabel {
    $|		fill: \{option("labelColor", "black")};
    $|		font-size: \{option("labelFontSize", "12px")};
    $|	}
    $|	.packetTitle {
    $|		fill: \{option("titleColor", "black")};
    $|		font-size: \{option("titleFontSize", "14px")};
    $|	}
    $|	.packetBlock {
    $|		stroke: \{option("blockStrokeColor", "black")};
    $|		stroke-width: \{option("blockStrokeWidth", "1")};
    $|		fill: \{option("blockFillColor", "#efefef")};
    $|	}
    $|	
  )
}
