extends GutTest
## PunyTown rebuilds the web town's roof clusters as Shade's Medieval Age
## houses (PIX-133). The plan is pure tile ids, so it is checked here without
## the paid pack: shapes, doors, colours, and that every town tier keeps its
## doors and roads.

const TIERS := ["town", "town@2", "town@3", "town@4"]


## A grid from rows of letters: R roof, S slate, D door, . grass.
func _grid(rows: Array) -> Dictionary:
	var names := {"R": "roof", "S": "roof_slate", "D": "door", ".": "grass", "=": "path"}
	var grid := {}
	for y in rows.size():
		for x in String(rows[y]).length():
			grid[Vector2i(x, y)] = names[rows[y][x]]
	return grid


func test_a_wide_cottage_is_the_gable_centred_on_its_door() -> void:
	var plan := PunyTown.plan(_grid([
		"RRRRRRRRR",
		"RRRRRRRRR",
		"RRRRRRRRR",
		"RRRRRRRRR",
		"RRRRRRRRR",
		"RRRRDRRRR",
	]))
	var pieces: Dictionary = plan["pieces"]
	assert_eq(pieces.size(), 54)
	assert_eq(pieces[Vector2i(4, 5)], PunyTown.DOOR)
	for x in 9:
		assert_eq(pieces[Vector2i(x, 0)], PunyTown.GABLE_TOP[x], "the gable's top row")
		assert_eq(pieces[Vector2i(x, 4)], PunyTown.GABLE_EAVE[x], "the eave over the wall")
	assert_eq(plan["freed"], [])
	assert_eq(plan["decor"].size(), 2, "a chimney on a house this tall")


func test_slate_roofs_shift_only_the_roof_pieces() -> void:
	var pieces: Dictionary = PunyTown.plan(_grid([
		"SSSSSSSSS",
		"SSSSSSSSS",
		"SSSSSSSSS",
		"SSSSDSSSS",
	]))["pieces"]
	assert_eq(pieces[Vector2i(0, 0)], PunyTown.GABLE_TOP[0] + 91 * PunyTown.COLUMNS)
	assert_eq(pieces[Vector2i(4, 3)], PunyTown.DOOR, "doors are shared by every colour")
	assert_eq(pieces[Vector2i(2, 3)], PunyTown.WINDOW)


func test_narrow_houses_are_hip_roofed_wings_with_their_door() -> void:
	var pieces: Dictionary = PunyTown.plan(_grid([
		"RRRRR",
		"RRRRR",
		"RRRRR",
		"RRDRR",
	]))["pieces"]
	assert_eq(pieces.size(), 20)
	assert_eq(pieces[Vector2i(0, 0)], PunyTown.WING_TOP[0])
	assert_eq(pieces[Vector2i(4, 0)], PunyTown.WING_TOP[2])
	assert_eq(pieces[Vector2i(2, 3)], PunyTown.DOOR)


func test_a_lone_side_column_is_a_low_lean_to() -> void:
	var plan := PunyTown.plan(_grid([
		"RRRRRRRRRR",
		"RRRRRRRRRR",
		"RRRRRRRRRR",
		"RRRRRRRRRR",
		"RRRRDRRRRR",
	]))
	# The gable takes nine columns; the tenth stays three rows high.
	assert_true(plan["pieces"].has(Vector2i(9, 2)))
	assert_false(plan["pieces"].has(Vector2i(9, 1)))
	assert_has(plan["freed"], Vector2i(9, 0))


func test_every_town_tier_keeps_its_doors_and_roads() -> void:
	for tier: String in TIERS:
		var data := _load(tier)
		var plan := PunyTown.plan(data.grid)
		var pieces: Dictionary = plan["pieces"]
		assert_gt(pieces.size(), 200, "%s has its houses" % tier)
		for cell: Vector2i in data.grid:
			var tile: String = data.grid[cell]
			if tile == "door" or tile == "door_shut":
				if pieces.has(cell):
					assert_eq(pieces[cell], PunyTown.DOOR, "%s door at %s" % [tier, cell])
			if tile == "path" or tile == "lamp" or tile == "well":
				assert_false(pieces.has(cell), "%s keeps the %s at %s open" % [tier, tile, cell])
			if tile.begins_with("roof"):
				assert_true(pieces.has(cell) or plan["freed"].has(cell), "%s roof at %s is drawn or freed" % [tier, cell])


func test_every_roof_piece_lies_on_one_slope() -> void:
	# The roofs' light (PIX-523) reads each piece's slope: a piece laid on
	# both sides of a gable would be lit the wrong way on one of them.
	var slopes := PunyTown.roof_slopes()
	var gable: Array = [PunyTown.GABLE_TOP] + PunyTown.GABLE_BODY + [PunyTown.GABLE_FOOT, PunyTown.GABLE_EAVE]
	for row: Array in gable:
		for c in row.size():
			var want := PunyTown.SLOPE_WEST if c < 4 else (PunyTown.RIDGE_DOWN if c == 4 else PunyTown.SLOPE_EAST)
			assert_eq(int(slopes[row[c]]) % PunyTown.EDGE_TOP, want, "gable piece %d in column %d" % [row[c], c])
	var wing := {
		PunyTown.SLOPE_NORTH: PunyTown.WING_TOP + PunyTown.WING_UPPER + PunyTown.UPPER_FILL, PunyTown.RIDGE_ACROSS: PunyTown.WING_RIDGE,
		PunyTown.SLOPE_SOUTH: PunyTown.WING_LOWER + PunyTown.LOWER_FILL + PunyTown.WING_EAVE,
	}
	for want: int in wing:
		for tile: int in (wing[want] as Array):
			if tile >= 0:
				assert_eq(int(slopes[tile]) % PunyTown.EDGE_TOP, want, "wing piece %d" % tile)
	for tile: int in [PunyTown.WALL_LEFT, PunyTown.WALL, PunyTown.WALL_RIGHT, PunyTown.WINDOW, PunyTown.DOOR] + PunyTown.CHIMNEY:
		assert_false(slopes.has(tile), "%d is no roof" % tile)


func test_the_roof_light_knows_every_piece_of_every_house() -> void:
	# Every piece a house is built of, in every roof colour (a town's
	# gables and wings, the far-off village's wings): a wall stays as drawn,
	# a roof piece has its slope and a copy of itself in another colour,
	# where the two share only the wall under the roof (PIX-523).
	var map := PunyTown.roof_map()
	var houses: Array[Dictionary] = []
	for tier: String in TIERS:
		houses.append(PunyTown.plan(_load(tier).grid, Hamlet.house_style("town"))["pieces"])
	for kind: String in PunyTown.ROOF_ROWS:
		houses.append(PunyTown.wing_house(Rect2i(0, 0, 5, 6), 2, kind))
		var grid := _grid(["RRRRRRRRR", "RRRRRRRRR", "RRRRRRRRR", "RRRRRRRRR", "RRRRRRRRR", "RRRRRRRRR", "RRRRDRRRR"])
		for cell: Vector2i in grid:
			if grid[cell] == "roof":
				grid[cell] = kind
		houses.append(PunyTown.plan(grid)["pieces"])
	for pieces: Dictionary in houses:
		for cell: Vector2i in pieces:
			var tile: int = pieces[cell]
			var texel := map.get_pixel(tile % PunyTown.COLUMNS, tile / PunyTown.COLUMNS)
			if PunyTown.is_wall(tile):
				assert_eq(texel.r8, 0, "the wall piece %d stays as drawn" % tile)
				continue
			assert_gt(texel.r8, 0, "the roof piece %d has its slope" % tile)
			var copy := tile + (texel.g8 - 128) * PunyTown.COLUMNS
			assert_ne(copy, tile)
			assert_eq(map.get_pixel(copy % PunyTown.COLUMNS, copy / PunyTown.COLUMNS).r8, texel.r8, "the roof piece %d's copy %d lies on its slope" % [tile, copy])


## PIX-525: a roof colour is a map tile too: the hero can't walk on it, the
## map paints it in its colour and far off without the pack it is one of
## Shade's CC0 one-tile houses.
func test_every_roof_colour_is_a_tile_with_its_map_colour_and_far_icon() -> void:
	for kind: String in PunyTown.ROOF_ROWS:
		assert_true(WorldTiles.TILE_INFO.has(kind), "%s is a map tile" % kind)
		assert_false(WorldTiles.is_walkable(kind), "%s blocks" % kind)
		assert_true(Atlas.ROOFS.has(kind), "%s has its colour on the map" % kind)
		assert_true(Skyline.ICONS.has(kind), "%s has its house far off" % kind)


## PIX-525: each roof colour's rows lead to a whole copy of the
## terracotta's pieces (a wrong row draws a gable cut from another one).
func test_each_roof_colour_is_the_terracottas_pieces_in_its_block() -> void:
	if not PunyTown.available():
		pass_test("Medieval Age pack not installed here (scripts/fetch-private-art.sh).")
		return
	var sheet: Image = (load(PunyTown.SHEET) as Texture2D).get_image()
	for kind: String in PunyTown.ROOF_ROWS:
		var rows: int = PunyTown.ROOF_ROWS[kind]
		for tile: int in PunyTown.roof_slopes():
			var copy := tile + rows * PunyTown.COLUMNS
			var differ := 0
			for y in 16:
				for x in 16:
					var a := sheet.get_pixel(tile % PunyTown.COLUMNS * 16 + x, tile / PunyTown.COLUMNS * 16 + y).a8
					var b := sheet.get_pixel(copy % PunyTown.COLUMNS * 16 + x, copy / PunyTown.COLUMNS * 16 + y).a8
					differ += int(a != b)
			assert_eq(differ, 0, "%s: the piece %d's copy %d is its shape" % [kind, tile, copy])


func test_the_pack_draws_when_installed() -> void:
	if not PunyTown.available():
		pass_test("Medieval Age pack not installed here (scripts/fetch-private-art.sh); the town keeps its old houses.")
		return
	var sheet: Texture2D = load(PunyTown.SHEET)
	assert_eq(sheet.get_size(), Vector2(PunyTown.COLUMNS * 16, PunyTown.ROWS * 16), "the whole atlas")
	var layer := TileMapLayer.new()
	layer.tile_set = PunyTown.tileset()
	PunyTown.place(layer, Vector2i(3, 4), PunyTown.DOOR)
	assert_eq(layer.get_cell_atlas_coords(Vector2i(3, 4)), Vector2i(PunyTown.DOOR % PunyTown.COLUMNS, PunyTown.DOOR / PunyTown.COLUMNS))
	layer.free()


## A town as grown through an age ("town@3"), or any other map by id.
func _load(id: String) -> MapData:
	if id.begins_with("town@"):
		return MapData.load_tiered("town", Town.projects_through(int(id.get_slice("@", 1))), 1)
	return MapData.load_by_id(id)
