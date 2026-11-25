extends GutTest
## Where Saltmere's sand meets its grass and its road (PIX-551): the mask the
## ground's shader draws the dunes' edge from. It marks the cells either side
## of that edge, weighs the sand and the sea as one, keeps Shade's own by
## rock, and changes nothing of the grid or of where the hero walks.


func _texel(image: Image, cell: Vector2i) -> Color:
	return image.get_pixelv(cell + Vector2i.ONE * SandShape.RING)


## A meadow 8 cells square with `others` in it (cell -> tile).
func _mask(others: Dictionary) -> Image:
	var grid := {}
	for y in 8:
		for x in 8:
			grid[Vector2i(x, y)] = others.get(Vector2i(x, y), "grass")
	return SandShape.image_of(grid, func(_cell: Vector2i) -> String: return "grass", Vector2i(8, 8))


func test_the_cells_either_side_of_the_sand_s_edge_are_drawn_again() -> void:
	var image := _mask({Vector2i(4, 4): "sand", Vector2i(5, 4): "sand"})
	assert_eq(_texel(image, Vector2i(4, 4)).r, 1.0, "sand weighs in the field")
	assert_eq(_texel(image, Vector2i(3, 4)).r, 0.0, "grass doesn't")
	assert_eq(_texel(image, Vector2i(4, 4)).g, SandShape.PLAIN, "the sand's cell")
	assert_eq(_texel(image, Vector2i(3, 3)).g, SandShape.PLAIN, "the grass beside it, corners too")
	assert_eq(_texel(image, Vector2i(2, 4)).g, 0.0, "not the grass a cell further")
	assert_eq(_texel(image, Vector2i(3, 4)).b, 1.0, "and its edge may wander")


func test_the_sea_weighs_as_sand_and_is_never_drawn_again() -> void:
	var image := _mask({Vector2i(3, 4): "sand", Vector2i(4, 4): "sand", Vector2i(5, 4): "shore", Vector2i(6, 4): "sea"})
	assert_eq(_texel(image, Vector2i(5, 4)).r, 1.0, "the edge never bends toward the waterline")
	assert_eq(_texel(image, Vector2i(5, 4)).g, 0.0, "the shallows keep Shade's waterline")
	assert_eq(_texel(image, Vector2i(6, 4)).g, 0.0)
	assert_eq(_texel(image, Vector2i(4, 4)).g, SandShape.PLAIN, "the beach between grass and sea is drawn")


func test_a_road_keeps_its_dirt_and_the_sand_beside_it_loses_the_strip() -> void:
	var image := _mask({Vector2i(3, 3): "path", Vector2i(4, 3): "path", Vector2i(3, 4): "sand", Vector2i(4, 4): "sand", Vector2i(3, 5): "sand", Vector2i(4, 5): "sand"})
	assert_eq(_texel(image, Vector2i(3, 3)).g, 0.0, "the road's cell is never drawn again")
	assert_eq(_texel(image, Vector2i(3, 3)).r, 0.0)
	assert_almost_eq(_texel(image, Vector2i(3, 4)).g, SandShape.NEAR, 0.01, "sand by the road: its dirt's edge stays")
	assert_eq(_texel(image, Vector2i(2, 5)).g, SandShape.PLAIN, "grass by the sand, off the road")


func test_rock_keeps_shade_s_own_and_stills_the_edge_round_it() -> void:
	var image := _mask({Vector2i(2, 4): "sand", Vector2i(3, 4): "sand", Vector2i(4, 4): "sand", Vector2i(5, 4): "sand", Vector2i(6, 4): "mountain"})
	assert_eq(_texel(image, Vector2i(5, 4)).g, 0.0, "a cliff's grassy top is no dune")
	assert_eq(_texel(image, Vector2i(4, 4)).g, SandShape.PLAIN)
	assert_eq(_texel(image, Vector2i(4, 4)).b, 0.0, "no wandering within two cells of it")
	assert_eq(_texel(image, Vector2i(2, 4)).b, 1.0)


func test_saltmere_s_edges_are_marked_and_its_grid_and_walking_untouched() -> void:
	var data := MapData.load_by_id("saltmere")
	var before := data.grid.hash()
	var walked := {}
	for cell: Vector2i in data.grid:
		walked[cell] = data.is_walkable(cell)
	var image := SandShape.image_of(data.grid, func(_cell: Vector2i) -> String: return "mountain", data.size)
	assert_eq(image.get_size(), data.size + Vector2i.ONE * 2 * SandShape.RING)
	# By the fish racks (the playtest's 16,21): the dune's stair.
	assert_eq(_texel(image, Vector2i(13, 21)).g, SandShape.PLAIN, "grass by the dune")
	assert_eq(_texel(image, Vector2i(14, 21)).g, SandShape.PLAIN, "the dune's first cell")
	assert_almost_eq(_texel(image, Vector2i(16, 19)).g, SandShape.NEAR, 0.01, "sand under the road")
	assert_eq(_texel(image, Vector2i(16, 18)).g, 0.0, "the road itself")
	assert_eq(_texel(image, Vector2i(18, 21)).g, 0.0, "the shallows")
	assert_eq(_texel(image, Vector2i(40, 20)).g, 0.0, "open grass")
	var marked := 0
	for cell: Vector2i in data.grid:
		var texel := _texel(image, cell)
		var ground := PunyTerrain.ground_of(data.grid[cell])
		if texel.g > 0.0:
			marked += 1
			assert_true(ground in ["sand", "grass"], "only sand and grass are drawn again, at %s" % cell)
		assert_eq(texel.r, 1.0 if ground in SandShape.SANDY else 0.0, "the field is the map's own sand and sea, at %s" % cell)
		assert_eq(data.is_walkable(cell), walked[cell], "walking at %s" % cell)
	assert_gt(marked, 150, "the dunes' edges all along the shore")
	assert_eq(data.grid.hash(), before, "the grid is as it was")


func test_only_saltmere_is_drawn_so() -> void:
	assert_eq(SandShape.MAPS, ["saltmere"])
