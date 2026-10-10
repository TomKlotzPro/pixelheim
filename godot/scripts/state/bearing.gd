class_name Bearing
extends RefCounted
## Where the hero is headed, their bearing (PIX-239, PIX-240): the active quest - a side
## quest or a bounty the hero chose to follow in the journal
## (ProgressionState.tracked), or else the main story's next step - as a
## title, one plain line for what to do now, the place it's in, a map and a
## cell to point at when there's one, and how far along it is. The line above the dock, the journal's top, the map
## screen and the arrow at the view's edge all say the same thing from here.
## Pure: everything it needs is passed in.

const NOWHERE := Vector2i(-1, -1)


## The active lead: {title, step, place, map_id, cell, who, progress,
## quest_id, named, main} (`who`: the villager it's about, when it's a
## person; `named`: a followed bounty's named monster), or {} once the
## story is done and nothing is followed. Where its place lies past a gate
## still shut (PIX-254), it leads to what opens the gate, in the gate's
## words (Gates.detour; `discovered`, the save's fog of war, says whether an
## old hero is already past it).
static func active(progression: ProgressionState, settlement: SettlementState, items: Dictionary, discovered: Dictionary = {}) -> Dictionary:
	if progression.tracked != "":
		var quest := Quests.by_id(progression.tracked)
		var entry: Dictionary = progression.quests.get(progression.tracked, {})
		if not quest.is_empty() and not entry.is_empty() and not entry.get("done", false):
			return Gates.detour(of_quest(quest, progression, settlement, items), progression, settlement, items, discovered)
		# A notice on the bounty board, followed while its quarry lives.
		var named := Hunts.named(progression.tracked)
		if not named.is_empty() and Hunts.on_board(named) and Hunts.status(named, board_floors(progression), progression.hunted) == "wanted":
			return Gates.detour(of_bounty(named), progression, settlement, items, discovered)
	return main(progression, settlement, items, discovered)


## The main story's lead, whatever is followed: its next step's, or {} once
## it's told. While a side quest or a bounty leads, the map keeps this one
## as a hollow gold diamond, so the main goal is never lost (PIX-253 step 2).
## Past a gate still shut, what opens it (PIX-254).
static func main(progression: ProgressionState, settlement: SettlementState, items: Dictionary, discovered: Dictionary = {}) -> Dictionary:
	var step := MainQuest.next_step(progression, settlement)
	return {} if step.is_empty() else Gates.detour(of_step(step, progression, settlement, items), progression, settlement, items, discovered)


## Whether `lead` is the main story's (PIX-253 step 2: the arrow is gold
## then): its next step, or a thread followed that carries it - one of
## Maren's letters, her relics, a relic's hunt (Journal.is_main_line).
static func tells_story(lead: Dictionary) -> bool:
	if lead.is_empty():
		return false
	if lead["main"]:
		return true
	var quest := Quests.by_id(String(lead["quest_id"]))
	return not quest.is_empty() and Journal.is_main_line(quest)


## The main story's lead behind `lead` (the active one): {} while the main
## story leads itself or is told, else its next step's.
static func behind(lead: Dictionary, progression: ProgressionState, settlement: SettlementState, items: Dictionary, discovered: Dictionary = {}) -> Dictionary:
	if lead.is_empty() or lead["main"]:
		return {}
	return main(progression, settlement, items, discovered)


## A main story step's lead: its chapter, its line, and where it is - the
## giver of the quest it waits on (or that quest's own way once taken), the
## mountain's gate for a floor, the board on the square for the town's
## projects, a named monster's lair, Maren over her tin or a letter's
## recipient (PIX-253).
static func of_step(step: Dictionary, progression: ProgressionState, settlement: SettlementState, items: Dictionary) -> Dictionary:
	var lead := _blank(String(step.get("chapter", "")), String(step["text"]))
	lead["main"] = true
	var when: Dictionary = step["when"]
	match String(when["kind"]):
		"questTaken":
			_at_giver(lead, Quests.by_id(when["questId"]), settlement)
		"questDone":
			var quest := Quests.by_id(when["questId"])
			if progression.quests.has(quest["id"]):
				var way := of_quest(quest, progression, settlement, items)
				for key: String in ["place", "map_id", "cell", "who", "progress", "quest_id"]:
					lead[key] = way[key]
			else:
				_at_giver(lead, quest, settlement)
		"cleared":
			_at_gate(lead, int(when["level"]))
		"project", "townTier":
			_at(lead, "town", Town.project_board())
		"hunted":
			_at_lair(lead, Hunts.named(when["named"]))
		"seen":
			# Maren digging for her tin (PIX-253), or a letter's answer
			# waiting to be read (PIX-255: Hale's order book on his table).
			if when["sceneId"] == Letters.scene_id():
				_at_tin(lead, progression, settlement)
			else:
				var reading := Letters.reading(String(when["sceneId"]))
				if not reading.is_empty():
					_at(lead, String(reading["mapId"]), Letters.reading_rect(reading).get_center())
		"delivered":
			# A letter (PIX-253): its recipient once it's in hand; Maren
			# while the tin still waits, or for one she has yet to give.
			var letter := Quests.by_id(when["questId"])
			if progression.quests.has(letter["id"]):
				var way := of_quest(letter, progression, settlement, items)
				for key: String in ["place", "map_id", "cell", "who", "progress", "quest_id"]:
					lead[key] = way[key]
			else:
				_at_tin(lead, progression, settlement)
	return lead


## A taken quest's lead: what's left to do, where, and how far along; once
## it's all there, its giver to hand it in to.
static func of_quest(quest: Dictionary, progression: ProgressionState, settlement: SettlementState, items: Dictionary) -> Dictionary:
	var objective: Dictionary = quest["objective"]
	var lead := _blank(String(quest["name"]), String(objective.get("label", quest.get("brief", ""))))
	lead["quest_id"] = quest["id"]
	var count := int(objective.get("count", 1))
	var have := Quests.progress(quest, progression.quests, items)
	if count > 1:
		lead["progress"] = "%d/%d" % [have, count]
	# Carried to someone else (PIX-253): to them, whatever the pack holds.
	if objective["kind"] == "deliverTo":
		lead["step"] = String(quest["brief"])
		_at_npc(lead, objective["to"], settlement)
		return lead
	if Quests.is_ready(quest, progression.quests, items):
		var giver := Npcs.by_id(quest["giver"], settlement.settlers)
		lead["step"] = Text.t("Hand it in to %s.") % String(giver.get("name", quest["giver"]))
		_at_giver(lead, quest, settlement)
		return lead
	match String(objective["kind"]):
		"hunt":
			_at_lair(lead, Hunts.named(objective["named"]))
		"kill":
			var home := Bestiary.home_of(objective["monsterId"])
			if not home.is_empty():
				_at(lead, home["mapId"], Vector2i(int(home["x"]), int(home["y"])))
		"deliver":
			for chest: Dictionary in Interactables._data()["chests"]:
				if chest.get("loot", {}).get("itemId", "") == objective["itemId"]:
					_at(lead, chest["mapId"], Vector2i(int(chest["x"]), int(chest["y"])))
					break
		"craft":
			for entry: Dictionary in Economy.recipes():
				if entry["itemId"] == objective["itemId"]:
					var station: Dictionary = Economy._data()["jobStations"].get(entry["job"]["id"], {})
					if not station.is_empty():
						_at(lead, station["mapId"], NOWHERE)
					break
	return lead


## A bounty's lead (PIX-239): the named monster on the board's notice, slain
## in its lair. Its bounty is paid where it falls: nothing to hand in.
static func of_bounty(named: Dictionary) -> Dictionary:
	var lead := _blank(String(named["name"]), Text.t("Slay %s in its lair") % Text.mid(String(named["name"])))
	lead["named"] = named["id"]
	_at_lair(lead, named)
	return lead


## The floors the bounty board counts (Hunts.board_floors), read off the save.
static func board_floors(progression: ProgressionState) -> Array:
	return Hunts.board_floors(progression.cleared_levels, Relics.found(progression), progression.deepest)


static func _blank(title: String, step: String) -> Dictionary:
	return {"title": title, "step": step, "place": "", "map_id": "", "cell": NOWHERE, "who": "", "progress": "", "quest_id": "", "named": "", "main": false}


## At `cell` of `map_id` (NOWHERE: somewhere on that map), named by its place.
static func _at(lead: Dictionary, map_id: String, cell: Vector2i) -> void:
	lead["map_id"] = map_id
	lead["cell"] = cell
	lead["place"] = Catalog.place_name(map_id)


static func _at_giver(lead: Dictionary, quest: Dictionary, settlement: SettlementState) -> void:
	if quest.is_empty():
		return
	_at_npc(lead, quest["giver"], settlement)


## At a villager, where they live.
static func _at_npc(lead: Dictionary, npc_id: String, settlement: SettlementState) -> void:
	var npc := Npcs.by_id(npc_id, settlement.settlers)
	lead["who"] = npc_id
	if npc.has("mapId"):
		_at(lead, npc["mapId"], Vector2i(int(npc.get("x", -1)), int(npc.get("y", -1))))


## At Maren (PIX-253): in the ashes of her house while her tin waits there
## (Npcs.on_map stands her there), else where she always stands.
static func _at_tin(lead: Dictionary, progression: ProgressionState, settlement: SettlementState) -> void:
	_at_npc(lead, "elder", settlement)
	var dig := Letters.dig_spot(Town.done_projects(settlement))
	if dig.x >= 0 and Letters.tin_waits(progression):
		lead["cell"] = dig


static func _at_lair(lead: Dictionary, named: Dictionary) -> void:
	if named.has("mapId") and named.has("lair"):
		_at(lead, named["mapId"], Hunts.lair(named))


## The gate of the dungeon whose floors hold `level`: a portal on some map
## that opens onto it.
static func _at_gate(lead: Dictionary, level: int) -> void:
	for dungeon_id: String in ["mountain", "undermountain"]:
		var dungeon := Dungeons.dungeon(dungeon_id)
		if level not in dungeon.get("floors", []):
			continue
		var gate := gate_of(dungeon_id)
		if not gate.is_empty():
			_at(lead, gate["mapId"], gate["cell"])
		return


static var _gates := {}


## Where a dungeon's gate stands: {mapId, cell}, looked for once on the
## overworld's portals.
static func gate_of(dungeon_id: String) -> Dictionary:
	if _gates.is_empty():
		var overworld := MapData.load_by_id("overworld")
		for cell: Vector2i in overworld.portals:
			var target: Dictionary = overworld.portals[cell]
			if target.get("kind", "") == "dungeon":
				_gates[target["dungeon"]] = {"mapId": "overworld", "cell": cell}
	return _gates.get(dungeon_id, {})


static var _doors := {}


## The door on `from_map` that starts the way to `to_map`: the first step of
## the shortest walk through the maps' doors (learned once from every named
## map), or NOWHERE when there's no way or no need.
static func way_out(from_map: String, to_map: String) -> Vector2i:
	if from_map == to_map or to_map == "":
		return NOWHERE
	_learn_doors()
	var first := {from_map: NOWHERE}
	var queue: Array[String] = [from_map]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		for next: String in _doors.get(here, {}):
			if first.has(next):
				continue
			first[next] = _doors[here][next] if here == from_map else first[here]
			if next == to_map:
				return first[next]
			queue.append(next)
	return NOWHERE


## Where a door way_out found on `map_id` leads: the map behind it, "" for
## a cell that isn't one (the map screen follows a way across the maps on
## one page, PIX-269 step 7).
static func through(map_id: String, door: Vector2i) -> String:
	_learn_doors()
	var doors: Dictionary = _doors.get(map_id, {})
	for next: String in doors:
		if doors[next] == door:
			return next
	return ""


## Each named map's doors to other maps: map id -> {its target: a door cell}.
static func _learn_doors() -> void:
	if not _doors.is_empty():
		return
	for map_id: String in Catalog._data()["places"]:
		var doors := {}
		var data := MapData.load_by_id(map_id)
		if data == null:
			continue
		for cell: Vector2i in data.portals:
			var target: Dictionary = data.portals[cell]
			if target.get("kind", "") == "map" and not doors.has(target["mapId"]):
				doors[target["mapId"]] = cell
		_doors[map_id] = doors


## The line above the dock (PIX-239): the step, the place it's in when the
## step doesn't already say it, and the count. A step that's a sentence
## ("Hand it in to Bram.") loses its full stop before what follows it.
static func line(lead: Dictionary) -> String:
	if lead.is_empty():
		return ""
	var text := String(lead["step"])
	var place := String(lead["place"])
	var progress := String(lead["progress"])
	if (place != "" and place not in text) or progress != "":
		text = text.trim_suffix(".")
	if place != "" and place not in text:
		text += " - " + place
	if progress != "":
		text += " (%s)" % progress
	return text
