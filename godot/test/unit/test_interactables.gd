extends GutTest
## Treasure and sign data exported from the web game must stay coherent with
## the maps and sprites — mirrors the module-load validation in chests.ts.


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


func test_every_treasure_sprite_exists() -> void:
	for sprite_name in ["chest_closed", "chest_open", "road_glint", "herb_patch"]:
		assert_true(ResourceLoader.exists("res://assets/sprites/%s.png" % sprite_name))


func test_sprite_name_follows_the_web_rules() -> void:
	var chest := {"look": "chest"}
	assert_eq(Interactables.sprite_name(chest, false), "chest_closed")
	assert_eq(Interactables.sprite_name(chest, true), "chest_open")
	assert_eq(Interactables.sprite_name({"look": "glint"}, false), "road_glint")
	assert_eq(Interactables.sprite_name({"look": "glint"}, true), "")
	assert_eq(Interactables.sprite_name({"look": "herb"}, false), "herb_patch")


func test_town_signs_include_the_house_for_sale() -> void:
	var labels := []
	for sign_def: Dictionary in Interactables.signs_on("town"):
		labels.append(sign_def["label"])
	assert_has(labels, "FOR SALE")
	assert_has(labels, "FORGE")
	assert_has(labels, "INN")
	assert_gte(labels.size(), 6)


func test_loot_text_formats_every_kind() -> void:
	assert_eq(
		Interactables.loot_text({"loot": {"kind": "gold", "amount": 60}}),
		"You found 60 gold!"
	)
	assert_eq(
		Interactables.loot_text({"loot": {"kind": "item", "itemId": "potion_hp", "qty": 2}}),
		"You found 2× Potion Hp!"
	)
	assert_eq(
		Interactables.loot_text({"loot": {"kind": "gear", "itemId": "iron_sword"}}),
		"You found Iron Sword!"
	)
	assert_eq(Interactables.loot_text({"mimic": true}), "")
