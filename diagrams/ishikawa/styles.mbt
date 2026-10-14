///|
/// The Ishikawa diagram's stylesheet, before it is scoped to the diagram.
pub fn styles(theme : @theme.Theme) -> String {
  let v = (name : String) => theme.text(name)
  (
    $|
    $|.ishikawa .ishikawa-spine,
    $|.ishikawa .ishikawa-branch,
    $|.ishikawa .ishikawa-sub-branch {
    $|  stroke: \{v("lineColor")};
    $|  stroke-width: 2;
    $|  fill: none;
    $|}
    $|
    $|.ishikawa .ishikawa-sub-branch {
    $|  stroke-width: 1;
    $|}
    $|
    $|.ishikawa .ishikawa-arrow {
    $|  fill: \{v("lineColor")};
    $|}
    $|
    $|.ishikawa .ishikawa-head {
    $|  fill: \{v("mainBkg")};
    $|  stroke: \{v("lineColor")};
    $|  stroke-width: 2;
    $|}
    $|
    $|.ishikawa .ishikawa-label-box {
    $|  fill: \{v("mainBkg")};
    $|  stroke: \{v("lineColor")};
    $|  stroke-width: 2;
    $|}
    $|
    $|.ishikawa text {
    $|  font-family: \{v("fontFamily")};
    $|  font-size: \{v("fontSize")};
    $|  fill: \{v("textColor")};
    $|}
    $|
    $|.ishikawa .ishikawa-head-label {
    $|  font-weight: 600;
    $|  text-anchor: middle;
    $|  dominant-baseline: middle;
    $|  font-size: 14px;
    $|}
    $|
    $|.ishikawa .ishikawa-label {
    $|  text-anchor: end;
    $|}
    $|
    $|.ishikawa .ishikawa-label.cause {
    $|  text-anchor: middle;
    $|  dominant-baseline: middle;
    $|}
    $|
    $|.ishikawa .ishikawa-label.align {
    $|  text-anchor: end;
    $|  dominant-baseline: middle;
    $|}
    $|
    $|.ishikawa .ishikawa-label.up {
    $|  dominant-baseline: baseline;
    $|}
    $|
    $|.ishikawa .ishikawa-label.down {
    $|  dominant-baseline: hanging;
    $|}
    $|
  )
}
