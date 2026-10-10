extends GutTest
## The Letter to the Frostgate (PIX-255, PIX-253 step 7): the ice cave in
## three floors from the data - the frosted galleries with Gunnar's
## strongbox, the frozen lake with somebody's boots in its edge, the glass
## hall where Rimefang sleeps on Liane's lantern - every one reached from the
## entrance down the stairs and back up them, each harder than the one
## above, and the ice slide down to the foot of Liane's stair once Rimefang
## is down; Liane's sums in the Next line; old saves at each stage; Aske
## coming home as Pixelheim's lamplighter, the Town's beat as he does, and
## the third dream.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const FLOORS := ["icecave", "icecave_lake", "icecave_glass"]
const ENTRANCE := Vector2i(4, 25)
## The light rig, for how far the hero's lantern reaches.
const RIG := preload("res://scripts/light_rig.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


# ---- The floors ---------------------------------------------------------------------

func test_the_ice_cave_is_three_floors_top_down() -> void:
	assert_eq(Depths.floors("icecave").map(func(entry: Dictionary) -> String: return entry["mapId"]), FLOORS)
	for i in FLOORS.size():
		assert_eq(Depths.number(FLOORS[i]), i + 1)
		assert_eq(Depths.root(FLOORS[i]), "icecave", "a floor goes by its dungeon's first in the tables")
		assert_false(Depths.is_planned(FLOORS[i]), "%s is drawn by hand" % FLOORS[i])
	assert_eq(Depths.number("observatory"), 0, "Liane's room is no floor")
	assert_eq(Catalog.place_name("icecave_lake"), "The Frozen Lake")
	assert_eq(Catalog.place_name("icecave_glass"), "The Glass Hall")
	assert_has(Atlas.ORDER, "icecave_glass", "each floor a page of the map")


func test_every_floor_is_reached_from_the_entrance_down_the_stairs() -> void:
	var map := MapData.load_by_id("icecave")
	var at: Vector2i = Depths.waking("icecave", Vector2i.ZERO)["cell"]
	assert_eq(at, ENTRANCE, "the entrance, at the foot of Liane's stair")
	var reached := {}
	for depth in FLOORS.size():
		assert_eq(map.id, FLOORS[depth])
		var walked := _walked(map, at)
		reached[map.id] = true
		var down: Dictionary = Depths.stairs(map.id).get("down", {})
		if down.is_empty():
			# The bottom: Rimefang's lair and the ice slide behind it.
			assert_true(walked.has(Hunts.lair(Hunts.named(Depths.boss("icecave")))), "Rimefang's lair is walked to")
			var door: Dictionary = Depths.shortcut_on(map.id)
			assert_true(STEPS.any(func(step: Vector2i) -> bool: return walked.has(door["cell"] + step)), "and the ice slide")
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
	assert_eq(Ways.depth(MapData.load_by_id("icecave_glass")), 3)
	# The way in from Liane's room still lands at the entrance, and the
	# first floor's stair up still leads back into her room.
	var room := MapData.load_by_id("observatory")
	var into: Array = room.portals.values().filter(func(to: Dictionary) -> bool: return to.get("mapId", "") == "icecave")
	assert_eq(into.size(), 1)
	assert_lt(Vector2(Vector2i(int(into[0]["x"]), int(into[0]["y"])) - ENTRANCE).length(), 2.0)
	assert_eq(Ways.below("observatory"), "icecave")


func test_each_floor_is_harder_than_the_one_above() -> void:
	for i in range(1, FLOORS.size()):
		assert_gt(Depths.lift(FLOORS[i]), Depths.lift(FLOORS[i - 1]), "%s's foes stand higher" % FLOORS[i])
		assert_gt(Depths.foe_level(FLOORS[i]), Depths.foe_level(FLOORS[i - 1]), "%s's packs are stronger" % FLOORS[i])
	assert_eq(Depths.boss("icecave"), "rimefang")
	assert_eq(Hunts.named("rimefang")["mapId"], "icecave_glass", "Rimefang sleeps at the bottom")
	assert_gt(float(Hunts.named("rimefang")["level"]), Depths.foe_level("icecave_glass"), "and stands above its floor")
	assert_eq(Hunts.living_on("icecave", [], []), [], "no Rimefang on the first floor any more")


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
	assert_eq(_chest("icecave_strongbox")["loot"]["itemId"], "caravan_strongbox", "Gunnar's strongbox in the frosted galleries")
	assert_string_contains(state.spoils.open_chest(_chest("icecave_strongbox"))["message"], "Gunnar's strongbox", "and it says so as it's found")
	var boots := _chest("icecave_boots")
	assert_eq(boots["mapId"], "icecave_lake")
	assert_eq(boots["loot"], {"kind": "gear", "itemId": "frost_boots"}, "somebody's boots in the frozen lake's edge")
	var opened: Dictionary = state.spoils.open_chest(boots)
	assert_string_contains(opened["message"], "barefoot")
	assert_eq(Hunts.named("rimefang")["drop"], "lianes_lantern", "and Liane's lantern under Rimefang")
	assert_string_contains(Hunts.named("rimefang")["seen"], "It was only ever cold.")


func test_the_lake_is_frozen_hard_enough_to_walk_on() -> void:
	var lake := MapData.load_by_id("icecave_lake")
	var ice: Array = lake.grid.keys().filter(func(cell: Vector2i) -> bool: return lake.grid[cell] == "ice")
	assert_gt(ice.size(), 150, "a lake, not a puddle")
	var walked := _walked(lake, lake.spawn)
	for cell: Vector2i in ice:
		assert_true(lake.is_walkable(cell), "%s: frozen hard" % cell)
		assert_true(walked.has(cell), "%s: walked onto from the shore" % cell)
		assert_eq(lake.region_at(cell), "icecave")
	# The ice keeps off the walls (the frost MapView draws round it stays
	# on the stone), and so it does in the glass hall.
	for map_id: String in ["icecave_lake", "icecave_glass"]:
		var map := MapData.load_by_id(map_id)
		for cell: Vector2i in map.grid:
			if map.grid[cell] != "ice":
				continue
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var tile := map.tile_at(cell + Vector2i(dx, dy))
					if tile in ["wall", "lamp"]:
						assert_true(map_id == "icecave_glass" and _a_column(map, cell + Vector2i(dx, dy)), "%s %s: ice against a wall" % [map_id, cell])
	var glass := MapData.load_by_id("icecave_glass")
	assert_eq(glass.tile_at(Hunts.lair(Hunts.named("rimefang"))), "ice", "Rimefang sleeps on the glass hall's ice")
	assert_eq(Hunts.living_on("icecave_lake", [], []), [], "nothing named on the lake")


func test_the_ice_slide_runs_down_to_lianes_stair_once_rimefang_is_down() -> void:
	var glass := MapData.load_by_id("icecave_glass")
	var door: Dictionary = Depths.shortcut_on("icecave_glass")
	var cell: Vector2i = door["cell"]
	assert_eq(door["look"], "slide")
	assert_eq(glass.tile_at(cell), "sealed", "plugged while it lives")
	assert_eq(glass.pieces[cell], PunyDungeon.DOORS["slide"][0], "with a boulder of ice")
	assert_false(glass.portals.has(cell))
	assert_false(Depths.open_shortcut(glass, ["seam_warden"]), "another dungeon's boss opens nothing here")
	assert_true(Depths.open_shortcut(glass, ["rimefang"]))
	assert_true(glass.is_walkable(cell), "open once it's down")
	assert_eq(glass.portals[cell], door["to"])
	assert_eq(glass.pieces[cell], PunyDungeon.STAIRS_DOWN, "a run of ice down into the dark")
	assert_true(Ways.open_ground(glass, cell + Vector2i.DOWN), "walked into from the hall")
	# Down to the foot of Liane's stair: the dungeon's way in.
	var to: Dictionary = door["to"]
	assert_eq(to["mapId"], "icecave")
	var cave := MapData.load_by_id("icecave")
	var landing := Vector2i(int(to["x"]), int(to["y"]))
	assert_true(Ways.open_ground(cave, landing), "it lands on open ground")
	var stair := Vector2i(-1, -1)
	for portal: Vector2i in cave.portals:
		if cave.portals[portal].get("mapId", "") == "observatory":
			stair = portal
	assert_lt(Vector2(landing - stair).length(), 3.0, "beside the stair up to Liane's room: the entrance")
	assert_true(_walked(cave, landing).has(ENTRANCE), "and walks straight to it")
	assert_eq(Depths.shortcut_on("icecave"), {}, "only at the bottom")
	assert_eq(Depths.shortcut_on("shafts_blackseam")["look"], "cage", "the shafts' ore cage is a cage still")


func test_the_next_line_reads_the_plans_through_chapter_five() -> void:
	_chapter_four_done()
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Deliver Maren's letter to Aske at Liane's observatory")
	var lead := Bearing.main(state.progression, state.settlement, state.pack.items, state.world.discovered)
	assert_eq([lead["who"], lead["map_id"]], ["frost_aske", "frostgate"], "to Aske")
	var door := Vector2i(27, 6)
	assert_lt(Vector2(lead["cell"] - door).length(), 3.0, "who keeps Liane's door")
	assert_string_contains(state.questing.deliver("frost_aske"), "The Letter to the Frostgate")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Read Liane's sums in her room")
	lead = Bearing.main(state.progression, state.settlement, state.pack.items, state.world.discovered)
	assert_eq(lead["map_id"], "observatory", "to her room")
	assert_true(Letters.reading_rect(Letters.reading("liane_sums")).has_point(lead["cell"]), "and her desk")
	state.mark_seen("liane_sums")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Bring Liane's lantern up from the glass hall")
	lead = Bearing.main(state.progression, state.settlement, state.pack.items, state.world.discovered)
	assert_eq([lead["map_id"], lead["cell"]], ["icecave_glass", Hunts.lair(Hunts.named("rimefang"))], "to Rimefang, three floors down")
	# The arrow on each floor points at the way on down.
	assert_eq(Bearing.way_out("icecave", "icecave_glass"), Depths.stairs("icecave")["down"]["cell"])
	assert_eq(Bearing.way_out("icecave_lake", "icecave_glass"), Depths.stairs("icecave_lake")["down"]["cell"])
	_win("rimefang")
	assert_eq(int(state.pack.items.get("lianes_lantern", 0)), 1)
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Bring the four keepsakes home to Maren")
	assert_eq(Letters.satchel(state.progression)[3], {"quest": Quests.by_id("letter_aske"), "delivered": true})


func test_a_hero_past_the_lantern_is_never_sent_back_to_the_sums() -> void:
	_chapter_four_done()
	state.questing.deliver("frost_aske")
	_win("rimefang")
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["id"], "gate", "the lantern won first: on to Maren")
	assert_false(MainQuest.is_met(MainQuest.step("sums"), state.progression, state.settlement), "the sums still there to read")


func test_lianes_sums_lie_on_her_desk() -> void:
	var sums := Letters.reading("liane_sums")
	assert_false(sums.is_empty())
	assert_eq(sums["quest"]["id"], "letter_aske", "the answer to Maren's letter to Aske")
	assert_eq(sums["mapId"], "observatory", "in her room")
	var room := MapData.load_by_id("observatory")
	var stand := 0
	var rect := Letters.reading_rect(sums)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			assert_eq(Letters.reading_at("observatory", Vector2i(x, y)), sums, "E on any of the desk's cells")
			for step: Vector2i in STEPS:
				if room.is_walkable(Vector2i(x, y) + step) and not rect.has_point(Vector2i(x, y) + step):
					stand += 1
	assert_gt(stand, 0, "and a hero can stand at it")
	assert_true(Letters.reading_at("observatory", Depths.stairs("icecave").get("up", {}).get("cell", Vector2i(13, 5))).is_empty(), "not at the stairwell")
	assert_eq(sums["lines"].slice(1), [
		"\"The seal only buys time. Fifty years, at most.\"",
		"\"A thing chained a hundred years will burn anything. Don't seal him. Free him. The collar answers to our five marks.\"",
	], "the plan's words")


func test_the_sums_stay_shut_until_the_letter_is_delivered_and_are_read_once() -> void:
	var sums := Letters.reading("liane_sums")
	state.questing.finish_dialogue("elder")
	assert_eq(Letters.reading_lines(sums, state.progression), [sums["shut"]], "Aske keeps her room")
	assert_false(Letters.reads_now(sums, state.progression))
	state.questing.deliver("frost_aske")
	assert_true(Letters.reads_now(sums, state.progression), "Aske opens her door")
	assert_eq(Letters.reading_lines(sums, state.progression), sums["lines"])
	state.mark_seen("liane_sums")
	assert_false(Letters.reads_now(sums, state.progression))
	assert_eq(Letters.reading_lines(sums, state.progression), [sums["again"]], "a short word after")


func test_askes_answer_opens_lianes_door() -> void:
	var quest := Quests.by_id("letter_aske")
	assert_eq(quest["answer"][0], "She told me to keep her door shut till someone came for the lantern. Fifty years. You took your time.")
	assert_string_contains(quest["gist"], "Free him.")
	assert_eq(Npcs.by_id("frost_aske", [])["mapId"], "frostgate", "he waits at the observatory")
	var at := Vector2i(int(Npcs.by_id("frost_aske", [])["x"]), int(Npcs.by_id("frost_aske", [])["y"]))
	assert_true(MapData.load_by_id("frostgate").is_walkable(at))
	assert_eq(Quests.for_giver("frost_aske").map(func(entry: Dictionary) -> String: return entry["id"]), ["aske_wolves", "aske_rimefang"], "his errands as before")


# ---- Old saves ----------------------------------------------------------------------

func test_a_save_anywhere_in_the_ice_cave_wakes_at_its_entrance() -> void:
	assert_eq(Depths.waking("frostgate", Vector2i(20, 20)), {"mapId": "frostgate", "cell": Vector2i(20, 20)})
	assert_eq(Depths.waking("observatory", Vector2i(8, 8)), {"mapId": "observatory", "cell": Vector2i(8, 8)}, "Liane's room is no floor")
	# Where Rimefang used to sleep in the old one-floor cave, or on any floor.
	for map_id: String in FLOORS:
		assert_eq(Depths.waking(map_id, Vector2i(38, 7)), {"mapId": "icecave", "cell": ENTRANCE}, map_id)
	assert_true(Ways.open_ground(MapData.load_by_id("icecave"), ENTRANCE))


func test_a_save_from_inside_the_ice_cave_round_trips_without_a_new_field() -> void:
	var before: Array = state.to_dict().keys()
	state.world.map_id = "icecave_lake"
	state.world.cell = Vector2i(30, 14)
	Discovery.discover_around(state.world.discovered, MapData.load_by_id("icecave_lake"), Vector2i(30, 14))
	state.world.opened_chests.append("icecave_boots")
	var saved: Dictionary = state.to_dict()
	assert_eq(saved.keys(), before, "no new field")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(saved))["state"])
	assert_true(Discovery.is_discovered(reloaded.world.discovered, "icecave_lake", Vector2i(30, 14)), "each floor keeps its own fog")
	assert_true(reloaded.spoils.is_opened(_chest("icecave_boots")), "the boots stay found, by their chest's id")


func test_a_hero_who_won_the_lantern_is_not_asked_to_fight_again() -> void:
	# An old save from before the letters: the lantern won, no letter carried.
	state.progression.hunted.append("rimefang")
	state.pack.add_item("lianes_lantern")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_eq(Hunts.living_on("icecave_glass", [], reloaded.progression.hunted).size(), 0, "no Rimefang in the glass hall")
	assert_eq(int(reloaded.pack.items.get("lianes_lantern", 0)), 1, "the lantern kept")
	assert_true(Depths.shortcut_open("icecave_glass", reloaded.progression.hunted), "the ice slide open")
	assert_true(MainQuest.is_met(MainQuest.step("lantern"), reloaded.progression, reloaded.settlement))
	assert_true(reloaded.holdings.is_settled("frost_aske"), "and Aske lighting Pixelheim's lamps")
	assert_true(reloaded.reveals.is_empty(), "found home as the save loads, no tour")


func test_a_save_with_askes_letter_still_to_deliver_brings_him_home_on_delivery() -> void:
	state.questing.finish_dialogue("elder")
	state.progression.hunted.append("rimefang")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_false(reloaded.holdings.is_settled("frost_aske"), "he waits for his letter")
	assert_eq(Npcs.by_id("frost_aske", reloaded.settlement.settlers)["mapId"], "frostgate")
	assert_string_contains(reloaded.questing.deliver("frost_aske"), "Pixelheim")
	assert_true(reloaded.holdings.is_settled("frost_aske"))


func test_the_late_web_save_loads_and_plays() -> void:
	var late := SaveCodec.decode_code(FileAccess.get_file_as_string("res://test/fixtures/web_save_late.txt"))
	state.apply(late.duplicate(true))
	assert_eq(state.hero.hero_name, "Hrafna")
	var woke := Depths.waking(state.world.map_id, state.world.cell)
	assert_true(MapData.load_by_id(woke["mapId"]).is_walkable(woke["cell"]), "it wakes on open ground")
	for map_id: String in FLOORS:
		assert_gt(MapData.load_by_id(map_id).size.x, 0, "%s loads for it" % map_id)
	if "rimefang" in state.progression.hunted:
		assert_true(state.holdings.is_settled("frost_aske"), "the lantern won: Aske is home")
	assert_eq(state.town_tier(), int(late["townTier"]), "and its town keeps its age")
	assert_eq(state.to_dict().keys(), late.keys(), "its fields, no more")


# ---- Aske comes home ----------------------------------------------------------------

func test_aske_comes_home_once_his_letter_is_delivered_and_the_lantern_won() -> void:
	state.questing.finish_dialogue("elder")
	_win("rimefang")
	assert_false(state.holdings.is_settled("frost_aske"), "he waits for his letter")
	var said: String = state.questing.deliver("frost_aske")
	assert_string_contains(said, "lamplighter", "packing for Pixelheim")
	assert_true(state.holdings.is_settled("frost_aske"))
	assert_has(state.reveals, "settler:frost_aske", "the town's tour stops on the square")
	var home := Npcs.by_id("frost_aske", state.settlement.settlers)
	assert_eq(home["mapId"], "town", "Pixelheim's lamplighter")
	assert_false(_ids(Npcs.on_map("frostgate", 1, state.settlement.settlers)).has("frost_aske"), "gone from the Frostgate")
	for tier in range(0, 5):
		var town := MapData.load_tiered("town", Town.projects_through(tier), tier)
		assert_true(town.is_walkable(Vector2i(int(home["x"]), int(home["y"]))), "on open ground in town at age %d" % tier)
	var board := Town.project_board()
	assert_gt(Vector2(Vector2i(int(home["x"]), int(home["y"])) - board).length(), 2.5, "clear of the board on the square")
	var stop: Dictionary = Town.recruit("frost_aske")["homecoming"]
	assert_eq(stop["detail"], "\"One lamp, fifty years. Forty lamps can't be harder.\"")


func test_aske_comes_home_with_the_lantern_when_his_letter_went_first() -> void:
	state.questing.finish_dialogue("elder")
	state.questing.deliver("frost_aske")
	assert_false(state.holdings.is_settled("frost_aske"), "not without the lantern")
	var won: Dictionary = state.spoils.defeat_monster(Hunts.fighter("rimefang"), "icecave_glass", "", 13)
	assert_true(state.holdings.is_settled("frost_aske"))
	assert_true((won["lines"] as Array).any(func(line: String) -> bool: return "Aske" in line), "the log says so")


func test_aske_keeps_the_couriers_lantern_trimmed() -> void:
	var untrimmed: float = RIG.lantern_reach(state.holdings.settler_share("lantern"))
	assert_eq(untrimmed, RIG.LANTERN_REACH, "untrimmed with no lamplighter home")
	state.progression.hunted.append("rimefang")
	state.holdings.come_home(true)
	assert_almost_eq(state.holdings.settler_share("lantern"), 0.33, 0.001)
	assert_gt(RIG.lantern_reach(state.holdings.settler_share("lantern")), untrimmed * 1.3, "a third further")
	assert_has(Town.settler_perks(state.settlement.settlers, state.progression.quests), Town.recruit("frost_aske")["perk"], "the hall lists it")
	assert_eq(state.holdings.settler_share("forge"), 0.0, "and nothing at Hilda's")


func test_askes_homecoming_adds_no_field_to_the_save() -> void:
	state.progression.hunted.append("rimefang")
	var before: Array = state.to_dict().keys()
	state.holdings.come_home()
	var after: Dictionary = state.to_dict()
	assert_eq(after.keys(), before)
	assert_has(after["settlers"], "frost_aske", "a settler, as the others are")


# ---- The Town's beat, and the third dream ---------------------------------------

func test_the_town_opens_as_aske_comes_home() -> void:
	_chapter_four_done()
	assert_false(Town.age_blockers(3, state.progression, state.settlement).is_empty(), "three keepsakes aren't four: no Town before chapter five")
	assert_false(state.reveals.has("opens:3"))
	state.questing.deliver("frost_aske")
	_win("rimefang")
	assert_eq(Town.age_blockers(3, state.progression, state.settlement), [] as Array[String], "four keepsakes home")
	assert_eq(state.reveals.slice(-2), ["settler:frost_aske", "opens:3"], "Aske on the square, then the board")
	assert_string_contains(Town.age(3)["opens"]["line"], "Town")
	assert_eq(state.town_tier(), 2, "the board raises the Town, as ever")
	# The fountain is dug, but it still wants Fafnyr's scale (chapter 7).
	state.pack.gold = 50000
	state.pack.add_item("deep_root", 20)
	state.pack.add_item("forest_herb", 20)
	assert_ne(state.holdings.fund_project("slate_hall"), "")
	assert_ne(state.holdings.fund_project("moss_cottage"), "")
	assert_string_contains(Town.project_blocker("fountain", state.progression, state.settlement, state.pack.gold, state.pack.items), Catalog.item_name("dragon_scale"))
	assert_eq(state.town_tier(), 2, "the Town finished only with the scale in its fountain")
	assert_has(Town.sites(Town.done_projects(state.settlement)).map(func(site: Dictionary) -> String: return site["project"]), "fountain", "its basin staked out on the square")


func test_the_town_beat_waits_for_the_village_and_never_repeats() -> void:
	_chapter_four_done()
	state.settlement.projects.assign(Town.projects_through(1) + ["river_bridge"])
	state.settlement.town_tier = 1
	state.questing.deliver("frost_aske")
	_win("rimefang")
	assert_false(state.reveals.has("opens:3"), "the Village first")
	state.reveals.clear()
	state.settlement.projects.assign(Town.projects_through(2).slice(0, -1) + ["river_bridge"])
	state.pack.gold = 50000
	state.pack.add_item("marsh_reed", 20)
	state.holdings.fund_project(Town.projects_through(2)[-1])
	assert_eq(state.reveals.slice(-2), ["age:2", "opens:3"], "the Village done, the Town stands open")
	# A town already building its Town hears nothing of it again.
	state.reveals.clear()
	state.settlement.projects.append("slate_hall")
	state.holdings.note_age_open()
	assert_false(state.reveals.has("opens:3"))


func test_an_older_towns_age_is_kept() -> void:
	state.settlement.projects.assign(Town.projects_through(3))
	state.settlement.town_tier = 3
	state.progression.hunted.append_array(["tidecaller", "seam_warden", "hollow_captain", "rimefang"])
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_eq(reloaded.town_tier(), 3)
	assert_true(reloaded.holdings.is_settled("frost_aske"))
	assert_false(reloaded.reveals.has("opens:3"), "no beat for a Town already built")
	assert_eq(Town.current_age(reloaded.settlement), 4)


func test_the_third_dream_comes_the_first_night_after_aske_is_home() -> void:
	var seen := ["dream_courier", "dream_lamps"]
	assert_eq(Story.next_dream([], seen, ["mines_pell"]), "", "nothing yet")
	assert_eq(Story.next_dream([], seen, ["mines_pell", "frost_aske"]), "dream_corners", "very large, very old")
	assert_eq(Story.next_dream([], ["dream_courier"], ["mines_pell", "frost_aske"]), "dream_lamps", "the old man counting lamps first")
	assert_eq(Story.next_dream([1, 2, 3], seen, ["mines_pell", "frost_aske"]), "dream_corners", "before the old climb's")
	assert_eq(Story.next_dream([], seen + ["dream_corners"], ["mines_pell", "frost_aske"]), "", "once")
	var said := []
	for step: Dictionary in Cutscene.scenes()["dream_corners"]:
		if step["kind"] == "caption":
			said.append(step["text"])
	assert_has(said, "You dream you are very large, very old, and lying on something with too many corners.")
	assert_has(said, "Someone promised to let you go.")
	assert_has(said, "Someone always promises.")
	assert_false(Cutscene.scenes()["dream_corners"].any(func(step: Dictionary) -> bool: return step["kind"] == "eyes"), "no eyes in the dark")


# ---- Helpers ------------------------------------------------------------------------

## A hero at the start of chapter five: the letters out, Wenna's, Pell's and
## Hale's delivered, the ladle, the ingot and the shield won, the Hamlet and
## the Village built and the river bridge mended.
func _chapter_four_done() -> void:
	state.questing.finish_dialogue("elder")
	state.settlement.town_tier = 2
	state.settlement.projects.assign(Town.projects_through(2) + ["river_bridge"])
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	state.questing.deliver("saltmere_wenna")
	_win("tidecaller")
	state.questing.deliver("mines_pell")
	_win("seam_warden")
	state.questing.deliver("greyhold_ulla")
	state.mark_seen("hale_order_book")
	_win("hollow_captain")
	state.reveals.clear()


func _win(named_id: String) -> void:
	state.spoils.defeat_monster(Hunts.fighter(named_id), Hunts.named(named_id)["mapId"], "", 13)


func _chest(chest_id: String) -> Dictionary:
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest["id"] == chest_id:
			return chest
	return {}


func _ids(npcs: Array) -> Array:
	return npcs.map(func(npc: Dictionary) -> String: return npc["id"])


## Whether a wall cell is a column standing in the glass hall's ice: walls
## all round it are few.
func _a_column(map: MapData, cell: Vector2i) -> bool:
	var walls := 0
	for step: Vector2i in STEPS:
		if map.tile_at(cell + step) in ["wall", "lamp"]:
			walls += 1
	return walls == 0


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
