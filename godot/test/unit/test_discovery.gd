extends GutTest
## Fog bookkeeping must match discover.ts: a 5x5 window, clipped at edges,
## and what was seen stays seen.

var map: MapData


func before_all() -> void:
	map = MapData.load_by_id("overworld")


func test_open_ground_reveals_a_five_by_five_window() -> void:
	var discovered := {}
	Discovery.discover_around(discovered, map, Vector2i(48, 38))
	assert_eq(discovered["overworld"].size(), 25)
	assert_true(Discovery.is_discovered(discovered, "overworld", Vector2i(46, 36)))
	assert_false(Discovery.is_discovered(discovered, "overworld", Vector2i(45, 38)))


func test_map_corners_clip_the_window() -> void:
	var discovered := {}
	Discovery.discover_around(discovered, map, Vector2i.ZERO)
	assert_eq(discovered["overworld"].size(), 9)


func test_seen_tiles_accumulate_across_steps() -> void:
	var discovered := {}
	Discovery.discover_around(discovered, map, Vector2i(48, 38))
	Discovery.discover_around(discovered, map, Vector2i(49, 38))
	assert_eq(discovered["overworld"].size(), 30)
	assert_false(Discovery.is_discovered(discovered, "town", Vector2i(48, 38)))


func test_waypoints_unlock_by_discovery_and_staffing() -> void:
	var gate: Dictionary = Interactables.waypoints()[0]
	assert_eq(gate["id"], "town_gate")
	var discovered := {}
	assert_false(Interactables.waypoint_discovered(gate, discovered))
	Discovery.discover_around(discovered, map, Vector2i(48, 40))
	assert_true(Interactables.waypoint_discovered(gate, discovered))
	assert_true(Interactables.waypoint_usable(gate, discovered, []))
	var square: Dictionary = Interactables.waypoints().filter(func(waypoint: Dictionary) -> bool: return waypoint["id"] == "town_square")[0]
	assert_eq(square["requiresSettler"], "settler_wren")
	var town := MapData.load_by_id("town")
	var town_seen := {}
	Discovery.discover_around(town_seen, town, Vector2i(40, 27))
	assert_false(Interactables.waypoint_usable(square, town_seen, []))
	assert_true(Interactables.waypoint_usable(square, town_seen, ["settler_wren"]))


func test_every_waypoint_arrival_is_walkable_near_its_marker() -> void:
	for waypoint: Dictionary in Interactables.waypoints():
		var target := MapData.load_by_id(waypoint["mapId"])
		var arrival := Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"]))
		assert_true(target.is_walkable(arrival), "%s arrival blocked" % waypoint["id"])
