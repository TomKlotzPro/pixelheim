extends GutTest
## A map's ground worked out once a session (One Reach, PIX-269, step 4):
## kept as its first visit worked it out, the same tile for tile, taken
## from there on coming back, and worked out again only when the map is
## drawn differently (a village that has grown).


func before_each() -> void:
	KeptGround.forget()


func after_all() -> void:
	KeptGround.forget()


func test_the_kept_ground_is_the_ground_tile_for_tile() -> void:
	var map := MapData.load_by_id("saltmere")
	var kept := KeptGround.of(map, map.grid, MapView.EDGE_PAD)
	var tiles := PunyTerrain.ground_tiles(map.grid, map.size, MapView.EDGE_PAD)
	assert_eq(kept.ground.size(), tiles.size(), "every corner, the edges' padding too")
	for cell: Vector2i in tiles:
		if kept.ground_at(cell) != tiles[cell]:
			assert_eq(kept.ground_at(cell), tiles[cell], "the corner at %s" % cell)
			return
	var crowns := PunyTerrain.forest_tiles(map.grid, map.size, MapView.EDGE_PAD)
	var crowned := 0
	for i in kept.crowns.size():
		if kept.crowns[i] >= 0:
			crowned += 1
			var cell := kept.corner + Vector2i(i % kept.width, i / kept.width)
			assert_eq(kept.crowns[i], crowns.get(cell, -1), "the crown at %s" % cell)
	assert_eq(crowned, crowns.size(), "the crowns, and bare rock where none")
	assert_eq(kept.ground_at(Vector2i(-100, -100)), -1, "nothing kept off the grid")


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
