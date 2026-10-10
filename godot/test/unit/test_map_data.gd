extends GutTest
## Maps exported from the web game must load into the same world it plays.

var map: MapData


func before_all() -> void:
	map = MapData.load_by_id("overworld")


func test_overworld_dimensions() -> void:
	assert_eq(map.size, Vector2i(96, 64))


func test_grid_covers_every_cell() -> void:
	assert_eq(map.grid.size(), map.size.x * map.size.y)


func test_spawn_is_the_village_path() -> void:
	assert_eq(map.spawn, Vector2i(48, 38))
	assert_true(map.is_walkable(map.spawn))


func test_village_door_opens_and_walls_block() -> void:
	# The gate three wide (PIX-248), the wall either side of it.
	for x in [47, 48, 49]:
		assert_eq(map.tile_at(Vector2i(x, 42)), "door")
		assert_true(map.is_walkable(Vector2i(x, 42)))
	assert_eq(map.tile_at(Vector2i(46, 42)), "wall")
	assert_false(map.is_walkable(Vector2i(46, 42)))


func test_village_door_is_the_town_portal() -> void:
	var target: Dictionary = map.portals[Vector2i(48, 42)]
	assert_eq(target["kind"], "map")
	assert_eq(target["mapId"], "town")


func test_overworld_has_all_its_portals() -> void:
	# The mountain's gate (onto its road since PIX-253 step 8; the
	# Undermountain's cave filled in, PIX-257), the town, the two passes, and the
	# roads out to the bigger Reach (PIX-164: Saltmere; PIX-167: the mines;
	# PIX-168: Greyhold; PIX-169: the Frostgate pass), each road out three
	# cells wide (PIX-269), the two passes too since they open in the cliffs
	# rather than through a cave mouth; the village's gate three wide too
	# (PIX-248).
	assert_eq(map.portals.size(), 22)
	assert_eq(map.portals[Vector2i(16, 63)]["mapId"], "saltmere")
	assert_eq(map.portals[Vector2i(0, 20)]["mapId"], "blackiron")
	assert_eq(map.portals[Vector2i(95, 15)]["mapId"], "greyhold")
	assert_eq(map.portals[Vector2i(68, 0)]["mapId"], "frostgate")
	assert_eq(map.portals[Vector2i(0, 32)]["mapId"], "mirefen")
	assert_eq(map.portals[Vector2i(95, 33)]["mapId"], "deepwood")
	for side: int in [-1, 1]:
		assert_eq(map.portals[Vector2i(16 + side, 63)]["mapId"], "saltmere")
		assert_eq(map.portals[Vector2i(0, 20 + side)]["mapId"], "blackiron")
		assert_eq(map.portals[Vector2i(95, 15 + side)]["mapId"], "greyhold")
		assert_eq(map.portals[Vector2i(68 + side, 0)]["mapId"], "frostgate")
		assert_eq(map.portals[Vector2i(0, 32 + side)]["mapId"], "mirefen")
		assert_eq(map.portals[Vector2i(95, 33 + side)]["mapId"], "deepwood")


func test_map_corners_are_impassable_mountains() -> void:
	for corner in [
		Vector2i(0, 0), Vector2i(map.size.x - 1, 0),
		Vector2i(0, map.size.y - 1), map.size - Vector2i.ONE,
	]:
		assert_eq(map.tile_at(corner), "mountain")


func test_outside_the_map_is_not_walkable() -> void:
	assert_false(map.is_walkable(Vector2i(-1, 0)))
	assert_false(map.is_walkable(Vector2i(0, map.size.y)))
