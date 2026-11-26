extends GutTest
## The Mirefen alive (PIX-401): its dead trees, reed beds, boardwalks, stilt
## huts and wisps laid where they say and never in anyone's way - no path,
## portal, pack's home, chest, lair or way taken or closed; the middle road
## goes on west as a boardwalk to a hut; the pools' reeds by the mire.


func _map() -> MapData:
	return MapData.load_by_id(MireDressing.MAP)


func _laid(map: MapData) -> Dictionary:
	return MireDressing.lay(map, Hamlet.kept_on(map, {}))


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


func test_the_fen_grows_trees_reeds_walks_and_huts() -> void:
	var laid := _laid(_map())
	assert_eq(laid["walks"].size(), MireDressing.WALKS.size(), "every boardwalk laid")
	assert_eq(laid["huts"].size(), MireDressing.HUTS.size(), "every stilt hut stands")
	assert_between(laid["trees"].size(), 40, 140, "dead trees about the fen")
	assert_between(laid["reeds"].size(), 60, 260, "reed beds about the fen")
	assert_eq(_laid(_map()), laid, "the same every time")
	assert_true(MireDressing.lay(MapData.load_by_id("deepwood"), {})["blocks"].is_empty(), "the Mirefen's alone")


func test_nothing_stands_on_a_path_a_portal_a_home_a_chest_or_a_lair() -> void:
	var map := _map()
	var kept := Hamlet.kept_on(map, {})
	var laid := _laid(map)
	var lairs: Array[Vector2i] = []
	for entry: Dictionary in Hunts.all():
		if String(entry.get("mapId", "")) == map.id and entry.has("lair"):
			lairs.append(Hunts.lair(entry))
	assert_false(lairs.is_empty(), "Grandmother Gulp keeps her lair here")
	for cell: Vector2i in laid["blocks"]:
		assert_false(kept.has(cell), "%s keeps clear of packs, portals, chests and the spawn" % cell)
		assert_true(WorldTiles.is_walkable(map.tile_at(cell)), "%s stands on open ground" % cell)
		assert_does_not_have(Hamlet.WAYS, map.tile_at(cell), "%s off the paths" % cell)
		for lair in lairs:
			assert_gt(maxi(absi(cell.x - lair.x), absi(cell.y - lair.y)), MireDressing.LAIR_CLEAR, "%s clear of the lair" % cell)
		for walk: Rect2i in laid["walks"]:
			assert_false(walk.has_point(cell), "%s off the boardwalks" % cell)
	for cell: Vector2i in laid["trees"]:
		assert_eq(map.tile_at(cell), "marsh", "a dead tree in the mire at %s" % cell)
	for cell: Vector2i in laid["reeds"]:
		assert_eq(map.tile_at(cell), "marsh", "a reed bed in the mire at %s" % cell)
		assert_does_not_have(laid["blocks"], cell, "reeds are walked through")
	for cell: Vector2i in laid["wet"]:
		assert_false(kept.has(cell), "%s's shallows keep clear of packs, portals, chests and the spawn" % cell)
		assert_does_not_have(Hamlet.WAYS, map.tile_at(cell), "%s's shallows off the paths" % cell)
		assert_does_not_have(laid["blocks"], cell, "the shallows are waded through at %s" % cell)


func test_no_way_is_closed() -> void:
	var map := _map()
	var before := _reach(map, map.spawn)
	var blocks: Array = _laid(map)["blocks"]
	for cell: Vector2i in blocks:
		map.covered[cell] = true
	var after := _reach(map, map.spawn)
	for cell: Vector2i in before:
		if cell not in blocks:
			assert_true(after.has(cell), "%s still reached from the spawn" % cell)
	for portal: Vector2i in map.portals:
		assert_true(after.has(portal), "the way out at %s still reached" % portal)


## The road west of the middle bridge stopped in the open fen: it goes on
## as the first boardwalk, at its width, to the west hut standing over it.
func test_the_middle_road_goes_on_to_the_west_hut() -> void:
	var map := _map()
	var walk: Rect2i = MireDressing.WALKS[0]
	for y in range(walk.position.y, walk.end.y):
		assert_eq(map.tile_at(Vector2i(walk.end.x, y)), "path", "the road meets the walk's east end on row %d" % y)
		assert_ne(map.tile_at(Vector2i(walk.position.x - 1, y)), "path", "and the walk goes on where the road did not")
	var hut: Vector2i = MireDressing.HUTS[0]
	assert_eq(hut.y, walk.position.y - 1, "the west hut stands right over the walk")
	assert_true(walk.position.x <= hut.x and hut.x + 1 < walk.end.x, "its ladder down onto it")


## No walk stops in the open fen (PIX-519: the ruin's seemed to stop in the
## grass short of the road): each of its two ends, its last two rows or
## columns, meets a road, a bridge, a door (the ruin's doorway), a hut or
## another walk going on.
func test_every_walk_lands_at_both_ends() -> void:
	var map := _map()
	var huts := {}
	for hut: Vector2i in MireDressing.HUTS:
		for cell in MireDressing.hut_cells(hut):
			huts[cell] = true
	for walk: Rect2i in MireDressing.WALKS:
		var along := Vector2i.RIGHT if walk.size.x >= walk.size.y else Vector2i.DOWN
		var length := walk.size.x if along == Vector2i.RIGHT else walk.size.y
		for at: int in [0, length - 2]:
			var end := Rect2i(walk.position + along * at, walk.size - along * (length - 2))
			var landed := false
			for cell: Vector2i in MireDressing._cells(end.grow(1)):
				var side := cell.x < end.position.x or cell.x >= end.end.x
				if walk.has_point(cell) or (side and (cell.y < end.position.y or cell.y >= end.end.y)):
					continue  # its own cells, and the corners off its sides
				var on_walk := MireDressing.WALKS.any(func(other: Rect2i) -> bool: return other.has_point(cell))
				landed = landed or on_walk or huts.has(cell) or map.tile_at(cell) in ["path", "bridge", "floor"]
			assert_true(landed, "the walk %s lands at its end %s" % [walk, end])
		for cell: Vector2i in MireDressing._cells(walk):
			assert_true(map.is_walkable(cell), "the walk %s over open ground at %s" % [walk, cell])
	# The ruin's runs from its doorway right down onto the road.
	var ruin: Rect2i = MireDressing.WALKS[MireDressing.WALKS.size() - 1]
	for x in range(ruin.position.x, ruin.end.x):
		assert_eq(map.tile_at(Vector2i(x, ruin.position.y - 1)), "floor", "the ruin's doorway over its walk")
		assert_eq(map.tile_at(Vector2i(x, ruin.end.y)), "path", "the road under it")


## Each walk runs over water (PIX-519: water under its planks alone showed
## nowhere, a deck lying in the grass): the fen's laid beside it, or the
## map's own, or a stilt hut's pool (PIX-557), along three quarters of its
## sides that aren't another walk at least.
func test_every_walk_over_water() -> void:
	var map := _map()
	var laid := _laid(map)
	var pools := {}
	for hut: Vector2i in laid["huts"]:
		for cell in MireDressing.hut_cells(hut):
			pools[cell] = true
	for walk: Rect2i in laid["walks"]:
		var sides := MireDressing._sides(walk).filter(func(cell: Vector2i) -> bool: return not MireDressing._on_walk(laid["walks"], cell))
		var wet := sides.filter(func(cell: Vector2i) -> bool: return cell in laid["wet"] or pools.has(cell) or map.tile_at(cell) in ["water", "bridge"])
		assert_gte(wet.size() * 4, sides.size() * 3, "the walk %s over water: %d of its %d sides" % [walk, wet.size(), sides.size()])


## The shallows are the same whatever the day's patches and wherever the
## hero arrives (PIX-519's review: one who quit wading came back on dry fen
## in the water, and the ground was worked out again), and so are the huts;
## what else stands still keeps off today's.
func test_the_shallows_the_same_every_day_and_arrival() -> void:
	var map := _map()
	var kept := Hamlet.kept_on(map, {})
	var laid := _laid(map)
	var today := {Vector2i(9, 26): true}
	var decks := Gathering.decks(map)
	for region: String in decks:
		for cell: Vector2i in decks[region]:
			today[cell] = true
	var other := MireDressing.lay(map, kept, {}, today)
	assert_true(laid["wet"].has(Vector2i(9, 26)), "the shallows the flow wades into")
	assert_eq(other["wet"], laid["wet"], "the same shallows")
	# And the huts the same every day (PIX-557: one stood only on the days no
	# patch grew under it); nothing else stands on today's patch or arrival.
	assert_eq(other["huts"], laid["huts"], "the same huts")
	var huts := {}
	for hut: Vector2i in other["huts"]:
		for cell in MireDressing.hut_cells(hut):
			huts[cell] = true
	for cell: Vector2i in other["blocks"]:
		assert_true(huts.has(cell) or not today.has(cell), "nothing stands on today's patch or arrival at %s" % cell)


## Both huts stand on the fen drawn, the field decor that blocks giving way
## to them (PIX-557's review: a bush behind the west hut, with the hero
## south of its walk, kept it down).
func test_the_huts_stand_whatever_the_field_decor() -> void:
	var map := _map()
	var actors := Node2D.new()
	add_child_autofree(actors)
	var view := MapView.new(map, actors)
	view.plan(Vector2i(8, 26))
	assert_eq(view.get_meta("mire")["huts"], MireDressing.HUTS, "every hut stands")
	for hut: Vector2i in MireDressing.HUTS:
		for cell in MireDressing.hut_cells(hut):
			assert_false(view.solid_scatter.has(cell), "no field decor under the hut at %s" % cell)


func test_wisps_float_over_the_fen_apart() -> void:
	var map := _map()
	for i in MireDressing.WISPS.size():
		var at: Vector2i = MireDressing.WISPS[i]
		assert_true(map.grid.has(at) and map.tile_at(at) != "mountain", "a wisp over the fen at %s" % at)
		for j in range(i + 1, MireDressing.WISPS.size()):
			var other: Vector2i = MireDressing.WISPS[j]
			assert_gte(maxi(absi(at.x - other.x), absi(at.y - other.y)), 8, "wisps %s and %s far apart" % [at, other])


## Drawn: what stands blocks its cells, the walks are Shade's planks over
## the fen's water, shallow and waded beside them (PIX-548) and nowhere
## else, the wisps are out only at night, each with its soft light.
func test_the_fen_drawn() -> void:
	var map := _map()
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	var laid: Dictionary = view.get_meta("mire")
	for cell: Vector2i in laid["blocks"]:
		assert_true(map.covered.has(cell), "%s blocked" % cell)
	assert_false(laid["trees"].is_empty(), "trees drawn")
	# The walks drawn as bridges (PIX-519): Shade's planks the way each runs,
	# over the fen's water, on cells the hero still walks as before.
	var look := view.look()
	for walk: Rect2i in laid["walks"]:
		for cell in MireDressing._cells(walk):
			assert_eq(String(look[cell]), "bridge", "the walk drawn as a bridge at %s" % cell)
			assert_true(map.is_walkable(cell), "and walked at %s" % cell)
			assert_ne(map.tile_at(cell), "bridge", "the map's own cell kept at %s" % cell)
			assert_eq(PunyTerrain.ground_at(look, cell), "river", "the fen's water under its planks at %s" % cell)
			assert_ne(view._objects_layer.get_cell_source_id(cell), -1, "Shade's planks laid at %s" % cell)
	for cell: Vector2i in laid["wet"]:
		assert_eq(String(look[cell]), "water", "the fen's shallows beside a walk at %s" % cell)
		assert_true(map.is_walkable(cell), "waded through at %s" % cell)
		assert_ne(view.tile_layer.get_cell_source_id(cell), MapView.BLOCKER_SOURCE, "nothing stops the hero at %s" % cell)
		# Drawn shallow, not as the fen's pools, and waded (PIX-548).
		assert_true(map.shallows.has(cell), "waded at %s" % cell)
		assert_eq(roundi(view.kept.water_image.get_pixelv(cell).a * 255.0), PunyTerrain.WATER_SHALLOWS * PunyTerrain.TONE_BIT, "drawn shallow at %s" % cell)
	assert_eq(map.shallows.size(), laid["wet"].size(), "the shallows are the walks' sides alone")
	# Each stilt hut over a pool of the fen's own water, its row and the one
	# behind, not its shallows (PIX-557: the pool drawn in its picture was too
	# faint to see); every cell its raised house stands over blocked, never
	# waded (its review: a hero there was lost behind it); and at night a
	# small light under its window, one a hut.
	for hut: Vector2i in laid["huts"]:
		for cell in MireDressing.hut_cells(hut):
			assert_true(map.covered.has(cell), "blocked under the hut at %s" % cell)
			assert_false(map.shallows.has(cell), "not waded at %s" % cell)
			if cell.y < hut.y - 1:
				assert_ne(String(look[cell]), "water", "the fen under its roof at %s" % cell)
				continue
			assert_eq(String(look[cell]), "water", "the hut's pool at %s" % cell)
			assert_eq(roundi(view.kept.water_image.get_pixelv(cell).a * 255.0) / PunyTerrain.TONE_BIT, PunyTerrain.WATER_MIRE, "the mire's own water at %s" % cell)
	var windows := view.props.find_children("*", "PointLight2D", true, false).filter(func(light: Node) -> bool: return light.get_meta("tint") == Lights.WINDOW)
	assert_eq(windows.size(), laid["huts"].size(), "a light under each hut's window")
	# Never waded on a way, a walk's planks nor the fen's own pools, which
	# keep the mire's water.
	for cell: Vector2i in map.grid:
		if Hamlet.is_way(map.id, map.tile_at(cell)) or MireDressing._on_walk(laid["walks"], cell) or map.tile_at(cell) == "water":
			assert_false(map.shallows.has(cell), "no wading at %s" % cell)
			if PunyTerrain.is_wet(String(look[cell])):
				assert_eq(roundi(view.kept.water_image.get_pixelv(cell).a * 255.0) / PunyTerrain.TONE_BIT, PunyTerrain.WATER_MIRE, "the mire's own water at %s" % cell)
	for cell: Vector2i in view.drawn_as:
		assert_false(view.patches.has(cell), "no patch grows on the planks or the shallows at %s" % cell)
	assert_eq(PunyTerrain.span_axis(look, Vector2i(44, 20)), Vector2i.DOWN, "the ruin's runs down to the road")
	assert_eq(PunyTerrain.span_axis(look, Vector2i(8, 25)), Vector2i.RIGHT, "the west hut's along the road")
	view.set_night(false)
	assert_string_contains(MireDressing.describe(view), "dark")
	view.set_night(true)
	assert_string_contains(MireDressing.describe(view), "wisps %d lit" % MireDressing.WISPS.size())
	var wisps: Array = view.get_meta("mire_wisps")
	for wisp: Node2D in wisps:
		assert_eq(wisp.find_children("*", "PointLight2D", true, false).size(), 1, "each wisp a soft light")
	view.set_night(false)
	assert_string_contains(MireDressing.describe(view), "dark")


func test_the_pictures() -> void:
	for n in AshArt.SNAGS.size():
		var snag := MireArt.draw("snag_%d" % n)
		assert_eq(snag.get_size(), Vector2i(16, AshArt.SNAG_HEIGHT))
		for y in snag.get_height():
			for x in snag.get_width():
				assert_false(snag.get_pixel(x, y).is_equal_approx(AshArt.INKS["Q"]), "no ash at a fen tree's foot")
	assert_eq(MireArt.draw("reeds_0").get_size(), MireArt.REED_SIZE)
	# Every bed a clump, its stems spread across it, never one stake: read
	# just over the tuft, where each stem stands at its own foot before it
	# leans.
	for n in MireArt.REED_BEDS:
		var bed := MireArt.draw("reeds_%d" % n)
		var columns := 0
		for x in bed.get_width():
			var at := bed.get_pixel(x, MireArt.REED_SIZE.y - 2)
			if MireArt.REED_GREENS.any(func(green: Color) -> bool: return at.is_equal_approx(green)):
				columns += 1
		assert_gte(columns, 5, "reed bed %d's stems stand in %d columns" % [n, columns])
	assert_eq(MireArt.draw("hut").get_size(), MireArt.HUT_SIZE)
	assert_gt(MireArt.draw("hut").get_pixel(16, 20).a, 0.0, "the hut drawn")


## The pools by the mire grow Scatter's bank reeds, as the river by grass.
func test_the_mire_s_pools_grow_bank_reeds() -> void:
	var grid := {}
	for x in 400:
		grid[Vector2i(x, 0)] = "marsh"
		grid[Vector2i(x, 1)] = "water"
		grid[Vector2i(x, 2)] = "water"
	var reeds := 0
	for x in 400:
		reeds += 1 if Scatter.detail(grid, Vector2i(x, 1)) == "reeds" else 0
		assert_eq(Scatter.detail(grid, Vector2i(x, 2)), "", "none out in the pool")
	assert_almost_eq(reeds / 4.0, float(Scatter.DETAIL["bank"][0]), 6.0, "about the bank's share")
