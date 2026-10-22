extends GutTest
## A map's ground worked out once a session (One Reach, PIX-269, step 4):
## kept as its first visit worked it out, the same tile for tile, taken
## from there on coming back, and worked out again only when the map is
## drawn differently (a village that has grown).


func before_each() -> void:
	KeptGround.forget()


func after_all() -> void:
	KeptGround.forget()


## The village, off the Reach's plane, carries its own edges on past them;
## where its cliffs meet its roads they stand on the road (PunyTerrain
## .rimmed), and elsewhere its ground is the ground, tile for tile.
func test_the_kept_ground_is_the_ground_tile_for_tile() -> void:
	var map := MapData.load_by_id("town")
	var kept := KeptGround.of(map, map.grid, MapView.EDGE_PAD)
	var tiles := PunyTerrain.ground_tiles(map.grid, map.size, MapView.EDGE_PAD)
	assert_eq(kept.ground.size(), tiles.size(), "every corner, the edges' padding too")
	var rimmed := 0
	for cell: Vector2i in tiles:
		if kept.rim_at(cell) >= 0:
			rimmed += 1
			assert_ne(kept.ground_at(cell), tiles[cell], "a cliff stands on the road at %s, no grass at its foot" % cell)
		elif kept.ground_at(cell) != tiles[cell]:
			assert_eq(kept.ground_at(cell), tiles[cell], "the corner at %s" % cell)
			return
	assert_gt(rimmed, 0, "the village's cliffs by its roads")
	var crowns := PunyTerrain.forest_tiles(map.grid, map.size, MapView.EDGE_PAD)
	var crowned := 0
	for i in kept.crowns.size():
		if kept.crowns[i] >= 0:
			crowned += 1
			var cell := kept.corner + Vector2i(i % kept.width, i / kept.width)
			assert_eq(kept.crowns[i], crowns.get(cell, -1), "the crown at %s" % cell)
	assert_eq(crowned, crowns.size(), "the crowns, and bare rock where none")
	assert_eq(kept.ground_at(Vector2i(-100, -100)), -1, "nothing kept off the grid")


## A map under the Reach's sky draws past its edges what lies there in the
## plane (One Reach, PIX-269): past Saltmere's north edge the Reach's
## fields over its cliffs, past its east and south edges its open sea, past
## its west cliffs the ridge's rock. Inside, its ground is its own, tile for
## tile.
func test_past_a_reach_maps_edges_lies_what_lies_there() -> void:
	var map := MapData.load_by_id("saltmere")
	var kept := KeptGround.of(map, map.grid, MapView.EDGE_PAD)
	var tiles := PunyTerrain.ground_tiles(map.grid, map.size, MapView.EDGE_PAD)
	for y in range(1, map.size.y):
		for x in range(1, map.size.x):
			var cell := Vector2i(x, y)
			if kept.rim_at(cell) < 0 and kept.ground_at(cell) != tiles[cell]:
				assert_eq(kept.ground_at(cell), tiles[cell], "the corner at %s" % cell)
				return
	assert_eq(map.tile_at(Vector2i(13, 0)), "mountain")
	assert_eq(kept.ground_at(Vector2i(13, -2)), PunyTerrain.corner_tile(["grass", "grass", "cliff", "cliff"], hash(Vector2i(13, -2))),
		"past its north edge the Reach's grass, over the Reach's cliffs, not its own rock carried on")
	# Past its east and south edges the sea runs on (PIX-309: it ended there
	# in a hedge of the ridge's pines): no cliff, no rock.
	var deep: Array = PunyTerrain._combos()["seawater-deep,seawater-deep,seawater-deep,seawater-deep"]
	for y in range(5, 30):
		assert_eq(map.tile_at(Vector2i(59, y)), "deep_sea")
		assert_true(kept.ground_at(Vector2i(62, y)) in deep, "past the east edge, the open sea (row %d)" % y)
		assert_eq(kept.rim_at(Vector2i(60, y)), -1, "no cliff standing in it (row %d)" % y)
	for x in range(20, 28):
		assert_eq(map.tile_at(Vector2i(x, 33)), "deep_sea")
		for y in range(35, 34 + MapView.EDGE_PAD):
			assert_true(kept.ground_at(Vector2i(x, y)) in deep, "past the south edge, the open sea at %s" % Vector2i(x, y))
			assert_eq(kept.crown_at(Vector2i(x, y)), -1, "no pines on it at %s" % Vector2i(x, y))
	# Its west cliffs still meet the ridge's rock past the edge.
	var cliff: Array = PunyTerrain._combos()["cliff,cliff,cliff,cliff"]
	assert_eq(map.tile_at(Vector2i(0, 20)), "mountain")
	assert_true(kept.ground_at(Vector2i(-2, 20)) in cliff, "past its rock, the ridge's rock")


func test_coming_back_takes_it_from_what_was_kept() -> void:
	var first := MapData.load_by_id("deepwood")
	var kept := KeptGround.of(first, first.grid, MapView.EDGE_PAD)
	var again := MapData.load_by_id("deepwood")
	assert_same(KeptGround.of(again, again.grid, MapView.EDGE_PAD), kept, "the same map, the same ground: not worked out again")
	assert_same(KeptGround.decks(again), KeptGround.decks(first), "nor where its patches grow")
	assert_eq(KeptGround.decks(again), Gathering.decks(MapData.load_by_id("deepwood")), "the decks as dealt")


func test_a_map_drawn_differently_is_worked_out_again() -> void:
	var hamlet := MapData.load_tiered("town", Town.projects_through(1), 1)
	var kept := KeptGround.of(hamlet, hamlet.grid, MapView.EDGE_PAD)
	var grown := MapData.load_tiered("town", Town.projects_through(3), 1)
	var anew := KeptGround.of(grown, grown.grid, MapView.EDGE_PAD)
	assert_false(is_same(anew, kept), "the village grown: its own ground")
	assert_same(KeptGround.of(grown, grown.grid, MapView.EDGE_PAD), anew, "and that kept in its place")


func test_what_is_kept_stays_small() -> void:
	for map_id: String in ["overworld", "town", "saltmere", "blackiron", "mirefen", "greyhold", "deepwood", "frostgate"]:
		var map := MapData.load_by_id(map_id)
		KeptGround.of(map, map.grid, MapView.EDGE_PAD)
		KeptGround.decks(map)
	assert_lt(KeptGround.bytes(), 2 * 1024 * 1024, "the whole Reach kept in under 2 MB")


## The woods (Woods.pieces, the slowest part of drawing the Deepwood) are
## worked out on a map's first drawing and taken from there on the next,
## which stands every tree where it stood; a map whose ground changed works
## its own out again (PIX-360).
func test_the_woods_are_worked_out_once() -> void:
	var views: Array[MapView] = []
	for visit in 2:
		var root := Node2D.new()
		add_child_autofree(root)
		var standing := Node2D.new()
		root.add_child(standing)
		var view := MapView.new(MapData.load_by_id("deepwood"), standing)
		view.plan(view.data.spawn)
		view.build(root)
		views.append(view)
	assert_gt(views[0].woods.size(), 1000, "the Deepwood's woods worked out on its first drawing")
	assert_same(views[1].woods, views[0].woods, "and taken from what was kept on the next")
	var trees: Array = views.map(func(view: MapView) -> Array:
		return view.stand.get_children().filter(func(node: Node) -> bool: return node is Sprite2D and node.material in [view.decor_sway, view.woods_sway]) \
			.map(func(sprite: Sprite2D) -> Array: return [sprite.texture, sprite.position, sprite.offset, sprite.material == view.woods_sway]))
	assert_gt((trees[0] as Array).size(), 2000, "its trees drawn")
	assert_eq(trees[1], trees[0], "the same trees, where they stood")
	var changed := MapData.load_by_id("deepwood")
	changed.grid[Vector2i(10, 3)] = "grass"
	assert_false(is_same(KeptGround.woods(changed), views[0].woods), "a map whose ground changed works its woods out again")
