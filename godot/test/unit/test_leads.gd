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


var _decks := {}


## The lead of something that asks for `item_id`, a thing patches grow
## (PIX-560): it sends the hero to a map with a page of its own, to ground
## its patches grow on, in a region that grows some every day, under the
## name the map writes over that region, and the line above the dock says so.
func _assert_leads_to_where_it_grows(lead: Dictionary, item_id: String, what: String) -> void:
	assert_eq(lead["gather"], item_id, "%s: it says what to gather" % what)
	assert_has(Atlas.ORDER, lead["map_id"], "%s: on a map with a page" % what)
	var map := MapData.load_by_id(lead["map_id"])
	var region := map.region_at(lead["cell"])
	assert_eq(lead["region"], region, "%s: the mark stands in the region it names" % what)
	assert_eq(Bestiary.region_materials().get(region, ""), item_id, "%s: where it grows" % what)
	assert_gt(Gathering.daily_in(region), 0.0, "%s: some of it every day" % what)
	if not _decks.has(map.id):
		_decks[map.id] = Gathering.decks(map)
	assert_has(_decks[map.id].get(region, []), lead["cell"], "%s: on ground a patch may grow on" % what)
	assert_eq(lead["place"], Atlas.region_title(region), "%s: the place is its region" % what)
	assert_string_contains(Bearing.line(lead), Atlas.region_title(region, map), "%s: by the name the map gives it" % what)


## PIX-560: the newcomer needed four Marsh Reeds for the inn and nothing on
## the main path said where they grow. Every quest that asks for something
## a patch grows (to hand over, or to craft with), and every project of the
## main story that does, leads to where it grows while the pack lacks it.
func test_what_asks_for_a_gathered_thing_leads_to_where_it_grows() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	var grown := func(item_id: String) -> bool: return not Economy.grows_at(item_id).is_empty()
	var checked: Array[String] = []
	for quest: Dictionary in Quests.all():
		var objective: Dictionary = quest["objective"]
		var needs := {}
		if objective["kind"] == "deliver" and not Interactables._data()["chests"].any(func(chest: Dictionary) -> bool: return chest.get("loot", {}).get("itemId", "") == objective["itemId"]):
			needs = {objective["itemId"]: 1}
		elif objective["kind"] == "craft":
			needs = Economy.recipes().filter(func(entry: Dictionary) -> bool: return entry["itemId"] == objective["itemId"])[0]["needs"]
		var asked: Array = needs.keys().filter(grown)
		if asked.is_empty():
			continue
		_assert_leads_to_where_it_grows(Bearing.of_quest(quest, state.progression, state.settlement, {}), asked[0], quest["id"])
		checked.append(quest["id"])
	for step: Dictionary in MainQuest.steps():
		if step["when"]["kind"] != "project":
			continue
		var asked: Array = Town.project(step["when"]["projectId"])["cost"]["items"].keys().filter(grown)
		if asked.is_empty():
			continue
		_assert_leads_to_where_it_grows(Bearing.of_step(step, state.progression, state.settlement, {}), asked[0], step["id"])
		checked.append(step["id"])
	for id: String in ["herbs_for_vex", "iva_reeds", "hildas_buckler", "rebuild"]:
		assert_has(checked, id, "the reeds' askers are among them")


func test_the_reeds_lead_to_the_marsh_until_the_pack_has_them() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	var inn := MainQuest.step("rebuild")
	var lead := Bearing.of_step(inn, state.progression, state.settlement, {"marsh_reed": 1})
	assert_eq(Bearing.line(lead), "For the board on the square: Marsh Reed - The Sunken Marsh (1/4)")
	assert_eq(lead["map_id"], "overworld", "the marsh west of the gate")
	lead = Bearing.of_step(inn, state.progression, state.settlement, {"marsh_reed": 4})
	assert_eq([lead["map_id"], lead["cell"], lead["gather"]], ["town", Town.project_board(), ""], "with the reeds, to the board")
	assert_eq(lead["step"], inn["text"])
	assert_true(Economy.grows_at("wolf_pelt").is_empty(), "no patch grows a pelt")
