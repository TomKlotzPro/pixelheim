extends GutTest
## The Ash and Blackiron as burnt land (PIX-308): the rock by the ash burns
## (each rock cell as the open ground nearest it, through the rock), is toned
## as burnt rock and crowned by no pines, dead trees standing on it instead;
## the Ash grows burnt tufts, charcoal, ash and cinders that glow on a layer
## of their own; Blackiron's outcrops are worked, rails and spoil flat on open
## ground off the roads, what stands up standing on the rock, nothing that
## blocks; and the mines and the mountain road breathe the Ash's air.


func before_all() -> void:
	KeptGround.forget()


func after_all() -> void:
	KeptGround.forget()


## A grid from rows of letters: a ash, . grass, = path, M mountain, ~ water.
static func _grid(rows: Array) -> Dictionary:
	var tiles := {"a": "ash", ".": "grass", "=": "path", "M": "mountain", "~": "water"}
	var grid := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			grid[Vector2i(x, y)] = tiles[row[x]]
	return grid


func test_rock_burns_as_the_ground_nearest_it() -> void:
	var grid := _grid([
		"aaaaaa......",
		"aMMMMa......",
		"aMMMMMMMMMM.",
		"aMMMMa......",
		"aa~~aa......",
	])
	var burnt := AshLand.burnt(grid, Vector2i(12, 5), {})
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(4, 3), Vector2i(1, 3)]:
		assert_true(burnt.has(cell), "the outcrop in the ash burns at %s" % cell)
	assert_true(burnt.has(Vector2i(3, 3)), "water beside it cools nothing")
	assert_false(burnt.has(Vector2i(10, 2)), "the ridge's end by the grass doesn't")
	for cell: Vector2i in burnt:
		assert_eq(grid[cell], "mountain", "only rock burns")


func test_the_reach_and_blackiron_burn_and_the_mountain_road_keeps_its_ridges() -> void:
	var mines := MapData.load_by_id("blackiron")
	var burnt := AshLand.burnt(mines.grid, mines.size, mines.regions)
	var rock := mines.grid.values().count("mountain")
	assert_eq(burnt.size(), rock, "all of Blackiron's rock is burnt")
	var reach := MapData.load_by_id("overworld")
	burnt = AshLand.burnt(reach.grid, reach.size, reach.regions)
	for cell: Vector2i in [Vector2i(19, 18), Vector2i(20, 19), Vector2i(15, 27), Vector2i(30, 9)]:
		assert_true(burnt.has(cell), "the Ash's outcrops and the ridge along it burn at %s" % cell)
	for cell: Vector2i in reach.grid:
		if reach.grid[cell] == "mountain" and cell.y > 40:
			assert_false(burnt.has(cell), "the green south's ridges don't, at %s" % cell)
	var road := MapData.load_by_id("mountain_road")
	assert_true(AshLand.burnt(road.grid, road.size, road.regions).is_empty(), "the mountain road's grey pines stay its own")


func test_burnt_rock_is_toned_and_crowned_by_no_pines() -> void:
	var data := MapData.load_by_id("blackiron")
	var kept := KeptGround.of(data, data.grid, 2)
	assert_false(kept.burnt.is_empty())
	for cell: Vector2i in kept.burnt:
		var tone := kept.tint_image.get_pixelv(cell)
		var burnt_rock: Color = PunyTerrain.TINTS["burnt_rock"]
		assert_lt(Vector3(tone.r - burnt_rock.r, tone.g - burnt_rock.g, tone.b - burnt_rock.b).length(), 0.01, "burnt rock's tone at %s" % cell)
		assert_eq(PunyTerrain.tone_at(kept.tint_image, cell), "tone")
		for corner: Vector2i in [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]:
			assert_eq(kept.crown_at(corner), -1, "no pine over burnt rock at %s" % corner)
	var reach := MapData.load_by_id("overworld")
	var green := KeptGround.of(reach, reach.grid, 2)
	assert_true(range(green.crowns.size()).any(func(i: int) -> bool: return green.crowns[i] >= 0), "the green ridges keep their pines")


func test_dead_trees_stand_on_burnt_rock_in_place_of_pines() -> void:
	var grid := {}
	for y in 60:
		for x in 60:
			grid[Vector2i(x, y)] = "mountain"
	var grown := 0
	for cell: Vector2i in grid:
		var snag := AshLand.snag(grid, cell)
		if Scatter.choice(grid, cell) == AshLand.BOULDER:
			assert_eq(snag, -1, "a boulder stays a boulder at %s" % cell)
		if snag >= 0:
			grown += 1
			assert_between(snag, 0, AshArt.SNAGS.size() - 1)
			assert_eq(AshLand.snag(grid, cell), snag, "the same every time")
	assert_almost_eq(grown * 100.0 / grid.size(), float(AshLand.SNAGS), 3.0, "about as many as the pines were")
	for i in AshArt.SNAGS.size():
		var image := AshArt.draw("snag_%d" % i)
		assert_eq(image.get_size(), Vector2i(AshArt.TILE, AshArt.SNAG_HEIGHT))
		assert_gt(image.get_pixel(7, AshArt.SNAG_HEIGHT - 3).a, 0.0, "dead tree %d stands on its foot" % i)


func test_the_ash_grows_burnt_things_and_cinders_glow_apart() -> void:
	var kinds := {}
	for y in 80:
		for x in 80:
			var kind := Scatter.detail({Vector2i(x, y): "ash"}, Vector2i(x, y))
			if kind != "":
				kinds[kind] = true
	for kind: String in ["burnt_tuft", "charcoal", "ash_stones", "cinders"]:
		assert_has(kinds, kind, "the ash grows %s" % kind)
	assert_eq(Scatter.detail({Vector2i(3, 3): "grass"}, Vector2i(3, 3), "mines"), Scatter.detail({Vector2i(3, 3): "ash"}, Vector2i(3, 3)), "Blackiron's grass is burnt as the ash is")
	for kind: String in GroundDetail.kinds():
		for variant in GroundDetail.VARIANTS.size():
			assert_eq(GroundDetail.glows(GroundDetail.coords(kind, variant)), kind == "cinders", "only cinders glow: %s" % kind)


func test_blackiron_is_worked_and_nothing_it_lays_blocks() -> void:
	var data := MapData.load_by_id("blackiron")
	var lines := 0
	for working: Dictionary in AshLand.WORKINGS["blackiron"]:
		lines += AshLand.rail_cells(working["rails"]).size()
	for paid: bool in [true, false]:
		var before := [data.grid.hash(), data.covered.hash()]
		var plan := AshLand.workings(data, {}, paid)
		assert_eq([data.grid.hash(), data.covered.hash()], before, "planning changes nothing on the map")
		assert_eq(plan["rails"], lines, "every rail laid (paid %s)" % paid)
		assert_gt(plan["spoil"], 5, "spoil heaped")
		assert_gt(plan["standing"], 10, "shoring, carts, winches and ore stand at the faces")
		for piece: Dictionary in plan["pieces"]:
			var cell: Vector2i = piece["cell"]
			if piece["flat"]:
				assert_true(data.is_walkable(cell) and data.tile_at(cell) in ["ash", "grass"], "flat on open ground at %s" % cell)
				assert_false(data.portals.has(cell), "never on a way on")
			else:
				assert_eq(data.tile_at(cell), "mountain", "standing on the rock, which blocks already, at %s" % cell)
			if not paid:
				assert_ne(piece["sheet"], "props", "Shade's CC0 sheets and our own without the pack")
	# A cell where something stands is left alone.
	var first: Vector2i = AshLand.rail_cells(AshLand.WORKINGS["blackiron"][0]["rails"])[0]
	var kept_clear := AshLand.workings(data, {first: true}, true)
	assert_false(kept_clear["pieces"].any(func(piece: Dictionary) -> bool: return piece["cell"] == first), "nothing laid where something stands")
	assert_true(AshLand.workings(MapData.load_by_id("overworld"), {}, true)["pieces"].is_empty(), "only a mining country is worked")


func test_a_drawn_blackiron_lays_its_workings_where_nothing_stands() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var standing := Node2D.new()
	root.add_child(standing)
	var data := MapData.load_by_id("blackiron")
	var view := MapView.new(data, standing)
	view.plan(data.spawn)
	view.build(root)
	assert_false(view.workings["pieces"].is_empty())
	for cell: Vector2i in view.worked:
		assert_false(view.bare.has(cell), "nothing where something stands at %s" % cell)
		assert_false(view.solid_scatter.has(cell), "nor on the field's blocking scatter at %s" % cell)
		assert_false(view.field.has(cell), "no decor grown over a working at %s" % cell)
	assert_gt(view.snags.size(), 50, "dead trees on the burnt rock")
	for cell: Vector2i in view.snags:
		assert_true(view.kept.burnt.has(cell))
	assert_gt(view.ember_layer.get_used_cells().size(), 10, "cinders glowing in the ash")


func test_the_mines_and_the_mountain_road_breathe_the_ashs_air() -> void:
	var mines := MapData.load_by_id("blackiron")
	assert_eq(Weather.air_at(mines, Vector2i(20, 16)), "ash")
	var road := MapData.load_by_id("mountain_road")
	assert_eq(Weather.air_at(road, road.spawn), "ash")
	assert_false(Weather.rains_in(mines, "ash"), "no shower over the Ash's heat")
