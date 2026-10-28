extends GutTest
## The old stone ruins in the open (Ruins, PIX-381): which walls are a
## ruin's, that every one of their cells is drawn and still blocks, that the
## course lining the floor always stands, that each looks its region's way,
## and that the same map draws the same ruin every time.

## The maps the Reach's ruins stand on, and how each one looks.
const RUINS := {"mirefen": ["mire"], "deepwood": ["wood", "wood"]}


## A grid from rows of letters.
func _grid(rows: Array) -> Dictionary:
	var names := {".": "grass", "#": "wall", "_": "floor", "S": "shrine", "*": "snow", "~": "ash", "m": "marsh"}
	var grid := {}
	for y in rows.size():
		for x in String(rows[y]).length():
			grid[Vector2i(x, y)] = names[rows[y][x]]
	return grid


func test_the_reach_s_ruins_and_no_other_walls() -> void:
	for map_id: String in ["mirefen", "deepwood", "greyhold", "town", "overworld", "frostgate", "saltmere"]:
		var plan := Ruins.plan(MapData.load_by_id(map_id).grid)
		assert_eq(plan["looks"], RUINS.get(map_id, []), "%s's ruins, by look" % map_id)


func test_every_wall_of_a_ruin_is_drawn_and_still_blocks() -> void:
	for map_id: String in RUINS:
		var data := MapData.load_by_id(map_id)
		var plan := Ruins.plan(data.grid)
		for cell: Vector2i in data.grid:
			if data.grid[cell] == "wall":
				assert_true(plan["walls"].has(cell), "%s's wall %s drawn" % [map_id, cell])
		for cell: Vector2i in plan["walls"]:
			assert_eq(data.grid[cell], "wall", "%s: only walls take a wall's piece" % map_id)
			assert_false(data.is_walkable(cell), "%s's %s still blocks" % [map_id, cell])
		for cell: Vector2i in plan["ground"]:
			assert_true(data.is_walkable(cell) or data.grid[cell] in ["shrine", "lamp"], "%s: the ground's pieces lie on open ground, %s" % [map_id, cell])
		for tile: int in plan["walls"].values() + plan["ground"].values():
			assert_between(tile, 0, RuinArt.COUNT - 1, "%s: tile %d on the atlas" % [map_id, tile])


func test_the_course_lining_the_floor_stands_and_the_rest_may_fall() -> void:
	var grid := _grid([
		"......",
		".####.",
		".#__#.",
		".#S_#.",
		".##_#.",
		"......",
	])
	var walls: Dictionary = Ruins.plan(grid)["walls"]
	assert_eq(walls.size(), 11)
	for cell: Vector2i in walls:
		assert_lt(walls[cell], RuinArt.WALLS, "%s lines the floor: standing stone, not a heap" % cell)
	# A thick wall's outer course: some of it fallen into heaps.
	var thick := _grid([
		"........",
		".######.",
		".######.",
		".##__##.",
		".##__##.",
		".##__##.",
		"........",
	])
	var heaps: Array = Ruins.plan(thick)["walls"].values().filter(func(tile: int) -> bool: return tile >= RuinArt.MOUNDS_AT)
	assert_gt(heaps.size(), 0, "some of the outer course fallen")


func test_a_ruin_looks_its_region_s_way() -> void:
	var ruin := [".#_#.", ".###."]
	for pair: Array in [["*", "snow"], ["~", "ash"], ["m", "mire"], [".", "wood"]]:
		var rows: Array = [String(pair[0]).repeat(5)] + ruin + [String(pair[0]).repeat(5)]
		assert_eq(Ruins.plan(_grid(rows))["looks"], [pair[1]], "a ruin in the %s" % pair[1])


func test_a_wall_without_a_floor_is_no_ruin() -> void:
	assert_eq(Ruins.plan(_grid(["....", ".##.", ".##.", "...."]))["walls"], {})


func test_the_same_map_draws_the_same_ruin() -> void:
	var grid := MapData.load_by_id("deepwood").grid
	assert_eq(Ruins.plan(grid), Ruins.plan(grid))


func test_the_atlas_holds_every_piece() -> void:
	assert_eq(RuinArt.WALLS, RuinArt.LOOKS.size() * RuinArt.BASES.size() * RuinArt.VARIANTS)
	assert_eq(RuinArt.atlas().get_height(), ceili(RuinArt.COUNT / float(RuinArt.COLUMNS)) * RuinArt.TILE)
	var source := RuinArt.tileset().get_source(0) as TileSetAtlasSource
	assert_eq(source.get_tiles_count(), RuinArt.COUNT, "every tile made with the tileset")
