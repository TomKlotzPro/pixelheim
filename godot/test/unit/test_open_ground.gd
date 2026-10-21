extends GutTest
## Open ground (PIX-305): most of every outdoor screen was one grass tuft
## repeated, snow that tuft whitened, the Mirefen's tone 2px Bayer blobs that
## read as camouflage, and where a region's tone thinned along a road it left
## wandering bands of dither across the ash. Now each cell of the tint mask
## asks for a whole tone, the mire's (its murk and puddles), or the ash's
## over a neighbour's dirt alone; the shader (open_ground.gdshaderinc) lays
## patches, drifts and puddles; Scatter picks small things for the grass, the
## snow and the mire, which GroundDetail draws; and with the paid pack the
## Medieval Age's greens and snow lie as patches (OpenGround) in the
## shader's lushest hollows and its drifts' shadows.


func before_all() -> void:
	KeptGround.forget()


func after_all() -> void:
	KeptGround.forget()


## A grid from rows of letters: a ash, m marsh, . grass, = path, M mountain,
## s snow, ~ water.
static func _grid(rows: Array) -> Dictionary:
	var tiles := {"a": "ash", "m": "marsh", ".": "grass", "=": "path", "M": "mountain", "s": "snow", "~": "water", "f": "forest"}
	var grid := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			grid[Vector2i(x, y)] = tiles[row[x]]
	return grid


static func _mask(grid: Dictionary, size: Vector2i, regions := {}) -> Image:
	return PunyTerrain.tint_map(grid, size, regions).get_image()


func test_each_cell_asks_for_a_whole_tone_and_says_which() -> void:
	var grid := _grid(["am..", "....", "....", "s.=."])
	var regions := {Vector2i(0, 3): "frost", Vector2i(2, 3): "frost", Vector2i(1, 3): "mire"}
	var mask := _mask(grid, Vector2i(4, 4), regions)
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(0, 0)), "tone", "the ash, whole")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(1, 0)), "mire", "the marsh is the mire's, with its murk and puddles")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(0, 3)), "tone", "the snow, whole")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(1, 3)), "mire", "the Mirefen's grass is the mire's own ground")
	assert_almost_eq(mask.get_pixelv(Vector2i(1, 3)).g, PunyTerrain.TINTS["marsh"].g, 0.01)
	assert_almost_eq(mask.get_pixelv(Vector2i(2, 3)).r, PunyTerrain.TINTS["stone"].r, 0.01, "the pass's road is trodden stone")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(3, 1)), "none", "a meadow is Shade's own green")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(9, 9)), "none", "off the map")


func test_the_ash_reaches_into_its_neighbours_dirt_alone() -> void:
	# Shade's dirt runs a few pixels past an ash cell in tufts, into the grass
	# and under a cliff's foot: those cells take the ash's tone over their
	# dirt only. A road beside the ash keeps its own colour; a region toned
	# from Shade's grass (snow, the mire) reaches into nothing.
	var grid := _grid(["....=a", ".aa.=a", ".aaM..", "......", "m.....", "s....."])
	var mask := _mask(grid, Vector2i(6, 6), {Vector2i(0, 5): "frost"})
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(3, 1), Vector2i(0, 3), Vector2i(3, 3)]:
		assert_eq(PunyTerrain.tone_at(mask, cell), "fringe", "grass beside the ash at %s" % cell)
		assert_almost_eq(mask.get_pixelv(cell).r, PunyTerrain.TINTS["ash"].r, 0.01, "in the ash's own hue")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(3, 2)), "fringe", "the cliff standing in the ash")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(4, 0)), "none", "a road beside the ash stays a road")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(5, 3)), "none", "two cells out, nothing")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(1, 4)), "none", "the mire reaches into nothing")
	assert_eq(PunyTerrain.tone_at(mask, Vector2i(1, 5)), "none", "nor does the snow")


func test_the_reach_tones_its_ash_whole_and_leaves_its_roads_their_own() -> void:
	var data := MapData.load_by_id("overworld")
	var mask := _mask(data.grid, data.size, data.regions)
	for cell: Vector2i in data.grid:
		match data.grid[cell]:
			"ash":
				assert_eq(PunyTerrain.tone_at(mask, cell), "tone", "ash at %s" % cell)
			"path":
				assert_eq(PunyTerrain.tone_at(mask, cell), "none", "the road at %s, no band of the ash's tone along it" % cell)
	var mire := MapData.load_by_id("mirefen")
	var bog := _mask(mire.grid, mire.size, mire.regions)
	for cell: Vector2i in mire.grid:
		if mire.grid[cell] in ["grass", "marsh"] and mire.regions.get(cell, "") == "mire":
			assert_eq(PunyTerrain.tone_at(bog, cell), "mire", "the Mirefen's ground at %s is all the mire's" % cell)


func test_small_things_grow_by_region_where_no_decor_does() -> void:
	var fields := {}
	for y in 120:
		for x in 120:
			fields[Vector2i(x, y)] = "grass"
	for tile: String in Scatter.DETAIL:
		var grid := {}
		for cell: Vector2i in fields:
			grid[cell] = tile
		var grown := 0
		var open := 0
		for cell: Vector2i in grid:
			var kind := Scatter.detail(grid, cell)
			if Scatter.choice(grid, cell) >= 0:
				assert_eq(kind, "", "nothing small under %s's decor at %s" % [tile, cell])
				continue
			open += 1
			if kind != "":
				grown += 1
				assert_has(Scatter.DETAIL[tile][1], kind)
				assert_eq(Scatter.detail(grid, cell), kind, "the same every time")
		var share := grown * 100.0 / open
		assert_almost_eq(share, float(Scatter.DETAIL[tile][0]), 1.5, "%s grows small things in about %d%% of its open cells" % [tile, Scatter.DETAIL[tile][0]])
		# The meadow and the grove round a lamp (PIX-323) are a few cells
		# each, in flower on purpose.
		if tile not in ["meadow", "grove"]:
			assert_between(share, 6.0, 14.0, "denser than the field's old 3%%, never a carpet")
	assert_eq(Scatter.detail({Vector2i.ZERO: "path"}, Vector2i.ZERO), "", "nothing on a road")
	assert_eq(Scatter.detail({Vector2i.ZERO: "forest"}, Vector2i.ZERO), "", "nor under the trees")


func test_the_mires_grass_grows_the_mires_small_things() -> void:
	var kinds := {}
	for y in 60:
		for x in 60:
			var grid := {Vector2i(x, y): "grass"}
			var kind := Scatter.detail(grid, Vector2i(x, y), "mire")
			if kind != "":
				kinds[kind] = true
	for kind: String in kinds:
		assert_has(Scatter.DETAIL["marsh"][1], kind, "reeds and sedge in the mire, no meadow flowers")


func test_every_small_thing_is_drawn_whole_in_its_cell() -> void:
	for tile: String in Scatter.DETAIL:
		for kind: String in Scatter.DETAIL[tile][1]:
			assert_has(GroundDetail.DRAWINGS, kind, "%s's %s is drawn" % [tile, kind])
	var seen := {}
	for kind: String in GroundDetail.DRAWINGS:
		var drawing: Array = GroundDetail.DRAWINGS[kind]
		for line: String in drawing:
			for ink in line:
				assert_true(ink == "." or GroundDetail.INKS.has(ink), "%s's %s is one of Shade's colours" % [kind, ink])
		for variant in GroundDetail.VARIANTS.size():
			var spot: Vector2i = GroundDetail.VARIANTS[variant]
			assert_lte(spot.y + drawing.size(), GroundDetail.TILE, "%s fits its cell at %s" % [kind, spot])
			for line: String in drawing:
				assert_lte(spot.x + line.length(), GroundDetail.TILE, "%s fits its cell at %s" % [kind, spot])
			var at := GroundDetail.coords(kind, variant)
			assert_false(seen.has(at), "a tile of its own")
			seen[at] = true
	var source := GroundDetail.tileset().get_source(0) as TileSetAtlasSource
	for at: Vector2i in seen:
		assert_true(source.has_tile(at), "made with the tileset, never later (One Reach)")


func test_a_patch_is_cut_to_the_packs_pieces() -> void:
	var cells := {}
	# A block four wide and three deep, a strip a cell wide off its east
	# side, a lone cell, and a cell cut away from its south-west corner.
	for y in range(0, 3):
		for x in range(0, 4):
			cells[Vector2i(x, y)] = "grass"
	for x in range(4, 8):
		cells[Vector2i(x, 1)] = "grass"
	cells[Vector2i(10, 10)] = "grass"
	var shaped := OpenGround.shape(cells)
	assert_false(shaped.has(Vector2i(10, 10)), "a lone cell is trimmed")
	for x in range(5, 8):
		assert_false(shaped.has(Vector2i(x, 1)), "a strip a cell wide is trimmed")
	var block: Vector2i = OpenGround.PATCHES["grass"]["block"]
	var at := func(spot: Array) -> int: return (block.y + int(spot[1])) * OpenGround.COLUMNS + block.x + int(spot[0])
	assert_eq(shaped[Vector2i(0, 0)], at.call(OpenGround.EDGES["NW"][0]), "its corners")
	assert_eq(shaped[Vector2i(3, 2)], at.call(OpenGround.EDGES["SE"][0]))
	assert_has([at.call([13, 0]), at.call([14, 0])], shaped[Vector2i(1, 0)], "its top edge")
	assert_has([at.call([12, 1]), at.call([12, 2])], shaped[Vector2i(0, 1)], "its west edge")
	var fills := []
	for y in 4:
		for x in 4:
			fills.append(at.call([x, y]))
	assert_has(fills, shaped[Vector2i(1, 1)], "a fill inside")
	var notched := {}
	for y in range(0, 4):
		for x in range(0, 4):
			notched[Vector2i(x, y)] = "grass"
	notched.erase(Vector2i(0, 3))
	var cut := OpenGround.shape(notched)
	assert_eq(cut[Vector2i(1, 2)], at.call(OpenGround.NOTCHES["SW"]), "a corner cut in")
	for tile: int in shaped.values() + cut.values():
		assert_has(OpenGround.pieces(), tile, "every piece made with the town's tileset (PunyTown.pieces)")
	for tile: int in OpenGround.pieces():
		assert_has(PunyTown.pieces(), tile)


func test_patches_lie_in_open_grass_and_snow_clear_of_edges() -> void:
	for map_id: String in ["overworld", "frostgate", "saltmere", "greyhold", "mirefen"]:
		var data := MapData.load_by_id(map_id)
		var origin := ReachPlane.origin(map_id)
		var patches := OpenGround.plan(data.grid, data.size, data.regions, origin)
		var lattice := {}
		for cell: Vector2i in patches:
			var tile: String = data.grid[cell]
			assert_has(OpenGround.PATCHES, tile, "%s: a patch on %s at %s" % [map_id, tile, cell])
			assert_false(data.regions.get(cell, "") in OpenGround.BARE_REGIONS, "%s: none in the mire" % map_id)
			assert_true(Rect2i(Vector2i.ONE * OpenGround.MARGIN, data.size - Vector2i.ONE * 2 * OpenGround.MARGIN).has_point(cell), "%s: clear of the line at %s" % [map_id, cell])
			assert_gt(OpenGround.noise(Vector2(origin + cell) + Vector2(0.5, 0.5), lattice), float(OpenGround.PATCHES[tile]["above"]), "%s: where the shader's patches are deepest" % map_id)
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					assert_eq(PunyTerrain.ground_at(data.grid, cell + Vector2i(dx, dy)), "grass", "%s: %s clear of roads, water and cliffs" % [map_id, cell])
			var north_or_south := patches.has(cell + Vector2i.UP) or patches.has(cell + Vector2i.DOWN)
			var east_or_west := patches.has(cell + Vector2i.LEFT) or patches.has(cell + Vector2i.RIGHT)
			assert_true(north_or_south and east_or_west, "%s: no strip a cell wide at %s" % [map_id, cell])
		if map_id == "mirefen":
			assert_eq(patches.size(), 0, "the mire's are the shader's murk")
		else:
			assert_gt(patches.size(), 40 if map_id in ["overworld", "frostgate"] else 4, "%s has patches" % map_id)


func test_the_patches_noise_is_the_shaders() -> void:
	# open_ground.gdshaderinc's ground_hash, worked out in 32-bit floats as
	# the graphics card does.
	assert_almost_eq(OpenGround.ground_hash(Vector2(3, -7)), 0.99500, 0.002)
	assert_almost_eq(OpenGround.ground_hash(Vector2(12, 5)), 0.04004, 0.002)
	assert_almost_eq(OpenGround.ground_hash(Vector2(-40, 17)), 0.38965, 0.002)
	var lattice := {}
	for y in 20:
		for x in 20:
			assert_between(OpenGround.noise(Vector2(x * 1.7, y * 2.3), lattice), 0.0, 1.0)
	var shader := FileAccess.get_file_as_string("res://shaders/open_ground.gdshaderinc")
	assert_string_contains(shader, "vec2 PATCH_SCALES = vec2(%.1f, %.1f)" % [OpenGround.PATCH_SCALES.x, OpenGround.PATCH_SCALES.y], "one noise, both sides")
	assert_string_contains(shader, "vec2 PATCH_WEIGHTS = vec2(%.2f, %.2f)" % [OpenGround.PATCH_WEIGHTS.x, OpenGround.PATCH_WEIGHTS.y])
	var turns := {"SWELLS_TURN": OpenGround.SWELLS_TURN, "CLUMPS_TURN": OpenGround.CLUMPS_TURN}
	for turn: String in turns:
		var at: Vector2 = turns[turn]
		assert_string_contains(shader, "mat2 %s = mat2(vec2(%.7f, %.7f)" % [turn, at.x, at.y], "%s turned alike" % turn)


func test_a_drawn_map_lays_its_small_things_where_nothing_stands() -> void:
	for map_id: String in ["overworld", "mirefen", "frostgate", "town"]:
		var root := Node2D.new()
		add_child_autofree(root)
		var standing := Node2D.new()
		root.add_child(standing)
		var data := MapData.load_tiered(map_id, [], 0) if map_id == "town" else MapData.load_by_id(map_id)
		var view := MapView.new(data, standing)
		view.plan(data.spawn)
		view.build(root)
		var laid := view.detail_layer.get_used_cells()
		assert_gt(laid.size(), 40, "%s grows small things" % map_id)
		for cell: Vector2i in laid:
			assert_false(view.bare.has(cell), "%s: nothing small where something stands at %s" % [map_id, cell])
			assert_eq(view.detail_layer.get_cell_atlas_coords(cell), view.kept.details[cell], "%s: as Scatter picked" % map_id)
		assert_eq(view.patch_layer != null, PunyTown.available() and not view.kept.patches.is_empty(), "%s: the Medieval Age's patches with the paid pack only" % map_id)
		if map_id == "town":
			assert_null(view.patch_layer, "none in Pixelheim's yards and gardens")
		elif PunyTown.available() and map_id != "mirefen":
			assert_not_null(view.patch_layer, "%s: patches in the open land" % map_id)


func test_rooms_and_dungeons_grow_no_small_things() -> void:
	for map_id: String in ["town_inn", "seacave", "shafts"]:
		var root := Node2D.new()
		add_child_autofree(root)
		var standing := Node2D.new()
		root.add_child(standing)
		var data := MapData.load_by_id(map_id)
		var view := MapView.new(data, standing)
		view.plan(data.spawn)
		view.build(root)
		# Without the paid pack a room is drawn on Shade's ground (no
		# PunyInterior), with nothing for small things to grow on.
		assert_true(view.detail_layer == null or view.detail_layer.get_used_cells().is_empty(), "%s grows none" % map_id)
