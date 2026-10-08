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


func test_the_pack_draws_when_installed() -> void:
	if not PunyTown.available():
		pass_test("Medieval Age pack not installed here (pnpm godot:art); the town keeps its old houses.")
		return
	var sheet: Texture2D = load(PunyTown.SHEET)
	assert_eq(sheet.get_size(), Vector2(PunyTown.COLUMNS * 16, 132 * 16), "the whole atlas")
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
