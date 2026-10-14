// Cases follow upstream's journey.spec.js and journeyDb.spec.js.

///|
fn summary(source : String) -> String raise {
  let journey = @journey.parse(source)
  let parts = []
  if journey.title != "" {
    parts.push("title: \{journey.title}")
  }
  if journey.acc_title != "" {
    parts.push("accTitle: \{journey.acc_title}")
  }
  if journey.acc_description != "" {
    parts.push("accDescr: \{journey.acc_description}")
  }
  for task in journey.tasks {
    let people = task.people.join("|")
    parts.push("[\{task.section}] \{task.task} = \{task.score} (\{people})")
  }
  parts.join("; ")
}

///|
test "title and accessibility text" {
  inspect(
    summary("journey\ntitle Adding journey diagram functionality to mermaid"),
    content="title: Adding journey diagram functionality to mermaid",
  )
  inspect(
    summary(
      "journey\naccTitle: The title\naccDescr: A user journey for\nsection Order from website",
    ),
    content="accTitle: The title; accDescr: A user journey for",
  )
  inspect(
    summary(
      "journey\naccDescr {\n  A user journey for\n  family shopping\n}\nsection Order from website",
    ),
    content="accDescr: A user journey for\nfamily shopping",
  )
}

///|
test "tasks keep their section, score and actors" {
  inspect(
    summary(
      (
        #|journey
        #|    title Adding journey diagram functionality to mermaid
        #|    section Documentation
        #|      A task: 5: Alice, Bob, Charlie
        #|      B task: 3:Bob, Charlie
        #|      C task: 5
        #|      D task: 5: Charlie, Alice
        #|      E task: 5:
        #|    section Another section
        #|      P task: 5:
        #|      Q task: 5:
        #|      R task: 5:
        #|
      ),
    ),
    content="title: Adding journey diagram functionality to mermaid; [Documentation] A task = 5 (Alice|Bob|Charlie); [Documentation] B task = 3 (Bob|Charlie); [Documentation] C task = 5 (); [Documentation] D task = 5 (Charlie|Alice); [Documentation] E task = 5 (); [Another section] P task = 5 (); [Another section] Q task = 5 (); [Another section] R task = 5 ()",
  )
}

///|
test "what is written around the colons is kept or dropped as upstream does" {
  // The description keeps its trailing blank; a score that is no number
  // is NaN; pieces after the actors are ignored.
  inspect(
    summary("journey\n  Make tea : abc: Me , You: more"),
    content="[] Make tea  = NaN (Me|You)",
  )
  let journey = @journey.parse("journey\n T: 1: b, a, 10, 2, b")
  json_inspect(journey.actors(), content=["10", "2", "a", "b"])
}

///|
test "syntax errors" {
  let fails = (source : String) => {
    try @journey.parse(source) catch {
      _ => true
    } noraise {
      _ => false
    }
  }
  inspect(fails("journey\n  Task without score"), content="true")
  inspect(fails("journey\n  section\n  Task: 5"), content="true")
  inspect(fails("journey\n  a; b: 5"), content="true")
  inspect(fails("journey\n  %% only a comment\n"), content="false")
}
