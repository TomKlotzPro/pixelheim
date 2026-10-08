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


## Camps (PIX-142): each wild pack's tent and torch stand on open ground of
## its region, never on its home or a door, and block like the art they are.
func test_packs_camp_beside_their_homes() -> void:
	var map := MapData.load_by_id("overworld")
	var view := MapView.new(map, null)
	view.plan(map.spawn)
	var tents := 0
	for spawn: Dictionary in Bestiary.spawns_on("overworld"):
		var home := Vector2i(spawn["x"], spawn["y"])
		assert_false(view.camps.has(home), "%s's home stays open" % spawn["id"])
		assert_true(map.is_walkable(home))
		var tent := home + Vector2i(-1, -1)
		if view.camps.has(tent):
			tents += 1
			assert_eq(view.camps[tent]["tile"], MapView.TENTS[map.region_at(home)])
	assert_gt(tents, 5, "most packs have room for a tent")
	for cell: Vector2i in view.camps:
		assert_true(map.covered.has(cell), "a camp at %s blocks" % cell)
		assert_false(map.portals.has(cell))
