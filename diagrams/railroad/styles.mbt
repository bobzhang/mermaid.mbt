///|
/// The railroad diagrams' stylesheet, before it is scoped to the diagram.
pub fn styles(config : @config.Config) -> String {
  let o = Options::new(config)
  let n = @dom.number
  (
    $|
    $|  .railroad-diagram {
    $|    font-family: \{o.font_family};
    $|    font-size: \{n(o.font_size)}px;
    $|  }
    $|
    $|  .railroad-terminal rect {
    $|    fill: \{o.terminal_fill};
    $|    stroke: \{o.terminal_stroke};
    $|    stroke-width: \{n(o.stroke_width)}px;
    $|  }
    $|
    $|  .railroad-terminal text {
    $|    fill: \{o.terminal_text_color};
    $|    font-family: \{o.font_family};
    $|    font-size: \{n(o.font_size)}px;
    $|    text-anchor: middle;
    $|    dominant-baseline: middle;
    $|  }
    $|
    $|  .railroad-nonterminal rect {
    $|    fill: \{o.non_terminal_fill};
    $|    stroke: \{o.non_terminal_stroke};
    $|    stroke-width: \{n(o.stroke_width)}px;
    $|  }
    $|
    $|  .railroad-nonterminal text {
    $|    fill: \{o.non_terminal_text_color};
    $|    font-family: \{o.font_family};
    $|    font-size: \{n(o.font_size)}px;
    $|    text-anchor: middle;
    $|    dominant-baseline: middle;
    $|  }
    $|
    $|  .railroad-line {
    $|    stroke: \{o.line_color};
    $|    stroke-width: \{n(o.stroke_width)}px;
    $|    fill: none;
    $|  }
    $|
    $|  .railroad-start circle,
    $|  .railroad-end circle {
    $|    fill: \{o.marker_fill};
    $|  }
    $|
    $|  .railroad-comment ellipse {
    $|    fill: \{o.comment_fill};
    $|    stroke: \{o.comment_stroke};
    $|    stroke-width: \{n(o.stroke_width)}px;
    $|  }
    $|
    $|  .railroad-comment text {
    $|    fill: \{o.comment_text_color};
    $|    font-style: italic;
    $|    font-family: \{o.font_family};
    $|    font-size: \{n(o.font_size)}px;
    $|    text-anchor: middle;
    $|    dominant-baseline: middle;
    $|  }
    $|
    $|  .railroad-special rect {
    $|    fill: \{o.special_fill};
    $|    stroke: \{o.special_stroke};
    $|    stroke-width: \{n(o.stroke_width)}px;
    $|    stroke-dasharray: 5,3;
    $|  }
    $|
    $|  .railroad-special text {
    $|    fill: \{o.non_terminal_text_color};
    $|    font-family: \{o.font_family};
    $|    font-size: \{n(o.font_size)}px;
    $|    text-anchor: middle;
    $|    dominant-baseline: middle;
    $|  }
    $|
    $|  .railroad-rule-name {
    $|    font-weight: bold;
    $|    fill: \{o.rule_name_color};
    $|    font-family: \{o.font_family};
    $|    font-size: \{n(o.font_size)}px;
    $|  }
    $|
    $|  .railroad-group {
    $|    /* Grouping container, no specific styles */
    $|  }
    $|
  )
}
