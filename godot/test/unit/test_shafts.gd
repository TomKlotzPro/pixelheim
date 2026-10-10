extends GutTest
## The Letter to Blackiron (PIX-255, PIX-253 step 5): the Blackiron shafts
## in three floors from the data - the upper shafts with Bram's humming
## cheese, the west gallery with Pell's very cross canary, the Black Seam
## with the Seam Warden sitting on the last ingot - every one reached from
## the entrance down the stairs and back up them, each harder than the one
## above, and the ore cage up to the pithead once the Warden is down; old
## saves at each stage; Old Pell and his canary coming home above Hilda's
## forge, the Village's beat as he does, and the second dream.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const FLOORS := ["shafts", "shafts_gallery", "shafts_blackseam"]
const ENTRANCE := Vector2i(4, 27)

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


# ---- The floors ---------------------------------------------------------------------

func test_the_shafts_are_three_floors_top_down() -> void:
	assert_eq(Depths.floors("shafts").map(func(entry: Dictionary) -> String: return entry["mapId"]), FLOORS)
	for i in FLOORS.size():
		assert_eq(Depths.number(FLOORS[i]), i + 1)
		assert_eq(Depths.root(FLOORS[i]), "shafts", "a floor goes by its dungeon's first in the tables")
	assert_eq(Depths.number("blackiron"), 0)
	assert_true(Depths.is_planned("shafts_gallery"), "the west gallery is laid out from a seed")
	assert_false(Depths.is_planned("shafts"))
	assert_false(Depths.is_planned("shafts_blackseam"))
	assert_eq(Catalog.place_name("shafts_gallery"), "The West Gallery")
	assert_eq(Catalog.place_name("shafts_blackseam"), "The Black Seam")
	assert_has(Atlas.ORDER, "shafts_blackseam", "each floor a page of the map")


func test_every_floor_is_reached_from_the_entrance_down_the_stairs() -> void:
	var map := MapData.load_by_id("shafts")
	var at: Vector2i = Depths.waking("shafts", Vector2i.ZERO)["cell"]
	assert_eq(at, ENTRANCE, "the entrance, by the stair up to the valley")
	var reached := {}
	for depth in FLOORS.size():
		assert_eq(map.id, FLOORS[depth])
		var walked := _walked(map, at)
		reached[map.id] = true
		var down: Dictionary = Depths.stairs(map.id).get("down", {})
		if down.is_empty():
			# The bottom: the Seam Warden's lair and the ore cage behind him.
			assert_true(walked.has(Hunts.lair(Hunts.named(Depths.boss("shafts")))), "the Warden's lair is walked to")
			var door: Dictionary = Depths.shortcut_on(map.id)
			assert_true(STEPS.any(func(step: Vector2i) -> bool: return walked.has(door["cell"] + step)), "and the ore cage")
			break
		assert_true(STEPS.any(func(step: Vector2i) -> bool: return walked.has(down["cell"] + step)), "%s: its stair down is walked to" % map.id)
		var target: Dictionary = map.portals[down["cell"]]
		map = MapData.load_by_id(target["mapId"])
		at = Vector2i(int(target["x"]), int(target["y"]))
	assert_eq(reached.size(), 3, "all three floors")


func test_the_stairs_go_both_ways() -> void:
	for i in FLOORS.size() - 1:
		var upper := MapData.load_by_id(FLOORS[i])
		var lower := MapData.load_by_id(FLOORS[i + 1])
		var down: Dictionary = Depths.stairs(upper.id)["down"]
		var up: Dictionary = Depths.stairs(lower.id)["up"]
		assert_eq(upper.tile_at(down["cell"]), "stairwell", "%s: a stair down" % upper.id)
		assert_eq(lower.tile_at(up["cell"]), "cave", "%s: a stair up" % lower.id)
		assert_eq(upper.portals[down["cell"]], {"kind": "map", "mapId": lower.id, "x": up["arrive"].x, "y": up["arrive"].y}, "down lands beside the stair up")
		assert_eq(lower.portals[up["cell"]], {"kind": "map", "mapId": upper.id, "x": down["arrive"].x, "y": down["arrive"].y}, "up lands beside the stair down")
		assert_true(Ways.open_ground(upper, down["arrive"]), "%s: its landing is open ground" % upper.id)
		assert_true(Ways.open_ground(lower, up["arrive"]), "%s: its landing is open ground" % lower.id)
		assert_eq(Ways.kind_of(upper, down["cell"]), "down", "the way down asks first")
		assert_eq(Ways.kind_of(lower, up["cell"]), "stairs")
		assert_true(Ways.goes_under(upper, lower), "going down keeps its brief dark")
		assert_false(Ways.goes_under(lower, upper), "coming up dissolves")
		assert_eq(Ways.depth(lower), Ways.depth(upper) + 1)
	assert_eq(Ways.depth(MapData.load_by_id("shafts_blackseam")), 3)
	# The way in from the valley still lands by the entrance.
	var valley := MapData.load_by_id("blackiron")
	var into: Array = valley.portals.values().filter(func(to: Dictionary) -> bool: return to.get("mapId", "") == "shafts")
	assert_eq(into.size(), 1)
	assert_lt(Vector2(Vector2i(int(into[0]["x"]), int(into[0]["y"])) - ENTRANCE).length(), 2.0)


func test_each_floor_is_harder_than_the_one_above() -> void:
	for i in range(1, FLOORS.size()):
		assert_gt(Depths.lift(FLOORS[i]), Depths.lift(FLOORS[i - 1]), "%s's foes stand higher" % FLOORS[i])
		assert_gt(Depths.foe_level(FLOORS[i]), Depths.foe_level(FLOORS[i - 1]), "%s's packs are stronger" % FLOORS[i])
	assert_eq(Depths.boss("shafts"), "seam_warden")
	assert_eq(Hunts.named("seam_warden")["mapId"], "shafts_blackseam", "the Seam Warden waits at the bottom")
	assert_gt(float(Hunts.named("seam_warden")["level"]), Depths.foe_level("shafts_blackseam"), "and stands above his floor")
	assert_eq(Hunts.living_on("shafts", [], []), [], "no Warden on the first floor any more")


func test_each_floor_has_something_to_find() -> void:
	for map_id: String in FLOORS:
		var entry := Depths.floor_of(map_id)
		var map := MapData.load_by_id(map_id)
		if entry.has("find"):
			var chest: Array = Interactables.chests_on(map_id).filter(func(found: Dictionary) -> bool: return found["id"] == entry["find"])
			assert_eq(chest.size(), 1, "%s: its find is a chest on it" % map_id)
			var cell := Vector2i(int(chest[0]["x"]), int(chest[0]["y"]))
			assert_true(map.is_walkable(cell), "%s: the chest stands on the floor" % map_id)
			var reached := _walked(map, map.spawn)
			assert_true(STEPS.any(func(step: Vector2i) -> bool: return reached.has(cell + step)), "%s: and can be opened" % map_id)
		else:
			assert_true(entry.has("boss"), "%s: its find is the boss's keepsake" % map_id)
	assert_eq(_chest("shafts_cheese")["loot"]["itemId"], "shaft_cheese", "Bram's cheese in the upper shafts")
	assert_string_contains(Catalog.item("shaft_cheese")["description"], "hums")
	assert_string_contains(state.spoils.open_chest(_chest("shafts_cheese"))["message"], "It hums", "and says so as it's found")
	assert_eq(_chest("shafts_canary")["loot"]["itemId"], "canary", "Pell's canary in the west gallery")
	assert_eq(Depths.find_cell("shafts_gallery"), Vector2i(int(_chest("shafts_canary")["x"]), int(_chest("shafts_canary")["y"])))
	assert_eq(Hunts.named("seam_warden")["drop"], "black_ingot", "and the ingot under the Warden")
	# The old seam's gold went down with the seam, to the miners' store.
	var seam := _chest("shafts_seam")
	assert_eq(seam["mapId"], "shafts_blackseam")
	assert_true(_walked(MapData.load_by_id("shafts_blackseam"), Vector2i(4, 18)).has(Vector2i(int(seam["x"]), int(seam["y"]))))


func test_the_canary_shouts_from_the_rubble_of_the_west_gallery() -> void:
	var map := MapData.load_by_id("shafts_gallery")
	var piece: Array = map.grid.keys().filter(func(cell: Vector2i) -> bool: return map.grid[cell] == "wreck")
	assert_gt(piece.size(), 5, "rails, rocks and a lever")
	var last: Rect2i = Depths.plan("shafts_gallery")["rooms"][-1]
	for cell: Vector2i in piece:
		assert_true(map.pieces.has(cell), "each drawn on the dungeon sheet")
		assert_string_contains(String(map.notes[cell]), "shouting", "and E on it hears her")
		assert_true(last.has_point(cell), "in the last room, by the way down")
	assert_has(map.pieces.values(), PunyDungeon.LEVER)
	var opened: Dictionary = state.spoils.open_chest(_chest("shafts_canary"))
	assert_true(opened["opened"])
	assert_string_contains(opened["message"], "shouts", "she has a few words for her rescuer")
	assert_eq(int(state.pack.items.get("canary", 0)), 1)


func test_the_gallery_is_the_same_every_visit() -> void:
	var first := Depths.generate("shafts_gallery")
	var again := Depths.generate("shafts_gallery")
	assert_eq(first.grid, again.grid)
	assert_eq(first.pieces, again.pieces)
	assert_eq(first.style, "cave")
	var spawns := Bestiary.spawns_on("shafts_gallery")
	assert_eq(spawns.size(), Depths.floor_of("shafts_gallery")["plan"]["packs"].size(), "a pack a room")
	for spawn: Dictionary in spawns:
		assert_eq(first.region_at(Vector2i(int(spawn["x"]), int(spawn["y"]))), "shafts", "%s lives in the shafts' region" % spawn["id"])


func test_the_ore_cage_runs_up_to_the_pithead_once_the_warden_is_down() -> void:
	var seam := MapData.load_by_id("shafts_blackseam")
	var door: Dictionary = Depths.shortcut_on("shafts_blackseam")
	var cell: Vector2i = door["cell"]
	assert_eq(door["look"], "cage")
	assert_eq(seam.tile_at(cell), "sealed", "shut while he lives")
	assert_eq(seam.pieces[cell], PunyDungeon.CAGE, "the cage's barred gate")
	assert_false(seam.portals.has(cell))
	assert_false(Depths.open_shortcut(seam, ["tidecaller"]), "another dungeon's boss opens nothing here")
	assert_true(Depths.open_shortcut(seam, ["seam_warden"]))
	assert_true(seam.is_walkable(cell), "open once he's down")
	assert_eq(seam.portals[cell], door["to"])
	assert_eq(seam.pieces[cell], PunyDungeon.DOORWAY)
	assert_eq(seam.tile_at(cell + Vector2i(-1, 1)), "winch", "its winch beside it")
	assert_true(Ways.open_ground(seam, cell + Vector2i.DOWN), "walked into from the hall")
	# Up to the pithead by the shafts' mouth: the dungeon's way in.
	var to: Dictionary = door["to"]
	var valley := MapData.load_by_id(String(to["mapId"]))
	var landing := Vector2i(int(to["x"]), int(to["y"]))
	assert_true(Ways.open_ground(valley, landing), "it lands on open ground")
	var mouth := Vector2i(-1, -1)
	for portal: Vector2i in valley.portals:
		if valley.portals[portal].get("mapId", "") == "shafts":
			mouth = portal
	assert_lt(Vector2(landing - mouth).length(), 3.0, "beside the shafts' mouth: the entrance")
	assert_true(_walked(valley, landing).has(mouth + Vector2i.DOWN), "and walks straight back to it")
	assert_eq(Depths.shortcut_on("shafts"), {}, "only at the bottom")
	assert_eq(Depths.shortcut_on("seacave_grotto")["look"], "gate", "the sea cave's tide door is a gate still")


func test_the_next_line_reads_the_plans_through_chapter_three() -> void:
	_chapter_two_done()
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Cross the river and deliver Maren's letter to Old Pell at Blackiron")
	state.questing.deliver("mines_pell")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Fetch the last ingot from the Black Seam")
	var lead := Bearing.main(state.progression, state.settlement, state.pack.items, state.world.discovered)
	assert_eq([lead["map_id"], lead["cell"]], ["shafts_blackseam", Hunts.lair(Hunts.named("seam_warden"))], "to the Seam Warden, three floors down")
	# The arrow on each floor points at the way on down.
	assert_eq(Bearing.way_out("shafts", "shafts_blackseam"), Depths.stairs("shafts")["down"]["cell"])
	assert_eq(Bearing.way_out("shafts_gallery", "shafts_blackseam"), Depths.stairs("shafts_gallery")["down"]["cell"])
	assert_false(Gates.opened(Gates.by_id("barricade"), state.progression, state.settlement), "Ulla's barricade waits on the ingot")
	_win("seam_warden")
	assert_true(Gates.opened(Gates.by_id("barricade"), state.progression, state.settlement), "and opens on it: Pell has written ahead")
	assert_eq(int(state.pack.items.get("black_ingot", 0)), 1)
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["id"], "lamps", "then the Village's lamps, on the way to Greyhold")
	assert_eq(Letters.satchel(state.progression)[1], {"quest": Quests.by_id("letter_pell"), "delivered": true})


# ---- Old saves ----------------------------------------------------------------------

func test_a_save_anywhere_in_the_shafts_wakes_at_their_entrance() -> void:
	assert_eq(Depths.waking("blackiron", Vector2i(20, 20)), {"mapId": "blackiron", "cell": Vector2i(20, 20)})
	# Where the Seam Warden used to sit in the old one-floor shafts, or on any floor.
	for map_id: String in FLOORS:
		assert_eq(Depths.waking(map_id, Vector2i(38, 7)), {"mapId": "shafts", "cell": ENTRANCE}, map_id)
	assert_true(Ways.open_ground(MapData.load_by_id("shafts"), ENTRANCE))


func test_a_save_from_inside_the_shafts_round_trips_without_a_new_field() -> void:
	var before: Array = state.to_dict().keys()
	state.world.map_id = "shafts_gallery"
	state.world.cell = Vector2i(10, 9)
	Discovery.discover_around(state.world.discovered, MapData.load_by_id("shafts_gallery"), Vector2i(10, 9))
	state.world.opened_chests.append("shafts_canary")
	var saved: Dictionary = state.to_dict()
	assert_eq(saved.keys(), before, "no new field")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(saved))["state"])
	assert_true(Discovery.is_discovered(reloaded.world.discovered, "shafts_gallery", Vector2i(10, 9)), "each floor keeps its own fog")
	assert_true(reloaded.spoils.is_opened(_chest("shafts_canary")), "the canary's cage stays opened, by its id")


func test_a_hero_who_won_the_ingot_is_not_asked_to_fight_again() -> void:
	# An old save from before the letters: the ingot won, no letter carried.
	state.progression.hunted.append("seam_warden")
	state.pack.add_item("black_ingot")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_eq(Hunts.living_on("shafts_blackseam", [], reloaded.progression.hunted).size(), 0, "no Warden in the Black Seam")
	assert_eq(int(reloaded.pack.items.get("black_ingot", 0)), 1, "the ingot kept")
	assert_true(Depths.shortcut_open("shafts_blackseam", reloaded.progression.hunted), "the ore cage open")
	assert_true(MainQuest.is_met(MainQuest.step("ingot"), reloaded.progression, reloaded.settlement))
	assert_true(reloaded.holdings.is_settled("mines_pell"), "and Pell home above the forge")
	assert_true(reloaded.reveals.is_empty(), "found home as the save loads, no tour")


func test_a_save_with_pells_letter_still_to_deliver_brings_him_home_on_delivery() -> void:
	state.questing.finish_dialogue("elder")
	state.progression.hunted.append("seam_warden")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_false(reloaded.holdings.is_settled("mines_pell"), "he waits for his letter")
	assert_eq(Npcs.by_id("mines_pell", reloaded.settlement.settlers)["mapId"], "blackiron")
	assert_string_contains(reloaded.questing.deliver("mines_pell"), "Pixelheim")
	assert_true(reloaded.holdings.is_settled("mines_pell"))


func test_the_late_web_save_loads_and_plays() -> void:
	var late := SaveCodec.decode_code(FileAccess.get_file_as_string("res://test/fixtures/web_save_late.txt"))
	state.apply(late.duplicate(true))
	assert_eq(state.hero.hero_name, "Hrafna")
	var woke := Depths.waking(state.world.map_id, state.world.cell)
	assert_true(MapData.load_by_id(woke["mapId"]).is_walkable(woke["cell"]), "it wakes on open ground")
	for map_id: String in FLOORS:
		assert_gt(MapData.load_by_id(map_id).size.x, 0, "%s loads for it" % map_id)
	if "seam_warden" in state.progression.hunted:
		assert_true(state.holdings.is_settled("mines_pell"), "the ingot won: Pell is home")
	assert_eq(state.town_tier(), int(late["townTier"]), "and its town keeps its age")
	assert_eq(state.to_dict().keys(), late.keys(), "its fields, no more")


# ---- Old Pell comes home ------------------------------------------------------------

func test_pell_comes_home_once_his_letter_is_delivered_and_the_ingot_won() -> void:
	state.questing.finish_dialogue("elder")
	_win("seam_warden")
	assert_false(state.holdings.is_settled("mines_pell"), "he waits for his letter")
	var said: String = state.questing.deliver("mines_pell")
	assert_string_contains(said, "canary", "packing, canary and all")
	assert_true(state.holdings.is_settled("mines_pell"))
	assert_has(state.reveals, "settler:mines_pell", "the town's tour stops at the forge")
	var home := Npcs.by_id("mines_pell", state.settlement.settlers)
	assert_eq(home["mapId"], "town_smith", "above Hilda's forge")
	assert_false(_ids(Npcs.on_map("blackiron", 1, state.settlement.settlers)).has("mines_pell"), "gone from Blackiron")
	assert_true(_ids(Npcs.on_map("town_smith", 1, state.settlement.settlers, ["hildas_forge"])).has("mines_pell"))
	assert_true(MapData.load_by_id("town_smith").is_walkable(Vector2i(int(home["x"]), int(home["y"]))))
	var stop: Dictionary = Town.recruit("mines_pell")["homecoming"]
	assert_eq(stop["detail"], "The canary and the cat have reached an understanding. The understanding is shouting.")


func test_pell_comes_home_with_the_ingot_when_his_letter_went_first() -> void:
	state.questing.finish_dialogue("elder")
	state.questing.deliver("mines_pell")
	assert_false(state.holdings.is_settled("mines_pell"), "not without the ingot")
	var won: Dictionary = state.spoils.defeat_monster(Hunts.fighter("seam_warden"), "shafts_blackseam", "", 9)
	assert_true(state.holdings.is_settled("mines_pell"))
	assert_true((won["lines"] as Array).any(func(line: String) -> bool: return "Pell" in line), "the log says so")


func test_while_the_forge_is_ash_pell_waits_by_hildas_stall() -> void:
	state.progression.hunted.append("seam_warden")
	state.holdings.come_home(true)
	var square := Npcs.on_map("town", 0, state.settlement.settlers, []).filter(func(npc: Dictionary) -> bool: return npc["id"] == "mines_pell")
	assert_eq(square.size(), 1, "on the square")
	assert_true(MapData.load_tiered("town", [], 1).is_walkable(Vector2i(int(square[0]["x"]), int(square[0]["y"]))))
	assert_false(_ids(Npcs.on_map("town_smith", 0, state.settlement.settlers, [])).has("mines_pell"))


func test_pell_at_the_bellows_makes_hildas_work_cheaper() -> void:
	state.settlement.projects.append("hildas_forge")
	var blade := InventoryState.create_gear("iron_sword")
	var alone: int = state.trade.forge_price(blade, 1, false)
	state.progression.hunted.append("seam_warden")
	state.holdings.come_home(true)
	var with_pell: int = state.trade.forge_price(blade, 1, false)
	assert_lt(with_pell, alone, "a tenth less again")
	assert_has(Town.settler_perks(state.settlement.settlers, state.progression.quests), Town.recruit("mines_pell")["perk"], "the hall lists it")


func test_the_canarys_clock_stops_once_pell_lives_in_town() -> void:
	state.progression.quests["pell_canary"] = {"progress": 0, "done": false}
	state.pack.add_item("canary")
	state.questing.tick_runs(0.1)
	assert_false(state.questing.timed_run().is_empty(), "a race to Blackiron")
	state.progression.hunted.append("seam_warden")
	state.holdings.come_home(true)
	assert_eq(state.questing.tick_runs(500.0)["message"], "", "no racing her across the Reach to town")
	assert_eq(int(state.pack.items.get("canary", 0)), 1, "she stays in the pack")
	assert_true(state.questing.timed_run().is_empty())
	state.questing.resolve_quests("mines_pell")
	assert_true(state.progression.quests["pell_canary"]["done"], "and Pell takes her at the forge")


func test_pells_homecoming_adds_no_field_to_the_save() -> void:
	state.progression.hunted.append("seam_warden")
	var before: Array = state.to_dict().keys()
	state.holdings.come_home()
	var after: Dictionary = state.to_dict()
	assert_eq(after.keys(), before)
	assert_has(after["settlers"], "mines_pell", "a settler, as the others are")


# ---- The Village's beat, and the second dream -----------------------------------

func test_the_village_opens_as_pell_comes_home() -> void:
	_chapter_two_done()
	assert_true(state.holdings.is_settled("saltmere_wenna"), "Wenna is home: a settler")
	assert_false(Town.age_blockers(2, state.progression, state.settlement).is_empty(), "one keepsake isn't two: no Village before chapter three")
	assert_false(state.reveals.has("opens:2"))
	state.questing.deliver("mines_pell")
	_win("seam_warden")
	assert_eq(Town.age_blockers(2, state.progression, state.settlement), [] as Array[String], "two keepsakes home and a settler")
	assert_eq(state.reveals.slice(-2), ["settler:mines_pell", "opens:2"], "Pell's door, then the board")
	assert_has(Town.age(2), "opens")
	assert_eq(state.town_tier(), 1, "the board raises the Village, as ever")
	state.pack.gold = 5000
	state.pack.add_item("marsh_reed", 20)
	state.pack.add_item("wolf_pelt", 20)
	for project: Dictionary in Town.age(2)["projects"]:
		assert_ne(state.holdings.fund_project(project["id"]), "", project["id"])
	assert_eq(state.town_tier(), 2, "lamps, stalls and newcomers: a Village")
	assert_has(state.reveals, "age:2")


func test_the_village_beat_waits_for_the_hamlet_and_never_repeats() -> void:
	_chapter_two_done()
	state.settlement.projects.assign(["river_bridge"])
	state.questing.deliver("mines_pell")
	_win("seam_warden")
	assert_false(state.reveals.has("opens:2"), "the Hamlet first")
	state.reveals.clear()
	state.settlement.projects.assign(Town.projects_through(1).slice(0, -1))
	state.pack.gold = 5000
	state.pack.add_item("marsh_reed", 20)
	state.holdings.fund_project(Town.projects_through(1)[-1])
	assert_eq(state.reveals.slice(-2), ["age:1", "opens:2"], "the Hamlet done, the Village stands open")
	# A town already building its Village hears nothing of it again.
	state.reveals.clear()
	state.settlement.projects.append("street_lamps")
	state.holdings.note_age_open()
	assert_false(state.reveals.has("opens:2"))


func test_an_older_villages_age_is_kept() -> void:
	state.settlement.projects.assign(Town.projects_through(2))
	state.settlement.town_tier = 2
	state.progression.hunted.append_array(["tidecaller", "seam_warden"])
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_eq(reloaded.town_tier(), 2)
	assert_true(reloaded.holdings.is_settled("mines_pell"))
	assert_false(reloaded.reveals.has("opens:2"), "no beat for a Village already built")
	assert_eq(Town.current_age(reloaded.settlement), 3)


func test_the_second_dream_comes_the_first_night_after_pell_is_home() -> void:
	assert_eq(Story.next_dream([], ["dream_courier"], []), "", "nothing yet")
	assert_eq(Story.next_dream([], ["dream_courier"], ["mines_pell"]), "dream_lamps", "the old man counting lamps")
	assert_eq(Story.next_dream([], [], ["mines_pell"]), "dream_courier", "the first night's dream first")
	assert_eq(Story.next_dream([1, 2, 3], ["dream_courier"], ["mines_pell"]), "dream_lamps", "before the old climb's")
	assert_eq(Story.next_dream([], ["dream_courier", "dream_lamps"], ["mines_pell"]), "", "once")
	var said := []
	for step: Dictionary in Cutscene.scenes()["dream_lamps"]:
		if step["kind"] == "caption":
			said.append(step["text"])
	assert_has(said, "\"Thirty-one. They've a new one by the bridge. Crooked.\"")
	assert_false(Cutscene.scenes()["dream_lamps"].any(func(step: Dictionary) -> bool: return step["kind"] == "eyes"), "no eyes in the dark")


# ---- Helpers ------------------------------------------------------------------------

## A hero at the start of chapter three: the letters out, Wenna's delivered,
## Tam's ladle won (Wenna home), the Hamlet built and the river bridge
## mended.
func _chapter_two_done() -> void:
	state.questing.finish_dialogue("elder")
	state.settlement.town_tier = 1
	state.settlement.projects.assign(Town.projects_through(1) + ["river_bridge"])
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	state.questing.deliver("saltmere_wenna")
	_win("tidecaller")
	state.reveals.clear()


func _win(named_id: String) -> void:
	state.spoils.defeat_monster(Hunts.fighter(named_id), Hunts.named(named_id)["mapId"], "", 10)


func _chest(chest_id: String) -> Dictionary:
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest["id"] == chest_id:
			return chest
	return {}


func _ids(npcs: Array) -> Array:
	return npcs.map(func(npc: Dictionary) -> String: return npc["id"])


## Every cell a walk from `from` reaches on open ground, through no way on.
func _walked(map: MapData, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		for step: Vector2i in STEPS:
			var next := here + step
			if not seen.has(next) and Ways.open_ground(map, next):
				seen[next] = true
				queue.append(next)
	return seen
