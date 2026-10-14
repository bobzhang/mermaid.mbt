///|
/// The database as JSON, shaped like upstream's own records, for
/// comparing the two parsers (scripts/check_sequence_parse.py).
pub fn SequenceDb::dump(self : SequenceDb) -> Json {
  let optional = (text : String?) => {
    match text {
      Some(text) => Json::string(text)
      None => Json::null()
    }
  }
  let optional_number = (value : Double?) => {
    match value {
      Some(value) => Json::number(value)
      None => Json::null()
    }
  }
  let actors : Array[Json] = []
  for id, actor in self.actors {
    actors.push({
      "id": id,
      "name": actor.name,
      "description": actor.description,
      "wrap": actor.wrap,
      "prevActor": optional(actor.prev_actor),
      "nextActor": optional(actor.next_actor),
      "type": actor.kind,
      "box": optional(actor.box.bind(box => Some(box.name.unwrap_or("")))),
      "links": Json::object(actor.links),
      "properties": Json::object(actor.properties),
    })
  }
  let messages : Array[Json] = []
  for message in self.messages {
    let entry : Map[String, Json] = {
      "id": message.id.to_string(),
      "from": optional(message.from),
      "to": optional(message.to),
      "wrap": message.wrap,
      "type": message.kind.to_double(),
    }
    if message.kind == AUTONUMBER {
      entry["message"] = {
        "start": optional_number(message.sequence_start),
        "step": optional_number(message.sequence_step),
        "visible": message.sequence_visible,
      }
    } else {
      entry["message"] = Json::string(message.message)
    }
    if message.placement is Some(placement) {
      entry["placement"] = Json::number(placement.to_double())
    } else if message.kind != AUTONUMBER {
      entry["activate"] = Json::boolean(message.activate)
      entry["centralConnection"] = Json::number(
        message.central_connection.to_double(),
      )
    }
    messages.push(Json::object(entry))
  }
  let created : Map[String, Json] = Map([])
  for id, index in self.created_actors {
    created[id] = Json::number(index.to_double())
  }
  let destroyed : Map[String, Json] = Map([])
  for id, index in self.destroyed_actors {
    destroyed[id] = Json::number(index.to_double())
  }
  {
    "actors": actors,
    "messages": messages,
    "boxes": self.boxes.map(box => {
      let entry : Json = {
        "name": optional(box.name),
        "wrap": box.wrap,
        "fill": box.fill,
        "actorKeys": box.actor_keys.map(Json::string),
      }
      entry
    }),
    "createdActors": created,
    "destroyedActors": destroyed,
    "title": self.title,
    "accTitle": self.acc_title,
    "accDescription": self.acc_description,
  }
}
