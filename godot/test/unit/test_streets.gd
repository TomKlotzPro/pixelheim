extends GutTest
## Pixelheim's streets show its age (PIX-307): trodden dirt in the Ashes and
## the Hamlet, gravel from the Village, Upper Street and the gate road
## cobbled in the Town, and in the City every street cobbled, the square and
## the avenue to the gate in sandstone, brick round the fountain. Greyhold's
## courtyard is flagged and its paths cobbled; the Frostgate's road cobbled
## up to its observatory's flagged yard. Paving is only drawn: it covers
## open ground and never touches the grid.

const UPPER_STREET := Vector2i(40, 12)
const GATE_ROAD := Vector2i(40, 5)
const SQUARE := Vector2i(36, 22)
const BY_THE_FOUNTAIN := Vector2i(39, 24)
const HEARTH_LANE := Vector2i(20, 26)
## The road outside the wall, and the farm track over the river: dirt at
## every age.
const OUTSIDE := Vector2i(40, 0)
const FARM_TRACK := Vector2i(76, 14)


func _town() -> Dictionary:
	return MapData.load_by_id("town").grid


func test_each_age_paves_its_own_streets() -> void:
	var grid := _town()
	var ages := []
	for tier in range(Town.MAX_TIER + 1):
		ages.append(Streets.plan("town", grid, tier))
	assert_true(ages[0].is_empty(), "the Ashes' streets are trodden dirt")
	assert_true(ages[1].is_empty(), "and the Hamlet's")
	assert_eq(ages[2].get(UPPER_STREET), "gravel", "the Village gravels its streets")
	assert_eq(ages[2].get(SQUARE), "gravel", "and its square")
	assert_eq(ages[3].get(UPPER_STREET), "cobbles", "the Town cobbles Upper Street")
	assert_eq(ages[3].get(GATE_ROAD), "cobbles", "and the gate road")
	assert_eq(ages[3].get(SQUARE), "gravel", "its square still gravel")
	assert_eq(ages[4].get(HEARTH_LANE), "cobbles", "the City cobbles every street")
	assert_eq(ages[4].get(SQUARE), "sandstone", "its square in sandstone")
	assert_eq(ages[4].get(GATE_ROAD), "sandstone", "and its avenue to the gate")
	assert_eq(ages[4].get(BY_THE_FOUNTAIN), "bricks", "brick round the fountain")
	for tier in range(2, Town.MAX_TIER + 1):
		assert_ne(Streets.tiles(ages[tier]), Streets.tiles(ages[tier - 1]), "age %d draws its own paving" % tier)
		for cell: Vector2i in [OUTSIDE, FARM_TRACK]:
			assert_false(ages[tier].has(cell), "%s stays a dirt road at age %d" % [cell, tier])


## The fountain stands on its paving, centred (PIX-364). The grid marks one
## cell "well" and the basin is 2x2 from it, so a Village paving round that
## one cell kerbed a one-cell square under the basin's top-left quarter.
## Whatever the square lays under and round it apart from its own paving (a
## hole, the City's brick ring) is centred on the basin within an art pixel.
func test_the_fountain_sits_on_its_base() -> void:
	var grid := MapData.load_tiered("town", ["fountain"], 1).grid
	var fountain: Dictionary = PunyProps.plan(grid)["props"].filter(func(p: Dictionary) -> bool: return p["kind"] == "fountain")[0]
	var cell: Vector2i = fountain["cell"]
	var basin := Rect2(Vector2(cell * 16), Vector2.ZERO)
	for piece: Array in fountain["tiles"]:
		basin = basin.merge(Rect2(Vector2((cell + piece[0]) * 16), Vector2(16, 16)))
	var bases := 0
	for tier in range(Town.MAX_TIER + 1):
		var paved := Streets.plan("town", grid, tier)
		var square: String = paved.get(cell + Vector2i(-3, 0), "")
		var base := Rect2()
		for y in range(cell.y - 1, cell.y + 3):
			for x in range(cell.x - 1, cell.x + 3):
				if paved.get(Vector2i(x, y), "") != square:
					var at := Rect2(Vector2(x, y) * 16, Vector2(16, 16))
					base = at if not base.has_area() else base.merge(at)
		if base.has_area():
			bases += 1
			assert_lte(base.get_center().distance_to(basin.get_center()), 1.0, "age %d: the basin on its base (%s, %s)" % [tier, base, basin])
	assert_gt(bases, 0, "the City's brick ring at least")


func test_paving_lies_on_open_ground_and_leaves_the_grid_alone() -> void:
	for map_id: String in ["town", "greyhold", "frostgate"]:
		var data := MapData.load_by_id(map_id)
		var before := data.grid.hash()
		for tier in range(Town.MAX_TIER + 1):
			for cell: Vector2i in Streets.plan(map_id, data.grid, tier):
				var tile: String = data.grid[cell]
				assert_true(WorldTiles.is_walkable(tile) or tile in ["well", "lamp", "counter", "crate", "barrel"],
					"%s paves %s at %s, open ground or a prop standing on it" % [map_id, tile, cell])
		assert_eq(data.grid.hash(), before, "%s's grid as it was" % map_id)


func test_greyhold_and_the_frostgate_are_paved_at_any_age() -> void:
	var fort := MapData.load_by_id("greyhold").grid
	var pass_ := MapData.load_by_id("frostgate").grid
	for tier in [0, Town.MAX_TIER]:
		var yard := Streets.plan("greyhold", fort, tier)
		assert_eq(yard.get(Vector2i(33, 20)), "flags", "the courtyard flagged")
		assert_eq(yard.get(Vector2i(37, 20)), "sandstone", "its paths in sandstone, the road through the gate showing on the flags")
		assert_false(yard.has(Vector2i(12, 26)), "the road outside the walls stays dirt")
		var frost := Streets.plan("frostgate", pass_, tier)
		assert_eq(frost.get(Vector2i(27, 14)), "cobbles", "the road to the observatory cobbled")
		assert_eq(frost.get(Vector2i(25, 9)), "flags", "its yard flagged")
	assert_true(Streets.plan("saltmere", MapData.load_by_id("saltmere").grid, Town.MAX_TIER).is_empty(), "a map with no areas paves nothing")


## The pack's edge pieces by which neighbours are paved: alone, along a
## street, at its end, in a corner; a cell paved all round takes a fill.
func test_each_cell_takes_the_piece_for_its_neighbours() -> void:
	var look: Dictionary = Streets.LOOKS["cobbles"]
	var edges: Vector2i = look["edges"]
	var piece := func(at: Vector2i) -> int: return at.y * Streets.COLUMNS + at.x
	var alone := {Vector2i(5, 5): "cobbles"}
	assert_eq(Streets.tile(alone, Vector2i(5, 5)), piece.call(edges + Vector2i(0, 3)), "a cell alone")
	var block := {}
	for y in 3:
		for x in 3:
			block[Vector2i(x, y)] = "cobbles"
	assert_eq(Streets.mask(block, Vector2i(0, 1)), 1 | 2 | 4 | 8 | 16, "the left side's middle")
	assert_eq(Streets.tile(block, Vector2i(0, 1)), piece.call(edges + Vector2i(8, 1)))
	assert_eq(Streets.mask(block, Vector2i(1, 1)), Streets.FULL)
	var fills: Array = look["fill"].map(func(at: Array) -> int: return int(at[1]) * Streets.COLUMNS + int(at[0]))
	assert_has(fills, Streets.tile(block, Vector2i(1, 1)), "the middle paved all round takes a fill")
	# Two looks meet in a straight join: each sees the other as paving.
	block[Vector2i(1, 1)] = "sandstone"
	assert_eq(Streets.mask(block, Vector2i(0, 1)), 1 | 2 | 4 | 8 | 16)


## Every one of the 256 neighbourhoods reduces to a piece the block holds.
func test_every_neighbourhood_has_its_piece() -> void:
	var made := {}
	for tile: int in Streets.pieces():
		made[tile] = true
	for bits in 256:
		var paved := {Vector2i.ZERO: "gravel"}
		for bit: int in Streets.NEIGHBOURS:
			if bits & bit:
				paved[Streets.NEIGHBOURS[bit]] = "gravel"
		var tile := Streets.tile(paved, Vector2i.ZERO)
		assert_true(made.has(tile), "neighbours %d: tile %d is one of the pieces" % [bits, tile])


## Drawn on the town's tileset, so made with it up front (One Reach,
## PIX-269), and the data names only looks there are, on maps there are.
func test_the_pieces_are_made_ahead_and_the_data_is_whole() -> void:
	var town := {}
	for tile: int in PunyTown.pieces():
		town[tile] = true
	for tile: int in Streets.pieces():
		assert_true(town.has(tile), "paving tile %d made with the town's tileset" % tile)
		assert_lt(tile / Streets.COLUMNS, 132, "on the sheet")
	var doc := SaveCodec.parse_json(FileAccess.get_file_as_string(Streets.DATA)) as Dictionary
	for map_id: String in doc:
		var data := MapData.load_by_id(map_id)
		for area: Dictionary in doc[map_id]:
			assert_true(area.has("name") and area.has("ground") and area.has("from"), "%s: %s" % [map_id, area])
			for look: String in (area["from"] as Dictionary).values():
				assert_true(Streets.LOOKS.has(look), "%s's %s is a look" % [map_id, look])
			for ground: String in area["ground"]:
				assert_true(WorldTiles.TILE_INFO.has(ground), "%s paves %s, a tile" % [map_id, ground])
			if area.has("rect"):
				var r: Array = area["rect"]
				var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
				assert_true(Rect2i(Vector2i.ZERO, data.size).encloses(rect), "%s's %s inside the map" % [map_id, area["name"]])
	for look: String in Streets.KERBED:
		assert_true(Streets.LOOKS.has(look))


## No street runs into the water (PIX-390): Tom found the south street's
## kerb right on the river, the grass beside it too, from the Ashes to the
## City. A bank lies between them now, and every map with streets keeps
## one, at every age, the town's ruins standing or every project built.
func test_no_street_runs_into_the_water() -> void:
	var projects := []
	for age: Dictionary in Town.ages():
		for project: Dictionary in age["projects"]:
			projects.append(project["id"])
	for map_id: String in ["town", "greyhold", "frostgate"]:
		for done: Array in [[], projects]:
			var grid := MapData.load_tiered(map_id, done, 1).grid
			for tier in range(Town.MAX_TIER + 1):
				assert_eq(Streets.on_water(grid, Streets.plan(map_id, grid, tier)), [] as Array[Vector2i], "%s at age %d, %d built" % [map_id, tier, done.size()])
	var town := MapData.load_by_id("town")
	for x in range(2, 64):
		assert_eq(town.tile_at(Vector2i(x, 35)), "grass", "the bank below the south street at (%d, 35)" % x)
		assert_eq(town.tile_at(Vector2i(x, 36)), "water", "the river at its foot at (%d, 36)" % x)


## What counts as running into the water: a road or a paved cell with water
## at a side; not a corner, not a bridge's end, not grass.
func test_a_street_on_the_water_is_one_with_water_at_a_side() -> void:
	var grid := {
		Vector2i(0, 0): "path", Vector2i(1, 0): "water",
		Vector2i(0, 1): "well", Vector2i(1, 1): "sea",
		Vector2i(0, 2): "path", Vector2i(1, 2): "bridge",
		Vector2i(0, 3): "path", Vector2i(1, 4): "water",
		Vector2i(0, 5): "grass", Vector2i(1, 5): "water",
	}
	var paved := {Vector2i(0, 1): "sandstone"}
	var found := Streets.on_water(grid, paved)
	found.sort()
	assert_eq(found, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])
