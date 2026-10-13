///|
test "nested rules are flattened under the scope" {
  let css =
    #|& {
    #|    font-family: "trebuchet ms", verdana, arial, sans-serif;
    #|    font-size: 16px;
    #|    fill: #333
    #|  }
    #|  @keyframes dash {
    #|    to {
    #|      stroke-dashoffset: 0;
    #|    }
    #|  }
    #|  & .edge-animation-slow {
    #|    stroke-dasharray: 9,5 !important;
    #|    animation: dash 50s linear infinite;
    #|  }
    #|  /* Classes common for multiple diagrams */
    #|
    #|  .edge-pattern-dotted {
    #|    stroke-dasharray: 2;
    #|  }
    #|   & p {
    #|    margin: 0
    #|   }
    #|  .pieCircle{
    #|    stroke: black;
    #|    stroke-width : 2px;
    #|    opacity : 0.7;
    #|  }
    #|  .slice {
    #|    fill: #333;
    #|    font-size:17px;
    #|    // fill: white;
    #|  }
    #|  [data-look="neo"].node rect, [data-look="neo"].cluster rect {
    #|    stroke: #9370DB;
    #|    filter: drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));
    #|  }
    #|  :root { --mermaid-font-family: "trebuchet ms", verdana, arial, sans-serif; }
    #|
  inspect(
    @css.compile("#mermaid-svg", css),
    content=(
      #|#mermaid-svg{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;fill:#333;}@keyframes dash{to{stroke-dashoffset:0;}}#mermaid-svg .edge-animation-slow{stroke-dasharray:9,5!important;animation:dash 50s linear infinite;}#mermaid-svg .edge-pattern-dotted{stroke-dasharray:2;}#mermaid-svg p{margin:0;}#mermaid-svg .pieCircle{stroke:black;stroke-width:2px;opacity:0.7;}#mermaid-svg .slice{fill:#333;font-size:17px;}#mermaid-svg [data-look="neo"].node rect,#mermaid-svg [data-look="neo"].cluster rect{stroke:#9370DB;filter:drop-shadow(1px 2px 2px rgba(185, 185, 185, 1));}#mermaid-svg :root{--mermaid-font-family:"trebuchet ms",verdana,arial,sans-serif;}
    ),
  )
}

///|
test "empty rules and stray text are dropped" {
  inspect(
    @css.compile("#a", ".b { } .c { color: red }"),
    content="#a .c{color:red;}",
  )
  inspect(@css.compile("#a", ""), content="")
  inspect(
    @css.compile("#a", ".b > .c, .d + .e { margin : 0 auto }"),
    content="#a .b>.c,#a .d+.e{margin:0 auto;}",
  )
}
