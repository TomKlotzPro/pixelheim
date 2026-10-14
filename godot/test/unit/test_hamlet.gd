extends GutTest
## Each settlement beyond Pixelheim its own (PIX-313) and Morvax's smithy
## (PIX-312): its houses in its own grammar, its barrels and crates at the
## Puny folk's scale, its set dressing placed where it says and never in
## anyone's way - no villager's place, door, path or portal taken, no way
## closed.

const MAPS := ["saltmere", "greyhold", "frostgate", "blackiron", "mountain_road"]


## Every open cell reachable from `from` on `map`.
static func _reach(map: MapData, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var stack: Array[Vector2i] = [from]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if not seen.has(next) and map.grid.has(next) and map.is_walkable(next):
				seen[next] = true
				stack.append(next)
	return seen


func test_every_settlement_has_its_look() -> void:
	for map_id: String in MAPS:
		assert_ne(Hamlet.look_of(map_id), "", "%s has a look of its own" % map_id)
	assert_eq(Hamlet.look_of("town"), "", "Pixelheim keeps its own")
	assert_eq(Hamlet.look_of("overworld"), "")
	var looks := {}
	for map_id: String in MAPS:
		looks[Hamlet.look_of(map_id)] = true
	assert_eq(looks.size(), MAPS.size(), "no two settlements alike")


func test_every_piece_stands_where_it_is_placed() -> void:
	for map_id: String in Hamlet.DRESSING:
		var map := MapData.load_by_id(map_id)
		var planned := Hamlet.plan(map, Hamlet.kept_on(map))
		var wanted: Array = Hamlet.DRESSING[map_id].filter(func(entry: Dictionary) -> bool: return not entry.has("store"))
		assert_eq(planned["pieces"].size(), wanted.size(), "%s: no piece left out" % map_id)
		for piece: Dictionary in planned["pieces"]:
			if piece.has("art"):
				assert_true(HamletArt.PIECES.has(piece["art"]), "%s: %s is drawn" % [map_id, piece["art"]])


func test_nothing_stands_on_a_villager_a_door_a_path_or_a_portal() -> void:
	for map_id: String in Hamlet.DRESSING:
		var map := MapData.load_by_id(map_id)
		var kept := Hamlet.kept_on(map)
		for cell: Vector2i in Hamlet.plan(map, kept)["blocks"]:
			assert_false(kept.has(cell), "%s: %s keeps clear of villagers, portals, chests and packs" % [map_id, cell])
			assert_true(WorldTiles.is_walkable(map.tile_at(cell)), "%s: %s stands on open ground" % [map_id, cell])
			assert_does_not_have(Hamlet.WAYS, map.tile_at(cell), "%s: %s off the paths" % [map_id, cell])
			assert_false(map.tile_at(cell + Vector2i.UP).begins_with("door"), "%s: %s is no door's step" % [map_id, cell])


func test_no_way_is_closed() -> void:
	for map_id: String in Hamlet.DRESSING:
		var map := MapData.load_by_id(map_id)
		var before := _reach(map, map.spawn)
		var blocks: Array = Hamlet.plan(map, Hamlet.kept_on(map))["blocks"]
		for cell: Vector2i in blocks:
			map.covered[cell] = true
		var after := _reach(map, map.spawn)
		for cell: Vector2i in before:
			if cell not in blocks:
				assert_true(after.has(cell), "%s: %s still reached from the spawn" % [map_id, cell])


func test_what_floats_hangs_or_lies_flat_blocks_nothing() -> void:
	for map_id: String in Hamlet.DRESSING:
		var map := MapData.load_by_id(map_id)
		var planned := Hamlet.plan(map, Hamlet.kept_on(map))
		for piece: Dictionary in planned["pieces"]:
			if piece["kind"] != "stand":
				for cell: Vector2i in piece["cells"]:
					assert_does_not_have(planned["blocks"], cell, "%s: a %s piece blocks nothing" % [map_id, piece["kind"]])
			if piece["kind"] == "moored":
				for cell: Vector2i in piece["cells"]:
					assert_has(Hamlet.AFLOAT, map.tile_at(cell), "%s: a boat afloat at %s" % [map_id, cell])


func test_a_standing_piece_never_closes_a_corridor() -> void:
	# A single open cell between a wall and the water: blocking it would
	# cut the strip in two.
	var map := MapData.new()
	map.id = "test"
	for x in 5:
		map.grid[Vector2i(x, 0)] = "mountain"
		map.grid[Vector2i(x, 1)] = "grass"
		map.grid[Vector2i(x, 2)] = "water"
	var none: Array[Vector2i] = []
	assert_false(Hamlet.fits(map, [Vector2i(2, 1)] as Array[Vector2i], {}, none), "a corridor stays open")
	for x in 5:
		map.grid[Vector2i(x, 2)] = "grass"
		map.grid[Vector2i(x, 3)] = "grass"
	assert_true(Hamlet.fits(map, [Vector2i(2, 2)] as Array[Vector2i], {}, none), "open ground round it: it fits")
	assert_false(Hamlet.fits(map, [Vector2i(2, 2)] as Array[Vector2i], {Vector2i(2, 2): true}, none), "never on a kept cell")
	map.grid[Vector2i(2, 2)] = "path"
	assert_false(Hamlet.fits(map, [Vector2i(2, 2)] as Array[Vector2i], {}, none), "never on a path")


func test_each_settlement_builds_in_its_own_grammar() -> void:
	for map_id: String in MAPS:
		var map := MapData.load_by_id(map_id)
		var style := Hamlet.house_style(map_id)
		var plain := PunyTown.plan(map.grid)
		var own := PunyTown.plan(map.grid, style)
		assert_false(own["pieces"].is_empty(), "%s has houses" % map_id)
		assert_eq(own["pieces"].keys(), plain["pieces"].keys(), "%s: every house stands where it stood" % map_id)
		var walls: Array = style["walls"]
		for cell: Vector2i in own["pieces"]:
			var was: int = plain["pieces"][cell]
			if not walls.is_empty() and was in [PunyTown.WALL_LEFT, PunyTown.WALL, PunyTown.WALL_RIGHT]:
				assert_has(walls, own["pieces"][cell], "%s: its own walls at %s" % [map_id, cell])
			elif was in [PunyTown.WINDOW, PunyTown.DOOR]:
				assert_eq(own["pieces"][cell], was, "%s: windows and doors stay" % map_id)
		# A chimney on every roof, but where the smithy's stack stands for it.
		var chimneys: Array = own["decor"].values().filter(func(tile: int) -> bool: return tile == PunyTown.CHIMNEY[1])
		var houses := PunyTown.houses(map.grid)
		if style.has("stack"):
			assert_eq(chimneys.size(), 0, "%s: the forge stack is its chimney" % map_id)
		else:
			assert_eq(chimneys.size(), houses.size(), "%s: a chimney on every roof" % map_id)
		for house: Dictionary in houses:
			if house["door"].x >= 0 and not style.has("stack"):
				assert_gte(MapView.chimney_of(house["door"], own["decor"]).x, 0, "%s: the door at %s smokes from its chimney" % [map_id, house["door"]])


func test_pixelheim_keeps_its_houses() -> void:
	var town := MapData.load_by_id("town")
	assert_eq(PunyTown.plan(town.grid, Hamlet.house_style("town")), PunyTown.plan(town.grid), "no style in town")


func test_the_frostgate_roofs_lie_under_snow_and_no_wall_does() -> void:
	assert_true(Hamlet.house_style("frostgate").get("snow", false))
	for map_id: String in ["saltmere", "greyhold", "blackiron", "mountain_road"]:
		assert_false(Hamlet.house_style(map_id).get("snow", false), "%s's roofs are bare" % map_id)
	for tile: int in [PunyTown.WALL_LEFT, PunyTown.WALL, PunyTown.WALL_RIGHT, PunyTown.WINDOW, PunyTown.DOOR]:
		assert_true(PunyTown.is_wall(tile))
	for tile: int in Hamlet.pieces():
		assert_true(PunyTown.is_wall(tile), "a settlement's wall %d stays bare of snow" % tile)
	assert_false(PunyTown.is_wall(PunyTown.WING_RIDGE[1]), "a roof takes the snow")


func test_barrels_and_crates_are_at_the_folk_s_scale() -> void:
	# Shade's barrel stood 16 px, as tall as the villager (14) beside it.
	for kind: String in ["barrel", "crate"]:
		for map_id: String in ["town", "overworld"] + MAPS:
			var art := Hamlet.store(map_id, kind, Vector2i.ZERO)
			assert_true(HamletArt.PIECES.has(art), "%s's %s is drawn" % [map_id, kind])
			assert_lte(_height(art), 12, "%s's %s (%s) stands below a villager's shoulder" % [map_id, kind, art])
	assert_eq(Hamlet.store("mountain_road", "barrel", Vector2i.ZERO), "tub", "the smith quenches in a tub")
	assert_eq(Hamlet.store("mountain_road", "crate", Vector2i.ZERO), "coal")
	assert_eq(Hamlet.store("frostgate", "crate", Vector2i(7, 38)), "woodpile_snow", "the hermit's woodpile by his hut")
	assert_eq(Hamlet.store("frostgate", "crate", Vector2i(42, 38)), "box", "the caravan's crates")


## How many rows of `art` hold a pixel.
static func _height(art: String) -> int:
	var rows: Array = HamletArt.PIECES[art]
	var used := 0
	for row: String in rows:
		if row.replace(".", "") != "":
			used += 1
	return used


func test_every_piece_is_drawn_on_the_grid_in_shade_s_inks() -> void:
	for art: String in HamletArt.PIECES:
		var rows: Array = HamletArt.PIECES[art]
		var width := String(rows[0]).length()
		assert_eq(width % HamletArt.TILE, 0, "%s: whole cells wide" % art)
		for row: String in rows:
			assert_eq(row.length(), width, "%s: every row as wide" % art)
			for key in row:
				assert_true(key == "." or HamletArt.INKS.has(key), "%s: %s is one of the inks" % [art, key])
	assert_eq(HamletArt.washing(2).get_width(), 32, "a washing line two cells across")
	assert_eq(HamletArt.afloat("boat").get_frame_count("default"), 2, "a boat rides the swell")
	assert_eq(HamletArt.glint().get_frame_count("default"), HamletArt.GLINT_BEATS * HamletArt.GLINT_AT.size())
	assert_eq(HamletArt.door_glow().get_frame_count("default"), HamletArt.DOOR_GLOW.size())


func test_a_settlement_drawn_lays_its_dressing() -> void:
	for map_id: String in ["saltmere", "mountain_road"]:
		var map := MapData.load_by_id(map_id)
		var root := Node2D.new()
		add_child_autofree(root)
		var actors := Node2D.new()
		root.add_child(actors)
		var view := MapView.new(map, actors)
		view.plan(map.spawn)
		view.build(root)
		assert_false(view.hamlet["pieces"].is_empty(), "%s dressed" % map_id)
		for cell: Vector2i in view.hamlet["blocks"]:
			assert_true(map.covered.has(cell), "%s: what stands at %s blocks" % [map_id, cell])
			assert_true(view.bare.has(cell), "%s: no field decor under it" % map_id)
