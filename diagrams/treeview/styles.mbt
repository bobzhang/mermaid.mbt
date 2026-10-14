///|
/// The tree view's stylesheet. The theme's `treeView` variable may override
/// any of the defaults.
pub fn styles(theme : @theme.Theme) -> String {
  let option = (name : String, default : String) => {
    match theme.nested("treeView", name) {
      String(value) => value
      Number(value, ..) => @dom.number(value)
      _ => default
    }
  }
  (
    $|
    $|    .treeView-node-label {
    $|        font-size: \{option("labelFontSize", "16px")};
    $|        fill: \{option("labelColor", "black")};
    $|        white-space: pre;
    $|    }
    $|    .treeView-node-dir {
    $|        font-weight: bold;
    $|    }
    $|    .treeView-node-line {
    $|        stroke: \{option("lineColor", "black")};
    $|    }
    $|    .treeView-node-icon {
    $|        color: \{option("iconColor", "#546e7a")};
    $|    }
    $|    .treeView-node-description {
    $|        font-size: \{option("labelFontSize", "16px")};
    $|        fill: \{option("descriptionColor", "#6a9955")};
    $|        font-style: italic;
    $|        white-space: pre;
    $|    }
    $|    .treeView-highlight-bg {
    $|        fill: \{option("highlightBg", "rgba(255, 193, 7, 0.15)")};
    $|        stroke: \{option("highlightStroke", "#ffc107")};
    $|        stroke-width: 1;
    $|    }
    $|    
  )
}
