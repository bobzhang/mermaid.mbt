///|
/// The database as JSON, with upstream's field names, for comparing
/// against mermaid's own parse.
pub fn GitGraph::dump(self : GitGraph) -> Json {
  let kind_number = (kind : CommitType) => {
    match kind {
      Normal => 0.0
      Reverse => 1.0
      Highlight => 2.0
      Merge => 3.0
      CherryPick => 4.0
    }
  }
  let commits : Array[Json] = []
  for _, commit in self.commits {
    let fields : Map[String, Json] = {
      "id": Json::string(commit.id),
      "message": Json::string(commit.message),
      "seq": Json::number(commit.seq.to_double()),
      "type": Json::number(kind_number(commit.kind)),
      "tags": Json(commit.tags),
      "parents": Json(commit.parents),
      "branch": Json::string(commit.branch),
    }
    if commit.kind == Merge {
      if commit.custom_type is Some(kind) {
        fields["customType"] = Json::number(kind_number(kind))
      }
      fields["customId"] = Json::boolean(commit.custom_id)
    }
    commits.push(Json::object(fields))
  }
  let branches : Map[String, Json] = Map([])
  for name, tip in self.branches {
    branches[name] = match tip {
      Some(id) => Json::string(id)
      None => Json::null()
    }
  }
  {
    "commits": Json::array(commits),
    "branches": Json::object(branches),
    "branchOrder": Json(self.branch_names()),
    "currentBranch": Json::string(self.current_branch),
    "direction": Json::string(self.direction),
    "title": Json::string(self.title),
    "accTitle": Json::string(self.acc_title),
    "accDescription": Json::string(self.acc_description),
  }
}
