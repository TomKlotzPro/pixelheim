class_name Quests
## The villagers' quests (src/game/quests.ts): talking to a giver accepts
## their quest, talking again with the objective met turns it in. Bounties
## count kills; deliveries count what the pack holds and hand it over on
## turn-in. Pure, over the exported progression.json; GameState applies them.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/progression.json"))
	return _doc


static func all() -> Array:
	return _data()["quests"]


static func by_id(quest_id: String) -> Dictionary:
	for quest: Dictionary in all():
		if quest["id"] == quest_id:
			return quest
	return {}


## A giver's quests, in the web's order (questsFor).
static func for_giver(giver: String) -> Array:
	return all().filter(func(quest: Dictionary) -> bool: return quest["giver"] == giver)


## How far along a quest is (questProgress): kills counted so far, or the
## goods in the pack, never past the goal.
static func progress(quest: Dictionary, entries: Dictionary, items: Dictionary) -> int:
	var entry: Dictionary = entries.get(quest["id"], {})
	if entry.is_empty():
		return 0
	var objective: Dictionary = quest["objective"]
	var have: int = items.get(objective["itemId"], 0) if objective["kind"] == "deliver" else int(entry["progress"])
	return mini(int(objective["count"]), have)


## Accepted, not yet turned in, and the goal met (questReady).
static func is_ready(quest: Dictionary, entries: Dictionary, items: Dictionary) -> bool:
	var entry: Dictionary = entries.get(quest["id"], {})
	return not entry.is_empty() and not entry["done"] and progress(quest, entries, items) >= int(quest["objective"]["count"])
