extends GutTest
## Treasure and sign data (assets/maps/interactables.json, edited by hand)
## must stay coherent with the maps, the items and the art: the checks the web
## edition ran on its chests as it loaded them, kept here (PIX-301).


func test_chests_sit_on_walkable_portal_free_cells() -> void:
	var maps := {}
	var count := 0
	for chest: Dictionary in Interactables._data()["chests"]:
		count += 1
		var map_id: String = chest["mapId"]
		if not maps.has(map_id):
			maps[map_id] = MapData.load_by_id(map_id)
		var map: MapData = maps[map_id]
		var cell := Vector2i(int(chest["x"]), int(chest["y"]))
		assert_true(map.is_walkable(cell), "%s not walkable" % chest["id"])
		assert_false(map.portals.has(cell), "%s sits on a portal" % chest["id"])
	assert_gt(count, 0)


func test_every_chest_has_its_own_id_and_known_loot() -> void:
	var seen := {}
	for chest: Dictionary in Interactables._data()["chests"]:
		var chest_id := String(chest["id"])
		assert_false(seen.has(chest_id), "%s: a chest's id is its own" % chest_id)
		seen[chest_id] = true
		if chest.get("mimic", false):
			continue
		assert_true(chest.has("loot"), "%s: a chest holds something" % chest_id)
		var loot: Dictionary = chest.get("loot", {})
		if loot.get("kind", "") == "gold":
			assert_gt(int(loot.get("amount", 0)), 0, "%s: some gold" % chest_id)
		else:
			assert_false(Catalog.item(String(loot.get("itemId", ""))).is_empty(), "%s: holds a known item" % chest_id)
	assert_gt(seen.size(), 30)


## A mimic fights where it stands, so it needs an encounter region; no chest
## stands where a pack lives (a spawn's cell and the three beyond it, right
## and down, where the web's packs stood).
func test_chests_keep_clear_of_packs_and_a_mimic_stands_in_a_region() -> void:
	var spawns: Array = Bestiary._data()["spawns"]
	for chest: Dictionary in Interactables._data()["chests"]:
		var map_id := String(chest["mapId"])
		var cell := Vector2i(int(chest["x"]), int(chest["y"]))
		for spawn: Dictionary in spawns:
			if String(spawn["mapId"]) != map_id:
				continue
			var home := Rect2i(int(spawn["x"]), int(spawn["y"]), 2, 2)
			assert_false(home.has_point(cell), "%s stands where %s lives" % [chest["id"], spawn["id"]])
		if chest.get("mimic", false):
			assert_ne(MapData.load_by_id(map_id).region_at(cell), "", "%s: a mimic in an encounter region" % chest["id"])


func test_every_treasure_look_has_shades_art() -> void:
	for look: String in ["chest", "glint", "herb"]:
		assert_gt(PunyProps.treasure_tile(look, false), -1, look)
	assert_gt(PunyProps.treasure_tile("chest", true), -1, "an opened chest stays")


func test_town_signs_include_the_house_for_sale() -> void:
	var labels := []
	for sign_def: Dictionary in Interactables.signs_on("town"):
		labels.append(sign_def["label"])
	assert_has(labels, "FOR SALE")
	assert_has(labels, "FORGE")
	assert_has(labels, "INN")
	assert_gte(labels.size(), 6)

