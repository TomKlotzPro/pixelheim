extends GutTest
## The walls standing in the open (StoneWalls, PIX-386): every wall that is
## neither a ruin's nor the rampart's is drawn and still blocks, a fort's
## have battlements on their open sides and a hut's none, each looks its
## region's way, and the same map draws the same walls every time.


## A grid from rows of letters.
func _grid(rows: Array) -> Dictionary:
	var names := {".": "grass", "#": "wall", "s": "stone", "D": "door", "*": "snow", "~": "ash", "_": "floor"}
	var grid := {}
	for y in rows.size():
		for x in String(rows[y]).length():
			grid[Vector2i(x, y)] = names[rows[y][x]]
	return grid


## What MapView skips for a map: a ruin's walls, the rampart's pieces.
func _skip(data: MapData) -> Dictionary:
	var skip: Dictionary = Ruins.plan(data.grid)["walls"]
	if data.id in Rampart.MAPS:
		skip.merge(Rampart.plan(data.grid)["pieces"])
	elif data.id in Rampart.GATEHOUSES:
		skip.merge(Rampart.plan(data.grid, false, true)["pieces"])
	return skip


func test_greyhold_s_fort_is_drawn_whole_and_still_blocks() -> void:
	var data := MapData.load_by_id("greyhold")
	var skip := _skip(data)
	var plan := StoneWalls.plan(data.grid, skip)
	# The ring, cut by its gaps and its gate into four, and four pillars.
	assert_eq(plan["looks"], ["wood", "wood", "wood", "wood", "wood", "wood", "wood", "wood"], "the fort's walls, in the woods' moss")
	for cell: Vector2i in data.grid:
		if data.grid[cell] == "wall":
			assert_true(plan["walls"].has(cell) != skip.has(cell), "%s drawn once, by the walls or the gatehouse" % cell)
	for cell: Vector2i in plan["walls"]:
		assert_false(data.is_walkable(cell), "%s still blocks" % cell)
	for cell: Vector2i in plan["ground"]:
		assert_true(data.is_walkable(cell), "the ground's pieces lie on open ground, %s" % cell)
	for tile: int in plan["walls"].values() + plan["ground"].values():
		assert_between(tile, 0, RuinArt.COUNT - 1, "tile %d on the atlas" % tile)


func test_a_fort_has_battlements_and_a_hut_none() -> void:
	var fort := _grid([
		"..........",
		".########.",
		".#ssssss#.",
		".#ssssss#.",
		".####D###.",
		"..........",
	])
	var walls: Dictionary = StoneWalls.plan(fort, {})["walls"]
	assert_eq(walls.size(), 19)
	# The north run's faces along their top, the side runs' tops down their
	# outer side (none on the yard's), the corners on both.
	assert_eq(_battled(walls, Vector2i(4, 1)), RuinArt.BATTLED_N)
	assert_eq(_battled(walls, Vector2i(1, 1)), RuinArt.BATTLED_N | RuinArt.BATTLED_W)
	assert_eq(_battled(walls, Vector2i(8, 1)), RuinArt.BATTLED_N | RuinArt.BATTLED_E)
	assert_eq(_battled(walls, Vector2i(1, 2)), RuinArt.BATTLED_W)
	assert_eq(_battled(walls, Vector2i(8, 3)), RuinArt.BATTLED_E)
	# A face with the wall come down into it from the north: none on top.
	assert_eq(_battled(walls, Vector2i(1, 4)), 0)
	var hut: Dictionary = StoneWalls.plan(_grid(["....", ".##.", ".#D.", "...."]), {})["walls"]
	for cell: Vector2i in hut:
		assert_eq(_battled(hut, cell), 0, "a hut's wall %s stands plain" % cell)


func test_walls_look_their_region_s_way() -> void:
	for pair: Array in [["*", "snow"], ["~", "ash"], [".", "wood"]]:
		var row := String(pair[0]).repeat(6)
		var grid := _grid([row, row.substr(0, 1) + "####" + row.substr(0, 1), row])
		assert_eq(StoneWalls.plan(grid, {})["looks"], [pair[1]], "a wall in the %s" % pair[1])


func test_what_others_draw_is_left_to_them() -> void:
	var grid := _grid(["......", ".####.", ".#__#.", ".####.", "......"])
	assert_eq(StoneWalls.plan(grid, Ruins.plan(grid)["walls"])["walls"], {}, "a ruin's walls are the ruin's")


func test_the_same_map_draws_the_same_walls() -> void:
	var data := MapData.load_by_id("greyhold")
	assert_eq(StoneWalls.plan(data.grid, _skip(data)), StoneWalls.plan(data.grid, _skip(data)))


func test_the_atlas_holds_every_standing_piece() -> void:
	assert_eq(RuinArt.standing(RuinArt.LOOKS.size() - 1, RuinArt.SHAPES.size() - 1, RuinArt.STANDING_VARIANTS - 1), RuinArt.COUNT - 1)
	var source := RuinArt.tileset().get_source(0) as TileSetAtlasSource
	assert_eq(source.get_tiles_count(), RuinArt.COUNT, "every tile made with the tileset")


## The battlements the tile at `cell` was drawn with: none on a ruin's piece.
func _battled(walls: Dictionary, cell: Vector2i) -> int:
	if walls[cell] < RuinArt.STANDING_AT:
		return 0
	var shape: int = ((walls[cell] - RuinArt.STANDING_AT) / RuinArt.STANDING_VARIANTS) % RuinArt.SHAPES.size()
	return RuinArt.SHAPES[shape].y
