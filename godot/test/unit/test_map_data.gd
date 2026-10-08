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
	assert_eq(map.tile_at(Vector2i(48, 42)), "door")
	assert_true(map.is_walkable(Vector2i(48, 42)))
	assert_eq(map.tile_at(Vector2i(47, 42)), "wall")
	assert_false(map.is_walkable(Vector2i(47, 42)))


func test_village_door_is_the_town_portal() -> void:
	var target: Dictionary = map.portals[Vector2i(48, 42)]
	assert_eq(target["kind"], "map")
	assert_eq(target["mapId"], "town")


func test_overworld_has_all_its_portals() -> void:
	# The mountain, the undermountain, the town, the two passes, and the
	# roads out to the bigger Reach (PIX-164: Saltmere; PIX-167: the mines).
	assert_eq(map.portals.size(), 7)
	assert_eq(map.portals[Vector2i(16, 63)]["mapId"], "saltmere")
	assert_eq(map.portals[Vector2i(0, 20)]["mapId"], "blackiron")


func test_map_corners_are_impassable_mountains() -> void:
	for corner in [
		Vector2i(0, 0), Vector2i(map.size.x - 1, 0),
		Vector2i(0, map.size.y - 1), map.size - Vector2i.ONE,
	]:
		assert_eq(map.tile_at(corner), "mountain")


func test_outside_the_map_is_not_walkable() -> void:
	assert_false(map.is_walkable(Vector2i(-1, 0)))
	assert_false(map.is_walkable(Vector2i(0, map.size.y)))
