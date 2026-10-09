extends GutTest
## The Blackiron mines (PIX-167): the valley's road and the shafts, Garrick's
## chain to the Black Ingot, Pell's canary in a chest, and the Blackiron
## Plate crafted from the seam's ore.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_the_valley_and_the_shafts_join_up() -> void:
	var valley := MapData.load_by_id("blackiron")
	var shafts := MapData.load_by_id("shafts")
	assert_eq(shafts.style, "cave")
	var into: Array = valley.portals.values().map(func(to: Dictionary) -> String: return to.get("mapId", ""))
	assert_has(into, "shafts")
	assert_has(into, "overworld")
	assert_true(shafts.is_walkable(Hunts.lair(Hunts.named("seam_warden"))))
	assert_eq(Hunts.living_on("shafts", [], []).map(func(entry: Dictionary) -> String: return entry["id"]), ["seam_warden"])


func test_garricks_chain_ends_in_the_black_ingot() -> void:
	state.questing.resolve_quests("mines_garrick")
	for i in 4:
		state.spoils.defeat_monster(Bestiary.spawn("goblin_digger"), "shafts", "", 7)
	assert_string_contains(state.questing.resolve_quests("mines_garrick"), "Quest complete")
	state.questing.resolve_quests("mines_garrick")
	state.spoils.defeat_monster(Hunts.fighter("seam_warden"), "shafts", "", 7)
	assert_eq(int(state.pack.items.get("black_ingot", 0)), 1)
	assert_string_contains(state.questing.resolve_quests("mines_garrick"), "five marks")
	assert_eq(int(state.pack.items.get("black_ingot", 0)), 1, "the relic stays")


func test_pells_canary_waits_in_a_chest() -> void:
	var chest: Array = Interactables.chests_on("shafts").filter(func(c: Dictionary) -> bool: return c["id"] == "shafts_canary")
	assert_eq(chest.size(), 1)
	assert_eq(chest[0]["loot"]["itemId"], "canary")
	assert_true(MapData.load_by_id("shafts").is_walkable(Vector2i(int(chest[0]["x"]), int(chest[0]["y"]))))


func test_the_plate_is_forged_from_the_seam() -> void:
	for item_id: String in Catalog.armour_set("blackiron")["pieces"] + ["blackiron_axe"]:
		var recipes: Array = Economy._data()["recipes"].filter(func(r: Dictionary) -> bool: return r["itemId"] == item_id)
		assert_eq(recipes.size(), 1, item_id)
		assert_true("blackiron_ore" in recipes[0]["needs"], "%s needs blackiron ore" % item_id)
	assert_false(Economy.material_sources("blackiron_ore").is_empty())
