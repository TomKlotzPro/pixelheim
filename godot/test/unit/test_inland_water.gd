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


## A `const float` of a shader's, by name.
func _shader_number(code: String, constant: String) -> float:
	var found := RegEx.create_from_string("const float %s = (-?[0-9.]+);" % constant).search(code)
	assert_not_null(found, "the shader has no %s" % constant)
	return found.get_string(1).to_float() if found else NAN


func _code(mask: Image, cell: Vector2i) -> int:
	return roundi(mask.get_pixelv(cell).a * 255.0)


## inland_water.gdshaderinc's `water_in` at `at` (mask pixels), read as its
## sampler reads the mask: between four cells' middles, the edge's carried on.
func _water_in(mask: Image, at: Vector2) -> float:
	var spot := at / PunyTerrain.TILE - Vector2(0.5, 0.5)
	var low := spot.floor()
	var part := spot - low
	var red := 0.0
	var blue := 0.0
	for dy in 2:
		for dx in 2:
			var texel := mask.get_pixelv((Vector2i(low) + Vector2i(dx, dy)).clamp(Vector2i.ZERO, mask.get_size() - Vector2i.ONE))
			var weight := (part.x if dx == 1 else 1.0 - part.x) * (part.y if dy == 1 else 1.0 - part.y)
			red += texel.r * weight
			blue += texel.b * weight
	return maxf(red, blue * 3.0)


## The shader's `in_water` there, away from a bridge and a river's swing: how
## many pixels inside the drawn bank `at` lies (below 0: on the land's side)
## where the bank's wander bends it by `bend`; `lie` its `bank_lie`, `soft`
## the mire's softening (its `water_red`).
func _in_water(mask: Image, at: Vector2, bend: Vector2, lie: float, soft := 0.0) -> float:
	var here := 0.0
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		here += 0.25 * _water_in(mask, at + bend + corner * soft)
	return (here - 0.5) * PunyTerrain.TILE - lie


## Every way a bank's wander can bend it, at its most and not at all.
func _bends(wander: float) -> Array[Vector2]:
	var bends: Array[Vector2] = []
	for y: float in [-1.0, 0.0, 1.0]:
		for x: float in [-1.0, 0.0, 1.0]:
			bends.append(Vector2(x, y) * wander)
	return bends


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
	assert_eq(_code(mask, Vector2i(0, 4)), tone + PunyTerrain.BANK_GROUNDS["grass"], "the rock's foot: grass, as its top (PIX-431)")


func test_the_ash_and_the_grass_reach_the_river_each_on_its_own_ground() -> void:
	# PIX-437: the shader lays each pixel of the bank by the land cell its
	# tone is read from, so at the Ash's border the two cells must say which
	# is the toned dirt and which the grass.
	var data := MapData.load_by_id("overworld")
	var mask := _mask(data.grid, data.size, "overworld")
	var tint := PunyTerrain.tint_map(data.grid, data.size, data.regions).get_image()
	var tone := PunyTerrain.WATER_CLEAR * PunyTerrain.TONE_BIT
	assert_eq(_code(mask, Vector2i(87, 27)) - tone, PunyTerrain.BANK_GROUNDS["dirt"], "the Ash's last cell: dirt")
	assert_eq(PunyTerrain.tone_at(tint, Vector2i(87, 27)), "tone", "wholly toned")
	assert_eq(_code(mask, Vector2i(88, 27)) - tone, PunyTerrain.BANK_GROUNDS["grass"], "the first of the green: grass")
	assert_eq(PunyTerrain.tone_at(tint, Vector2i(88, 27)), "fringe", "its own dirt alone")
	var shader := (load("res://shaders/inland_water.gdshaderinc") as ShaderInclude).code
	assert_string_contains(shader, "tone_read(at)", "the bank's land reads where the tone does")


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


func test_a_bank_can_be_drawn_inside_its_waters_cells() -> void:
	# The bank is drawn inside the water's cells, by its rim and its wander
	# (PIX-467: what stops the hero is those cells, and a bank drawn out
	# over the land put water under their feet). The shader reads how far in
	# a pixel lies from the mask's blue where its red is whole
	# (inland_water.gdshaderinc's water_in), so a cell deeper than its bank
	# touches no land, not even by a corner; and running or pooled water is
	# three cells thick at the least (the test below; the hole in the ice, a
	# cell thin, bends its own little).
	var shader := (load("res://shaders/inland_water.gdshaderinc") as ShaderInclude).code
	assert_string_contains(shader, "return BANK_IN + bank_wander(tone);")
	assert_string_contains(shader, "in_water = (here - 0.5) * CELL + mix(LANDING_IN, -bank_lie(tone), ease);", "the bank is drawn where it lies")
	assert_string_contains(shader, "if (mask_texel(cell).r < 0.5) {\n\t\tin_water = min(in_water,", "and never on a land cell")
	# The shader's sums, done here on its own numbers: a bank lies its lie
	# into its water's cells, give or take its wander.
	var rim := _shader_number(shader, "BANK_IN")
	assert_gte(rim, 1.0, "the bank's wet lip, a pixel, lies inside the water's cells")
	assert_lt(_shader_number(shader, "LANDING_IN"), 0.0, "and under a bridge's planks")
	assert_string_contains(shader, "-0.5, 0.5) * 2.0 * bank_wander(tone);", "a bank bends its wander at the most, so wandered all the way out it is still inside")
	# The river's swing brings a bank no further in than the bank's own
	# wander can, so the hero stops no shorter of the water for it.
	assert_eq(_shader_number(shader, "SWING_CAP"), rim + 2.0 * _shader_number(shader, "BANK_WANDER"))
	# The mirror stands where the sea's does, above the cells' edge, so no
	# water lies above it (reflections.gdshader).
	var mirror := (load("res://shaders/reflections.gdshader") as Shader).code
	assert_gt(_shader_number(mirror, "SPILL"), -rim)
	for map_id: String in ["overworld", "town", "deepwood", "mirefen", "frostgate", "demo"]:
		var data := MapData.load_by_id(map_id)
		var mask := _mask(data.grid, data.size, map_id)
		for cell: Vector2i in data.grid:
			if data.grid[cell] != "water":
				continue
			var dry := func(step: Vector2i) -> bool: return data.grid.has(cell + step) and not PunyTerrain.is_wet(data.grid[cell + step])
			if _depth(mask, cell) > 1:
				for y in range(-1, 2):
					for x in range(-1, 2):
						assert_false(dry.call(Vector2i(x, y)), "%s %s is deep and touches land" % [map_id, cell])
			# Three cells thick at the least (test_water_is_drawn_between_its_banks).
			if map_id != "frostgate":
				for way: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
					if dry.call(-way):
						assert_false(dry.call(way) or dry.call(way * 2), "%s %s is under three cells thick" % [map_id, cell])


## The shader's own sums done here on a small mask (`_in_water`, its lines
## held below): where a bank is drawn, and that water is left between two.
## The mask's measure of how far in a pixel lies stops at half a cell unless
## a cell deeper than its bank is beside it, so water two cells thick read 8
## px in right across: clear water came out a pale shallow all foam, the
## mire's (softened, lying 8 in) all marsh that still stopped the hero
## (PIX-467's review: the Mirefen's 2x2 tips, the village stream's 1x2 nubs).
## Three cells thick it has a middle; the maps' rule is in the test above.
func test_water_is_drawn_between_its_banks() -> void:
	var shader := (load("res://shaders/inland_water.gdshaderinc") as ShaderInclude).code
	# The twin's lines, as the shader has them.
	assert_string_contains(shader, "return max(texel.r, texel.b * 3.0);")
	assert_string_contains(shader, "float here = water_red(local_px + bend, mire && !landing ? MIRE_SOFT : 0.0);")
	assert_string_contains(shader, "float in_water = (here - 0.5) * CELL + mix(LANDING_IN, -bank_lie(tone), ease);")
	assert_string_contains(shader, "return BANK_IN + bank_wander(tone);")
	assert_string_contains(shader, "if (abs(in_water - lap) < 0.5")
	var rim := _shader_number(shader, "BANK_IN")
	# Past the lip and as far as the foam laps: open water.
	var foam := _shader_number(shader, "LAP_OUT") + _shader_number(shader, "LAP_SWING") + 0.5
	var tile := float(PunyTerrain.TILE)
	var waters := {
		"town": [_shader_number(shader, "BANK_WANDER"), 0.0, 3],
		"mirefen": [_shader_number(shader, "MIRE_WANDER"), _shader_number(shader, "MIRE_SOFT"), 3],
		"frostgate": [_shader_number(shader, "ICE_WANDER"), 0.0, 1],
	}
	for map_id: String in waters:
		var wander: float = waters[map_id][0]
		var soft: float = waters[map_id][1]
		var thick: int = waters[map_id][2]
		var mask := _mask(_river(12, thick), Vector2i(12, thick + 2), map_id)
		var x := 6.5 * tile
		assert_gt(_in_water(mask, Vector2(x, (1.0 + thick * 0.5) * tile), Vector2.ZERO, rim + wander, soft), foam, "%s: open water down the middle, %d thick" % [map_id, thick])
		for bend in _bends(wander):
			var deepest := -INF
			var wide := 0
			for y in (thick + 2) * PunyTerrain.TILE:
				var inside := _in_water(mask, Vector2(x, y + 0.5), bend, rim + wander, soft)
				deepest = maxf(deepest, inside)
				wide += int(inside >= 0.0)
				if y < PunyTerrain.TILE or y >= (thick + 1) * PunyTerrain.TILE:
					assert_lt(inside, 0.0, "%s: no water over the land at %d, bent %s" % [map_id, y, bend])
			assert_gt(deepest, foam, "%s: open water wherever its banks wander (%s)" % [map_id, bend])
			assert_gte(wide, (thick * PunyTerrain.TILE) / 3, "%s: and a third of its cells at the least (%s)" % [map_id, bend])
	# Two cells thick, clear water never gets past its foam and the mire's
	# is no water at all: why the maps keep to three.
	var thin := _mask(_river(12, 2), Vector2i(12, 4), "town")
	assert_lt(_in_water(thin, Vector2(6.5 * tile, 2.0 * tile), Vector2.ZERO, rim + waters["town"][0]), foam)
	thin = _mask(_river(12, 2), Vector2i(12, 4), "mirefen")
	assert_lt(_in_water(thin, Vector2(6.5 * tile, 2.0 * tile), Vector2.ZERO, rim + waters["mirefen"][0], waters["mirefen"][1]), 0.0)
	# A nub a cell out of a stream's bank, three cells long (the village's):
	# its middle cell has open water on the stream's side.
	var grid := {}
	for y in 9:
		for x in 7:
			grid[Vector2i(x, y)] = "water" if x >= 2 and x <= 5 or (x == 1 and y >= 3 and y <= 5) else "grass"
	var nub := _mask(grid, Vector2i(7, 9), "town")
	assert_gt(_in_water(nub, Vector2(2.0 * tile - 1.0, 4.5 * tile), Vector2.ZERO, rim + waters["town"][0]), foam, "a nub's middle")


## A bank's reeds (Scatter's `bank`, PIX-390) stand in their water's first
## cell, which the bank is now drawn inside (PIX-467): off the land's side
## by as far as the bank can lie in from it, less its wet lip, so a reed's
## foot is in the water or on that lip and never on the grass.
func test_a_banks_reeds_stand_in_the_water() -> void:
	var shader := (load("res://shaders/inland_water.gdshaderinc") as ShaderInclude).code
	var clear := int(_shader_number(shader, "BANK_IN") + 2.0 * _shader_number(shader, "BANK_WANDER")) - 1
	var sheet := (GroundDetail.tileset().get_source(0) as TileSetAtlasSource).texture.get_image()
	var last := GroundDetail.TILE - 1
	var seen := {}
	for sides in range(1, 16):
		var west := sides & 1 > 0
		var east := sides & 2 > 0
		var north := sides & 4 > 0
		var south := sides & 8 > 0
		# Water is three cells thick (above), so no land lies at both sides.
		if (west and east) or (north and south):
			continue
		for pick in 4:
			var variant := GroundDetail.bank_variant(west, east, north, south, pick)
			assert_gte(variant, GroundDetail.VARIANTS.size(), "a bank's own spot")
			seen[variant] = true
			var tile := GroundDetail.coords("reeds", variant) * GroundDetail.TILE
			# The inked pixels' first and last, across and down.
			var low := Vector2i(GroundDetail.TILE, GroundDetail.TILE)
			var high := Vector2i(-1, -1)
			for y in GroundDetail.TILE:
				for x in GroundDetail.TILE:
					if sheet.get_pixel(tile.x + x, tile.y + y).a > 0.0:
						low = low.min(Vector2i(x, y))
						high = high.max(Vector2i(x, y))
			var where := "%s for land %s" % [GroundDetail.spot(variant), sides]
			assert_eq(high - low, Vector2i(5, 5), "the reeds are drawn whole at %s" % where)
			if west:
				assert_gte(low.x, clear, "off the west bank: %s" % where)
			if east:
				assert_gte(last - high.x, clear, "off the east bank: %s" % where)
			# A reed rises over the bank behind it: its foot stands clear.
			if north:
				assert_gte(high.y, clear, "its foot off the north bank: %s" % where)
			if south:
				assert_gte(last - high.y, clear, "its foot off the south bank: %s" % where)
	assert_gt(seen.size(), 8, "and not one spot for all")
	# Scatter asks for them by the land round the cell, the same every time.
	var grid := _river(40, 2)
	for x in 40:
		for y: int in [1, 2]:
			var variant := Scatter.detail_variant(grid, Vector2i(x, y))
			assert_eq(variant, Scatter.detail_variant(grid, Vector2i(x, y)))
			var spot := GroundDetail.spot(variant)
			assert_true(spot.y >= 6 if y == 1 else spot.y == 0, "by the land's side at %s: %s" % [Vector2i(x, y), spot])
	assert_lt(Scatter.detail_variant({Vector2i.ZERO: "grass"}, Vector2i.ZERO), GroundDetail.VARIANTS.size(), "open ground keeps its own spots")


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
