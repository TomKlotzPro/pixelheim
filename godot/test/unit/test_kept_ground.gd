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
## fields over its cliffs, past its east edge the ridge's rock, its cliff
## standing in the sea. Inside, its ground is its own, tile for tile.
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
	var cliff: Array = PunyTerrain._combos()["cliff,cliff,cliff,cliff"]
	for y in range(5, 30):
		assert_eq(map.tile_at(Vector2i(59, y)), "deep_sea")
		assert_true(kept.ground_at(Vector2i(62, y)) in cliff, "past the east edge, the ridge's rock (row %d)" % y)
		assert_gte(kept.rim_at(Vector2i(60, y)), 0, "its cliff standing in the sea (row %d)" % y)
		assert_eq(kept.ground_at(Vector2i(60, y)), PunyTerrain.corner_tile(["seawater-deep", "seawater-deep", "seawater-deep", "seawater-deep"], hash(Vector2i(60, y))), "the sea running on under it (row %d)" % y)


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
