class_name Letters
## Maren's five letters (PIX-253, the main story's new beginning). Fifty
## years ago she wrote one to each family of the five who climbed, and never
## sent them. The morning after the Night of Ash the courier helps her dig
## through what's left of her house and finds them in a tin under the
## hearthstone: four go out across the Reach - to Old Wenna in Saltmere, Old
## Pell at Blackiron, Captain Hale at Greyhold and Aske on the Frostgate -
## and each is answered as it's handed over; the fifth, to Morvax, stays
## with her. A letter is a quest of the "deliverTo" kind: Maren's, carried
## to someone else (Quests). Old saves are never sent back with one: a
## letter whose keepsake is already won counts as delivered, and a hero past
## the night who never saw the tin gets the letters at the first word with
## Maren. Pure, over progression.json's "letters"; Questing gives them out
## and hands them over.


static func _doc() -> Dictionary:
	return Quests._data()["letters"]


## The tin, in the story ledger once it's found.
static func scene_id() -> String:
	return String(_doc()["sceneId"])


## The four letters to deliver, as quests, in the story's order.
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for quest_id: String in _doc()["quests"]:
		out.append(Quests.by_id(quest_id))
	return out


static func is_letter(quest: Dictionary) -> bool:
	return String(quest.get("id", "")) in _doc()["quests"]


## Whether a letter's keepsake is won: the relic its family gives back,
## laid low with its chapter boss, or every relic home with Maren.
static func keepsake_won(quest: Dictionary, progression: ProgressionState) -> bool:
	if Relics.home(progression):
		return true
	for relic: Dictionary in Relics.all():
		if relic["itemId"] == quest.get("keepsake", ""):
			return relic["named"] in progression.hunted
	return false


## Whether a letter is delivered: handed over, or as good as - its keepsake
## won before the letters were written into the story.
static func delivered(quest: Dictionary, progression: ProgressionState) -> bool:
	return progression.quests.get(quest["id"], {}).get("done", false) or keepsake_won(quest, progression)


## Whether the tin still waits under Maren's hearthstone: the night is over
## and it hasn't been found.
static func tin_waits(progression: ProgressionState) -> bool:
	return progression.prologue == Prologue.DONE and scene_id() not in progression.story_seen


## Where Maren stands digging while the tin waits and her house is ash (the
## inn's project, `done` the projects built, rebuilds it with the homes
## around the square); (-1, -1) once it stands again.
static func dig_spot(done: Array) -> Vector2i:
	for ruin: Dictionary in Town.ruins(done):
		if ruin["home"] == "elder":
			var at: Dictionary = _doc()["dig"]
			return Vector2i(int(at["x"]), int(at["y"]))
	return Vector2i(-1, -1)


## What Maren says over the tin: the dig, in the ashes of her house; once
## it's rebuilt (a hero who came back to her later), a short word.
static func tin_lines(done: Array) -> Array:
	return _doc()["tin" if dig_spot(done).x >= 0 else "late"]


## What a villager has to say of the letters now (Bram's crew has cleared
## the cliff road once they're out, until Wenna has hers), or "".
static func news_for(npc_id: String, progression: ProgressionState) -> String:
	var news: Dictionary = _doc()["news"]
	if not news.has(npc_id) or scene_id() not in progression.story_seen or delivered(all()[0], progression):
		return ""
	return String(news[npc_id])


## Sela's word as the courier first pays for a bed (the night the first
## dream comes), or "" after.
static func room_line(progression: ProgressionState) -> String:
	var first: String = Story._data()["dreams"][0]["id"]
	return String(_doc()["room"]) if first not in progression.story_seen else ""


## What the tin left in the pack, said once it's opened: the letters given
## (by item id), and whether the cliff road is being cleared.
static func taken_line(given: Array[String]) -> String:
	var line := String(_doc()["answered"])
	if given.size() == all().size():
		line = String(_doc()["taken"])
	elif not given.is_empty():
		line = String(_doc()["takenSome"]) % ", ".join(given.map(func(item_id: String) -> String: return Catalog.item_name(item_id)))
	if all()[0]["objective"]["itemId"] in given:
		line += " " + String(_doc()["road"])
	return line
