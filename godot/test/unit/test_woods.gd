extends GutTest
## The woods and the ridges (PIX-309). Tom's audit: every ridge a straight
## planter of identical pines, the Deepwood an orchard of evenly spaced
## single trees, Saltmere's sea ending at the map's south edge in a pine
## hedge, and green pines against the Frostgate's snow at its pass. The
## Deepwood grows in clumps now, glades and thickets, trees of mixed sizes
## and kinds by region with undergrowth between them and the ground darker
## under them, the sun coming down into its glades; a ridge's pines and
## rocks stand out on its rim; the sea runs on past Saltmere's edges; the
## Reach's pines whiten toward the Frostgate. None of it blocks.


func before_all() -> void:
	KeptGround.forget()


func after_all() -> void:
	KeptGround.forget()


static func _forest(map: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in map.grid:
		if map.grid[cell] == "forest":
			out.append(cell)
	return out


func test_the_deepwood_grows_in_clumps_glades_and_thickets() -> void:
	var map := MapData.load_by_id("deepwood")
	var forest := _forest(map)
	assert_gt(forest.size(), 1000, "the Deepwood is a forest")
	var counts := {}
	var looks := {}
	var sizes := {}
	for paid: bool in [true, false]:
		for cell: Vector2i in forest:
			var pieces := Woods.pieces("forest", cell, Scatter.choice(map.grid, cell), Woods.look_at(map, cell), paid)
			if paid:
				counts[pieces.size()] = int(counts.get(pieces.size(), 0)) + 1
				for piece: Dictionary in pieces:
					looks[piece["rect"]] = true
					sizes[(piece["rect"] as Rect2).size] = true
			for piece: Dictionary in pieces:
				assert_eq(piece["sheet"], Woods.SHEET if paid else Woods.PUNY, "the Medieval Age's with the paid pack, Shade's free trees without")
	assert_gt(int(counts.get(0, 0)), forest.size() / 20, "glades: cells with nothing standing (%s)" % counts)
	assert_gt(int(counts.get(2, 0)) + int(counts.get(3, 0)), forest.size() / 5, "thickets: two trees to a cell (%s)" % counts)
	assert_gt(looks.size(), 12, "trees of many kinds")
	assert_true(sizes.has(Vector2(16, 32)) and sizes.has(Vector2(16, 16)) and sizes.has(Vector2(32, 32)), "tall, short and big ones (%s)" % str(sizes.keys()))


func test_each_region_grows_its_own_trees() -> void:
	var frost := MapData.load_by_id("frostgate")
	var snowy := 0
	for cell: Vector2i in _forest(frost):
		assert_eq(Woods.look_at(frost, cell), "snowy", "the Frostgate's woods under snow at %s" % cell)
		for piece: Dictionary in Woods.pieces("forest", cell, Scatter.choice(frost.grid, cell), "snowy", true):
			if (piece["rect"] as Rect2).position.y >= 9 * 16 and (piece["rect"] as Rect2).position.y < 12 * 16:
				snowy += 1
	assert_gt(snowy, 30, "snowy trees in the Frostgate")
	var deep := MapData.load_by_id("deepwood")
	assert_eq(Woods.look_at(deep, Vector2i(10, 3)), "deep")
	var reach := MapData.load_by_id("overworld")
	# The Ash's ridges keep Shade's free trees, as its own art has them.
	assert_eq(reach.grid[Vector2i(18, 18)], "mountain")
	assert_eq(Woods.look_at(reach, Vector2i(18, 18)), "", "an outcrop in the Ash")


func test_nothing_in_the_woods_blocks_and_the_ridge_grows_on_its_rim() -> void:
	var map := MapData.load_by_id("deepwood")
	for cell: Vector2i in _forest(map):
		assert_true(map.is_walkable(cell) or map.portals.has(cell) or map.covered.has(cell), "the forest walk-through at %s" % cell)
	var deep_rock := 0
	var rim := 0
	for ridged: MapData in [map, MapData.load_by_id("overworld")]:
		for cell: Vector2i in ridged.grid:
			if ridged.grid[cell] != "mountain":
				continue
			var open := false
			var near := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var other: String = ridged.grid.get(cell + Vector2i(dx, dy), "mountain")
					if other != "mountain":
						near = true
						if absi(dx) + absi(dy) == 1:
							open = true
			var choice := Scatter.choice(ridged.grid, cell)
			if not near:
				assert_eq(choice, -1, "%s: nothing stands over the crown at %s" % [ridged.id, cell])
				deep_rock += 1
			elif open and choice >= 0:
				rim += 1
	assert_gt(deep_rock, 100, "deep in the Reach's rock, the crown alone")
	assert_gt(rim, 80, "pines and rocks step out on the rim (%d)" % rim)


func test_the_ground_lies_darker_under_the_canopy_and_the_sun_comes_into_the_glades() -> void:
	var map := MapData.load_by_id("deepwood")
	var kept := KeptGround.of(map, map.grid, MapView.EDGE_PAD)
	assert_not_null(kept.shade_map, "the Deepwood's canopy shades its ground")
	for cell: Vector2i in [Vector2i(10, 3), Vector2i(20, 3), Vector2i(4, 5)]:
		assert_eq(kept.shade_image.get_pixelv(cell).r > 0.5, map.grid[cell] == "forest", "shaded under the forest only, at %s" % cell)
	var town := MapData.load_by_id("seacave")
	assert_null(KeptGround.of(town, town.grid, MapView.EDGE_PAD).shade_map, "no canopy underground")
	var shafts := Woods.shafts(map)
	assert_between(shafts.size(), 3, Woods.SHAFTS, "the sun into a few glades")
	for i in shafts.size():
		var cell := shafts[i]
		assert_true(WorldTiles.is_walkable(map.grid[cell]) and map.grid[cell] != "forest", "a shaft on open ground at %s" % cell)
		for j in i:
			assert_gte(maxi(absi(shafts[j].x - cell.x), absi(shafts[j].y - cell.y)), Woods.SHAFT_APART, "spread out")
	assert_eq(Woods.shafts(MapData.load_by_id("overworld")).size(), 0, "the Deepwood's alone")
	# The shade multiplies the ground by its own shade alone (PIX-330): the
	# night's dark and the lights on it too darkened the ground twice at
	# night, and lit a strip along every line between two maps.
	var shade := FileAccess.get_file_as_string("res://shaders/canopy_shade.gdshader")
	assert_string_contains(shade, "render_mode blend_mul, unshaded;", "the shade takes no light of its own")


func test_saltmeres_sea_runs_on_past_its_edges() -> void:
	var origin := ReachPlane.origin("saltmere")
	var size := ReachPlane.size_of("saltmere")
	for x in range(20, 28):
		assert_eq(ReachPlane.tile(origin + Vector2i(x, size.y + 2)), "deep_sea", "south of Saltmere, the open sea at %d" % x)
	assert_eq(ReachPlane.tile(origin + Vector2i(size.x + 3, 10)), "deep_sea", "east of it too")
	assert_eq(ReachPlane.tile(origin + Vector2i(-2, 20)), ReachPlane.RIDGE, "beside its cliffs, the ridge's rock")
	assert_eq(ReachPlane.tile(Vector2i(130, 80)), ReachPlane.RIDGE, "south of the Deepwood, the ridge")
	assert_eq(ReachPlane.tile(Vector2i(-200, -200)), ReachPlane.RIDGE, "far off, the ridge")


func test_the_reachs_pines_whiten_toward_the_frostgate() -> void:
	assert_true(PunyTerrain.snows_on("overworld", Vector2i(68, 0)), "at the pass")
	assert_true(PunyTerrain.snows_on("overworld", Vector2i(80, 1)))
	assert_false(PunyTerrain.snows_on("overworld", Vector2i(68, 9)), "not down in the Reach")
	assert_false(PunyTerrain.snows_on("overworld", Vector2i(10, 0)), "not west of the Frostgate")
	assert_false(PunyTerrain.snows_on("frostgate", Vector2i(10, 10)), "a snowfield's own whiten with its region")
	var thinning := 0
	for x in range(40, 96):
		if PunyTerrain.snows_on("overworld", Vector2i(x, 3)):
			thinning += 1
	assert_between(thinning, 5, 50, "the snow thins out a few cells down (%d of 56)" % thinning)
	var reach := MapData.load_by_id("overworld")
	var kept := KeptGround.of(reach, reach.grid, MapView.EDGE_PAD)
	assert_false(kept.crowns_toned, "the Reach's own region keeps its green")
	assert_not_null(kept.crown_map, "but its pines by the Frostgate whiten")
	assert_eq(kept.crown_image.get_pixel(68, 0).a, PunyTerrain.KIND_TONE)
	assert_eq(kept.crown_image.get_pixel(68, 20).a, 0.0)
	assert_eq(Woods.look_at(reach, Vector2i(66, 0)), "snowy", "and the pines on its rim there are snowy")
