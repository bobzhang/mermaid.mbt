///|
/// The Gantt chart's stylesheet, before it is scoped to the diagram: a port
/// of `styles.js`.
pub fn styles(theme : @theme.Theme) -> String {
  let v = (name : String) => theme.text(name)
  // `titleColor || textColor`.
  let title_color = match theme.get("titleColor") {
    Null | String("") => v("textColor")
    _ => v("titleColor")
  }
  (
    $|
    $|  .mermaid-main-font {
    $|        font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  .exclude-range {
    $|    fill: \{v("excludeBkgColor")};
    $|  }
    $|
    $|  .section {
    $|    stroke: none;
    $|    opacity: 0.2;
    $|  }
    $|
    $|  .section0 {
    $|    fill: \{v("sectionBkgColor")};
    $|  }
    $|
    $|  .section2 {
    $|    fill: \{v("sectionBkgColor2")};
    $|  }
    $|
    $|  .section1,
    $|  .section3 {
    $|    fill: \{v("altSectionBkgColor")};
    $|    opacity: 0.2;
    $|  }
    $|
    $|  .sectionTitle0 {
    $|    fill: \{v("titleColor")};
    $|  }
    $|
    $|  .sectionTitle1 {
    $|    fill: \{v("titleColor")};
    $|  }
    $|
    $|  .sectionTitle2 {
    $|    fill: \{v("titleColor")};
    $|  }
    $|
    $|  .sectionTitle3 {
    $|    fill: \{v("titleColor")};
    $|  }
    $|
    $|  .sectionTitle {
    $|    text-anchor: start;
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|
    $|  /* Grid and axis */
    $|
    $|  .grid .tick {
    $|    stroke: \{v("gridColor")};
    $|    opacity: 0.8;
    $|    shape-rendering: crispEdges;
    $|  }
    $|
    $|  .grid .tick text {
    $|    font-family: \{v("fontFamily")};
    $|    fill: \{v("textColor")};
    $|  }
    $|
    $|  .grid path {
    $|    stroke-width: 0;
    $|  }
    $|
    $|
    $|  /* Today line */
    $|
    $|  .today {
    $|    fill: none;
    $|    stroke: \{v("todayLineColor")};
    $|    stroke-width: 2px;
    $|  }
    $|
    $|
    $|  /* Task styling */
    $|
    $|  /* Default task */
    $|
    $|  .task {
    $|    stroke-width: 2;
    $|  }
    $|
    $|  .taskText {
    $|    text-anchor: middle;
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  .taskTextOutsideRight {
    $|    fill: \{v("taskTextDarkColor")};
    $|    text-anchor: start;
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
    $|  .taskTextOutsideLeft {
    $|    fill: \{v("taskTextDarkColor")};
    $|    text-anchor: end;
    $|  }
    $|
    $|
    $|  /* Special case clickable */
    $|
    $|  .task.clickable {
    $|    cursor: pointer;
    $|  }
    $|
    $|  .taskText.clickable {
    $|    cursor: pointer;
    $|    fill: \{v("taskTextClickableColor")} !important;
    $|    font-weight: bold;
    $|  }
    $|
    $|  .taskTextOutsideLeft.clickable {
    $|    cursor: pointer;
    $|    fill: \{v("taskTextClickableColor")} !important;
    $|    font-weight: bold;
    $|  }
    $|
    $|  .taskTextOutsideRight.clickable {
    $|    cursor: pointer;
    $|    fill: \{v("taskTextClickableColor")} !important;
    $|    font-weight: bold;
    $|  }
    $|
    $|
    $|  /* Specific task settings for the sections*/
    $|
    $|  .taskText0,
    $|  .taskText1,
    $|  .taskText2,
    $|  .taskText3 {
    $|    fill: \{v("taskTextColor")};
    $|  }
    $|
    $|  .task0,
    $|  .task1,
    $|  .task2,
    $|  .task3 {
    $|    fill: \{v("taskBkgColor")};
    $|    stroke: \{v("taskBorderColor")};
    $|  }
    $|
    $|  .taskTextOutside0,
    $|  .taskTextOutside2
    $|  {
    $|    fill: \{v("taskTextOutsideColor")};
    $|  }
    $|
    $|  .taskTextOutside1,
    $|  .taskTextOutside3 {
    $|    fill: \{v("taskTextOutsideColor")};
    $|  }
    $|
    $|
    $|  /* Active task */
    $|
    $|  .active0,
    $|  .active1,
    $|  .active2,
    $|  .active3 {
    $|    fill: \{v("activeTaskBkgColor")};
    $|    stroke: \{v("activeTaskBorderColor")};
    $|  }
    $|
    $|  .activeText0,
    $|  .activeText1,
    $|  .activeText2,
    $|  .activeText3 {
    $|    fill: \{v("taskTextDarkColor")} !important;
    $|  }
    $|
    $|
    $|  /* Completed task */
    $|
    $|  .done0,
    $|  .done1,
    $|  .done2,
    $|  .done3 {
    $|    stroke: \{v("doneTaskBorderColor")};
    $|    fill: \{v("doneTaskBkgColor")};
    $|    stroke-width: 2;
    $|  }
    $|
    $|  .doneText0,
    $|  .doneText1,
    $|  .doneText2,
    $|  .doneText3 {
    $|    fill: \{v("taskTextDarkColor")} !important;
    $|  }
    $|
    $|  /* Done task text displayed outside the bar sits against the diagram background,
    $|     not against the done-task bar, so it must use the outside/contrast color. */
    $|  .doneText0.taskTextOutsideLeft,
    $|  .doneText0.taskTextOutsideRight,
    $|  .doneText1.taskTextOutsideLeft,
    $|  .doneText1.taskTextOutsideRight,
    $|  .doneText2.taskTextOutsideLeft,
    $|  .doneText2.taskTextOutsideRight,
    $|  .doneText3.taskTextOutsideLeft,
    $|  .doneText3.taskTextOutsideRight {
    $|    fill: \{v("taskTextOutsideColor")} !important;
    $|  }
    $|
    $|
    $|  /* Tasks on the critical line */
    $|
    $|  .crit0,
    $|  .crit1,
    $|  .crit2,
    $|  .crit3 {
    $|    stroke: \{v("critBorderColor")};
    $|    fill: \{v("critBkgColor")};
    $|    stroke-width: 2;
    $|  }
    $|
    $|  .activeCrit0,
    $|  .activeCrit1,
    $|  .activeCrit2,
    $|  .activeCrit3 {
    $|    stroke: \{v("critBorderColor")};
    $|    fill: \{v("activeTaskBkgColor")};
    $|    stroke-width: 2;
    $|  }
    $|
    $|  .doneCrit0,
    $|  .doneCrit1,
    $|  .doneCrit2,
    $|  .doneCrit3 {
    $|    stroke: \{v("critBorderColor")};
    $|    fill: \{v("doneTaskBkgColor")};
    $|    stroke-width: 2;
    $|    cursor: pointer;
    $|    shape-rendering: crispEdges;
    $|  }
    $|
    $|  .milestone {
    $|    transform: rotate(45deg) scale(0.8,0.8);
    $|  }
    $|
    $|  .milestoneText {
    $|    font-style: italic;
    $|  }
    $|  .doneCritText0,
    $|  .doneCritText1,
    $|  .doneCritText2,
    $|  .doneCritText3 {
    $|    fill: \{v("taskTextDarkColor")} !important;
    $|  }
    $|
    $|  /* Done-crit task text outside the bar — same reasoning as doneText above. */
    $|  .doneCritText0.taskTextOutsideLeft,
    $|  .doneCritText0.taskTextOutsideRight,
    $|  .doneCritText1.taskTextOutsideLeft,
    $|  .doneCritText1.taskTextOutsideRight,
    $|  .doneCritText2.taskTextOutsideLeft,
    $|  .doneCritText2.taskTextOutsideRight,
    $|  .doneCritText3.taskTextOutsideLeft,
    $|  .doneCritText3.taskTextOutsideRight {
    $|    fill: \{v("taskTextOutsideColor")} !important;
    $|  }
    $|
    $|  .vert {
    $|    stroke: \{v("vertLineColor")};
    $|  }
    $|
    $|  .vertText {
    $|    font-size: 15px;
    $|    text-anchor: middle;
    $|    fill: \{v("vertLineColor")} !important;
    $|  }
    $|
    $|  .activeCritText0,
    $|  .activeCritText1,
    $|  .activeCritText2,
    $|  .activeCritText3 {
    $|    fill: \{v("taskTextDarkColor")} !important;
    $|  }
    $|
    $|  .titleText {
    $|    text-anchor: middle;
    $|    font-size: 18px;
    $|    fill: \{title_color};
    $|    font-family: \{v("fontFamily")};
    $|  }
    $|
  )
}
