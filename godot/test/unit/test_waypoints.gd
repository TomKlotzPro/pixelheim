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
	assert_eq(Waypoints.first_on(usable, "deepwood"), 0, "none in the Deepwood: the first on the Reach's page it's drawn on (PIX-269)")
	assert_eq(Waypoints.first_on(usable, "cellars"), -1, "none chosen: the map opens on where you are")
	assert_eq(Waypoints.first_on([], "overworld"), -1)
	assert_eq(Waypoints.first_on_page(_usable(["town_square", "saltmere_hamlet"]), "overworld"), 1, "Saltmere's is on the Reach's page")
	assert_eq(Waypoints.first_on_page(usable, "seacave"), -1)


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
	var greyhold := MapData.load_by_id("greyhold")
	assert_eq(Waypoints.region_of(_waypoint("greyhold_camp"), greyhold), "castle")
	assert_eq(Waypoints.region_name(_waypoint("greyhold_camp"), greyhold), "", "a map of one region: the place is the region, said once")


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


## Fast travel for the grown Reach (PIX-266): no trip back to a region is a
## long empty walk. At about six tiles a second this is some five seconds.
const REACH := 30


## Steps from `from` to every cell a walk on `map` reaches.
func _walks(map: MapData, from: Vector2i) -> Dictionary:
	var steps := {from: 0}
	var queue: Array[Vector2i] = [from]
	var at := 0
	while at < queue.size():
		var cell := queue[at]
		at += 1
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if not steps.has(next) and map.is_walkable(next):
				steps[next] = int(steps[cell]) + 1
				queue.append(next)
	return steps


## The fewest steps from `from` on `map` to the landing of a waypoint there.
func _nearest(map: MapData, from: Vector2i) -> int:
	var walks := _walks(map, from)
	var best := 1 << 20
	for waypoint: Dictionary in Interactables.waypoints():
		if waypoint["mapId"] == map.id:
			best = mini(best, int(walks.get(Waypoints.landing(waypoint), 1 << 20)))
	return best


func test_every_waypoint_stands_on_open_ground_a_walk_reaches() -> void:
	for waypoint: Dictionary in Interactables.waypoints():
		var map := MapData.load_by_id(waypoint["mapId"])
		var landing := Waypoints.landing(waypoint)
		assert_true(map.is_walkable(landing), "%s sets you down on open ground" % waypoint["id"])
		assert_true(_walks(map, map.spawn).has(landing), "%s: a walk in from %s's way in reaches it" % [waypoint["id"], map.id])
		# It's found on foot: standing where it sets you down, you see its mark.
		var at := Waypoints.cell(waypoint)
		assert_lte(maxi(absi(at.x - landing.x), absi(at.y - landing.y)), Discovery.SIGHT_RADIUS, "%s is seen from its landing" % waypoint["id"])


func test_every_wild_region_has_a_waypoint_near_its_way_in() -> void:
	var overworld := MapData.load_by_id("overworld")
	# A road out is several cells wide since PIX-269, every one a door: count
	# the regions they lead to, and check each cell of each road.
	var regions := {}
	for door: Vector2i in overworld.portals:
		var to: Dictionary = overworld.portals[door]
		if to["kind"] != "map" or to["mapId"] == "town":
			continue
		regions[to["mapId"]] = true
		var region := MapData.load_by_id(to["mapId"])
		# One in the region, from where the road comes in; or one on the
		# Ashenreach by the road's end, a step from it.
		var inside := _nearest(region, Vector2i(int(to["x"]), int(to["y"])))
		var outside := _nearest(overworld, door) + 1
		assert_lte(mini(inside, outside), REACH, "%s: a waypoint within %d steps of its way in (%d inside, %d outside)" % [region.id, REACH, inside, outside])
	assert_eq(regions.size(), 6, "the Reach's six roads out")


func test_every_camp_and_cave_mouth_is_a_short_walk_from_a_waypoint() -> void:
	for map_id: String in ["saltmere", "blackiron", "frostgate", "greyhold"]:
		var map := MapData.load_by_id(map_id)
		for villager: Dictionary in Npcs.on_map(map_id, Town.MAX_TIER, []):
			var at := Vector2i(int(villager["x"]), int(villager["y"]))
			assert_lte(_nearest(map, at), REACH, "%s: %s's post near a waypoint" % [map_id, villager["id"]])
		for door: Vector2i in map.portals:
			var to: Dictionary = map.portals[door]
			if to["kind"] == "map" and to["mapId"] != "overworld":
				assert_lte(_nearest(map, door), REACH, "%s: the way down to %s near a waypoint" % [map_id, to["mapId"]])


## A square drawn on the map, on the screen (`shown`: the map's px to the
## screen's).
func _on_screen(square: Rect2, shown: Transform2D) -> Rect2:
	return Rect2(shown * square.position, square.size * shown.get_scale().x)


func _whole(value: float) -> bool:
	return absf(value - roundf(value)) < 0.001


## The window's stretch (none, a browser's uneven ones in full screen, a big
## screen's) and where the page stands on it (whole or not).
func _screens() -> Array[Transform2D]:
	var out: Array[Transform2D] = []
	for scale: float in [1.0, 1.25, 4.0 / 3.0, 1.5, 1.6875, 2.0, 2.25]:
		for origin: Vector2 in [Vector2(70, 86), Vector2(70.4, 86.75), Vector2(105.3, 157.5)]:
			out.append(Transform2D(0.0, Vector2(scale, scale), 0.0, origin))
	return out


func test_the_ring_and_its_marker_share_a_middle_at_every_step_of_the_breath() -> void:
	# PIX-267: in a full-screen browser the red marker sat a pixel off the
	# middle of its gold ring.
	var grows := {}
	for ms in range(0, Waypoints.PULSE_MS, 10):
		grows[Waypoints.ring_grow(ms, false)] = true
	grows[Waypoints.STEADY_PX] = true
	assert_eq(grows.size(), Waypoints.PULSE_PX / 2 + 1, "every step of the breath")
	for shown in _screens():
		for px: int in [7, 9, 11, 12]:
			var center := Waypoints.mark_at(Vector2i(48, 6), px)
			var mark := maxf(px * 1.6, 6.0)
			var off := []
			var middle := Vector2.INF
			for grow: int in grows:
				if grow % 2 != 0:
					off.append("grow %d isn't an even step" % grow)
				var squares: Array[Rect2] = Waypoints.ring_squares(center, mark, grow, shown)
				squares.append_array(Waypoints.marker_squares(center, mark, shown))
				for index in squares.size():
					var drawn := _on_screen(squares[index], shown)
					if middle == Vector2.INF:
						middle = drawn.get_center()
					if not (_whole(drawn.position.x) and _whole(drawn.position.y) and _whole(drawn.end.x) and _whole(drawn.end.y)):
						off.append("grow %d square %d %s not on whole pixels" % [grow, index, drawn])
					if not drawn.get_center().is_equal_approx(middle):
						off.append("grow %d square %d about %s, not %s" % [grow, index, drawn.get_center(), middle])
					# The ring's edges nest, and so do the marker's (at its
					# smallest the ring's inner dark line lies on the marker's
					# dark rim).
					if index > 0 and index != 4 and not _on_screen(squares[index - 1], shown).encloses(drawn):
						off.append("grow %d square %d not inside the one before" % [grow, index])
				if not _on_screen(squares[2], shown).encloses(_on_screen(squares[5], shown)):
					off.append("grow %d: the marker's colour isn't inside the ring's gold" % grow)
			assert_eq(off, [], "stretched by %s from %s, %d px a tile: one middle, whole pixels" % [shown.get_scale().x, shown.origin, px])


func test_the_marker_stands_on_its_cell() -> void:
	for shown in _screens():
		for px: int in [7, 9, 11, 12]:
			for waypoint: Dictionary in Interactables.waypoints():
				var cell := Waypoints.cell(waypoint)
				var middle := Waypoints.snap_point(Waypoints.mark_at(cell, px), shown)
				assert_true(Rect2(Vector2(cell * px), Vector2(px, px)).has_point(middle), "%s at %d px a tile, stretched by %s" % [waypoint["id"], px, shown.get_scale().x])
