extends GutTest
## Pixelheim rebuilt by design (PIX-198): a village on a river bend under the
## mountain. These keep the plan honest: the gate road looks straight down to
## the hall, which faces the square; every door, villager, stall and corner
## worth finding can be walked to from the gate at every age; the square's
## boards and lanterns stand on it; and the river is crossed only where a
## bridge or the dock says so.

const AGES := [0, 1, 2, 3, 4]


## Every cell reachable on foot from the gate, the way MapView lays the town
## out at `tier` (houses, props and decor covering what they cover).
func _reach(tier: int) -> Array:
	var map := MapData.load_tiered("town", Town.projects_through(tier), 1)
	MapView.new(map, null).plan(map.spawn)
	# The gate road just inside the gate (PIX-248), where the Reach sets a
	# hero down.
	var gate := Vector2i(40, 3)
	var seen := {gate: true}
	var queue: Array[Vector2i] = [gate]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if seen.has(next):
				continue
			if map.is_walkable(next) or map.portals.has(next):
				seen[next] = true
				if not map.portals.has(next):
					queue.append(next)
	return [map, seen]


func test_the_gate_road_runs_straight_to_the_hall_on_the_square() -> void:
	var map := MapData.load_by_id("town")
	assert_eq(map.tile_at(Vector2i(40, 2)), "door", "the gate")
	for y in range(3, 12):
		assert_eq(map.tile_at(Vector2i(40, y)), "path", "the gate road at (40, %d)" % y)
	var hall := Vector2i(40, 19)
	assert_true(map.portals.has(hall), "the hall's door on the road's line")
	assert_eq(map.portals[hall]["mapId"], "town_hall")
	assert_eq(map.tile_at(hall + Vector2i.DOWN), "path", "and it opens onto the square")
	var square := Town.square()
	assert_eq(square.x, hall.x, "the square's heart below the hall's door")


func test_every_door_and_villager_can_be_walked_to_from_the_gate_at_every_age() -> void:
	for tier: int in AGES:
		var found := _reach(tier)
		var map: MapData = found[0]
		var seen: Dictionary = found[1]
		for cell: Vector2i in map.portals:
			assert_true(seen.has(cell), "age %d: the door at %s" % [tier, cell])
		for npc: Dictionary in Npcs.on_map("town", tier, [], Town.projects_through(tier)):
			var home := Vector2i(int(npc["x"]), int(npc["y"]))
			assert_true(seen.has(home), "age %d: %s at %s" % [tier, npc["id"], home])


func test_the_corners_worth_finding_can_be_reached() -> void:
	var seen: Dictionary = _reach(4)[1]
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest["mapId"] == "town":
			var cell := Vector2i(int(chest["x"]), int(chest["y"]))
			var beside := [cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]
			assert_true(beside.any(func(c: Vector2i) -> bool: return seen.has(c)), "the chest %s" % chest["id"])
	assert_true(seen.has(Vector2i(40, 36)), "the end of the dock")
	assert_true(seen.has(Vector2i(78, 21)), "the farms across the bridge")
	assert_true(seen.has(Vector2i(10, 6)) or seen.has(Vector2i(10, 7)), "the shrine yard")


func test_the_river_is_crossed_only_by_the_bridge_and_the_dock() -> void:
	var map := MapData.load_by_id("town")
	var crossings := 0
	for y in map.size.y:
		var row := ""
		for x in range(64, 73):
			row += map.tile_at(Vector2i(x, y)).left(1)
		if "b" in row:
			crossings += 1
	assert_eq(crossings, 2, "the bridge is two cells wide, one crossing")
	for x in range(3, 66):
		var south: String = map.tile_at(Vector2i(x, 37))
		assert_eq(south, "water", "the bend at (%d, 37) keeps the far bank out of reach" % x)


func test_the_squares_boards_and_lanterns_stand_on_it() -> void:
	var square := Town.square()
	for spot: Vector2i in [Town.project_board(), Town.bounty_board()] + Town.lanterns():
		assert_lt(Vector2(spot).distance_to(Vector2(square)), 6.0, "%s by the square's heart" % spot)
		assert_eq(MapData.load_by_id("town").tile_at(spot), "path", "%s on the square's ground" % spot)
	assert_eq(Town.lanterns().size(), 5)


func test_every_building_faces_south() -> void:
	var map := MapData.load_by_id("town")
	for cell: Vector2i in map.portals:
		if map.portals[cell].get("mapId", "") == "overworld":
			continue
		assert_true(map.tile_at(cell + Vector2i.UP).begins_with("roof"), "%s has its house above it" % cell)
		assert_false(map.tile_at(cell + Vector2i.DOWN).begins_with("roof"), "%s opens onto open ground" % cell)
