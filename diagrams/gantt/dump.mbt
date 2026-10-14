///|
fn time_json(time : Double?) -> Json {
  match time {
    None => Json::null()
    Some(value) =>
      if value.is_nan() {
        Json::string("NaN")
      } else {
        Json::number(value)
      }
  }
}

///|
/// The database with every task's dates worked out, as JSON: what
/// scripts/gantt_node.mjs prints for upstream's database, to compare the
/// two (scripts/check_time.py).
pub fn GanttDb::dump(self : GanttDb, now : Double) -> Json raise GanttError {
  let tasks : Array[Json] = []
  for task in self.compile(now) {
    let flags : Array[Json] = []
    for
      flag in [
        ("active", task.active),
        ("done", task.done),
        ("crit", task.crit),
        ("milestone", task.milestone),
        ("vert", task.vert),
      ] {
      if flag.1 {
        flags.push(Json::string(flag.0))
      }
    }
    tasks.push({
      "id": Json::string(task.id),
      "task": Json::string(task.task),
      "section": Json::string(task.section),
      "order": Json::number(task.order.to_double()),
      "start": time_json(task.start_time),
      "end": time_json(task.end_time),
      "renderEnd": time_json(task.render_end_time),
      "manualEnd": Json::boolean(task.manual_end_time),
      "processed": Json::boolean(task.processed),
      "classes": Json::array(task.classes.map(name => Json::string(name))),
      "flags": Json::array(flags),
    })
  }
  let strings = (values : Array[String]) => {
    Json::array(values.map(value => Json::string(value)))
  }
  {
    "tasks": Json::array(tasks),
    "dateFormat": Json::string(self.date_format),
    "axisFormat": Json::string(self.axis_format),
    "tickInterval": match self.tick_interval {
      Some(interval) => Json::string(interval)
      None => Json::null()
    },
    "todayMarker": Json::string(self.today_marker),
    "includes": strings(self.includes),
    "excludes": strings(self.excludes),
    "title": Json::string(self.title),
    "accTitle": Json::string(self.acc_title),
    "accDescription": Json::string(self.acc_description),
    "sections": strings(self.sections),
    "links": strings(self.links.keys().collect()),
    "weekday": Json::string(self.weekday),
    "inclusiveEndDates": Json::boolean(self.inclusive_end_dates),
  }
}
