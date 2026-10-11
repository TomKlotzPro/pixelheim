extends GutTest
## The Fifth Letter (PIX-253 step 8, the first part of PIX-257): once the
## four keepsakes are home Maren tells it all at the shrine and gives the
## courier the letter she kept, with her promise, which opens the mountain's
## gate; past it the mountain road climbs to Morvax's forge, where he reads
## the letter, won't come home, and the mountain shakes; then the run home,
## which the Night of Bells (step 9) writes - until then an honest card. The
## Ashen Mountain's floors, the Undermountain's, its cave and its waypoint
## leave play: nothing in the world, the map, the journal, Bearing or the
## hints points at them, and old saves keep what they earned.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## The mountain's gate on the Ashenreach, and the cell before it.
const GATE := Vector2i(48, 6)
const BEFORE_GATE := Vector2i(48, 7)
## Where the Undermountain's cave was.
const OLD_CAVE := Vector2i(24, 10)
const LATE := "res://test/fixtures/web_save_late.txt"

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _next(hero: Node = null) -> String:
	var who: Node = hero if hero != null else state
	return MainQuest.next_step(who.progression, who.settlement).get("id", "")


## A hero with the four keepsakes home, the tin long found.
func _keepsakes_home() -> void:
	state.mark_seen(Letters.scene_id())
	state.progression.quests[Relics.quest_id()] = {"progress": 4, "done": true}


## The hero as their save has them: written out (web v4) and read back.
func _reloaded(hero: Node = null) -> Node:
	var who: Node = hero if hero != null else state
	var back: Node = autofree(GameStateScript.new())
	back.apply(SaveCodec.parse_json(SaveCodec.serialize(who.to_dict()))["state"])
	return back


## Where a save stood when it was written, and where it wakes now (as the
## world wakes it: Depths.waking, then onto open ground).
func _wakes(map_id: String, cell: Vector2i) -> Dictionary:
	var woke := Depths.waking(map_id, cell)
	var map := MapData.load_by_id(woke["mapId"])
	return {"mapId": woke["mapId"], "cell": Ways.standing(map, woke["cell"])}


func _walked(map: MapData, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for step: Vector2i in STEPS:
			var next := at + step
			if not seen.has(next) and map.is_walkable(next) and not map.portals.has(next):
				seen[next] = true
				queue.append(next)
	return seen


# ---- The fifth letter ---------------------------------------------------------------

func test_the_fifth_letter_is_a_letter_to_morvax_at_his_forge() -> void:
	var quest := Letters.fifth_quest()
	assert_eq(quest["id"], "letter_morvax")
	assert_true(Letters.is_letter(quest))
	assert_false(quest["id"] in Letters.all().map(func(letter: Dictionary) -> String: return letter["id"]), "not in the tin: Maren keeps it")
	var objective: Dictionary = quest["objective"]
	assert_eq(objective["kind"], "deliverTo")
	assert_eq(objective["to"], "mountain_morvax")
	assert_eq(Catalog.item(objective["itemId"])["sprite"], "letter")
	assert_true(Catalog.item(objective["itemId"]).get("quest", false))
	var morvax := Npcs.by_id("mountain_morvax", [])
	assert_eq(morvax["mapId"], "morvax_forge")
	assert_eq(Quests.for_recipient("mountain_morvax"), [quest])
	assert_false(Quests.for_giver("elder").has(quest), "never offered in talk")
	assert_string_contains(" ".join(quest["letter"]), "Come home, you proud old goat")
	assert_string_contains(" ".join(quest["answer"]), "Not like this. I left to bring her a city. I can't come back with a cough.")
	assert_string_contains(" ".join(quest["answer"]), "You're late, courier. Fifty years late.")
	assert_string_contains(" ".join(quest["quake"]), "He's awake. He goes for the lights. He always goes for the lights.")


func test_maren_tells_it_all_once_the_keepsakes_are_home() -> void:
	state.mark_seen(Letters.scene_id())
	assert_false(Letters.fifth_due(state.progression, state.settlement), "not before the keepsakes")
	assert_eq(state.questing.hear_out(), "")
	_keepsakes_home()
	assert_eq(_next(), "confession")
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["chapter"], "The Fifth Letter")
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 6, "the chapter's card")
	assert_true(Letters.fifth_due(state.progression, state.settlement))
	assert_eq(Letters.fifth_lines(state.progression, state.settlement), Letters.confession_lines(), "her whole story, at the shrine")
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["who"], lead["map_id"]], ["elder", "town"])
	assert_false(Relics.gate_open(state.progression), "the gate waits on her promise")
	var said: Array[String] = []
	state.message.connect(func(text: String) -> void: said.append(text))
	state.questing.finish_dialogue("elder")
	assert_eq(said[-1], String(Letters.fifth()["given"]))
	assert_has(state.progression.story_seen, Letters.confession_id())
	assert_eq(int(state.pack.items.get("letter_morvax", 0)), 1, "the fifth letter in the satchel")
	assert_eq(int(state.pack.items.get(Relics.promise_id(), 0)), 1, "and her promise, the fifth mark")
	assert_true(Relics.gate_open(state.progression), "the mountain's gate opens")
	assert_eq(_next(), "letter_morvax")
	assert_false(Letters.fifth_due(state.progression, state.settlement), "given once")
	assert_eq(state.questing.hear_out(), "")
	assert_eq(Letters.satchel(state.progression)[-1], {"quest": Letters.fifth_quest(), "delivered": false})
	lead = Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["who"], lead["map_id"]], ["mountain_morvax", "morvax_forge"], "up the road to Morvax")


func test_morvax_reads_it_and_the_mountain_shakes() -> void:
	_keepsakes_home()
	state.questing.finish_dialogue("elder")
	var quest := Letters.fifth_quest()
	assert_eq(state.questing.letter_for("mountain_morvax"), quest)
	assert_eq(Letters.answer(quest, state.progression, state.settlement), quest["answer"])
	assert_eq(Letters.then_lines(quest, state.progression, state.settlement), quest["quake"], "the mountain shakes")
	assert_eq(Letters.after_lines("mountain_morvax", state.progression, state.settlement), [], "nothing after until it's read")
	var gold: int = state.pack.gold
	assert_string_contains(state.questing.deliver("mountain_morvax"), "Delivered: The Fifth Letter")
	assert_eq(state.pack.gold, gold + int(quest["reward"]["gold"]), "he pays the postage")
	assert_eq(int(state.pack.items.get("letter_morvax", 0)), 0)
	assert_eq(Letters.after_lines("mountain_morvax", state.progression, state.settlement), quest["after"])
	assert_eq(_next(), "run_home")
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 7, "the Night of Bells' card")
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"]], ["town", Town.square()], "run home")
	assert_eq(MainQuest.continued(state.progression, state.settlement), "", "no card: home, the Night of Bells begins (step 9)")
	assert_true(Bells.due(state.progression, state.settlement))
	assert_eq(Letters.satchel(state.progression)[-1], {"quest": quest, "delivered": true})


func test_the_run_home_begins_the_night_of_bells() -> void:
	_keepsakes_home()
	state.questing.finish_dialogue("elder")
	state.questing.finish_dialogue("mountain_morvax")
	var step := MainQuest.next_step(state.progression, state.settlement)
	assert_eq(step["when"]["kind"], "bells", "step 9 wrote it")
	assert_false(MainQuest.is_met(step, state.progression, state.settlement), "until the night begins")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Run home: the dragon is awake")
	assert_eq(MainQuest.continued_word(), "To be continued")
	# No broken quest: nothing else is asked of the hero meanwhile.
	assert_false(Letters.fifth_due(state.progression, state.settlement))
	assert_eq(state.questing.letter_for("mountain_morvax"), {})
	var bram := Quests.by_id("bram_imps")
	assert_false(state.questing.quest_open(bram), "Bram's imps wait for the Night of Bells")
	state.questing.bells_begin()
	assert_true(MainQuest.is_met(step, state.progression, state.settlement), "home, and the night begins")
	assert_true(state.questing.quest_open(bram), "the embers are imps")


# ---- The mountain road and the forge -----------------------------------------------

func test_the_gate_opens_on_the_road_up_to_the_forge() -> void:
	var reach := MapData.load_by_id("overworld")
	var gate: Dictionary = reach.portals[GATE]
	assert_eq(gate["mapId"], "mountain_road")
	assert_true(gate.get("barred", false), "barred until Maren's promise")
	var road := MapData.load_by_id("mountain_road")
	var arrival := Vector2i(int(gate["x"]), int(gate["y"]))
	assert_true(road.is_walkable(arrival))
	assert_eq(Catalog.place_name("mountain_road"), "The Mountain Road")
	assert_eq(Catalog.place_name("morvax_forge"), "Morvax's Forge")
	# The road's way back down is the gate seen from inside.
	var back := Ways.on(road).filter(func(way: Dictionary) -> bool: return String(way["to"].get("mapId", "")) == "overworld")
	assert_eq(back.size(), 1)
	assert_eq(back[0]["kind"], "gate")
	assert_true(back[0]["rock"], "set in the rock")
	assert_eq(Vector2i(int(back[0]["to"]["x"]), int(back[0]["to"]["y"])), BEFORE_GATE)
	# Up the switchbacks to the forge's door.
	var walked := _walked(road, arrival)
	var door := Vector2i(-1, -1)
	for cell: Vector2i in road.portals:
		if road.portals[cell].get("mapId", "") == "morvax_forge":
			door = cell
	assert_true(STEPS.any(func(step: Vector2i) -> bool: return walked.has(door + step)), "the road climbs to the forge's door")
	assert_false(ReachPlane.holds("mountain_road"), "a place of its own, behind the gate")
	assert_has(Atlas.ORDER, "mountain_road")


func test_ash_hounds_and_wyverns_hold_the_road() -> void:
	var road := MapData.load_by_id("mountain_road")
	var spawns := Bestiary.spawns_on("mountain_road")
	assert_eq(spawns.size(), 3)
	var kinds := {}
	for spawn: Dictionary in spawns:
		kinds[spawn["species"]] = true
		assert_eq(road.region_at(Vector2i(int(spawn["x"]), int(spawn["y"]))), "road")
		assert_true(road.is_walkable(Vector2i(int(spawn["x"]), int(spawn["y"]))))
		assert_eq(int(spawn["level"]), 13, "a step above the glass hall's packs")
		var arrival := Vector2i(17, 29)
		assert_gt(Vector2(Vector2i(int(spawn["x"]), int(spawn["y"])) - arrival).length(), 8.0, "%s: not on the hero's arrival" % spawn["id"])
	assert_eq(kinds.keys(), ["wolf", "wyvern"], "from the existing bestiary")
	assert_eq(Bestiary.region("road")["called"]["wolf"], "Ash Hound", "the road's wolves are ash hounds")
	# Lifted to the spawn's level, as the world spawns them.
	var hound := Bestiary.spawn("wolf", false, 13 - int(Bestiary.monster("wolf")["level"]))
	assert_eq(int(hound["level"]), 13)


func test_the_forge_holds_morvax_his_cot_his_anvil_and_his_tally_marks() -> void:
	var forge := MapData.load_by_id("morvax_forge")
	assert_true(PunyInterior.is_room("morvax_forge"))
	assert_has(forge.grid.values(), "bed", "a cot")
	assert_has(forge.grid.values(), "anvil", "a cold anvil")
	assert_false(forge.grid.values().has("forge"), "no fire in it: the iron ran out")
	var door: Vector2i = forge.portals.keys()[0]
	var walked := _walked(forge, door + Vector2i.UP)
	var morvax := Npcs.by_id("mountain_morvax", [])
	assert_true(STEPS.any(func(step: Vector2i) -> bool: return walked.has(Vector2i(int(morvax["x"]), int(morvax["y"])) + step)), "Morvax is walked up to")
	var tally := Letters.reading("morvax_tally")
	assert_false(tally.has("quest"), "no letter opens it: it's on the wall")
	var rect := Letters.reading_rect(tally)
	for x in range(rect.position.x, rect.end.x):
		assert_eq(forge.tile_at(Vector2i(x, rect.position.y)), "wall", "on the back wall")
		assert_true(walked.has(Vector2i(x, rect.position.y + 1)), "read from the floor below it")
		assert_eq(Letters.reading_at("morvax_forge", Vector2i(x, rect.position.y)), tally)
	assert_eq(Letters.drawn_on("morvax_forge"), [{"look": "tally", "rect": rect}], "drawn on the wall")
	# Read once, a short word after.
	assert_true(Letters.reads_now(tally, state.progression))
	assert_eq(Letters.reading_lines(tally, state.progression), tally["lines"])
	assert_string_contains(" ".join(tally["lines"]), "forty")
	state.mark_seen("morvax_tally")
	assert_eq(Letters.reading_lines(tally, state.progression), [tally["again"]])


# ---- The first dream ---------------------------------------------------------------

func test_the_first_dream_speaks_with_morvaxs_voice() -> void:
	var dream: Array = Cutscene.scenes()[Story.next_dream([], [])]
	assert_false(dream.any(func(step: Dictionary) -> bool: return step["kind"] == "eyes"), "no purple eyes")
	var said := dream.filter(func(step: Dictionary) -> bool: return step["kind"] == "caption").map(func(step: Dictionary) -> String: return step["text"])
	assert_true(said.any(func(line: String) -> bool: return line.contains("You're late, courier. Fifty years late.")), "his line, as he says it at the forge")
	assert_string_contains(" ".join(Letters.fifth_quest()["answer"]), "You're late, courier. Fifty years late.")


# ---- Old saves ---------------------------------------------------------------------

## A hero saved on the old mountain's floors: the save kept the gate (the
## floors were never saved), so it wakes there, its floors and gear as they
## were, and Maren's story is next.
func test_a_save_from_the_old_floors_wakes_by_the_gate() -> void:
	state.hero.level = 14
	for level in range(1, 7):
		state.progression.cleared_levels.append(level)
	state.progression.unlocked_level = 7
	state.world.map_id = "overworld"
	state.world.cell = BEFORE_GATE
	var back := _reloaded()
	assert_eq(_wakes(back.world.map_id, back.world.cell), {"mapId": "overworld", "cell": BEFORE_GATE}, "by the mountain's gate")
	assert_eq(back.hero.level, 14, "levels kept")
	assert_eq(Array(back.progression.cleared_levels), [1, 2, 3, 4, 5, 6], "its floors stay in the save")
	assert_true(Relics.gate_open(back.progression), "the gate open: it went up before")
	assert_eq(_next(back), "confession", "past the old gate, before the confession: Maren's story next")
	assert_true(Letters.fifth_due(back.progression, back.settlement))
	assert_eq(back.to_dict().keys(), state.to_dict().keys(), "no new field")


## The flows' old saves (test/fixtures, `--load`): one saved on the old
## seventh floor, one by the Undermountain's cave.
func test_the_old_save_fixtures_wake_where_they_should() -> void:
	state.apply(WebImport.parse_any(FileAccess.get_file_as_string("res://test/fixtures/old_floor7.json")))
	assert_eq(_wakes(state.world.map_id, state.world.cell), {"mapId": "overworld", "cell": BEFORE_GATE})
	assert_eq(state.hero.level, 13)
	assert_eq(_next(), "confession")
	state.apply(WebImport.parse_any(FileAccess.get_file_as_string("res://test/fixtures/old_cave.json")))
	assert_eq(_wakes(state.world.map_id, state.world.cell)["mapId"], "town")
	assert_eq(state.hero.level, 17, "levels kept")
	assert_true(state.pack.equipped.has("weapon"), "gear kept")


func test_a_save_by_the_old_cave_wakes_in_town() -> void:
	var town: Dictionary = Catalog._data()["townSpawn"]
	for cell: Vector2i in [Vector2i(25, 10), Vector2i(24, 11), Vector2i(26, 10)]:
		assert_eq(_wakes("overworld", cell)["mapId"], "town", "%s: by the cave that's rock now" % cell)
		assert_eq(Depths.waking("overworld", cell)["cell"], Vector2i(int(town["x"]), int(town["y"])))
	assert_eq(_wakes("overworld", Vector2i(30, 10))["mapId"], "overworld", "anywhere else on the Ash, where it stood")
	assert_eq(MapData.load_by_id("overworld").tile_at(OLD_CAVE), "mountain", "the cave is filled with rock")


func test_a_hero_who_heard_the_old_confession_gets_the_letter_at_the_next_word() -> void:
	state.progression.cleared_levels.assign(range(1, 11))
	state.mark_seen(Letters.scene_id())
	state.mark_seen(Letters.confession_id())
	assert_eq(_next(), "letter_morvax", "the confession heard, the old way")
	assert_true(Letters.fifth_due(state.progression, state.settlement))
	assert_eq(Letters.fifth_lines(state.progression, state.settlement), Letters.fifth()["late"], "a word, not the whole story again")
	state.questing.finish_dialogue("elder")
	assert_eq(int(state.pack.items.get("letter_morvax", 0)), 1)
	assert_eq(_next(), "letter_morvax", "now up the road")


## A hero who slew Fafnyr on the old mountain keeps him slain: Morvax reads
## the letter to a quiet mountain, the Night of Bells is skipped, and home
## (step 10) is next: Morvax's choice, asked at his forge.
func test_a_dragon_slayer_skips_the_night_of_bells() -> void:
	state.progression.cleared_levels.assign(range(1, 11))
	state.mark_seen(Letters.scene_id())
	assert_eq(_next(), "confession")
	state.questing.finish_dialogue("elder")
	assert_eq(_next(), "letter_morvax")
	var quest := Letters.fifth_quest()
	assert_eq(Letters.answer(quest, state.progression, state.settlement), quest["slain"]["answer"], "the mountain stays quiet")
	assert_eq(Letters.then_lines(quest, state.progression, state.settlement), [], "nothing wakes")
	state.questing.finish_dialogue("mountain_morvax")
	assert_eq(Letters.after_lines("mountain_morvax", state.progression, state.settlement), quest["slain"]["after"])
	assert_true(MainQuest.skips(7, state.progression, state.settlement))
	assert_eq(_next(), "morvax_choice", "no run home, no Night of Bells: home, and Morvax's choice")
	assert_false(Bells.due(state.progression, state.settlement), "no night for a dragon slayer")
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 8, "the card of home's chapter")
	assert_eq(MainQuest.continued(state.progression, state.settlement), "", "the story is written to its end: no card")


## The late web hero who beat Morvax on the old mountain: their story stays
## told, nothing is given them, nothing points at the floors.
func test_the_late_web_save_loads_and_plays() -> void:
	var late := SaveCodec.decode_code(FileAccess.get_file_as_string(LATE))
	state.apply(late.duplicate(true))
	assert_eq(state.hero.hero_name, "Hrafna")
	var woke := _wakes(state.world.map_id, state.world.cell)
	assert_true(MapData.load_by_id(woke["mapId"]).is_walkable(woke["cell"]), "it wakes on open ground")
	assert_eq(_next(), "", "their story is told")
	assert_false(Letters.fifth_due(state.progression, state.settlement), "no fifth letter for them")
	assert_eq(MainQuest.continued(state.progression, state.settlement), "", "no card")
	assert_true(Relics.gate_open(state.progression), "the road is open to them")
	assert_eq(Array(state.progression.cleared_levels), Array(late["clearedLevels"]), "its floors kept, unread")
	assert_eq(state.to_dict().keys(), late.keys(), "its fields, no more")


func test_a_save_after_the_letter_holds_its_place() -> void:
	_keepsakes_home()
	state.questing.finish_dialogue("elder")
	assert_eq(_next(_reloaded()), "letter_morvax", "the letter in hand, saved and loaded")
	assert_eq(int(_reloaded().pack.items.get("letter_morvax", 0)), 1)
	state.questing.finish_dialogue("mountain_morvax")
	var back := _reloaded()
	assert_eq(_next(back), "run_home")
	assert_true(Relics.gate_open(back.progression))
	assert_eq(back.to_dict().keys(), state.to_dict().keys(), "no new field")


# ---- Nothing points at the floors -------------------------------------------------

func test_nothing_in_the_world_leads_to_the_old_floors() -> void:
	# Map portals: no map opens onto a dungeon's numbered floors.
	for file: String in DirAccess.get_files_at("res://assets/maps"):
		if not file.ends_with(".json") or file == "interactables.json" or file.contains("@"):
			continue
		var map := MapData.load_by_id(file.get_basename())
		for cell: Vector2i in map.portals:
			assert_ne(String(map.portals[cell].get("kind", "")), "dungeon", "%s %s opens onto the old floors" % [map.id, cell])
	# Waypoints: none at the old cave.
	for waypoint: Dictionary in Interactables.waypoints():
		assert_ne(waypoint["id"], "undermountain_cave")
		var at := Vector2i(int(waypoint["at"]["x"]), int(waypoint["at"]["y"]))
		assert_ne([waypoint["mapId"], at], ["overworld", OLD_CAVE], "%s stands at the old cave" % waypoint["id"])
	# The hints: none names a floor or the deep.
	var hints := FileAccess.get_file_as_string("res://assets/data/hints.json")
	for word: String in ["floor", "Undermountain", "Ashen Mountain"]:
		assert_false(hints.contains(word), "a hint names %s" % word)
	# Bearing and the journal: no step of the story, no quest's way, leads
	# to a floor.
	for step: Dictionary in MainQuest.steps():
		assert_ne(step["when"]["kind"], "cleared", "%s asks for a floor" % step["id"])
		var lead := Bearing.of_step(step, state.progression, state.settlement, state.pack.items)
		assert_false(String(lead["map_id"]).begins_with("floor"), "%s leads to a floor" % step["id"])
		for words: String in [String(step["text"]), String(step["hint"]), String(step.get("elderHint", ""))]:
			assert_false(_names_old_floor(words), "%s: %s" % [step["id"], words])
	for quest: Dictionary in Quests.all():
		assert_false(_names_old_floor(Quests.where(quest)), "%s's way names an old floor: %s" % [quest["id"], Quests.where(quest)])
	# Maren's words once the gate is open, and the story she tells now.
	var maren := Npcs.on_map("town", 2, [], null, true)
	for npc: Dictionary in maren:
		if npc["id"] == "elder":
			for line: String in npc["lines"]:
				assert_false(line.contains("floors") or line.contains("below him"), line)
	assert_eq(Story.elder_story(range(1, 11), []), {}, "no story of a floor")


## Whether `text` names one of the old mountain's floors: by number ("floor
## 7", "floors 4-6", "from floor 8"), by name (the Sunken Forge), or the
## Undermountain. A region dungeon's "three floors down" is no old floor.
func _names_old_floor(text: String) -> bool:
	if RegEx.create_from_string("floors? \\d").search(text) != null or text.contains("Undermountain"):
		return true
	for level in range(1, Dungeons.floor_count() + 1):
		if text.contains(String(Dungeons.floor_def(level)["name"])):
			return true
	return false
