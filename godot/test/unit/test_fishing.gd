extends GutTest
## Fishing beyond Saltmere (PIX-450): a spot by Pixelheim's bridge, one on
## the Deepwood lake's shore and one at a Mirefen pool, each with catches of
## its own that sell for no more than the sea's, and their fish taken
## wherever a fresh fish is asked for (Pip's cat, Ola, Vex's stew).

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


## Every spot, as its map is drawn: open ground the hero walks to from the
## map's spawn, with water beside it to face.
func test_every_spot_stands_on_reachable_ground_by_the_water() -> void:
	var maps := {}
	for spot: Dictionary in Bestiary.fishing_spots():
		var map_id: String = spot["mapId"]
		if not maps.has(map_id):
			var map := MapData.load_by_id(map_id)
			MapView.new(map, null).plan(map.spawn)
			maps[map_id] = [map, _reach(map)]
		var map: MapData = maps[map_id][0]
		var at := Vector2i(int(spot["x"]), int(spot["y"]))
		assert_true(maps[map_id][1].has(at), "%s at %s can be walked to" % [spot["id"], at])
		var sides: Array = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		assert_true(sides.any(func(side: Vector2i) -> bool: return map.tile_at(at + side) in PunyTerrain.WATERS), "%s faces water" % spot["id"])


func test_each_new_spot_has_catches_of_its_own_worth_no_more_than_the_sea() -> void:
	var sea := _worth({})
	for pair: Array in [["town_bridge", "bridge_trout"], ["deepwood_lake", "smug_pike"], ["mirefen_pool", "moss_eel"]]:
		var spot := Gathering.fishing_spot(pair[0])
		assert_eq(Gathering.catch(func() -> float: return 0.0, spot), pair[1])
		assert_lt(_worth(spot), sea, "%s pays less a cast than the sea" % pair[0])
		for entry: Array in spot["catches"]:
			assert_false(Catalog.item(entry[0]).is_empty(), entry[0])
	assert_eq(Gathering.catch(func() -> float: return 0.99, Gathering.fishing_spot("town_bridge")), "old_boot")
	# Still once, then nothing's biting.
	state.roll = func() -> float: return 0.0
	assert_eq(state.spoils.fish("deepwood_lake")["gains"]["items"][0]["id"], "smug_pike")
	assert_string_contains(state.spoils.fish("deepwood_lake")["message"], "Nothing's biting")


func test_a_new_fish_does_wherever_a_fresh_fish_is_asked() -> void:
	state.progression.quests["pip_fish"] = {"progress": 0, "done": false}
	state.pack.add_item("fresh_fish")
	state.pack.add_item("smug_pike")
	assert_false(Quests.is_ready(Quests.by_id("pip_fish"), state.progression.quests, state.pack.items))
	state.pack.add_item("moss_eel", 2)
	assert_true(Quests.is_ready(Quests.by_id("pip_fish"), state.progression.quests, state.pack.items), "the cat isn't fussy")
	state.questing.resolve_quests("kid_pip")
	assert_true(state.progression.quests["pip_fish"]["done"])
	# The fresh fish goes first, then the others as they came.
	assert_eq([Catalog.held(state.pack.items, "fresh_fish"), int(state.pack.items.get("moss_eel", 0))], [1, 1])
	var stew := Economy.recipe("brew_stew")
	var jobs := {"smithing": {"level": 1, "xp": 0}, "alchemy": {"level": 3, "xp": 0}}
	assert_true(Economy.can_craft(stew, {"bridge_trout": 1, "forest_herb": 2}, jobs), "Vex stews a trout")
	assert_eq(Economy.missing_names(stew, {"lost_hat": 1, "forest_herb": 2}), ["1 × Fresh Fish"], "but not a hat")
	var fishing: Array = Economy.material_sources("fresh_fish").filter(func(lead: Dictionary) -> bool: return lead["kind"] == "fishing")
	assert_eq(fishing.size(), 1)
	for place in ["Pixelheim", "the Mirefen"]:
		assert_string_contains(fishing[0]["text"], place, "a fresh fish's lead names the waters whose fish stand for it")


## The Frostgate's Icefin is a fish too (PIX-464: the Mirefen eel counted and
## it didn't), but a real fresh fish is still taken first.
func test_the_icefin_does_for_a_fresh_fish_but_a_fresh_fish_goes_first() -> void:
	state.pack.add_item("icefin")
	state.pack.add_item("fresh_fish")
	assert_eq(Catalog.held(state.pack.items, "fresh_fish"), 2)
	state.pack.spend("fresh_fish")
	assert_eq([int(state.pack.items.get("fresh_fish", 0)), int(state.pack.items.get("icefin", 0))], [0, 1])


## Gold a cast pays on average, by what each catch is worth.
func _worth(spot: Dictionary) -> float:
	var catches: Array = spot.get("catches", Bestiary.fishing_rules()["catches"])
	var total := 0.0
	var gold := 0.0
	for entry: Array in catches:
		total += int(entry[1])
		gold += int(entry[1]) * int(Catalog.item(entry[0]).get("value", 0))
	return gold / total


## The cells reachable on foot from the map's spawn.
func _reach(map: MapData) -> Dictionary:
	var seen := {map.spawn: true}
	var queue: Array[Vector2i] = [map.spawn]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if not seen.has(next) and map.is_walkable(next) and not map.portals.has(next):
				seen[next] = true
				queue.append(next)
	return seen
