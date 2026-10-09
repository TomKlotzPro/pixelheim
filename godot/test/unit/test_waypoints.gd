extends GutTest
## Fast travel's choice on the map screen (PIX-241): the list starts on a
## waypoint where the hero is, the choice wraps, the ring goes round the
## chosen marker and breathes (still with reduce motion), and the tag naming
## it and its region stays on the map.


func _waypoint(id: String) -> Dictionary:
	for waypoint: Dictionary in Interactables.waypoints():
		if waypoint["id"] == id:
			return waypoint
	return {}


func _usable(ids: Array) -> Array:
	return ids.map(func(id: String) -> Dictionary: return _waypoint(id))


func test_the_ring_goes_round_the_waypoints_marker() -> void:
	var gate := _waypoint("town_gate")
	assert_eq(Waypoints.cell(gate), Vector2i(48, 42), "on the gate the map marks")
	assert_eq(Waypoints.landing(gate), Vector2i(48, 40), "where the hero is set down")


func test_the_list_starts_where_the_hero_is() -> void:
	var usable := _usable(["town_gate", "mountain_gate", "town_square"])
	assert_eq(Waypoints.first_on(usable, "overworld"), 0, "the first on the hero's map, as before")
	assert_eq(Waypoints.first_on(usable, "town"), 2, "the square, in town")
	assert_eq(Waypoints.first_on(usable, "deepwood"), -1, "none chosen: the map opens on where you are")
	assert_eq(Waypoints.first_on([], "overworld"), -1)


func test_the_choice_moves_and_wraps() -> void:
	assert_eq(Waypoints.step(0, 1, 5), 1)
	assert_eq(Waypoints.step(4, 1, 5), 0, "down from the last wraps to the first")
	assert_eq(Waypoints.step(0, -1, 5), 4, "up from the first wraps to the last")
	assert_eq(Waypoints.step(-1, 1, 5), 0, "none chosen: down takes the first")
	assert_eq(Waypoints.step(-1, -1, 5), 4, "none chosen: up takes the last")
	assert_eq(Waypoints.step(-1, 1, 0), -1, "nothing to choose")


func test_every_waypoint_has_its_marker_on_its_map() -> void:
	for waypoint: Dictionary in Interactables.waypoints():
		var map := MapData.load_by_id(waypoint["mapId"])
		var at := Waypoints.cell(waypoint)
		assert_true(at.x >= 0 and at.y >= 0 and at.x < map.size.x and at.y < map.size.y, "%s on its map" % waypoint["id"])
		assert_true(map.is_walkable(Waypoints.landing(waypoint)), "%s sets you down on open ground" % waypoint["id"])


func test_the_region_you_land_in() -> void:
	var overworld := MapData.load_by_id("overworld")
	assert_eq(Waypoints.region_of(_waypoint("mountain_gate"), overworld), "ash", "the mountain's foot is the Ash Fields")
	assert_eq(Waypoints.region_of(_waypoint("undermountain_cave"), overworld), "ash")
	assert_eq(Waypoints.region_of(_waypoint("deepwood_pass"), overworld), "forest", "the pass a step from the woods")
	assert_eq(Waypoints.region_of(_waypoint("mirefen_pass"), overworld), "marsh")
	assert_eq(Waypoints.region_of(_waypoint("town_gate"), overworld), "", "open ground by the gate")
	assert_eq(Waypoints.region_of(_waypoint("town_square"), MapData.load_by_id("town")), "", "the town has no wilds")
	var named := Waypoints.region_name(_waypoint("mountain_gate"), overworld)
	assert_eq(named, named.left(1).to_upper() + named.substr(1), "a line of its own starts with a capital")
	assert_string_contains(named.to_lower(), String(Bestiary.region("ash")["name"]).to_lower())
	assert_eq(Waypoints.region_name(_waypoint("town_gate"), overworld), "", "no region, no line")


func test_the_ring_breathes_but_holds_still_with_reduce_motion() -> void:
	assert_eq(Waypoints.ring_grow(0, false), Waypoints.PULSE_PX, "widest the moment it's chosen")
	assert_eq(Waypoints.ring_grow(Waypoints.PULSE_MS / 2, false), 0, "drawn in half a breath later")
	var sizes := {}
	for ms in range(0, Waypoints.PULSE_MS * 2, 25):
		var grow := Waypoints.ring_grow(ms, false)
		assert_eq(grow % 2, 0, "whole pixels of the UI's grid")
		assert_between(grow, 0, Waypoints.PULSE_PX)
		sizes[grow] = true
	assert_gt(sizes.size(), 2, "it breathes")
	for ms in [0, 300, 600, 900, 1234]:
		assert_eq(Waypoints.ring_grow(ms, true), Waypoints.STEADY_PX, "still with reduce motion")


func test_the_tag_stays_on_the_map() -> void:
	var bounds := Vector2(672, 448)
	var tag := Vector2(200, 50)
	var above := Waypoints.tag_at(Vector2(336, 280), 20, tag, bounds)
	assert_eq(above, Vector2(236, 206), "centred over the ring, clear of it")
	var below := Waypoints.tag_at(Vector2(336, 45), 20, tag, bounds)
	assert_eq(below.y, 45.0 + 20 + Waypoints.TAG_GAP, "under the ring when there's no room above")
	var left := Waypoints.tag_at(Vector2(3, 227), 20, tag, bounds)
	assert_eq(left.x, Waypoints.TAG_GAP, "kept in at the map's left edge")
	var right := Waypoints.tag_at(Vector2(669, 227), 20, tag, bounds)
	assert_eq(right.x, bounds.x - tag.x - Waypoints.TAG_GAP, "and at its right edge")
