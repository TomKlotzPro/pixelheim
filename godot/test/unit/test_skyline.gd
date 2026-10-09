extends GutTest
## Skyline (PIX-248): the village seen from the overworld is the town map as
## it stands, small - its houses in their own roofs, one ring of its own
## rampart with the gate where the road comes in, its river, its ruins - and
## it grows as the town is rebuilt. Pure: none of it needs the paid art.

const OUTER := Rect2i(36, 42, 26, 14)
const GATE := Vector2i(48, 42)


func _grid(rows: Array) -> Dictionary:
	var legend := {".": "grass", "#": "wall", "D": "door", "R": "roof"}
	var grid := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			grid[Vector2i(x, y)] = legend[row[x]]
	return grid


## The village as the town stands with every age up to `age` built.
func _village(age: int) -> Dictionary:
	var done := Town.projects_through(age)
	var ruins: Array = Town.ruins(done).map(func(ruin: Dictionary) -> Rect2i: return ruin["rect"])
	return Skyline.plan(MapData.load_by_id("overworld").grid, MapData.load_tiered("town", done, 1), ruins)


func _count(tiles: Dictionary, tile: int) -> int:
	return tiles.values().filter(func(each: int) -> bool: return each == tile).size()


func test_the_block_is_the_roofs_and_the_rampart_round_them() -> void:
	var grid := _grid([
		"..........",
		".####D###.",
		".########.",
		".##RRRR##.",
		".##RRRR##.",
		".########.",
		".########.",
		"..........",
	])
	assert_eq(Skyline.block(grid), Rect2i(1, 1, 8, 6))
	assert_eq(Skyline.block(_grid(["...", "..."])), Rect2i(), "no roofs, no block")
	assert_eq(Skyline.block(MapData.load_by_id("overworld").grid), OUTER, "the overworld's walled town")


func test_the_town_inside_its_walls() -> void:
	assert_eq(Skyline.inside(MapData.load_by_id("town")), Rect2i(2, 2, 80, 41))


func test_its_rows_keep_the_streets_between_the_houses() -> void:
	var rows := Skyline._spans(Skyline.TOWN_ROWS.size(), 2, 41, Skyline.TOWN_ROWS)
	assert_eq(rows[0], Vector2i(2, 5), "the inn's roof")
	assert_eq(rows[3], Vector2i(11, 14), "the top street")
	assert_eq(rows[-1], Vector2i(35, 43), "the south river to the walls")
	assert_eq(Skyline._spans(4, 0, 10, Skyline.TOWN_ROWS), [Vector2i(0, 2), Vector2i(2, 5), Vector2i(5, 7), Vector2i(7, 10)], "elsewhere, evenly")


func test_one_ring_of_the_towns_rampart_with_the_gate_in_it() -> void:
	var village := _village(1)
	var objects: Dictionary = village["objects"]
	assert_eq(village["block"], OUTER)
	assert_eq(objects[GATE], PunyTerrain.GATE, "the gate where the road comes in")
	for corner: Vector2i in [OUTER.position, Vector2i(OUTER.end.x - 1, OUTER.position.y), OUTER.end - Vector2i.ONE]:
		assert_eq(objects[corner], PunyTerrain.TOWER, "a tower on each corner")
	assert_eq(objects[Vector2i(40, 42)], PunyTerrain.TOWER_ACROSS, "a tower every few steps, as in town")
	assert_eq(objects[Vector2i(41, 55)], PunyTerrain.WALL_ACROSS)
	assert_eq(objects[Vector2i(36, 48)], PunyTerrain.WALL_DOWN)
	var rampart := [PunyTerrain.TOWER, PunyTerrain.TOWER_ACROSS, PunyTerrain.WALL_ACROSS, PunyTerrain.WALL_DOWN, PunyTerrain.GATE]
	for cell: Vector2i in objects:
		if objects[cell] in rampart:
			assert_false(OUTER.grow(-1).has_point(cell), "one ring: no wall inside it (%s)" % cell)
	assert_eq(village["ground"][GATE + Vector2i.DOWN], "path", "the road goes on in through the gate")


func test_every_house_stands_in_its_own_roof_with_a_window_and_a_door() -> void:
	var town := MapData.load_tiered("town", Town.projects_through(1), 1)
	var houses := PunyTown.houses(town.grid)
	var village := _village(1)
	var pieces: Dictionary = village["pieces"]
	var room := OUTER.grow(-1)
	assert_eq(_count(pieces, PunyTown.DOOR), houses.size(), "every house of the town, each with its door")
	assert_gte(_count(pieces, PunyTown.WINDOW), houses.size(), "and a window to light at night")
	assert_eq(village["smoke"].size(), houses.size(), "and smoke from its roof")
	for cell: Vector2i in pieces:
		assert_true(room.has_point(cell), "inside the rampart (%s)" % cell)
	for house: Dictionary in houses:
		var shift: int = PunyTown.ROOF_ROWS[house["kind"]] * PunyTown.COLUMNS
		var eaves: Array = PunyTown.WING_EAVE.map(func(tile: int) -> int: return tile + shift)
		assert_true(pieces.values().any(func(tile: int) -> bool: return tile in eaves), "a roof of %s" % house["kind"])
	assert_has(village["decor"].values(), Skyline.CHIMNEY, "a stack on the inn's tall roof")


func test_its_river_bridge_and_dock() -> void:
	var ground: Dictionary = _village(1)["ground"]
	assert_has(ground.values(), "water")
	assert_eq(_count_of(ground, "bridge"), 2, "the bridge, one row across the river")
	assert_eq(_count_of(ground, "dock"), 1)


func _count_of(ground: Dictionary, tile: String) -> int:
	return ground.values().filter(func(each: String) -> bool: return each == tile).size()


func test_it_grows_as_the_town_is_rebuilt() -> void:
	var ashes := _village(0)
	var hamlet := _village(1)
	var city := _village(Town.MAX_TIER)
	var houses := func(village: Dictionary) -> int: return _count(village["pieces"], PunyTown.DOOR)
	assert_eq(houses.call(ashes), 1, "after the fire only the hall stands")
	assert_false(ashes["ruins"].is_empty(), "the rest smoulders")
	assert_has(ashes["ground"].values(), "ash")
	assert_true(ashes["objects"].values().any(func(tile: int) -> bool: return tile in Skyline.DEBRIS), "burnt logs where they stood")
	assert_true(hamlet["ruins"].is_empty(), "rebuilt")
	assert_false(hamlet["ground"].values().has("ash"))
	assert_gt(houses.call(city), houses.call(hamlet), "the ages' cottages and the slate hall")
	assert_gt(city["lamps"].size(), hamlet["lamps"].size(), "the street lamps and the grand avenue's")
	assert_has(city["objects"].values(), Skyline.WELL, "the fountain on the square")


func test_the_block_is_only_drawn() -> void:
	var grid := MapData.load_by_id("overworld").grid
	var before := grid.duplicate()
	Skyline.plan(grid, MapData.load_by_id("town"))
	assert_eq(grid, before, "the block's cells stay what they were: nobody walks in it")
	assert_true(Skyline.plan({}, MapData.load_by_id("town"))["block"] == Rect2i(), "no block, nothing drawn")
