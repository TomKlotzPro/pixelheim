class_name Quests
## The villagers' quests (src/game/quests.ts): talking to a giver accepts
## their quest, talking again with the objective met turns it in. Bounties
## count kills; deliveries count what the pack holds and hand it over on
## turn-in, as do Maren's relics (one of each, PIX-170). Pure, over the exported progression.json; GameState applies them.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/progression.json")))
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
	var have := int(entry["progress"])
	match String(objective["kind"]):
		"deliver":
			have = items.get(objective["itemId"], 0)
		"relics":
			# Maren's ask (PIX-170): one of each relic, in any order.
			have = objective["items"].filter(func(item_id: String) -> bool: return int(items.get(item_id, 0)) > 0).size()
	return mini(int(objective["count"]), have)


## Accepted, not yet turned in, and the goal met (questReady).
static func is_ready(quest: Dictionary, entries: Dictionary, items: Dictionary) -> bool:
	var entry: Dictionary = entries.get(quest["id"], {})
	return not entry.is_empty() and not entry["done"] and progress(quest, entries, items) >= int(quest["objective"]["count"])


## Whether a giver has a quest to offer or to take back (questAwaitsWord):
## the first one not done is untaken (and open, `opened`), or ready to turn
## in. A keeper behind a counter talks first only then (Vex's herbs could
## never be taken while every word opened the counter).
static func awaits_word(giver: String, entries: Dictionary, items: Dictionary, opened := Callable()) -> bool:
	for quest: Dictionary in for_giver(giver):
		var entry: Dictionary = entries.get(quest["id"], {})
		if entry.get("done", false):
			continue
		if entry.is_empty() and opened.is_valid() and not opened.call(quest):
			return false
		return entry.is_empty() or is_ready(quest, entries, items)
	return false


## Whether a quest may be offered yet (PIX-171): side quests open as the
## story moves on - "opensAfter" names a main quest step, or another quest
## that must be done first.
static func is_open(quest: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	var after: String = quest.get("opensAfter", "")
	if after == "":
		return true
	var step := MainQuest.step(after)
	if not step.is_empty():
		return MainQuest.is_met(step, progression, settlement)
	return progression.quests.get(after, {}).get("done", false)


## Where a quest sends the hero (PIX-171), one line for the journal: the
## named monster's lair, the regions a quarry roams, the chest that holds
## what's wanted or the best lead for a material; "" when there's none.
static func where(quest: Dictionary) -> String:
	var objective: Dictionary = quest["objective"]
	match String(objective["kind"]):
		"hunt":
			return Text.t("In %s.") % Hunts.named(objective["named"]).get("where", "the wilds")
		"kill":
			var places := Bestiary.where_found(objective["monsterId"])
			return Text.t("Found in %s.") % ", ".join(places.slice(0, 3)) if not places.is_empty() else ""
		"deliver":
			for chest: Dictionary in Interactables._data()["chests"]:
				if chest.get("loot", {}).get("itemId", "") == objective["itemId"]:
					return Text.t("In a chest somewhere in %s.") % Catalog.place_name(chest["mapId"])
			var lead := Economy.where_to_find(objective["itemId"])
			return lead + "." if lead != "" else ""
		"relics":
			var out: Array[String] = []
			for relic: Dictionary in Relics.all():
				out.append(relic["place"])
			return Text.t("The five left them in %s.") % ", ".join(out)
	return ""
