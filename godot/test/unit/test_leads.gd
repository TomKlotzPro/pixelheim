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
	assert_eq(lead["place"], Atlas.region_title(region, map), "%s: the place is its region, by the name the map gives it" % what)
	assert_string_contains(Bearing.line(lead), lead["place"], "%s: the line names it" % what)


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
	# A main step that waits on such a quest, the quest in hand and not
	# followed (A First Brew said to brew at Vex's, its mark in the marsh).
	for step: Dictionary in MainQuest.steps():
		if step["when"]["kind"] != "questDone" or step["when"]["questId"] not in checked:
			continue
		var quest := Quests.by_id(step["when"]["questId"])
		state.progression.quests = {quest["id"]: {"progress": 0, "done": false}}
		var lead := Bearing.of_step(step, state.progression, state.settlement, {})
		_assert_leads_to_where_it_grows(lead, Bearing.of_quest(quest, state.progression, state.settlement, {})["gather"], step["id"])
		checked.append(step["id"])
	for id: String in ["herbs_for_vex", "iva_reeds", "hildas_buckler", "rebuild", "first_brew"]:
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


## A First Brew on the main path, taken and not followed: the herb, then
## the reed, each by name and place, and only then Vex's cauldron.
func test_the_first_brew_says_what_to_gather_before_it_says_to_brew() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.progression.quests["herbs_for_vex"] = {"progress": 0, "done": false}
	var brew := MainQuest.step("first_brew")
	var lead := Bearing.of_step(brew, state.progression, state.settlement, {})
	assert_eq(Bearing.line(lead), "To gather: Forest Herb\u00a0- The Whispering Forest (0/1)")
	lead = Bearing.of_step(brew, state.progression, state.settlement, {"forest_herb": 1})
	assert_eq(Bearing.line(lead), "To gather: Marsh Reed\u00a0- The Sunken Marsh (0/1)")
	assert_eq([lead["gather"], lead["region"], lead["main"]], ["marsh_reed", "marsh", true], "the HUD and the map are told")
	lead = Bearing.of_step(brew, state.progression, state.settlement, {"forest_herb": 1, "marsh_reed": 1})
	assert_eq([lead["step"], lead["gather"], lead["map_id"]], [brew["text"], "", "town"], "with both, to Vex")


## The ash healed round a lamp is the Greening on the map (PIX-325): the
## line of what grows there says the Greening too.
func test_healed_ash_is_named_as_the_map_names_it() -> void:
	var saved := [GameState.settlement.projects.duplicate(), GameState.post, GameState.world.steps]
	GameState.post = PostState.new()
	GameState.world.steps = 20 * DayNight.DAY_CYCLE_STEPS + 100.0
	GameState.settlement.projects.assign(Town.done_projects(GameState.settlement) + ["waystation_blackiron"])
	GameState.post.lit["blackiron"] = Gathering.day_of(GameState.world.steps) - Lamps.REACH
	var reach := MapData.load_by_id(Routes.MAP)
	assert_gte(Lamps.healed_on(reach), 50, "a whole ring healed")
	var lead := Bearing._blank("", "")
	assert_eq(Bearing._at_growth(lead, {"ember_shard": 2}, {}), "ember_shard")
	assert_eq([lead["place"], Atlas.region_title("ash", reach)], ["The Greening", "The Greening"])
	assert_string_contains(Bearing.line(lead), "The Greening")
	# And so do the cards (the board's, Vex's, the bestiary's): one name.
	assert_eq(Economy.growing_lines({"ember_shard": 8}, {}), ["Ember Shard: the Greening."] as Array[String])
	assert_string_contains(Economy.where_to_find("ember_shard"), "in the Greening")
	assert_has(Bestiary.where_found("wolf"), "the Greening by night")
	GameState.settlement.projects.assign(saved[0])
	GameState.post = saved[1]
	GameState.world.steps = saved[2]


## The board's card says where what it asks grows, the place alone (the
## inn's card in French ran past its box with the whole sentence), while
## the pack is short of it.
func test_the_boards_card_names_where_its_reeds_grow() -> void:
	var asked: Dictionary = Town.project("the_inn")["cost"]["items"]
	assert_eq(Economy.growing_lines(asked, {}), ["Marsh Reed: the Sunken Marsh."] as Array[String])
	assert_eq(Economy.growing_lines(asked, {"marsh_reed": 4}), [] as Array[String], "with the reeds, nothing more to say")
	assert_eq(Economy.growing_lines({"wolf_pelt": 1}, {}), [] as Array[String], "no patch grows a pelt")


## A place a card names can be found on the map (PIX-560): every region a
## material's leads can name for what grows is one its map's page writes,
## walked or not - a region of the Ashenreach by its own name there, any
## other as its map, which the page names or is titled (« la côte de
## Saltmere » on Saltmere).
func test_every_region_a_card_names_for_what_grows_is_on_the_map() -> void:
	var ground: Dictionary = Bestiary.gathering_rules()["ground"]
	var materials: Dictionary = Bestiary.region_materials()
	for region: String in ground:
		var forage: Array = Economy.material_sources(materials[region]).filter(func(lead: Dictionary) -> bool: return lead["kind"] == "forage")
		assert_eq(forage.size(), 1, "%s's material is foraged" % region)
		var said := Lamps.said(region)
		assert_string_contains(forage[0]["text"], said, "%s named on the card" % region)
		var home := Economy.grows_at(materials[region])
		var map := MapData.load_by_id(home["mapId"])
		for map_id: String in Economy.MAP_STAGE:
			if not Depths.is_planned(map_id) and region in MapData.load_by_id(map_id).regions.values():
				map = MapData.load_by_id(map_id)
				break
		if Atlas.names_regions(map):
			var written: Array = Atlas.labels(map, {}).map(func(label: Dictionary) -> String: return Text.mid(label["text"]))
			assert_has(written, said, "%s written on a page never walked" % region)
		else:
			var place := Text.mid(Catalog.place_name(map.id)).trim_prefix("the ").to_lower()
			assert_string_contains(said.to_lower(), place, "%s is its map, by the page's name" % region)


## A material with two homes grows in one a day (frost lily: the pass, then
## the ice cave). On the pass's off day nothing grew there, which isn't
## "all picked"; on its day the patch leads, and picked, it is.
func test_a_day_that_grew_none_here_is_not_all_picked() -> void:
	var decks := Gathering.decks(MapData.load_by_id("frostgate"))
	var world := WorldState.new()
	var seen := {}
	for day in range(2, 4):
		world.steps = day * DayNight.DAY_CYCLE_STEPS + 1.0
		world.gathered_at = {}
		var patches := Gathering.patches_on(decks, day)
		var today := Gathering.nearest_ready(patches, "frost_lily", world, Vector2i.ZERO)
		seen[today["grew"]] = true
		assert_eq(today["cell"] != Bearing.NOWHERE, today["grew"], "day %d: a patch leads where one grew" % day)
		for cell: Vector2i in patches:
			world.gathered_at[patches[cell]["id"]] = int(world.steps)
		today = Gathering.nearest_ready(patches, "frost_lily", world, Vector2i.ZERO)
		assert_eq(today["cell"], Bearing.NOWHERE, "day %d: picked, none leads" % day)
	assert_eq(seen.size(), 2, "one of two days grows none on the pass")
