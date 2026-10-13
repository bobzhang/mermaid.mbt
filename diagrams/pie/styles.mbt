///|
/// The pie chart's stylesheet, before it is scoped to the diagram.
pub fn styles(theme : @theme.Theme) -> String {
  let v = (name : String) => theme.text(name)
  (
    $|
    $|  .pieCircle{
    $|    stroke: \{v("pieStrokeColor")};
    $|    stroke-width : \{v("pieStrokeWidth")};
    $|    opacity : \{v("pieOpacity")};
    $|  }
    $|  .pieCircle.highlighted{
    $|    scale: 1.05;
    $|    opacity: 1;
    $|  }
    $|  .pieCircle.highlightedOnHover:hover{
    $|    transition-duration: 250ms;
    $|    scale: 1.05;
    $|    opacity: 1;
    $|  }
    $|  .pieOuterCircle{
    $|    stroke: \{v("pieOuterStrokeColor")};
    $|    stroke-width: \{v("pieOuterStrokeWidth")};
    $|    fill: none;
    $|  }
    $|  .pieTitleText {
    $|    text-anchor: middle;
    $|    font-size: \{v("pieTitleTextSize")};
    $|    fill: \{v("pieTitleTextColor")};
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|  .slice {
    $|    font-family: \{v("fontFamily")};
    $|    fill: \{v("pieSectionTextColor")};
    $|    font-size:\{v("pieSectionTextSize")};
    $|    // fill: white;
    $|  }
    $|  .legend text {
    $|    fill: \{v("pieLegendTextColor")};
    $|    font-family: \{v("fontFamily")};
    $|    font-size: \{v("pieLegendTextSize")};
    $|  }
    $|
  )
}
