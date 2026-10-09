extends GutTest
## The Frostgate pass (PIX-169): the road north out of the Ash Fields, the
## observatory's door down to the ice cave, Aske's chain to Liane's Lantern,
## Gunnar's strongbox in the yetis' den, icefin through the lake's ice, and
## the Frostweave set woven at Vex's from frost lilies and yeti fur.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_the_pass_and_the_ice_cave_join_up() -> void:
	var pass_map := MapData.load_by_id("frostgate")
	var cave := MapData.load_by_id("icecave")
	assert_eq(cave.style, "cave")
	assert_ne(cave.tint, Color.WHITE, "the ice cave has its frost")
	var into: Array = pass_map.portals.values().map(func(to: Dictionary) -> String: return to.get("mapId", ""))
	assert_has(into, "icecave")
	assert_has(into, "overworld")
	assert_true(cave.is_walkable(Hunts.lair(Hunts.named("rimefang"))))
	assert_eq(Hunts.living_on("icecave", [], []).map(func(entry: Dictionary) -> String: return entry["id"]), ["rimefang"])
	assert_false(Hunts.notices(range(1, 16), []).any(func(entry: Dictionary) -> bool: return entry["id"] == "rimefang"), "never on the board")


func test_the_pass_has_its_own_creatures() -> void:
	for monster_id: String in ["frost_wolf", "yeti", "wendigo", "frost_mammoth", "frost_drake"]:
		assert_false(Bestiary.monster(monster_id).is_empty(), monster_id)
		assert_ne(Bestiary.family_of(monster_id), "", "%s has a family" % monster_id)
		assert_true(PunyArt.MONSTERS.has(monster_id), "%s is drawn" % monster_id)
	assert_true(PunyArt.VILLAGERS.has("hermit"))
	# Rimefang's bolts are frost, not fire.
	assert_true(Hunts.named("rimefang")["move"].has("tint"))


func test_askes_chain_ends_in_lianes_lantern() -> void:
	assert_eq(Quests.for_giver("frost_aske").map(func(q: Dictionary) -> String: return q["id"]), ["aske_wolves", "aske_rimefang"])
	state.questing.resolve_quests("frost_aske")
	for i in 4:
		state.spoils.defeat_monster(Bestiary.spawn("frost_wolf"), "frost", "", 14)
	assert_string_contains(state.questing.resolve_quests("frost_aske"), "Quest complete")
	assert_string_contains(state.questing.resolve_quests("frost_aske"), "Liane's Lantern")
	state.spoils.defeat_monster(Hunts.fighter("rimefang"), "icecave", "", 14)
	assert_eq(int(state.pack.items.get("lianes_lantern", 0)), 1, "the relic is the hero's")
	assert_string_contains(state.questing.resolve_quests("frost_aske"), "the way she went")
	assert_eq(int(state.pack.items.get("lianes_lantern", 0)), 1, "and stays the hero's")


func test_gunnars_strongbox_waits_in_the_den() -> void:
	var chest: Array = Interactables.chests_on("icecave").filter(func(c: Dictionary) -> bool: return c["id"] == "icecave_strongbox")
	assert_eq(chest.size(), 1)
	assert_eq(chest[0]["loot"]["itemId"], "caravan_strongbox")
	assert_true(MapData.load_by_id("icecave").is_walkable(Vector2i(int(chest[0]["x"]), int(chest[0]["y"]))))


func test_the_ice_hole_gives_icefin() -> void:
	var spot := Gathering.fishing_spot_at("frostgate", Vector2i(39, 24))
	assert_eq(spot.get("id", ""), "frostgate_hole")
	var map := MapData.load_by_id("frostgate")
	assert_true(map.is_walkable(Vector2i(39, 24)), "the hole's edge is ice to stand on")
	assert_has(PunyTerrain.WATERS, map.tile_at(Vector2i(39, 23)), "and the hole is open water")
	assert_eq(Gathering.catch(func() -> float: return 0.0, spot), "icefin")
	assert_eq(Gathering.catch(func() -> float: return 0.0), "fresh_fish", "the sea's catch is unchanged")
	state.roll = func() -> float: return 0.0
	assert_string_contains(state.spoils.fish("frostgate_hole"), "icefin")
	assert_eq(int(state.pack.items.get("icefin", 0)), 1)


func test_the_frostweave_is_woven_at_vexs() -> void:
	var set_def := Catalog.armour_set("frostweave")
	assert_eq(set_def["pieces"].size(), 5)
	for item_id: String in set_def["pieces"] + ["rime_staff"]:
		var recipes: Array = Economy._data()["recipes"].filter(func(r: Dictionary) -> bool: return r["itemId"] == item_id)
		assert_eq(recipes.size(), 1, item_id)
		assert_eq(recipes[0]["job"]["id"], "alchemy", "%s is woven at the cauldron" % item_id)
	assert_false(Economy.material_sources("frost_lily").is_empty())
	assert_false(Economy.material_sources("yeti_fur").is_empty())
