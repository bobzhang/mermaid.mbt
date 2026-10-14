// Cases follow upstream's timeline.spec.js.

///|
fn summary(source : String) -> String raise {
  let timeline = @timeline.parse(source)
  let parts = ["\{timeline.direction}"]
  if timeline.title != "" {
    parts.push("title: \{timeline.title}")
  }
  parts.push("sections: " + timeline.sections.join("|"))
  for task in timeline.tasks {
    let events = task.events.join("|")
    parts.push("[\{task.section}] \{task.task} (\{events})")
  }
  parts.join("; ")
}

///|
test "sections, periods and events" {
  inspect(
    summary(
      (
        #|timeline
        #|    title History
        #|    section abc-123
        #|      task1: event1
        #|      task2: event2: event3
        #|           : event4
        #|    section more
        #|      task3
        #|
      ),
    ),
    content="LR; title: History; sections: abc-123|more; [abc-123] task1 (event1); [abc-123] task2 (event2|event3|event4); [more] task3 ()",
  )
}

///|
test "direction" {
  inspect(summary("timeline TD\n  a"), content="TD; sections: ; [] a ()")
  inspect(summary("timeline   LR\n  a"), content="LR; sections: ; [] a ()")
  inspect(summary("timeline\n  a"), content="LR; sections: ; [] a ()")
}

///|
test "text is kept as written" {
  // A period keeps the blanks before its colon; a colon inside an event
  // belongs to it unless a blank follows; a hash starts a comment only
  // outside of events.
  inspect(
    summary("timeline\n  10 o'clock  : a:b c :  d # e"),
    content="LR; sections: ; [] 10 o'clock   (a:b c | d # e)",
  )
}

///|
test "syntax errors" {
  let fails = (source : String) => {
    try @timeline.parse(source) catch {
      _ => true
    } noraise {
      _ => false
    }
  }
  // An event needs a period before it.
  inspect(fails("timeline\n  : event"), content="true")
  inspect(fails("timeline\n  section a: b"), content="true")
  inspect(fails("timeline\n  accTitle: ignored\n  a : b"), content="false")
}
