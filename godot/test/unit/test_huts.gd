extends GutTest
## The huts at the houses' scale (PIX-557): the waystations' huts, the
## Mirefen's stilt huts and Gunnar's lodge were drawn at 60% of Shade's
## houses' scale, their doors 9 or 10 pixels and the hero 14. Each stands
## on three cells, a cabin drawn in his inks with a pitched roof over walls
## two cells tall and a plank door the hero fits. Each blocks the open
## ground behind it its
## roof stands over (PIX-557's reviews: a hero there was lost behind it, a
## barrel hidden under Gunnar's).


func test_each_hut_stands_on_three_cells() -> void:
	var post := PostState.new()
	var settlement := SettlementState.new()
	for place: String in Routes.places():
		Routes.tally(post, place, "bram", Routes.station_at(place) if not Routes.station(place).is_empty() else Routes.signs_at(place))
		var work := String(Routes.station(place).get("work", ""))
		if work != "":
			settlement.projects.append(work)
	var reach := MapData.load_by_id(Routes.MAP)
	var huts: Array = Routes.plan(reach, post, settlement, Hamlet.kept_on(reach, {}))["pieces"].filter(func(piece: Dictionary) -> bool: return piece["kind"] == "hut")
	assert_eq(huts.size(), 4, "every waystation's hut stands")
	for hut: Dictionary in huts:
		var cell: Vector2i = hut["cell"]
		var wall := [cell, cell + Vector2i.RIGHT, cell + Vector2i(2, 0)]
		assert_eq(hut["cells"].slice(-3), wall, "%s's hut on three cells" % hut["place"])
		for x in 3:
			for y in [1, 2]:
				var behind := cell + Vector2i(x, -y)
				assert_eq(behind in hut["cells"], reach.is_walkable(behind), "%s's hut blocks the open ground under its roof at %s" % [hut["place"], behind])
	var fen := MapData.load_by_id(MireDressing.MAP)
	var laid := MireDressing.lay(fen, Hamlet.kept_on(fen, {}))
	assert_eq(laid["huts"], MireDressing.HUTS, "every stilt hut stands")
	for hut: Vector2i in laid["huts"]:
		assert_eq(MireDressing.hut_cells(hut).size(), 3 * MireDressing.HUT_DEEP, "the stilt hut at %s three cells wide, blocking the rows its raised house stands over" % hut)
		assert_eq(MireDressing.hut_cells(hut).slice(-3), [hut, hut + Vector2i.RIGHT, hut + Vector2i(2, 0)], "its wall's row last")
		for cell in MireDressing.hut_cells(hut):
			assert_has(laid["blocks"], cell, "and blocks %s" % cell)
	for art: String in ["lodge_frame", "lodge_walls", "lodge"]:
		assert_eq(Hamlet.cells_of({"art": art, "cell": Vector2i.ZERO}).size(), 3, "Gunnar's %s on three cells" % art)


## Gunnar's lodge (walls up, then open) blocks all
## the ground under its roof, and nothing of the Frostgate's stands there
## (PIX-557's review: it blocked its wall's row alone, the hero walked in
## behind its roof and was lost, and the camp's barrel stood hidden).
func test_a_built_lodge_leaves_nothing_under_its_roof() -> void:
	var map := MapData.load_by_id("frostgate")
	for step: int in [1, 2]:
		var post := PostState.new()
		Routes.tally(post, "frostgate", "bram", int(Hubs.marks()[step]))
		var lodges: Array = Hamlet.plan(map, Hamlet.kept_on(map), Hubs.dressing(map.id, post), true)["pieces"].filter(func(piece: Dictionary) -> bool:
			return piece.get("art", "") in HubArt.BUILT)
		assert_eq(lodges.size(), 1, "the lodge stands at step %d" % (step + 1))
		var foot: Vector2i = lodges[0]["cell"]
		for y in range(foot.y - Routes.HUT.y + 1, foot.y + 1):
			for x in range(foot.x, foot.x + Routes.HUT.x):
				var cell := Vector2i(x, y)
				assert_true(map.is_walkable(cell), "nothing of the map's under its roof at %s" % cell)
				assert_has(lodges[0]["cells"], cell, "and the lodge blocks %s" % cell)


## Each is a cabin drawn in HamletArt's inks, the same with or without the
## pack (PIX-557: Shade's town tiles made a flat block, a roof slab over one
## short wall row): three cells wide; a pitched roof, its rows widening
## from its ridge down to its eave; walls two cells tall under it; and a
## plank door with its frame, 12 by 18 at least, on the wall's foot: the
## hero fits it.
func test_each_is_a_cabin_with_a_pitched_roof_and_a_door_the_hero_fits() -> void:
	var cabins := {
		"the waystation's hut": [HamletArt.picture("hut"), RouteArt.HUT_DOOR, RouteArt.HUT_WALL],
		"the stilt hut": [MireArt.draw("hut"), MireArt.HUT_DOOR, MireArt.HUT_WALL],
		"Gunnar's lodge with its walls up": [HamletArt.picture("lodge_walls"), HubArt.LODGE_DOOR, HubArt.LODGE_WALL],
		"Gunnar's lodge": [HamletArt.picture("lodge"), HubArt.LODGE_DOOR, HubArt.LODGE_WALL],
	}
	var hero := 14
	if PunyTown.available():
		hero = PunyArt.frames(PunyArt.plain("warrior")).get_frame_texture("idle_down", 0).get_image().get_used_rect().size.y
	for name: String in cabins:
		var image: Image = cabins[name][0]
		var door: Rect2i = cabins[name][1]
		var wall: int = cabins[name][2]
		assert_eq(image.get_width(), 3 * HamletArt.TILE, "%s three cells wide" % name)
		assert_gte(door.size.x, 12, "%s's door 12 wide" % name)
		assert_gte(door.size.y, 18, "%s's door 18 tall" % name)
		assert_gte(door.size.y, hero, "the hero no taller than %s's door" % name)
		assert_gte(door.end.y - wall, 2 * HamletArt.TILE, "%s's walls two cells tall" % name)
		# The door is planks under a lintel, not the wall running through: no
		# row of it is the row of wall beside it.
		var same := 0
		for y in range(door.position.y, door.end.y):
			var alike := true
			for x in range(door.position.x, door.end.x):
				alike = alike and image.get_pixel(x, y) == image.get_pixel(door.end.x + 2, y)
			same += int(alike)
		assert_eq(same, 0, "%s's door is drawn" % name)
		assert_ne(image.get_pixel(door.position.x + 2, door.position.y), image.get_pixel(door.position.x + 2, door.position.y + 2), "%s's door has its lintel" % name)
		# The roof's west edge, row by row from its ridge to its eave: never
		# stepping back in, and well out by the eave (a slab's is straight).
		var edges: Array[int] = []
		for y in wall:
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.0:
					edges.append(x)
					break
		assert_gte(edges.size(), HamletArt.TILE, "%s's roof a cell tall at least" % name)
		for n in range(1, edges.size()):
			assert_lte(edges[n], edges[n - 1], "%s's roof widens down row %d" % [name, n])
		assert_gte(edges[0] - edges[-1], 8, "%s's roof pitched from its ridge to its eave" % name)
		# A dark outline round it, as Shade's props have.
		assert_eq(image.get_pixel(edges[-1], wall - 1), HamletArt.INKS["o"], "%s outlined at its eave" % name)
