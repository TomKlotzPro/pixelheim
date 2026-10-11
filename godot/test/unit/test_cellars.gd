extends GutTest
## The Letter to Greyhold (PIX-255, PIX-253 step 6, story chapter 4): the
## Greyhold cellars in three floors - the cells with Fenwick's locket, the
## garrison's crypt with Ana's father's badge, the Captain's Hall where the
## Hollow Captain stands down once he's read Maren's line, and the north
## stair straight back up to the foot of the keep's stair; Captain Hale's
## order book in his hall, read between the letter and the shield; Sergeant
## Ulla and the old guard at Pixelheim's gate and Brother Teo's bell in the
## town hall; old saves at each stage of the chapter.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const FLOORS := ["cellars", "cellars_crypt", "cellars_hall"]
const ENTRANCE := Vector2i(4, 27)

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


# ---- The floors ---------------------------------------------------------------------

func test_the_cellars_are_three_floors_top_down() -> void:
	assert_eq(Depths.floors("cellars").map(func(entry: Dictionary) -> String: return entry["mapId"]), FLOORS)
	for i in FLOORS.size():
		assert_eq(Depths.number(FLOORS[i]), i + 1)
		assert_eq(Depths.root(FLOORS[i]), "cellars", "a floor goes by its dungeon's first in the tables")
	assert_true(Depths.is_planned("cellars_crypt"), "the crypt is laid out from a seed")
	assert_false(Depths.is_planned("cellars"))
	assert_false(Depths.is_planned("cellars_hall"))
	assert_eq(Catalog.place_name("cellars_crypt"), "The Garrison's Crypt")
	assert_eq(Catalog.place_name("cellars_hall"), "The Captain's Hall")
	for map_id: String in FLOORS:
		assert_has(Atlas.ORDER, map_id, "%s has a page on the map" % map_id)


func test_every_floor_is_reached_from_the_entrance_down_the_stairs() -> void:
	var map := MapData.load_by_id("cellars")
	var at: Vector2i = Depths.waking("cellars", Vector2i.ZERO)["cell"]
	assert_eq(at, ENTRANCE, "the entrance, at the foot of the keep's stair")
	var reached := 0
	for depth in FLOORS.size():
		assert_eq(map.id, FLOORS[depth])
		reached += 1
		var walked := _walked(map, at)
		var down: Dictionary = Depths.stairs(map.id).get("down", {})
		if down.is_empty():
			assert_true(walked.has(Hunts.lair(Hunts.named(Depths.boss("cellars")))), "the Hollow Captain's place is walked to")
			var door: Dictionary = Depths.shortcut_on(map.id)
			assert_true(STEPS.any(func(step: Vector2i) -> bool: return walked.has(door["cell"] + step)), "and the north stair")
			break
		assert_true(STEPS.any(func(step: Vector2i) -> bool: return walked.has(down["cell"] + step)), "%s: its stair down is walked to" % map.id)
		var target: Dictionary = map.portals[down["cell"]]
		map = MapData.load_by_id(target["mapId"])
		at = Vector2i(int(target["x"]), int(target["y"]))
	assert_eq(reached, 3, "all three floors")


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
	# The first floor still climbs back into Captain Hale's hall.
	var cells := MapData.load_by_id("cellars")
	assert_eq(cells.portals[Vector2i(3, 28)]["mapId"], "keep")
	assert_eq(Ways.below("keep"), "cellars")


func test_each_floor_is_harder_than_the_one_above() -> void:
	for i in range(1, FLOORS.size()):
		assert_gt(Depths.lift(FLOORS[i]), Depths.lift(FLOORS[i - 1]), "%s's foes stand higher" % FLOORS[i])
		assert_gt(Depths.foe_level(FLOORS[i]), Depths.foe_level(FLOORS[i - 1]), "%s's packs are stronger" % FLOORS[i])
	assert_eq(Depths.boss("cellars"), "hollow_captain")
	var captain := Hunts.named("hollow_captain")
	assert_eq(captain["mapId"], "cellars_hall", "the Hollow Captain waits at the bottom")
	# Above his floor, and above the strongest of his garrison standing there.
	assert_gt(float(captain["level"]), Depths.foe_level("cellars_hall"))
	for kind: Dictionary in Bestiary.region("cellars")["monsters"]:
		var lifted := Bestiary.spawn(String(kind["monsterId"]), false, Depths.lift("cellars_hall"))
		assert_gt(int(captain["level"]), int(lifted["level"]), "%s on his floor stands below him" % kind["monsterId"])


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
	assert_eq(_chest("cellars_locket")["loot"]["itemId"], "fenwicks_locket", "the cells: Fenwick's locket")
	assert_eq(Depths.floor_of("cellars")["find"], "cellars_locket")
	var badge := _chest("cellars_badge")
	assert_eq(badge["loot"]["itemId"], "guard_badge", "the crypt: Ana's father's badge")
	assert_eq(Depths.find_cell("cellars_crypt"), Vector2i(int(badge["x"]), int(badge["y"])), "on the crypt's last slab")
	for chest_id: String in ["cellars_locket", "cellars_badge"]:
		assert_ne(String(_chest(chest_id).get("said", "")), "", "%s says what it is as it opens" % chest_id)
	assert_eq(Hunts.named("hollow_captain")["drop"], "oskars_shield", "the hall: Oskar's shield")
	assert_eq(_chest("cellars_armoury")["mapId"], "cellars", "the armoury's strongbox stays on the first floor")


func test_the_crypt_is_its_floors_set_piece() -> void:
	var map := MapData.load_by_id("cellars_crypt")
	var graves: Array = map.grid.keys().filter(func(cell: Vector2i) -> bool: return map.grid[cell] in ["statue", "grille"])
	assert_gt(graves.size(), 6, "stone knights and iron grilles")
	var last: Rect2i = Depths.plan("cellars_crypt")["rooms"][-1]
	for cell: Vector2i in graves:
		assert_string_contains(String(map.notes[cell]), "garrison", "E on them says whose")
		assert_true(last.has_point(cell), "in the last room, by the way down")
	assert_false(WorldTiles.is_walkable("statue"))
	assert_false(WorldTiles.is_walkable("grille"))
	# The hall's own knights and grilles stand too.
	var hall := MapData.load_by_id("cellars_hall")
	assert_gt(hall.grid.values().count("statue"), 4)
	assert_gt(hall.grid.values().count("grille"), 2)


func test_the_planned_floor_is_the_same_every_visit() -> void:
	var first := Depths.generate("cellars_crypt")
	var again := Depths.generate("cellars_crypt")
	assert_eq(first.grid, again.grid)
	assert_eq(first.regions, again.regions)
	assert_eq(first.style, "cave")
	var spawns := Bestiary.spawns_on("cellars_crypt")
	assert_eq(spawns.map(func(spawn: Dictionary) -> String: return spawn["id"]), ["cellars_crypt_1", "cellars_crypt_2", "cellars_crypt_3", "cellars_crypt_4"])
	for spawn: Dictionary in spawns:
		assert_eq(first.region_at(Vector2i(int(spawn["x"]), int(spawn["y"]))), "cellars", "%s lives in the cellars' region" % spawn["id"])
	for spawn: Dictionary in Bestiary.spawns_on("cellars_hall"):
		var hall := MapData.load_by_id("cellars_hall")
		assert_eq(hall.region_at(Vector2i(int(spawn["x"]), int(spawn["y"]))), "cellars", "%s stands on the hall's floor" % spawn["id"])


func test_the_north_stair_opens_once_the_captain_stands_down() -> void:
	var hall := MapData.load_by_id("cellars_hall")
	var door: Dictionary = Depths.shortcut_on("cellars_hall")
	var cell: Vector2i = door["cell"]
	assert_eq(hall.tile_at(cell), "sealed", "barred while he keeps his watch")
	assert_eq(hall.pieces[cell], PunyDungeon.GRILLE)
	assert_false(Depths.open_shortcut(hall, []))
	assert_true(Depths.open_shortcut(hall, ["hollow_captain"]))
	assert_true(hall.is_walkable(cell))
	assert_eq(hall.pieces[cell], PunyDungeon.STAIRS, "a stair up")
	assert_eq(hall.portals[cell], door["to"])
	# Up to the foot of the keep's stair: the cellars' entrance.
	var to: Dictionary = door["to"]
	assert_eq([String(to["mapId"]), Vector2i(int(to["x"]), int(to["y"]))], ["cellars", ENTRANCE])
	var cells := MapData.load_by_id("cellars")
	assert_true(Ways.open_ground(cells, ENTRANCE))
	assert_true(_walked(cells, ENTRANCE).has(Vector2i(3, 28) + Vector2i.RIGHT), "a step from the stair up into the keep")
	assert_false(Ways.goes_under(hall, cells), "coming up dissolves")
	assert_eq(Depths.shortcut_on("cellars"), {}, "only at the bottom")


# ---- The Hollow Captain stands down -----------------------------------------------------

func test_the_hollow_captain_yields_rather_than_falls() -> void:
	var share := Hunts.yields_at("hollow_captain")
	assert_between(share, 0.1, 0.5, "low, not dead")
	var captain := Hunts.fighter("hollow_captain")
	assert_false(Hunts.yields(captain), "whole, he fights")
	var low := ceili(int(captain["maxHp"]) * share)
	captain["hp"] = low + 1
	assert_false(Hunts.yields(captain))
	captain["hp"] = low
	assert_true(Hunts.yields(captain), "at his share he stands down")
	captain["hp"] = 0
	assert_true(Hunts.yields(captain), "even under a blow that would have felled him")
	var tidecaller := Hunts.fighter("tidecaller")
	tidecaller["hp"] = 1
	assert_false(Hunts.yields(tidecaller), "the others fight to the end")
	assert_false(Hunts.yields(Bestiary.spawn("hollow_guard")))
	var said := Hunts.standing_down("hollow_captain")
	assert_true((said["lines"] as Array).any(func(line: String) -> bool: return "Oskar isn't coming home. Stand down, Captain." in line), "Maren's line, read to him")
	assert_true((said["lines"] as Array).any(func(line: String) -> bool: return "shield" in line), "and he gives up Oskar's shield")
	assert_ne(String(said["card"]), "")


func test_standing_down_counts_as_the_hunt() -> void:
	# Paid out as a fall is: the keepsake, the named hunt, the main quest's step,
	# and the Frostgate road dug out.
	var avalanche := Gates.by_id("avalanche")
	assert_false(Gates.is_open(avalanche, state.progression, state.settlement, {}))
	state.spoils.defeat_monster(Hunts.fighter("hollow_captain"), "cellars", "", 11)
	assert_has(state.progression.hunted, "hollow_captain")
	assert_eq(int(state.pack.items.get("oskars_shield", 0)), 1, "Oskar's shield")
	assert_true(MainQuest.is_met(MainQuest.step("shield"), state.progression, state.settlement))
	assert_true(Gates.is_open(avalanche, state.progression, state.settlement, {}), "Ulla's wardens dig out the Frostgate road")


# ---- Hale's order book --------------------------------------------------------------

func test_hales_order_book_lies_on_his_table() -> void:
	var book := Letters.reading("hale_order_book")
	assert_false(book.is_empty())
	assert_eq(book["quest"]["id"], "letter_hale", "the answer to Maren's letter to Captain Hale")
	assert_eq(book["mapId"], "keep", "in his hall")
	var keep := MapData.load_by_id("keep")
	var stand := 0
	for cell: Vector2i in _rect_cells(Letters.reading_rect(book)):
		assert_eq(Letters.reading_at("keep", cell), book, "E on any of the table's cells")
		for step: Vector2i in STEPS:
			if keep.is_walkable(cell + step) and not Letters.reading_rect(book).has_point(cell + step):
				stand += 1
	assert_gt(stand, 0, "and a hero can stand at it")
	assert_true(Letters.reading_at("keep", Vector2i(13, 5)).is_empty(), "not at the stairwell")
	assert_true(Letters.reading_at("cellars", Vector2i(7, 6)).is_empty(), "nor anywhere else")
	assert_true((book["lines"] as Array).any(func(line: String) -> bool: return "Day 12" in line and "I agreed. I was wrong." in line))


func test_the_book_stays_shut_until_the_letter_is_delivered_and_is_read_once() -> void:
	var book := Letters.reading("hale_order_book")
	state.questing.finish_dialogue("elder")
	assert_eq(Letters.reading_lines(book, state.progression), [book["shut"]], "a courier never reads the post")
	assert_false(Letters.reads_now(book, state.progression))
	state.questing.deliver("greyhold_ulla")
	assert_true(Letters.reads_now(book, state.progression), "Ulla sends the courier to read it")
	assert_eq(Letters.reading_lines(book, state.progression), book["lines"])
	state.mark_seen("hale_order_book")
	assert_false(Letters.reads_now(book, state.progression))
	assert_eq(Letters.reading_lines(book, state.progression), [book["again"]], "a short word after")


func test_the_next_line_reads_through_chapter_four() -> void:
	_to_chapter_four()
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Take Maren's letter to Captain Hale at Greyhold")
	var lead := Bearing.main(state.progression, state.settlement, state.pack.items)
	assert_eq(lead["map_id"], "greyhold", "to Ulla's camp")
	state.questing.deliver("greyhold_ulla")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Read Hale's order book in his hall")
	lead = Bearing.main(state.progression, state.settlement, state.pack.items)
	assert_eq(lead["map_id"], "keep", "to his table")
	assert_true(Letters.reading_rect(Letters.reading("hale_order_book")).has_point(lead["cell"]))
	state.mark_seen("hale_order_book")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Read Maren's letter to the Hollow Captain")
	lead = Bearing.main(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"]], ["cellars_hall", Hunts.lair(Hunts.named("hollow_captain"))], "three floors down")
	# The arrow on each floor points at the way on down.
	assert_eq(MapData.load_by_id("keep").tile_at(Bearing.way_out("keep", "cellars_hall")), "stairwell")
	assert_eq(Bearing.way_out("cellars", "cellars_hall"), Depths.stairs("cellars")["down"]["cell"])
	assert_eq(Bearing.way_out("cellars_crypt", "cellars_hall"), Depths.stairs("cellars_crypt")["down"]["cell"])
	_win("hollow_captain")
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["id"], "letter_aske", "chapter four told")


# ---- Old saves ----------------------------------------------------------------------

func test_a_save_anywhere_in_the_cellars_wakes_at_their_entrance() -> void:
	assert_eq(Depths.waking("keep", Vector2i(8, 8)), {"mapId": "keep", "cell": Vector2i(8, 8)}, "in the hall: where it stood")
	# Where the Hollow Captain kept his watch in the old one-floor cellars, or any floor.
	for map_id: String in FLOORS:
		assert_eq(Depths.waking(map_id, Vector2i(40, 7)), {"mapId": "cellars", "cell": ENTRANCE}, map_id)


func test_a_save_from_inside_the_cellars_round_trips_without_a_new_field() -> void:
	# A hero past the tin: the story ledger is in the save already.
	state.questing.finish_dialogue("elder")
	var before: Array = state.to_dict().keys()
	state.world.map_id = "cellars_crypt"
	state.world.cell = Vector2i(10, 8)
	Discovery.discover_around(state.world.discovered, MapData.load_by_id("cellars_crypt"), Vector2i(10, 8))
	state.world.opened_chests.append("cellars_badge")
	state.mark_seen("hale_order_book")
	var saved: Dictionary = state.to_dict()
	assert_eq(saved.keys(), before, "no new field")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(saved))["state"])
	assert_true(Discovery.is_discovered(reloaded.world.discovered, "cellars_crypt", Vector2i(10, 8)), "each floor keeps its own fog")
	assert_true(reloaded.spoils.is_opened(_chest("cellars_badge")), "the badge's box stays opened, by its id")
	assert_has(reloaded.progression.story_seen, "hale_order_book", "the book read, in the story ledger")


func test_a_hero_who_delivered_the_letter_is_sent_to_the_book() -> void:
	_to_chapter_four()
	state.questing.deliver("greyhold_ulla")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_eq(MainQuest.next_step(reloaded.progression, reloaded.settlement)["id"], "order_book")
	assert_false(reloaded.holdings.is_settled("greyhold_ulla"), "Ulla waits at her camp")


func test_a_hero_who_won_the_shield_is_not_asked_to_fight_again() -> void:
	state.progression.hunted.append("hollow_captain")
	state.pack.add_item("oskars_shield")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))["state"])
	assert_eq(Hunts.living_on("cellars_hall", [], reloaded.progression.hunted).size(), 0, "no Hollow Captain in his hall")
	assert_eq(Hunts.living_on("cellars", [], reloaded.progression.hunted).size(), 0)
	assert_eq(int(reloaded.pack.items.get("oskars_shield", 0)), 1, "the shield kept")
	assert_true(Depths.shortcut_open("cellars_hall", reloaded.progression.hunted), "the north stair open")
	assert_true(MainQuest.is_met(MainQuest.step("shield"), reloaded.progression, reloaded.settlement))
	assert_true(MainQuest.is_met(MainQuest.step("letter_hale"), reloaded.progression, reloaded.settlement), "the letter as good as delivered")
	assert_ne(MainQuest.next_step(reloaded.progression, reloaded.settlement)["id"], "order_book", "never sent back to the book")
	assert_true(Letters.reads_now(Letters.reading("hale_order_book"), reloaded.progression), "though it's there to read")
	assert_true(reloaded.holdings.is_settled("greyhold_ulla"), "Ulla at the gate")
	assert_true(reloaded.holdings.is_settled("greyhold_teo"), "Teo's bell in the hall")


func test_the_late_web_save_loads_and_plays() -> void:
	var late := SaveCodec.decode_code(FileAccess.get_file_as_string("res://test/fixtures/web_save_late.txt"))
	state.apply(late.duplicate(true))
	var woke := Depths.waking(state.world.map_id, state.world.cell)
	assert_true(MapData.load_by_id(woke["mapId"]).is_walkable(woke["cell"]), "it wakes on open ground")
	for map_id: String in FLOORS:
		assert_gt(MapData.load_by_id(map_id).size.x, 0, "%s loads for it" % map_id)
	assert_true(Gates.is_open(Gates.by_id("avalanche"), state.progression, state.settlement, state.world.discovered))
	assert_eq(state.to_dict().keys(), late.keys(), "its fields, no more")


# ---- Ulla and Teo come home ---------------------------------------------------------

func test_ulla_and_teo_come_home_once_the_letter_is_delivered_and_the_captain_stands_down() -> void:
	state.questing.finish_dialogue("elder")
	_win("hollow_captain")
	assert_false(state.holdings.is_settled("greyhold_ulla"), "they wait for Maren's letter")
	assert_eq(Npcs.by_id("greyhold_ulla", state.settlement.settlers)["mapId"], "greyhold")
	var said: String = state.questing.deliver("greyhold_ulla")
	assert_string_contains(said, "Frostgate road", "Ulla's marching, her wardens digging")
	assert_string_contains(said, "bell", "Teo's bringing the bell")
	for id: String in ["greyhold_ulla", "greyhold_teo"]:
		assert_true(state.holdings.is_settled(id), id)
		assert_has(state.reveals, "settler:" + id, "the town's tour stops at their door")
		assert_false(_ids(Npcs.on_map("greyhold", 1, state.settlement.settlers)).has(id), "%s gone from Greyhold" % id)
	var ulla := Npcs.by_id("greyhold_ulla", state.settlement.settlers)
	assert_eq(ulla["mapId"], "town", "Ulla keeps Pixelheim's gate")
	assert_true(_ids(Npcs.on_map("town", 1, state.settlement.settlers, [])).has("greyhold_ulla"))
	var teo := Npcs.by_id("greyhold_teo", state.settlement.settlers)
	assert_eq(teo["mapId"], "town_hall", "Teo in the town hall, with the bell")
	assert_true(_ids(Npcs.on_map("town_hall", 1, state.settlement.settlers, [])).has("greyhold_teo"))
	assert_true(MapData.load_by_id("town_hall").is_walkable(Vector2i(int(teo["x"]), int(teo["y"]))))


func test_ulla_comes_home_with_the_shield_when_the_letter_went_first() -> void:
	state.questing.finish_dialogue("elder")
	state.questing.deliver("greyhold_ulla")
	assert_false(state.holdings.is_settled("greyhold_ulla"), "not while the captain keeps his watch")
	var won: Dictionary = state.spoils.defeat_monster(Hunts.fighter("hollow_captain"), "cellars", "", 11)
	assert_true(state.holdings.is_settled("greyhold_ulla"))
	assert_true(state.holdings.is_settled("greyhold_teo"))
	assert_true((won["lines"] as Array).any(func(line: String) -> bool: return "Ulla" in line), "the log says so")


func test_ulla_stands_inside_the_gate_at_every_age() -> void:
	var ulla: Dictionary = Town.recruit("greyhold_ulla")["home"]
	var cell := Vector2i(int(ulla["x"]), int(ulla["y"]))
	var gate := Vector2i(-1, -1)
	var town := MapData.load_by_id("town")
	for portal: Vector2i in town.portals:
		if town.portals[portal].get("mapId", "") == "overworld":
			gate = portal
	assert_lt(Vector2(cell - gate).length(), 4.0, "by the town's gate")
	for tier in Town.MAX_TIER + 1:
		var grown := MapData.load_tiered("town", Town.projects_through(tier), 1)
		assert_true(grown.is_walkable(cell), "age %d: on open ground" % tier)
		assert_ne(grown.tile_at(cell), "path", "age %d: beside the road, not on it" % tier)
		assert_false(grown.portals.has(cell))


func test_the_homecoming_adds_no_field_to_the_save() -> void:
	state.progression.hunted.append("hollow_captain")
	var before: Array = state.to_dict().keys()
	state.holdings.come_home()
	var after: Dictionary = state.to_dict()
	assert_eq(after.keys(), before)
	assert_has(after["settlers"], "greyhold_ulla", "settlers, as the others are")
	assert_has(after["settlers"], "greyhold_teo")
	assert_has(Town.settler_perks(state.settlement.settlers, state.progression.quests), Town.recruit("greyhold_teo")["perk"], "the hall lists them")


# ---- Helpers ------------------------------------------------------------------------

## A hero at chapter four's door: the first three chapters told, the letters
## in the satchel.
func _to_chapter_four() -> void:
	state.questing.finish_dialogue("elder")
	state.settlement.town_tier = 1
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	state.questing.deliver("saltmere_wenna")
	_win("tidecaller")
	state.questing.deliver("mines_pell")
	_win("seam_warden")
	state.settlement.projects.append("street_lamps")


func _win(named_id: String) -> void:
	state.spoils.defeat_monster(Hunts.fighter(named_id), Hunts.named(named_id)["mapId"], "", 10)


func _chest(chest_id: String) -> Dictionary:
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest["id"] == chest_id:
			return chest
	return {}


func _ids(npcs: Array) -> Array:
	return npcs.map(func(npc: Dictionary) -> String: return npc["id"])


func _rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out


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
