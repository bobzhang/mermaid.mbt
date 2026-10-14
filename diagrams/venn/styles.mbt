///|
/// The Venn diagram's stylesheet, before it is scoped to the diagram.
pub fn styles(theme : @theme.Theme) -> String {
  let v = (name : String) => theme.text(name)
  (
    $|
    $|  .venn-title {
    $|    font-size: 32px;
    $|    fill: \{v("vennTitleTextColor")};
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  .venn-circle text {
    $|    font-size: 48px;
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  .venn-intersection text {
    $|    font-size: 48px;
    $|    fill: \{v("vennSetTextColor")};
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  .venn-text-node {
    $|    font-family: \{v("fontFamily")};
    $|    color: \{v("vennSetTextColor")};
    $|  }
    $|
  )
}
