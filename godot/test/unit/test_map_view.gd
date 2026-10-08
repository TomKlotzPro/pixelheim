extends GutTest
## MapView.plan (PIX-136): before anything is drawn, a visit marks on the map
## what its art covers, and never lands the hero inside it.


func test_an_arrival_on_a_blocked_cell_lands_at_the_spawn() -> void:
	var map := MapData.load_by_id("town")
	var wall := Vector2i(-1, -1)
	for cell: Vector2i in map.grid:
		if not map.is_walkable(cell):
			wall = cell
			break
	assert_ne(wall, Vector2i(-1, -1), "the town has walls")
	var view := MapView.new(map, null)
	assert_eq(view.plan(wall), map.spawn)


func test_an_open_arrival_stays() -> void:
	var map := MapData.load_by_id("town")
	var view := MapView.new(map, null)
	assert_eq(view.plan(map.spawn), map.spawn)


func test_blocking_scatter_is_covered_and_never_under_the_hero() -> void:
	var map := MapData.load_by_id("overworld")
	var view := MapView.new(map, null)
	var arrival := view.plan(map.spawn)
	assert_false(view.solid_scatter.is_empty(), "the overworld's fields grow bushes and stumps")
	for cell: Vector2i in view.solid_scatter:
		assert_true(map.covered.has(cell), "scatter at %s blocks" % cell)
	assert_false(view.solid_scatter.has(arrival))
	assert_true(map.is_walkable(arrival))


func test_a_dungeon_floor_plans_no_houses_or_scatter() -> void:
	var map := MapData.load_by_id("overworld")
	map.floor_level = 1
	var view := MapView.new(map, null)
	view.plan(map.spawn)
	assert_true(view.buildings["pieces"].is_empty())
	assert_true(view.solid_scatter.is_empty())


func test_a_cell_centre_is_half_a_tile_in() -> void:
	assert_eq(MapView.center(Vector2i(2, 3)), Vector2(40, 56))
