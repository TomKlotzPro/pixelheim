extends GutTest
## A region's dungeon in floors (PIX-255, Tom: « Les donjons, ça serait bien
## sur plusieurs étages »): the sea cave's three floors from the data -
## every one reached from the entrance down the stairs and back up them,
## each harder than the one above, the Tidecaller at the bottom and the
## tide door straight out to the beach once he's down; the planned floor
## the same every visit; every planned floor laid as it was; old saves at
## each stage; and Old Wenna coming home to Sela's inn with Tam's stew.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const FLOORS := ["seacave", "seacave_galleries", "seacave_grotto"]

## The planned floors' rooms as DungeonFloor lays them: an md5 of each one's
## grid. The old mountain's numbered floors, which these rooms were first
## laid for, left play (PIX-257): taking them out of DungeonFloor must
## leave every region's planned floor, and the Kings' Vault's, as it is.
const PLANNED := {
	"seacave_galleries": "cebbf5ec86ef48009a6183b88211e116", "shafts_gallery": "e6a1f12228804dd0a8fe16ebb1ff48fe",
	"cellars_crypt": "a5a1b03ef43086e6f99c6e80d37691e9", "vault_1": "42a03c5a474ce811f3374337c58e92c9",
	"vault_2": "a59c21c41a8760be44b02bc092e0a4e9", "vault_3": "ca93ab6ce41cbb0823988811134b917a",
	"vault_4": "f96d02603fd978bf949e491028b7511a", "vault_5": "38d888593a2c33c1a7c401b12b9da177",
}

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


# ---- The floors ---------------------------------------------------------------------

func test_the_sea_cave_is_three_floors_top_down() -> void:
	assert_eq(Depths.floors("seacave").map(func(entry: Dictionary) -> String: return entry["mapId"]), FLOORS)
	for i in FLOORS.size():
		assert_eq(Depths.number(FLOORS[i]), i + 1)
		assert_eq(Depths.root(FLOORS[i]), "seacave", "a floor goes by its dungeon's first in the tables")
	assert_eq(Depths.number("saltmere"), 0)
	assert_eq(Depths.root("saltmere"), "saltmere")
	assert_true(Depths.is_planned("seacave_galleries"), "the drowned galleries are laid out from a seed")
	assert_false(Depths.is_planned("seacave"))
	assert_false(Depths.is_planned("seacave_grotto"))


func test_every_floor_is_reached_from_the_entrance_down_the_stairs() -> void:
	var reached := {}
	var map := MapData.load_by_id("seacave")
	var at: Vector2i = Depths.waking("seacave", Vector2i.ZERO)["cell"]
	assert_eq(at, Vector2i(5, 25), "the entrance, by the stair up to the beach")
	for depth in FLOORS.size():
		assert_eq(map.id, FLOORS[depth])
		var walked := _walked(map, at)
		reached[map.id] = true
		var down: Dictionary = Depths.stairs(map.id).get("down", {})
		if down.is_empty():
			# The bottom: the Tidecaller's lair and the tide door behind him.
			assert_true(walked.has(Hunts.lair(Hunts.named(Depths.boss("seacave")))), "the boss's lair is walked to")
			var door: Dictionary = Depths.shortcut_on(map.id)
			assert_true(STEPS.any(func(step: Vector2i) -> bool: return walked.has(door["cell"] + step)), "and the tide door")
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
	assert_eq(Ways.depth(MapData.load_by_id("seacave_grotto")), 3)


func test_each_floor_is_harder_than_the_one_above() -> void:
	for i in range(1, FLOORS.size()):
		assert_gt(Depths.lift(FLOORS[i]), Depths.lift(FLOORS[i - 1]), "%s's foes stand higher" % FLOORS[i])
		assert_gt(Depths.foe_level(FLOORS[i]), Depths.foe_level(FLOORS[i - 1]), "%s's packs are stronger" % FLOORS[i])
	assert_eq(Depths.boss("seacave"), "tidecaller")
	assert_eq(Hunts.named("tidecaller")["mapId"], "seacave_grotto", "the Tidecaller waits at the bottom")
	assert_gt(float(Hunts.named("tidecaller")["level"]), Depths.foe_level("seacave_grotto"), "and stands above his floor")


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
	assert_eq(Depths.floor_of("seacave")["find"], "seacave_rum", "Sela's rum in the smugglers' caves")
	var wreck := _chest("seacave_wreck")
	assert_eq(Depths.find_cell("seacave_galleries"), Vector2i(int(wreck["x"]), int(wreck["y"])), "the wreck's crate is the galleries' find")


func test_the_wreck_is_the_galleries_set_piece_and_says_whose_it_was() -> void:
	var map := MapData.load_by_id("seacave_galleries")
	var wreck: Array = map.grid.keys().filter(func(cell: Vector2i) -> bool: return map.grid[cell] == "wreck")
	assert_gt(wreck.size(), 6, "beams, a mast, a wheel")
	var last: Rect2i = Depths.plan("seacave_galleries")["rooms"][-1]
	for cell: Vector2i in wreck:
		assert_true(map.pieces.has(cell), "each drawn on the dungeon sheet")
		assert_string_contains(String(map.notes[cell]), "Tam", "and E on it says whose it was")
		assert_true(last.has_point(cell), "in the last room, by the way down")
	assert_false(WorldTiles.is_walkable("wreck"))


func test_the_shortcut_opens_onto_the_beach_once_the_tidecaller_is_down() -> void:
	var grotto := MapData.load_by_id("seacave_grotto")
	var door: Dictionary = Depths.shortcut_on("seacave_grotto")
	var cell: Vector2i = door["cell"]
	assert_eq(grotto.tile_at(cell), "sealed", "shut while he lives")
	assert_false(grotto.portals.has(cell))
	assert_false(Depths.open_shortcut(grotto, []))
	assert_true(Depths.open_shortcut(grotto, ["tidecaller"]))
	assert_true(grotto.is_walkable(cell), "open once he's down")
	assert_eq(grotto.portals[cell], door["to"])
	assert_eq(grotto.pieces[cell], PunyDungeon.DOORWAY)
	# Out onto the beach by the cave's mouth: the dungeon's way in.
	var to: Dictionary = door["to"]
	var beach := MapData.load_by_id(String(to["mapId"]))
	var landing := Vector2i(int(to["x"]), int(to["y"]))
	assert_true(Ways.open_ground(beach, landing), "it lands on open ground")
	var mouth := Vector2i(-1, -1)
	for portal: Vector2i in beach.portals:
		if beach.portals[portal].get("mapId", "") == "seacave":
			mouth = portal
	assert_lt(Vector2(landing - mouth).length(), 4.0, "beside the sea cave's mouth: the entrance")
	assert_true(_walked(beach, landing).has(mouth + Vector2i.DOWN), "and walks straight back to it")
	assert_eq(Depths.shortcut_on("seacave"), {}, "only at the bottom")


func test_the_planned_floor_is_the_same_every_visit() -> void:
	var first := Depths.generate("seacave_galleries")
	var again := Depths.generate("seacave_galleries")
	assert_eq(first.grid, again.grid)
	assert_eq(first.regions, again.regions)
	assert_eq(first.pieces, again.pieces)
	assert_eq(first.id, "seacave_galleries")
	assert_eq(first.style, "cave")
	var spec := Depths._spec("seacave_galleries")
	spec["seed"] = int(spec["seed"]) + 1
	assert_ne(DungeonFloor.lay(spec)["map"].grid, first.grid, "another seed, another floor")
	var spawns := Bestiary.spawns_on("seacave_galleries")
	assert_eq(spawns.size(), Depths.floor_of("seacave_galleries")["plan"]["packs"].size(), "a pack a room")
	assert_eq(spawns.map(func(spawn: Dictionary) -> String: return spawn["id"]), ["seacave_galleries_1", "seacave_galleries_2", "seacave_galleries_3", "seacave_galleries_4"])
	for spawn: Dictionary in spawns:
		assert_eq(first.region_at(Vector2i(int(spawn["x"]), int(spawn["y"]))), "seacave", "%s lives in the sea cave's region" % spawn["id"])


func test_the_planned_floors_lay_as_they_did() -> void:
	for map_id: String in ["seacave_galleries", "shafts_gallery", "cellars_crypt", "vault_1", "vault_2", "vault_3", "vault_4", "vault_5"]:
		var grid: Dictionary = Depths.plan(map_id)["map"].grid
		var cells: Array = grid.keys()
		cells.sort()
		var rows: PackedStringArray = []
		for cell: Vector2i in cells:
			rows.append("%d,%d=%s" % [cell.x, cell.y, grid[cell]])
		assert_eq("|".join(rows).md5_text(), PLANNED.get(map_id, ""), map_id)


func test_the_next_line_leads_down_the_floors_through_chapter_two() -> void:
	state.questing.finish_dialogue("elder")
	state.settlement.town_tier = 1
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Deliver Maren's letter to Old Wenna in Saltmere")
	state.questing.deliver("saltmere_wenna")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Bring Tam's ladle up from the wreck in the sea cave")
	var lead := Bearing.main(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"]], ["seacave_grotto", Hunts.lair(Hunts.named("tidecaller"))], "to the Tidecaller, three floors down")
	# The arrow on each floor points at the way on down.
	assert_eq(MapData.load_by_id("saltmere").portals[Bearing.way_out("saltmere", "seacave_grotto")]["mapId"], "seacave")
	assert_eq(Bearing.way_out("seacave", "seacave_grotto"), Depths.stairs("seacave")["down"]["cell"])
	assert_eq(Bearing.way_out("seacave_galleries", "seacave_grotto"), Depths.stairs("seacave_galleries")["down"]["cell"])
	_win("tidecaller")
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["id"], "letter_pell", "chapter two told")
	assert_eq(Letters.satchel(state.progression)[0], {"quest": Quests.by_id("letter_wenna"), "delivered": true})


# ---- Old saves ----------------------------------------------------------------------

func test_a_save_anywhere_in_the_sea_cave_wakes_at_its_entrance() -> void:
	# Before the cave: where it stood.
	assert_eq(Depths.waking("saltmere", Vector2i(20, 20)), {"mapId": "saltmere", "cell": Vector2i(20, 20)})
	# Inside the old one-floor cave, where the Tidecaller used to sit, or on any floor.
	for map_id: String in FLOORS:
		assert_eq(Depths.waking(map_id, Vector2i(35, 8)), {"mapId": "seacave", "cell": Vector2i(5, 25)}, map_id)
	assert_true(Ways.open_ground(MapData.load_by_id("seacave"), Vector2i(5, 25)))


func test_a_save_from_inside_the_cave_round_trips_without_a_new_field() -> void:
	var before: Array = state.to_dict().keys()
	state.world.map_id = "seacave_galleries"
	state.world.cell = Vector2i(10, 8)
	Discovery.discover_around(state.world.discovered, MapData.load_by_id("seacave_galleries"), Vector2i(10, 8))
	state.world.opened_chests.append("seacave_wreck")
	var saved: Dictionary = state.to_dict()
	assert_eq(saved.keys(), before, "no new field")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(saved))["state"])
	assert_true(Discovery.is_discovered(reloaded.world.discovered, "seacave_galleries", Vector2i(10, 8)), "each floor keeps its own fog")
	assert_true(reloaded.spoils.is_opened(_chest("seacave_wreck")), "the wreck's crate stays opened, by its id")


func test_a_hero_who_won_the_ladle_is_not_asked_to_fight_again() -> void:
	state.progression.hunted.append("tidecaller")
	state.pack.add_item("tams_ladle")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_eq(Hunts.living_on("seacave_grotto", [], reloaded.progression.hunted).size(), 0, "no Tidecaller in the grotto")
	assert_eq(int(reloaded.pack.items.get("tams_ladle", 0)), 1, "the ladle kept")
	assert_true(Depths.shortcut_open("seacave_grotto", reloaded.progression.hunted), "the tide door open")
	assert_true(MainQuest.is_met(MainQuest.step("ladle"), reloaded.progression, reloaded.settlement))
	assert_true(reloaded.holdings.is_settled("saltmere_wenna"), "and Wenna home at the inn")


func test_the_late_web_save_loads_and_plays() -> void:
	var late := SaveCodec.decode_code(FileAccess.get_file_as_string("res://test/fixtures/web_save_late.txt"))
	state.apply(late.duplicate(true))
	assert_eq(state.hero.hero_name, "Hrafna")
	var woke := Depths.waking(state.world.map_id, state.world.cell)
	assert_true(MapData.load_by_id(woke["mapId"]).is_walkable(woke["cell"]), "it wakes on open ground")
	for map_id: String in FLOORS:
		assert_gt(MapData.load_by_id(map_id).size.x, 0, "%s loads for it" % map_id)
	assert_eq(state.to_dict().keys(), late.keys(), "its fields, no more")


# ---- Old Wenna comes home -------------------------------------------------------------

func test_wenna_comes_home_once_her_letter_is_delivered_and_the_ladle_won() -> void:
	state.questing.finish_dialogue("elder")
	assert_true(state.progression.quests.has("letter_wenna"), "the letter in the satchel")
	_win("tidecaller")
	assert_false(state.holdings.is_settled("saltmere_wenna"), "she waits for her letter")
	assert_eq(Npcs.by_id("saltmere_wenna", state.settlement.settlers)["mapId"], "saltmere")
	var said: String = state.questing.deliver("saltmere_wenna")
	assert_string_contains(said, "Pixelheim", "she's packing")
	assert_true(state.holdings.is_settled("saltmere_wenna"))
	assert_has(state.reveals, "settler:saltmere_wenna", "the town's tour stops at the inn")
	var home := Npcs.by_id("saltmere_wenna", state.settlement.settlers)
	assert_eq(home["mapId"], "town_inn", "at Sela's inn")
	assert_false(_ids(Npcs.on_map("saltmere", 1, state.settlement.settlers)).has("saltmere_wenna"), "gone from Saltmere")
	assert_true(_ids(Npcs.on_map("town_inn", 1, state.settlement.settlers, ["the_inn"])).has("saltmere_wenna"))
	assert_true(MapData.load_by_id("town_inn").is_walkable(Vector2i(int(home["x"]), int(home["y"]))))


func test_wenna_comes_home_with_the_ladle_when_her_letter_went_first() -> void:
	state.questing.finish_dialogue("elder")
	state.questing.deliver("saltmere_wenna")
	assert_false(state.holdings.is_settled("saltmere_wenna"), "not without Tam's ladle")
	var won: Dictionary = state.spoils.defeat_monster(Hunts.fighter("tidecaller"), "seacave", "", 4)
	assert_true(state.holdings.is_settled("saltmere_wenna"))
	assert_true((won["lines"] as Array).any(func(line: String) -> bool: return "Wenna" in line), "the log says so")


func test_while_the_inn_is_ash_wenna_waits_by_selas_tent() -> void:
	state.progression.hunted.append("tidecaller")
	state.holdings.come_home(true)
	assert_true(_ids(Npcs.on_map("town", 0, state.settlement.settlers, [])).has("saltmere_wenna"), "on the square")
	assert_false(_ids(Npcs.on_map("town_inn", 0, state.settlement.settlers, [])).has("saltmere_wenna"))


func test_tams_stew_makes_a_night_at_the_inn_last_longer() -> void:
	var fights := int(Town._data()["rested"]["innFights"])
	state.settlement.projects.append("the_inn")
	state.pack.gold = 500
	state.upkeep.rest_at_inn()
	assert_eq(int(state.settlement.house["rested"]), fights, "Sela's bed alone")
	state.settlement.house["rested"] = 0
	state.progression.hunted.append("tidecaller")
	state.holdings.come_home()
	var line: String = state.upkeep.rest_at_inn()
	var stew := int(Town.recruit("saltmere_wenna")["inn"]["fights"])
	assert_gt(stew, 0)
	assert_eq(int(state.settlement.house["rested"]), fights + stew, "and a bowl of Tam's stew")
	assert_string_contains(line, "Tam's stew")
	assert_string_contains(line, str(fights + stew))
	assert_has(Town.settler_perks(state.settlement.settlers, state.progression.quests), Town.recruit("saltmere_wenna")["perk"], "the hall lists it")


func test_wennas_homecoming_adds_no_field_to_the_save() -> void:
	state.progression.hunted.append("tidecaller")
	var before: Array = state.to_dict().keys()
	state.holdings.come_home()
	var after: Dictionary = state.to_dict()
	assert_eq(after.keys(), before)
	assert_has(after["settlers"], "saltmere_wenna", "a settler, as the others are")


# ---- Helpers ------------------------------------------------------------------------

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


## Everything a plan holds, as one hash.
static func _fingerprint(plan: Dictionary) -> String:
	var map: MapData = plan["map"]
	var cells: Array = map.grid.keys()
	cells.sort()
	var parts: PackedStringArray = []
	parts.append("%s %s %s" % [map.id, map.size, map.spawn])
	for cell: Vector2i in cells:
		parts.append("%d,%d=%s" % [cell.x, cell.y, map.grid[cell]])
	for cell: Vector2i in map.portals:
		parts.append("p%s=%s" % [cell, map.portals[cell]])
	# A foe's words (a warden's name) are the language's, not the plan's.
	for foe: Dictionary in plan["foes"]:
		parts.append("%s %s %s %d" % [foe["id"], foe["elite"], foe["cell"], foe["lift"]])
	parts.append(str(plan["rooms"]))
	parts.append(str(plan["stairs"]))
	parts.append(str(plan["patch_ground"]))
	return "|".join(parts).md5_text()
