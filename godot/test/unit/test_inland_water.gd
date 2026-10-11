extends GutTest
## Water inland held to the sea (PIX-306): the water mask tells the shaders
## how deep each cell of a river, a pond or a pool lies (blue: cells to its
## bank / 3), what water it is (alpha: its tone by map, whether a bridge
## stands in it, which way it runs) and, on the land by its bank, the tone
## and the land's ground, so region_tint.gdshader can bend the bank off the
## grid and draw the land back where it bends in. The sea keeps its own.


## A river `width` rows deep across a field `length` long, grass above and
## below, a bridge across it at column `bridge` (-1 for none).
func _river(length: int, width: int, bridge := -1) -> Dictionary:
	var grid := {}
	for y in width + 2:
		for x in length:
			var wet := y > 0 and y <= width
			grid[Vector2i(x, y)] = ("bridge" if x == bridge else "water") if wet else "grass"
	return grid


func _mask(grid: Dictionary, size: Vector2i, map_id := "") -> Image:
	return PunyTerrain.water_map(grid, size, map_id).get_image()


func _depth(mask: Image, cell: Vector2i) -> int:
	return roundi(mask.get_pixelv(cell).b * PunyTerrain.DEPTH_CELLS)


func _code(mask: Image, cell: Vector2i) -> int:
	return roundi(mask.get_pixelv(cell).a * 255.0)


func test_a_river_deepens_from_its_banks() -> void:
	var mask := _mask(_river(20, 7), Vector2i(20, 9))
	assert_eq(_depth(mask, Vector2i(10, 1)), 1, "by the bank")
	assert_eq(_depth(mask, Vector2i(10, 2)), 2)
	assert_eq(_depth(mask, Vector2i(10, 4)), 3, "deep down the middle")
	assert_eq(_depth(mask, Vector2i(10, 6)), 2)
	assert_eq(_depth(mask, Vector2i(10, 7)), 1, "by the other bank")
	assert_eq(_depth(mask, Vector2i(10, 0)), 0, "the bank itself is dry")
	assert_eq(mask.get_pixel(10, 4).r, 1.0, "and still water to the foam and the reflections")


func test_a_ponds_corner_is_shallow_along_its_diagonal() -> void:
	# A pond three wide: its middle is deep only if no bank lies nearer
	# along a diagonal either.
	var grid := {}
	for y in 7:
		for x in 7:
			grid[Vector2i(x, y)] = "water" if x >= 2 and y >= 2 else "grass"
	var mask := _mask(grid, Vector2i(7, 7))
	assert_eq(_depth(mask, Vector2i(2, 2)), 1, "the corner by the bank")
	assert_eq(_depth(mask, Vector2i(3, 3)), 2, "a bank one cell off along the diagonal")


func test_water_runs_on_past_the_maps_edge() -> void:
	# A river running out of the map's side carries on beyond it, deep as
	# ever, not shallowing to a bank at the edge.
	var mask := _mask(_river(6, 7), Vector2i(6, 9))
	assert_eq(_depth(mask, Vector2i(0, 4)), 3)
	assert_eq(_depth(mask, Vector2i(5, 4)), 3)


func test_each_regions_water_has_its_tone() -> void:
	var grid := _river(12, 3)
	var size := Vector2i(12, 5)
	assert_eq(_code(_mask(grid, size, "overworld"), Vector2i(6, 2)) / PunyTerrain.TONE_BIT, PunyTerrain.WATER_CLEAR, "clear in the Reach")
	assert_eq(_code(_mask(grid, size, "town"), Vector2i(6, 2)) / PunyTerrain.TONE_BIT, PunyTerrain.WATER_CLEAR, "and in the village")
	assert_eq(_code(_mask(grid, size, "mirefen"), Vector2i(6, 2)) / PunyTerrain.TONE_BIT, PunyTerrain.WATER_MIRE, "murk in the mire")
	assert_eq(_code(_mask(grid, size, "deepwood"), Vector2i(6, 2)) / PunyTerrain.TONE_BIT, PunyTerrain.WATER_DEEP, "dark in the wood")
	assert_eq(_code(_mask(grid, size, "frostgate"), Vector2i(6, 2)) / PunyTerrain.TONE_BIT, PunyTerrain.WATER_ICE, "cold in the pass")


func test_rivers_run_along_their_length_and_pools_lie_still() -> void:
	var across := _mask(_river(12, 3), Vector2i(12, 5), "overworld")
	assert_eq(PunyTerrain.FLOWS[_code(across, Vector2i(6, 2)) % PunyTerrain.SPAN_BIT], Vector2i.LEFT, "a river across the map runs west")
	var grid := {}
	for y in 12:
		for x in 5:
			grid[Vector2i(x, y)] = "water" if x >= 1 and x <= 3 else "grass"
	var down := _mask(grid, Vector2i(5, 12), "town")
	assert_eq(PunyTerrain.FLOWS[_code(down, Vector2i(2, 6)) % PunyTerrain.SPAN_BIT], Vector2i.DOWN, "one down it runs south")
	for map_id: String in ["mirefen", "deepwood", "frostgate"]:
		var still := _mask(_river(12, 3), Vector2i(12, 5), map_id)
		assert_eq(_code(still, Vector2i(6, 2)) % PunyTerrain.SPAN_BIT, 0, "%s's water lies still" % map_id)


func test_a_bridge_stands_in_the_water() -> void:
	var mask := _mask(_river(12, 3, 6), Vector2i(12, 5), "overworld")
	assert_ne(_code(mask, Vector2i(6, 2)) & PunyTerrain.SPAN_BIT, 0, "the bridge's cells")
	assert_eq(_code(mask, Vector2i(5, 2)) & PunyTerrain.SPAN_BIT, 0, "the open water beside it")
	assert_eq(_depth(mask, Vector2i(6, 2)), 2, "water runs on under it")


func test_the_land_by_a_bank_carries_the_tone_and_its_ground() -> void:
	var grid := _river(12, 3)
	for x in 12:
		grid[Vector2i(x, 0)] = "path" if x < 6 else "grass"
		grid[Vector2i(x, 4)] = "sand"
	grid[Vector2i(0, 4)] = "mountain"
	var mask := _mask(grid, Vector2i(12, 5), "mirefen")
	var tone := PunyTerrain.WATER_MIRE * PunyTerrain.TONE_BIT
	assert_eq(mask.get_pixel(3, 0).r, 0.0, "the bank stays land to the foam and the reflections")
	assert_eq(_code(mask, Vector2i(3, 0)), tone + PunyTerrain.BANK_GROUNDS["dirt"], "a road by the water: dirt")
	assert_eq(_code(mask, Vector2i(9, 0)), tone + PunyTerrain.BANK_GROUNDS["grass"], "grass")
	assert_eq(_code(mask, Vector2i(6, 4)), tone + PunyTerrain.BANK_GROUNDS["sand"], "a beach: sand")
	assert_eq(_code(mask, Vector2i(0, 4)), tone + PunyTerrain.BANK_GROUNDS["cliff"], "the rock's foot: dirt")


func test_land_away_from_the_water_and_the_sea_carry_nothing() -> void:
	var grid := _river(12, 3)
	grid[Vector2i(3, 5)] = "grass"
	var mask := _mask(grid, Vector2i(12, 6))
	assert_eq(_code(mask, Vector2i(3, 5)), 0, "two cells from the bank")
	var coast := {}
	for y in 6:
		for x in 6:
			coast[Vector2i(x, y)] = "sea" if y >= 3 else ("shore" if y == 2 else "sand")
	var sea := _mask(coast, Vector2i(6, 6), "saltmere")
	for cell: Vector2i in [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 4)]:
		assert_eq(_code(sea, cell), 0, "the sea and its shore keep Shade's own depths: %s" % cell)
		assert_eq(sea.get_pixelv(cell).b, 0.0)


func test_a_mask_worked_out_a_row_at_a_time_is_the_whole() -> void:
	# KeptGround works the water out a row a slice beside the hero; the
	# banks it marks on the row below must survive that row's own turn.
	for map_id: String in ["overworld", "town", "mirefen", "deepwood"]:
		var data := MapData.load_by_id(map_id)
		var whole := _mask(data.grid, data.size, map_id)
		var sliced := Image.create(data.size.x, data.size.y, false, Image.FORMAT_RGBA8)
		var above := PackedInt32Array()
		above.resize(data.size.x)
		for y in data.size.y:
			PunyTerrain.water_rows(sliced, data.grid, y, y + 1, above, map_id)
		assert_eq(sliced.get_data(), whole.get_data(), "%s's water, sliced" % map_id)


func test_the_regions_waters_as_drawn() -> void:
	# The Reach's river runs west, the village's comes down from the north
	# and turns west along its south wall, the Deepwood's lake and the
	# Mirefen's pools lie still; every inland cell has its depth.
	var cases := {
		"overworld": [Vector2i(30, 29), "clear west"], "town": [Vector2i(68, 10), "clear south"],
		"deepwood": [Vector2i(10, 9), "deep still"], "mirefen": [Vector2i(20, 6), "mire still"],
	}
	for map_id: String in cases:
		var data := MapData.load_by_id(map_id)
		var mask := _mask(data.grid, data.size, map_id)
		assert_eq(PunyTerrain.water_near(mask, cases[map_id][0], 0), cases[map_id][1], map_id)
		for cell: Vector2i in data.grid:
			if data.grid[cell] in ["water", "bridge"]:
				assert_between(_depth(mask, cell), 1, PunyTerrain.DEPTH_CELLS, "%s %s has a depth" % [map_id, cell])
	var town := MapData.load_by_id("town")
	assert_eq(PunyTerrain.water_near(_mask(town.grid, town.size, "town"), Vector2i(30, 36), 0), "clear west", "the village's river along its south wall")
	var saltmere := MapData.load_by_id("saltmere")
	assert_eq(PunyTerrain.water_near(_mask(saltmere.grid, saltmere.size, "saltmere"), Vector2i(33, 30), 8), "", "Saltmere's sea is the sea")


func test_the_bridges_planks_and_the_ground_read_the_water() -> void:
	# The ground draws the water (water_life) and the planks show it between
	# them (planks); both read the same masks, so a map beside the hero's
	# hands them over too (MapView._toned).
	var shader := (load("res://shaders/region_tint.gdshader") as Shader).code
	assert_string_contains(shader, "inland_water.gdshaderinc")
	assert_string_contains(shader, "uniform bool planks")
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(MapData.load_by_id("mirefen"), actors)
	view.plan(view.data.spawn)
	view.build(root)
	assert_eq(view.ground_layer.material.get_shader_parameter("water_life"), true)
	var planks := view._objects_layer.material as ShaderMaterial
	assert_eq(planks.get_shader_parameter("planks"), true)
	assert_eq(planks.get_shader_parameter("strength"), 0.0, "the planks keep their own wood")
	assert_true(planks in view._toned)
