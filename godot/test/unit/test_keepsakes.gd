extends GutTest
## The burnt steads' keepsakes (PIX-448): one at each stead's door in the
## Ash, for a villager of Pixelheim there from the first morning; searched
## once, carried home as a letter is for a little gold and their word, and
## counted on the journal's Feats.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _deed() -> Dictionary:
	return Deeds.all().filter(func(deed: Dictionary) -> bool: return deed["kind"] == "keepsakes")[0]


func test_each_stead_keeps_one_keepsake_for_someone_of_pixelheim() -> void:
	var map := MapData.load_by_id(AshRuins.MAP)
	var laid := AshRuins.lay(map, Hamlet.kept_on(map, {}), {}, true)
	var doors := AshRuins.STEADS.map(func(stead: Dictionary) -> Vector2i: return stead["door"])
	var owners := {}
	assert_eq(Quests.keepsakes().size(), AshRuins.STEADS.size(), "one a stead")
	for quest: Dictionary in Quests.keepsakes():
		var found: Dictionary = quest["found"]
		var door := Vector2i(int(found["x"]), int(found["y"]))
		assert_eq(String(found["mapId"]), AshRuins.MAP, quest["id"])
		assert_has(doors, door, "%s waits at a stead's door" % quest["id"])
		doors.erase(door)
		# Faced from the open ground below it.
		for cell: Vector2i in [door, door + Vector2i.DOWN]:
			assert_true(map.is_walkable(cell) and cell not in laid["blocks"], "%s: %s is open" % [quest["id"], cell])
		var objective: Dictionary = quest["objective"]
		assert_eq(objective["kind"], "deliverTo")
		var to := Npcs.by_id(objective["to"], [])
		assert_true(String(to.get("mapId", "")).begins_with("town"), "%s goes home to Pixelheim" % quest["id"])
		assert_eq(int(to.get("minTownTier", 0)), 0, "%s's owner is there from the first morning" % quest["id"])
		assert_false(owners.has(objective["to"]), "one each")
		owners[objective["to"]] = true
		assert_true(Catalog.item(objective["itemId"]).get("quest", false), "a keepsake isn't for sale")
		assert_eq(quest["answer"].size(), 1, "one line back")
		assert_eq(int(quest["reward"].get("xp", 0)), 0, "nothing that moves the pacing")
		assert_between(int(quest["reward"]["gold"]), 1, 25, "a little gold")
		assert_false(Letters.is_letter(quest))


func test_a_keepsake_is_found_once_and_carried_home() -> void:
	var quest: Dictionary = Quests.keepsakes()[0]
	var door := Vector2i(int(quest["found"]["x"]), int(quest["found"]["y"]))
	var to: String = quest["objective"]["to"]
	var item: String = quest["objective"]["itemId"]
	assert_eq(Quests.keepsake_at(AshRuins.MAP, door, state.progression.quests), quest)
	assert_true(Quests.keepsake_at(AshRuins.MAP, door + Vector2i.DOWN, state.progression.quests).is_empty(), "only at the door")
	var gains: Dictionary = state.questing.salvage(quest)
	assert_false(Gains.is_empty(gains), "it rises out of the ash")
	assert_eq(int(state.pack.items.get(item, 0)), 1)
	assert_true(Quests.keepsake_at(AshRuins.MAP, door, state.progression.quests).is_empty(), "found: nothing more there")
	assert_true(Gains.is_empty(state.questing.salvage(quest)), "and never twice")
	assert_eq(int(state.pack.items.get(item, 0)), 1)
	assert_eq(Quests.mark_for(to, state.progression.quests, state.pack.items), "ready", "a side quest's hand-in over its owner")
	assert_false(Quests.mark_tells_story(to, state.progression.quests, state.pack.items), "not the story's gold")
	assert_eq(state.questing.letter_for(to), quest, "handed over at the end of a word with them")
	var gold: int = state.pack.gold
	var said: String = state.questing.deliver(to)
	assert_string_contains(said, quest["name"])
	assert_eq(state.pack.gold, gold + int(quest["reward"]["gold"]))
	assert_eq(int(state.pack.items.get(item, 0)), 0, "theirs again")
	assert_true(state.progression.quests[quest["id"]]["done"])
	assert_eq(Deeds.count(_deed(), state.hero, state.pack, state.progression), [1, Quests.keepsakes().size()])


func test_what_the_fire_missed_is_a_feat() -> void:
	for quest: Dictionary in Quests.keepsakes().slice(1):
		state.progression.quests[quest["id"]] = {"progress": 1, "done": true}
	state.pack_changed()
	assert_does_not_have(state.progression.deeds, _deed()["id"], "one still in the ash")
	state.progression.quests[Quests.keepsakes()[0]["id"]] = {"progress": 1, "done": true}
	state.pack_changed()
	assert_has(state.progression.deeds, _deed()["id"])
	assert_eq(int(state.pack.items.get(_deed()["itemId"], 0)), 1)


## A ring round the lamp on the road to `place`, `mornings` old.
func _ring(place: String, mornings: int) -> Dictionary:
	return {"place": place, "cell": Routes.lamp_of(place)["cell"], "kind": "ember", "reach": Lamps.REACH, "mornings": mornings}


## PIX-466: a stead has one line to say, only once its keepsake is home
## and the ground round its lamp has healed.
func test_a_stead_remembers_once_its_keepsake_is_home_and_its_lamp_has_healed() -> void:
	var lines := {}
	for quest: Dictionary in Quests.keepsakes():
		var lamp: String = quest["found"]["lamp"]
		var whole: Array[Dictionary] = [_ring(lamp, Lamps.REACH)]
		var growing: Array[Dictionary] = [_ring(lamp, Lamps.REACH - 1)]
		var door := Vector2i(int(quest["found"]["x"]), int(quest["found"]["y"]))
		assert_false(Routes.lamp_of(lamp).is_empty(), "%s: a lamp can stand on the road to %s" % [quest["id"], lamp])
		assert_eq(Quests.keepsake_of(AshRuins.MAP, door), quest)
		assert_eq(Quests.remembered(quest, state.progression.quests, whole), "", "%s: nothing before it's found" % quest["id"])
		state.questing.salvage(quest)
		assert_eq(Quests.remembered(quest, state.progression.quests, whole), "", "%s: nothing while it's carried" % quest["id"])
		state.questing.deliver(quest["objective"]["to"])
		assert_eq(Quests.remembered(quest, state.progression.quests, []), "", "%s: nothing with its lamp unlit" % quest["id"])
		assert_eq(Quests.remembered(quest, state.progression.quests, growing), "", "%s: nothing while its ring grows" % quest["id"])
		var others: Array[Dictionary] = []
		for place: String in Routes.places():
			if place != lamp and not Routes.lamp_of(place).is_empty():
				others.append(_ring(place, Lamps.REACH))
		assert_eq(Quests.remembered(quest, state.progression.quests, others), "", "%s: nothing by another lamp" % quest["id"])
		var said := Quests.remembered(quest, state.progression.quests, whole)
		assert_eq(said, String(quest["remembers"]))
		# One row of the plate (it wraps past some 83 letters), and it names
		# whose stead it is.
		assert_between(said.length(), 20, 80, "%s: one row of the plate" % quest["id"])
		assert_false("\n" in said)
		assert_string_contains(said, String(quest["name"]).split("'")[0])
		lines[said] = true
	assert_eq(lines.size(), AshRuins.STEADS.size(), "a line of its own each")
