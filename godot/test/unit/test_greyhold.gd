extends GutTest
## Greyhold (PIX-168): the road east off the Ash Fields to Oskar's fort and
## down its keep to the cellars, Ulla's chain to Oskar's Shield, Fenwick's
## locket in the end cell, the dead garrison stood down, and the Greyhold
## Warden set forged from the fort's old steel.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_the_fort_and_the_cellars_join_up() -> void:
	var fort := MapData.load_by_id("greyhold")
	var cellars := MapData.load_by_id("cellars")
	assert_eq(cellars.style, "cave")
	var into: Array = fort.portals.values().map(func(to: Dictionary) -> String: return to.get("mapId", ""))
	assert_has(into, "cellars")
	assert_has(into, "overworld")
	assert_true(cellars.is_walkable(Hunts.lair(Hunts.named("hollow_captain"))))
	assert_eq(Hunts.living_on("cellars", [], []).map(func(entry: Dictionary) -> String: return entry["id"]), ["hollow_captain"])
	assert_false(Hunts.notices(range(1, 16), []).any(func(entry: Dictionary) -> bool: return entry["id"] == "hollow_captain"), "never on the board")


func test_the_keep_door_is_a_house_door_and_the_gate_a_rampart() -> void:
	var fort := MapData.load_by_id("greyhold")
	assert_eq(PunyTerrain.wall_piece(fort.grid, Vector2i(37, 26)), PunyTerrain.GATE, "the south gate")
	assert_eq(PunyTerrain.wall_piece(fort.grid, Vector2i(37, 12)), -1, "the keep's door stays a door")
	assert_true(fort.is_walkable(Vector2i(37, 26)))


func test_the_fort_has_its_own_creatures() -> void:
	for monster_id: String in ["turncoat", "turncoat_bowman", "cutthroat", "hollow_guard"]:
		assert_false(Bestiary.monster(monster_id).is_empty(), monster_id)
		assert_ne(Bestiary.family_of(monster_id), "", "%s has a family" % monster_id)
		assert_true(PunyArt.MONSTERS.has(monster_id), "%s is drawn" % monster_id)
	for sprite: String in ["guard", "monk"]:
		assert_true(PunyArt.VILLAGERS.has(sprite), "%s is drawn" % sprite)


func test_ullas_chain_ends_in_oskars_shield() -> void:
	assert_eq(Quests.for_giver("greyhold_ulla").map(func(q: Dictionary) -> String: return q["id"]), ["ulla_turncoats", "ulla_captain"])
	state.resolve_quests("greyhold_ulla")
	for i in 5:
		state.defeat_monster(Bestiary.spawn("turncoat"), "castle", "", 11)
	assert_string_contains(state.resolve_quests("greyhold_ulla"), "Quest complete")
	assert_string_contains(state.resolve_quests("greyhold_ulla"), "The Hollow Captain")
	state.defeat_monster(Hunts.fighter("hollow_captain"), "cellars", "", 11)
	assert_eq(int(state.pack.items.get("oskars_shield", 0)), 1, "the relic is the hero's")
	assert_string_contains(state.resolve_quests("greyhold_ulla"), "Captain Hale")
	assert_eq(int(state.pack.items.get("oskars_shield", 0)), 1, "and stays the hero's")


func test_the_captain_is_no_guard_to_stand_down() -> void:
	state.resolve_quests("greyhold_teo")
	state.defeat_monster(Hunts.fighter("hollow_captain"), "cellars", "", 11)
	assert_eq(int(state.progression.quests["teo_rest"].get("progress", 0)), 0, "a named fighter counts for no kill quest")
	for i in 3:
		state.defeat_monster(Bestiary.spawn("hollow_guard"), "cellars", "", 11)
	assert_string_contains(state.resolve_quests("greyhold_teo"), "Quest complete")


func test_fenwicks_locket_waits_in_the_end_cell() -> void:
	var chest: Array = Interactables.chests_on("cellars").filter(func(c: Dictionary) -> bool: return c["id"] == "cellars_locket")
	assert_eq(chest.size(), 1)
	assert_eq(chest[0]["loot"]["itemId"], "fenwicks_locket")
	assert_true(MapData.load_by_id("cellars").is_walkable(Vector2i(int(chest[0]["x"]), int(chest[0]["y"]))))


func test_the_warden_set_is_forged_from_old_steel() -> void:
	var set_def := Catalog.armour_set("warden")
	assert_eq(set_def["pieces"].size(), 5)
	for item_id: String in set_def["pieces"] + ["warden_longsword"]:
		var recipes: Array = Economy._data()["recipes"].filter(func(r: Dictionary) -> bool: return r["itemId"] == item_id)
		assert_eq(recipes.size(), 1, item_id)
		assert_true("old_steel" in recipes[0]["needs"], "%s needs old steel" % item_id)
	assert_false(Economy.material_sources("old_steel").is_empty())
	assert_eq(Bestiary._data()["regionMaterials"]["castle"], "old_steel")
