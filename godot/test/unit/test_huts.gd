extends GutTest
## The huts at the houses' scale (PIX-557): the waystations' huts, the
## Mirefen's stilt huts and Gunnar's lodge were drawn at 60% of Shade's
## houses' scale, their doors 9 or 10 pixels and the hero 14. Each stands
## on three cells, and with the paid pack is his house, built as the town's
## narrow houses are, with his door in its wall: as tall as the hero. A
## waystation's hut and a stilt hut block the open ground behind them their
## roofs stand over (PIX-557's review: a hero there was lost behind them).


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


## With the pack each is Shade's house three cells wide, his door in the
## row its wall stands on, and his door stands as tall as the hero.
func test_with_the_pack_each_is_his_house_and_the_hero_fits_its_door() -> void:
	if not PunyTown.available():
		pending("the paid pack isn't here")
		return
	var door := Vector2i(PunyTown.DOOR % PunyTown.COLUMNS, PunyTown.DOOR / PunyTown.COLUMNS)
	var houses := {"the waystation's hut": RouteArt.cottage(), "the stilt hut": MireArt.cottage(), "Gunnar's lodge": HubArt.lodge()}
	for name: String in houses:
		var house: Node2D = houses[name]
		add_child_autofree(house)
		var cells := Rect2i()
		var doors := 0
		for node in house.find_children("*", "TileMapLayer", true, false):
			var layer := node as TileMapLayer
			cells = layer.get_used_rect() if cells.size == Vector2i.ZERO else cells.merge(layer.get_used_rect())
			for cell in layer.get_used_cells():
				if layer.get_cell_atlas_coords(cell) == door:
					doors += 1
					assert_eq(cell.y, -1, "%s's door in its wall" % name)
		assert_eq(cells.size, Vector2i(3, 3), "%s three cells wide, three tall" % name)
		assert_eq(doors, 1, "%s has Shade's door" % name)
	var drawn := PunyProps.texture(PunyTown.DOOR).get_image().get_used_rect().size.y
	var hero := PunyArt.frames(PunyArt.plain("warrior")).get_frame_texture("idle_down", 0).get_image().get_used_rect().size.y
	assert_gte(drawn, hero, "the hero no taller than the door")
	assert_gt(drawn, 10, "taller than the old huts' doors")
