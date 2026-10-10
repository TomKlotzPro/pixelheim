extends GutTest
## The keepers in their buildings (PIX-283). Tom: the inn rebuilt first, Sela
## was nowhere until more of the village stood, and Vex's first brew seemed
## broken. A keeper waited for the Hamlet's age (minTownTier) as well as for
## their building, and the Hamlet comes only once all four of its buildings
## stand, so whichever was rebuilt first stood empty: no innkeeper, no Vex to
## give or take her quest, no counter. Now a keeper is in their building as
## soon as it stands, whatever the age, and their stall or tent is gone; the
## quest's lead goes where they are.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const VEX := "alchemist_vex"

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


## The townsfolk who keep a building, and trade from a stall while it's ash.
func _keepers() -> Array:
	return Npcs._data()["npcs"].filter(func(npc: Dictionary) -> bool: return npc.has("stall"))


func _ids(npcs: Array) -> Array:
	return npcs.map(func(npc: Dictionary) -> String: return npc["id"])


## Every way the village can stand at `tier`: in the Ashes each choice of
## the Hamlet's buildings rebuilt so far, later every building of its ages.
func _builds(tier: int) -> Array:
	if tier > 0:
		return [Town.projects_through(tier)]
	var hamlet: Array = Town.age(1)["projects"].map(func(entry: Dictionary) -> String: return entry["id"])
	var out := []
	for mask in 1 << hamlet.size():
		var done: Array[String] = []
		for i in hamlet.size():
			if mask & (1 << i):
				done.append(hamlet[i])
		out.append(done)
	return out


func test_every_keeper_is_in_their_building_once_it_stands_at_every_age() -> void:
	assert_eq(_keepers().size(), 4, "Odo, Hilda, Vex and Sela")
	for tier in range(Town.MAX_TIER + 1):
		for done: Array in _builds(tier):
			var on_square := _ids(Npcs.on_map("town", tier, [], done))
			for keeper: Dictionary in _keepers():
				var stall: Dictionary = keeper["stall"]
				var built: bool = stall["project"] in done
				var inside := _ids(Npcs.on_map(keeper["mapId"], tier, [], done))
				var at := "%s at age %d with %s built" % [keeper["id"], tier, done]
				assert_eq(keeper["id"] in inside, built, "%s: in their building exactly when it stands" % at)
				assert_eq(keeper["id"] in on_square, not built, "%s: at their stall exactly while it's ash" % at)
				var spot := Vector2i(int(stall["x"]), int(stall["y"]))
				if keeper["id"] == "innkeeper":
					assert_eq(Town.ashes_tent(done) != Vector2i(-1, -1), not built, "%s: the tent goes with the inn" % at)
				else:
					var crates := Town.stall_crates(done)
					var side := -1 if spot.x < Town.square().x else 1
					assert_eq(crates.has(spot + Vector2i(side, 0)), not built, "%s: the stall goes with it" % at)


func test_sela_is_in_her_inn_the_day_it_is_rebuilt() -> void:
	state.pack.gold = 1000
	state.pack.items["marsh_reed"] = 4
	assert_ne(state.holdings.fund_project("the_inn"), "")
	assert_eq(state.town_tier(), 0, "still the Ashes: the store, the forge and the brewery are rubble")
	var done := Town.done_projects(state.settlement)
	assert_has(_ids(Npcs.on_map("town_inn", 0, [], done)), "innkeeper", "Sela behind her counter")
	assert_does_not_have(_ids(Npcs.on_map("town", 0, [], done)), "innkeeper", "her tent struck")
	assert_has(_ids(Npcs.on_map("town", 0, [], done)), VEX, "Vex still at her stall")


func test_without_the_buildings_a_keeper_waits_for_the_age_as_before() -> void:
	assert_does_not_have(_ids(Npcs.on_map("town_inn", 0, [])), "innkeeper")
	assert_has(_ids(Npcs.on_map("town_inn", 1, [])), "innkeeper")


func test_vex_stands_where_the_buildings_put_her() -> void:
	var at_stall := Npcs.by_id(VEX, [], [])
	assert_eq([at_stall["mapId"], int(at_stall["x"]), int(at_stall["y"])], ["town", 34, 27], "her stall on the square")
	var inside := Npcs.by_id(VEX, [], ["vexs_brewery"])
	assert_eq([inside["mapId"], int(inside["x"]), int(inside["y"])], ["town_alchemist", 8, 2], "her room")
	assert_eq(Npcs.by_id(VEX, [])["mapId"], "town_alchemist", "without the buildings, where she lives")
	assert_eq(Npcs.keeper_of("town_alchemist")["id"], VEX)
	assert_true(Npcs.keeper_of("town_hall").is_empty(), "the mayor keeps no stall")


## The quest's lead (the line above the dock, the arrow, the map) goes to
## Vex and her cauldron where they are: her stall on the square while her
## house is ash (it led to the ruin's shut door), her room once it stands.
func test_the_first_brew_leads_to_vex_where_she_works() -> void:
	state.questing.resolve_quests(VEX)
	state.progression.tracked = "herbs_for_vex"
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"], lead["who"]], ["town", Vector2i(34, 27), VEX], "brewed at her stall")
	state.settlement.projects.assign(["vexs_brewery"])
	lead = Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"]], ["town_alchemist", Bearing.NOWHERE], "at her cauldron once it stands")
	state.progression.quests["herbs_for_vex"]["progress"] = 1
	lead = Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_string_contains(lead["step"], "Hand it in to")
	assert_eq([lead["map_id"], lead["cell"]], ["town_alchemist", Vector2i(8, 2)], "to Vex in her room")
	state.settlement.projects.clear()
	lead = Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"]], ["town", Vector2i(34, 27)], "to Vex at her stall")


## And it brews at every stage: at her stall's counter while the house is
## ash, at the cauldron in her room once it stands, before or after the
## Hamlet; the quest finishes with it.
func test_the_first_brew_brews_at_every_stage() -> void:
	for built: bool in [false, true]:
		state = autofree(GameStateScript.new())
		state.new_game("Robin", "warrior")
		state.roll = func() -> float: return 0.99
		state.questing.resolve_quests(VEX)
		if built:
			state.settlement.projects.assign(["vexs_brewery"])
			state.world.map_id = Npcs.by_id(VEX, [], Town.done_projects(state.settlement))["mapId"]
		else:
			state.world.map_id = "town"
			state.trade.stall_shop = Economy.station_shop("alchemy")
		state.pack.add_item("forest_herb")
		state.pack.add_item("marsh_reed")
		assert_true(state.trade.craft("brew_potion_hp")["made"], "brewed (her house built: %s)" % built)
		state.trade.stall_shop = ""
		state.questing.resolve_quests(VEX)
		assert_true(state.progression.quests["herbs_for_vex"]["done"], "handed in (her house built: %s)" % built)
