// The grammar's corners, as upstream's parser decides them: every case
// here was compared with mermaid through scripts/check_git_parse.py.

///|
/// The history as one line per commit, or the reason it is rejected.
fn history(source : String) -> String {
  let config = @config.Config::new(diagram_type="gitGraph") catch {
    _ => return "config error"
  }
  let graph = @gitgraph.parse(source, config) catch {
    @langium.ParseError(..) => return "syntax error"
    @gitgraph.GitError(message) => return "error: \{message}"
    @gitgraph.Unsupported(message) => return "unsupported: \{message}"
    _ => return "error"
  }
  let lines = ["\{graph.direction} \{graph.branch_names().join(",")}"]
  for _, commit in graph.commits {
    let parents = commit.parents.join("+")
    let tags = commit.tags.map(tag => " #\{tag}").join("")
    lines.push("\{commit.id}@\{commit.branch}<\{parents}\{tags}")
  }
  lines.join("; ")
}

///|
test "headers" {
  inspect(history("gitGraph\n commit id:\"a\"\n"), content="LR main; a@main<")
  inspect(history("gitGraph:\n commit id:\"a\"\n"), content="LR main; a@main<")
  inspect(
    history("gitGraph TB:\n commit id:\"a\"\n"),
    content="TB main; a@main<",
  )
  inspect(
    history("gitGraph BT :\n commit id:\"a\"\n"),
    content="BT main; a@main<",
  )
  // A statement may follow the header on its line.
  inspect(history("gitGraph: commit id:\"a\""), content="LR main; a@main<")
  // A direction needs its colon, and only three exist.
  inspect(history("gitGraph TB\n commit\n"), content="syntax error")
  inspect(history("gitGraph RL:\n commit\n"), content="syntax error")
}

///|
test "statements" {
  inspect(
    history(
      "gitGraph\n commit id:\"a\" tag:\"t1\" tag:\"t2\"\n branch dev order: 2\n commit id:'b' \"a message\"\n switch main\n merge dev id:\"m\" tag:\"v1\" type: REVERSE\n",
    ),
    content="LR main,dev; a@main< #t1 #t2; b@dev<a; m@main<a+b #v1",
  )
  // The last `id:` wins.
  inspect(
    history("gitGraph\n commit id:\"a\" id:\"b\"\n"),
    content="LR main; b@main<",
  )
  inspect(history("gitGraph\n commit id : \"a\"\n"), content="syntax error")
  inspect(history("gitGraph\n commit;\n"), content="syntax error")
  inspect(history("gitGraph\n commit type: normal\n"), content="syntax error")
}

///|
test "branch names are whatever the lexer leaves of them" {
  let branch = (name : String) => {
    history("gitGraph\n commit id:\"a\"\n branch \{name}\n")
  }
  inspect(branch("feature/x-1.2"), content="LR main,feature/x-1.2; a@main<")
  // A keyword gives way to a longer reference...
  inspect(branch("commits"), content="LR main,commits; a@main<")
  inspect(branch("cherry-picks"), content="LR main,cherry-picks; a@main<")
  // ...but stays a keyword on its own.
  inspect(branch("commit"), content="syntax error")
  inspect(branch("LR"), content="syntax error")
  // An integer is lexed before a reference; a dot after it prevents that.
  inspect(branch("1.0"), content="LR main,1.0; a@main<")
  inspect(branch("123abc"), content="syntax error")
  inspect(branch("2024-release"), content="syntax error")
  // `title` starts a title wherever it stands.
  inspect(branch("title-fix"), content="syntax error")
  inspect(branch("mytitle"), content="LR main,mytitle; a@main<")
  // A reference cannot end in a dot or a slash.
  inspect(branch("a."), content="syntax error")
  inspect(branch("\"any text\""), content="LR main,any text; a@main<")
}

///|
test "branch order" {
  // A branch without `order:` has order 0, like the main branch.
  inspect(
    history(
      "gitGraph\n commit id:\"a\"\n branch b1 order: 3\n branch b2 order: 1\n branch b3\n branch b4 order: 2\n",
    ),
    content="LR main,b3,b2,b4,b1; a@main<",
  )
}

///|
test "generated ids" {
  // Sequence number, then seven hex digits from the fixed-seed generator.
  inspect(
    history(
      "gitGraph\n commit\n branch dev\n commit id:\"b\"\n checkout main\n commit\n merge dev\n cherry-pick id:\"b\"\n",
    ),
    content=(
      #|LR main,dev; 0-4032789@main<; b@dev<0-4032789; 2-a7931e6@main<0-4032789; 3-baca913@main<2-a7931e6+b; 4-d51ce87@main<3-baca913+b #cherry-pick:b
    ),
  )
}

///|
test "operations the history does not allow" {
  inspect(
    history("gitGraph\n commit\n merge main\n"),
    content="error: Cannot merge branch 'main' into itself.",
  )
  inspect(
    history("gitGraph\n commit\n merge nowhere\n"),
    content="error: Incorrect usage of \"merge\". Branch to be merged (nowhere) does not exist",
  )
  inspect(
    history("gitGraph\n commit\n checkout nowhere\n"),
    content="error: Trying to checkout branch which is not yet created. (Help try using \"branch nowhere\")",
  )
  inspect(
    history("gitGraph\n commit id:\"a\"\n commit\n cherry-pick id:\"a\"\n"),
    content="error: Incorrect usage of \"cherryPick\". Source commit is already on current branch",
  )
}

///|
test "sanitized text" {
  // Angle brackets and equal signs stay written as entities: upstream's
  // sanitizer returns text without markup as it is.
  inspect(
    history("gitGraph\n commit id:\"a<b>=c\"\n branch \"x<br/>y\"\n"),
    content="LR main,x<br>y; a&lt;b&gt;&equals;c@main<",
  )
}
