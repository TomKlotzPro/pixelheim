extends GutTest
## Wild packs with homes (PIX-142): a leash around the home, sight that walls
## block, a ledger that keeps a cleared pack down for a while (not just until
## the next door), and homes kept clear of every place a hero arrives.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const TILE := 16.0

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_a_monster_wanders_its_leash_and_turns_home_past_it() -> void:
	var home := Vector2(100, 100)
	assert_eq(Packs.wander_dir(home, home + Vector2(2 * TILE, 0), Vector2.RIGHT), Vector2.RIGHT, "inside: any way")
	assert_eq(Packs.wander_dir(home, home + Vector2(4 * TILE, TILE), Vector2.RIGHT), Vector2.LEFT, "past it: home")
	assert_eq(Packs.wander_dir(home, home + Vector2(0, -4 * TILE), Vector2.ZERO), Vector2.DOWN)


func test_notice_is_close_and_a_chase_has_a_limit() -> void:
	var home := Vector2(100, 100)
	assert_true(Packs.within_notice(home, home + Vector2(5 * TILE, 0)))
	assert_false(Packs.within_notice(home, home + Vector2(5 * TILE + 1, 0)))
	assert_false(Packs.gives_up(home, home + Vector2(3 * TILE, 0), home + Vector2(6 * TILE, 0)))
	assert_true(Packs.gives_up(home, home + Vector2(9 * TILE, 0), home + Vector2(10 * TILE, 0)), "too far from home")
	assert_true(Packs.gives_up(home, home, home + Vector2(9 * TILE, 0)), "the hero got away")


func test_walls_block_sight_and_water_does_not() -> void:
	var map := MapData.new()
	for x in 10:
		for y in 3:
			map.grid[Vector2i(x, y)] = "grass"
	map.grid[Vector2i(4, 1)] = "wall"
	map.grid[Vector2i(4, 0)] = "water"
	assert_false(Packs.can_see(map, Vector2i(1, 1), Vector2i(8, 1)), "a wall between")
	assert_true(Packs.can_see(map, Vector2i(1, 0), Vector2i(8, 0)), "water lets the eye across")
	map.covered[Vector2i(4, 2)] = true
	assert_false(Packs.can_see(map, Vector2i(1, 2), Vector2i(8, 2)), "a house or a bush the art covers")
	assert_true(Packs.can_see(map, Vector2i(4, 1), Vector2i(8, 1)), "standing in a doorway, it still sees out")


func test_a_cleared_pack_stays_down_until_its_time_or_the_inn() -> void:
	state.world.steps = 100.0
	state.spoils.clear_pack("forest_1")
	assert_true(Packs.is_down(state.world, "forest_1"))
	state.world.steps = 599.0
	assert_true(Packs.is_down(state.world, "forest_1"))
	state.world.steps = 600.0
	assert_false(Packs.is_down(state.world, "forest_1"))
	assert_true(Packs.is_due(state.world, "forest_1"), "due: it comes home once out of sight")
	state.spoils.revive_pack("forest_1")
	assert_false(Packs.is_due(state.world, "forest_1"))
	assert_eq(state.world.slain, [] as Array[String])


func test_a_door_keeps_the_ledger_and_only_a_night_at_the_inn_clears_it() -> void:
	state.spoils.clear_pack("forest_1")
	state.move_to(MapData.load_by_id("town"), Vector2i(40, 30), Vector2.DOWN)
	state.move_to(MapData.load_by_id("overworld"), Vector2i(48, 40), Vector2.UP)
	assert_true(Packs.is_down(state.world, "forest_1"), "no free respawn through a door")
	state.hero.hp = 1
	state.pack.gold = 100
	state.upkeep.rest_at_inn()
	assert_eq(state.world.slain, [] as Array[String])
	# A fall is no night's rest (PIX-206): the wilds stay as they were.
	state.spoils.clear_pack("ash_1")
	state.upkeep.wake_at_inn()
	assert_eq(state.world.slain, ["ash_1"] as Array[String], "waking there after a fall wakes nothing")


func test_the_ledger_keeps_its_steps_in_the_save() -> void:
	var bare := {}
	state.world.write_into(bare)
	assert_false(bare["world"].has("slainAt"), "saves without it stay byte for byte")
	state.world.steps = 42.0
	state.spoils.clear_pack("marsh_2")
	var saved := {}
	state.world.write_into(saved)
	assert_eq(saved["world"]["slainAt"], {"marsh_2": 42})
	var back := WorldState.from_dict(saved)
	assert_eq(back.slain_at, {"marsh_2": 42})
	saved["world"].erase("slainAt")
	saved["worldSteps"] = 10
	var old := WorldState.from_dict(saved)
	assert_true(Packs.is_due(old, "marsh_2"), "a pack an old save kept down is long due")


func test_no_home_is_near_where_a_hero_arrives() -> void:
	var safe := float(Packs.rules()["safeTiles"])
	var maps := {}
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if not maps.has(spawn["mapId"]):
			var map := MapData.load_by_id(spawn["mapId"])
			MapView.new(map, null).plan(map.spawn)
			maps[spawn["mapId"]] = map
	var arrivals := _arrivals(maps.keys())
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		var map: MapData = maps[spawn["mapId"]]
		var home := Vector2i(spawn["x"], spawn["y"])
		assert_true(map.is_walkable(home), "%s's home is open ground" % spawn["id"])
		assert_ne(map.region_at(home), "", "%s's home is in a region" % spawn["id"])
		for arrival: Vector2i in arrivals[spawn["mapId"]]:
			var gap := maxi(absi(home.x - arrival.x), absi(home.y - arrival.y))
			assert_true(gap >= safe, "%s is %d tiles from an arrival at %s" % [spawn["id"], gap, arrival])


## Every cell a hero can appear on, per map: its spawn, its doors, where
## other maps' doors and the waypoints set them down.
func _arrivals(map_ids: Array) -> Dictionary:
	var out := {}
	for map_id: String in map_ids:
		var map := MapData.load_by_id(map_id)
		var cells: Array[Vector2i] = [map.spawn]
		cells.append_array(map.portals.keys())
		out[map_id] = cells
	var dir := DirAccess.open("res://assets/maps")
	for file in dir.get_files():
		if not file.ends_with(".json") or file == "interactables.json" or file.contains("@"):
			continue
		var other := MapData.load_by_id(file.get_basename())
		for target: Dictionary in other.portals.values():
			if target.get("kind") == "map" and out.has(target["mapId"]):
				out[target["mapId"]].append(Vector2i(target["x"], target["y"]))
	for waypoint: Dictionary in Interactables._data()["waypoints"]:
		if out.has(waypoint["mapId"]):
			out[waypoint["mapId"]].append(Vector2i(waypoint["arrival"]["x"], waypoint["arrival"]["y"]))
	return out
