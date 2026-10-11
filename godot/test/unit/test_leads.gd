extends GutTest
## Every lead true, every line current (PIX-184): where a material comes
## from names every way there is - shops, patches and fights, chests, fishing
## holes, quest rewards, monsters, loot - the nearest first, and a shop only
## with it on its shelves now. The old mountain's floors, their patches and
## hoards left play (PIX-257): no lead is worked out for them any more.

const GameStateScript := preload("res://scripts/state/game_state.gd")


func _texts(item_id: String, town_tier := 4, stock_stage := 99) -> Array:
	return Economy.material_sources(item_id, town_tier, stock_stage).map(func(lead: Dictionary) -> String: return lead["text"])


func _kinds(item_id: String) -> Array:
	return Economy.material_sources(item_id).map(func(lead: Dictionary) -> String: return lead["kind"])


func test_a_lead_for_every_way_to_come_by_it() -> void:
	assert_has(_texts("forest_herb"), "in a chest in the Ashenreach", "a chest of herbs")
	# The old mountain's floors left play (PIX-257): no lead names them.
	assert_false(_texts("marsh_reed").any(func(text: String) -> bool: return "floor" in text), "no floor named")
	assert_has(_texts("ember_shard"), "Smith Hilda's reward for Black Iron for the Forge", "a quest pays one")
	assert_eq(Economy.material_sources("ember_shard")[0]["kind"], "forage", "the Ash before Hilda's reward for ore from the mines")
	assert_has(_texts("icefin"), "caught fishing at the Frostgate Pass", "the hole in the ice has its own catch")
	assert_false(_texts("gem").any(func(text: String) -> bool: return "hoard" in text), "no hoard of an old floor")
	# What only the old floors held has a home now (PIX-257): the Kings'
	# Vault's loot, the dragon's scales among it.
	assert_true(_texts("dragon_scale").any(func(text: String) -> bool: return text.contains("the Kings' Vault")), "Fafnyr's scales lie in the Vault")


func test_loot_names_the_wilds_that_drop_it() -> void:
	var imp_horn: String = _texts("imp_horn").filter(func(text: String) -> bool: return text.begins_with("now and then in loot in"))[0]
	assert_string_contains(imp_horn, "the Mirefen")
	var wolf_pelt: String = _texts("wolf_pelt").filter(func(text: String) -> bool: return text.begins_with("now and then in loot in"))[0]
	assert_string_contains(wolf_pelt, "the Whispering Forest")
	assert_false(_texts("wolf_pelt").any(func(text: String) -> bool: return "from floor" in text and "loot" in text), "no 'loot from floor N' for the wilds")


func test_the_nearest_lead_comes_first() -> void:
	for item_id in ["wolf_pelt", "marsh_reed", "ember_shard", "gem", "frost_lily", "imp_horn"]:
		var stages: Array = Economy.material_sources(item_id).map(func(lead: Dictionary) -> float: return lead["stage"])
		var sorted := stages.duplicate()
		sorted.sort()
		assert_eq(stages, sorted, item_id)
	assert_eq(Economy.material_sources("frost_lily")[0]["kind"], "forage", "the Frostgate's lilies before Linnea's reward")


func test_a_shop_lead_only_when_the_shelf_holds_it() -> void:
	var by_age: Dictionary = Economy.shop("alchemist")["ageStock"]
	var item_id := "lantern_draught"
	var age := int(by_age[item_id])
	assert_false(_texts(item_id, age - 1).any(func(text: String) -> bool: return text.begins_with("sold by")), "not before its age")
	assert_true(_texts(item_id, age).any(func(text: String) -> bool: return text.begins_with("sold by")))


func test_a_quests_goods_are_not_for_sale() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	var goods: String = Catalog._data()["items"].keys().filter(func(id: String) -> bool: return Catalog.item(id).get("quest", false))[0]
	state.pack.add_item(goods)
	state.world.map_id = "town_shop"
	assert_eq(state.trade.sell_item(goods), 0)
	assert_eq(int(state.pack.items.get(goods, 0)), 1)


func test_the_recruits_ask_what_their_quests_ask() -> void:
	for recruit: Dictionary in Npcs._data()["recruits"]:
		# One the story brings home asks nothing (PIX-255: Wenna).
		if recruit.has("comesHome"):
			continue
		var first: Dictionary = Quests.for_giver(recruit["id"])[0]
		var objective: Dictionary = first["objective"]
		var ask: Dictionary = recruit["ask"]
		assert_eq(ask["kind"], objective["kind"], recruit["id"])
		assert_eq(int(ask["count"]), int(objective["count"]), recruit["id"])
		assert_eq(ask.get("itemId", ask.get("monsterId")), objective.get("itemId", objective.get("monsterId")), recruit["id"])
		for line: String in recruit["meetLines"] + [recruit["askLine"]]:
			assert_false(RegEx.create_from_string("\\d+ gold").search(line) != null, "%s asks no price: %s" % [recruit["id"], line])


func test_the_fountains_age_says_it_wants_the_scale() -> void:
	for age: Dictionary in Town._data()["tiers"]:
		for project: Dictionary in age.get("projects", []):
			if project["cost"].get("items", {}).has("dragon_scale"):
				var line: String = age["requires"][0]["line"]
				assert_string_contains(line, "scale", "age %d tells of the scale" % age["tier"])
