extends GutTest
## PunyTerrain: Shade's wang tables read from his .tsx, the dual grid laid
## over our cells, and the pieces that stand on them (bridges, ramparts, a
## town seen from afar). Expected tile ids come from the .tsx itself.

const GRASS := [0, 1, 2, 27, 28, 29, 54, 55, 56]


func _grid(rows: Array) -> Dictionary:
	var legend := {
		".": "grass", "~": "water", "^": "mountain", "=": "path", "B": "bridge",
		"#": "wall", "D": "door", "R": "roof", "_": "floor", "K": "dock", "s": "sand", "S": "sea",
	}
	var grid := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			grid[Vector2i(x, y)] = legend[row[x]]
	return grid


func test_corner_tiles_come_from_the_tsx() -> void:
	for pick in 9:
		assert_has(GRASS, PunyTerrain.corner_tile(["grass", "grass", "grass", "grass"], pick))
	assert_eq(PunyTerrain.corner_tile(["river", "river", "river", "river"], 0), 305)
	assert_eq(PunyTerrain.corner_tile(["cliff", "cliff", "cliff", "cliff"], 0), 136)
	assert_eq(PunyTerrain.corner_tile(["grass", "grass", "dirt", "dirt"], 0), 11, "road along the bottom half")
	assert_eq(PunyTerrain.corner_tile(["grass", "grass", "river", "grass"], 0), 277, "water in one corner")


func test_terrains_shade_never_paired_settle_onto_grass() -> void:
	assert_eq(PunyTerrain.settle(["cliff", "river", "grass", "dirt"]), ["cliff", "grass", "grass", "grass"])
	assert_eq(PunyTerrain.settle(["dirt", "sand", "sand", "dirt"]), ["dirt", "grass", "grass", "dirt"])
	assert_eq(
		PunyTerrain.settle(["grass", "river", "grass", "river"]), ["river", "river", "river", "river"],
		"water touching only diagonally floods, so blocked water never looks walkable"
	)


func test_the_dual_grid_puts_each_cell_in_four_corner_tiles() -> void:
	var grid := _grid(["...", ".~.", "..."])
	var tiles := PunyTerrain.ground_tiles(grid, Vector2i(3, 3))
	assert_eq(tiles.size(), 16, "one tile per cell corner: (3+1) x (3+1)")
	assert_eq(tiles[Vector2i(1, 1)], PunyTerrain.corner_tile(["grass", "grass", "river", "grass"], 0))
	assert_eq(tiles[Vector2i(2, 2)], PunyTerrain.corner_tile(["river", "grass", "grass", "grass"], 0))
	assert_has(GRASS, tiles[Vector2i(0, 0)], "off-map corners repeat the edge")


func test_water_ripples_in_frames_four_rows_apart() -> void:
	assert_eq(PunyTerrain.animation(270), [[270, 0.1], [378, 0.1], [486, 0.1], [594, 0.1]])
	assert_eq(PunyTerrain.animation(305), [], "open water holds still")
	var layer := TileMapLayer.new()
	layer.tile_set = PunyTerrain.tileset()
	PunyTerrain.place(layer, Vector2i.ZERO, 270)
	var slot: Array = PunyTerrain.sheet().slot(270)
	var source := PunyTerrain.tileset().get_source(slot[0]) as TileSetAtlasSource
	assert_eq(source.get_tile_animation_frames_count(slot[1]), 4)
	assert_eq(source.get_tile_animation_separation(slot[1]), Vector2i(0, 3), "separation counts tiles")
	layer.free()


func test_pines_crown_only_mountains_walled_in_on_all_sides() -> void:
	var grid := _grid(["^^^^^", "^^^^^", "^^^^^", ".....", "....."])
	var crowns := PunyTerrain.forest_tiles(grid, Vector2i(5, 5))
	assert_true(crowns.has(Vector2i(2, 1)), "deep in the range")
	assert_false(crowns.has(Vector2i(2, 4)), "no trees down on the grass")
	assert_eq(crowns[Vector2i(2, 1)], PunyTerrain.corner_tile(["trees", "trees", "trees", "trees"], 0))


func test_bridges_follow_their_span() -> void:
	var across := _grid(["~~~~", ".BB.", "~~~~"])
	assert_eq(PunyTerrain.object_at(across, Vector2i(1, 1)), 875, "west end")
	assert_eq(PunyTerrain.object_at(across, Vector2i(2, 1)), 877, "east end")
	var down := _grid(["~=~", "~B~", "~B~", "~B~", "~=~"])
	assert_eq(PunyTerrain.object_at(down, Vector2i(1, 1)), 820, "north end")
	assert_eq(PunyTerrain.object_at(down, Vector2i(1, 2)), 847)
	assert_eq(PunyTerrain.object_at(down, Vector2i(1, 3)), 874, "south end")
	assert_eq(PunyTerrain.object_at(_grid(["~~", ".B", "~~"]), Vector2i(1, 1)), 821, "one plank over a stream")
	assert_eq(PunyTerrain.object_at(down, Vector2i(0, 0)), -1)


## PIX-235: the web's shapes laid planks along a river; they run from land
## to land, whatever the span's shape.
func test_planks_run_between_the_banks() -> void:
	var tall := _grid(["~~~~", ".BB.", ".BB.", ".BB.", "~~~~"])
	assert_eq(PunyTerrain.span_axis(tall, Vector2i(1, 2)), Vector2i.RIGHT, "taller than wide, still across")
	assert_eq(PunyTerrain.object_at(tall, Vector2i(1, 2)), 875, "west end")
	assert_eq(PunyTerrain.object_at(tall, Vector2i(2, 2)), 877, "east end")
	var pier := _grid(["=====", "~KKK~", "~KKK~", "~~~~~"])
	assert_eq(PunyTerrain.span_axis(pier, Vector2i(2, 1)), Vector2i.DOWN, "a pier runs out from its bank")
	assert_eq(PunyTerrain.object_at(pier, Vector2i(2, 1)), 820, "its landing")
	assert_eq(PunyTerrain.object_at(pier, Vector2i(2, 2)), 874, "its end, out over the water")
	var long := _grid(["~~~~~~~~~~~~", "=BBBBBBBBBB=", "~~~~~~~~~~~~"])
	assert_eq(PunyTerrain.span_axis(long, Vector2i(1, 1)), Vector2i.RIGHT, "a span longer than a run's reach")
	assert_eq(PunyTerrain.span_end(long, Vector2i(1, 1), Vector2i.RIGHT), Vector2i(11, 1))


## PIX-236: a dock built out into a river stands in the river, not in a pale
## square of the coast's shallows.
func test_a_dock_stands_in_the_water_around_it() -> void:
	var river := _grid(["=====", "~KKK~", "~KKK~", "~~~~~"])
	assert_eq(PunyTerrain.ground_at(river, Vector2i(2, 1)), "river", "the middle of the village's pier too")
	var coast := _grid(["sss", "SKS", "SKS", "SSS"])
	assert_eq(PunyTerrain.ground_at(coast, Vector2i(1, 2)), "seawater-light", "the coast's over its shallows")
	assert_eq(PunyTerrain.ground_at(coast, Vector2i(1, 0)), "sand")


func test_ramparts_raise_towers_runs_and_a_gate() -> void:
	var grid := _grid([
		"######D######",
		"#...........#",
		"#...........#",
		"#...........#",
		"#############",
	])
	assert_eq(PunyTerrain.wall_piece(grid, Vector2i(0, 0)), PunyTerrain.TOWER, "corner")
	assert_eq(PunyTerrain.wall_piece(grid, Vector2i(3, 0)), PunyTerrain.WALL_ACROSS)
	assert_eq(PunyTerrain.wall_piece(grid, Vector2i(8, 4)), PunyTerrain.TOWER_ACROSS, "every 8th step")
	assert_eq(PunyTerrain.wall_piece(grid, Vector2i(0, 2)), PunyTerrain.WALL_DOWN)
	assert_eq(PunyTerrain.wall_piece(grid, Vector2i(6, 0)), PunyTerrain.GATE)
	assert_eq(PunyTerrain.wall_piece(grid, Vector2i(3, 2)), -1, "inside the walls")
	var house := _grid(["RRR", "RDR", "..."])
	assert_eq(PunyTerrain.wall_piece(house, Vector2i(1, 1)), -1, "a house door is no gate")


func test_a_town_seen_from_afar_is_a_keep_among_houses() -> void:
	var grid := _grid([
		"#######",
		"##D####",
		"#RRRRR#",
		"#RRRRR#",
		"#RRRRR#",
		"#######",
	])
	var skyline := PunyTerrain.skyline(grid)
	assert_eq(skyline[Vector2i(3, 3)], 714, "the keep's top-left at the block's heart")
	assert_eq(skyline[Vector2i(4, 4)], 742)
	assert_has(PunyTerrain.HOUSES, skyline[Vector2i(4, 2)])
	assert_has(PunyTerrain.HOUSES, skyline[Vector2i(2, 4)])
	assert_false(skyline.has(Vector2i(2, 2)), "never right behind the gate")
	assert_false(skyline.has(Vector2i(3, 2)), "houses stand on even cells only")


func test_interiors_are_not_outdoors() -> void:
	assert_false(PunyTerrain.is_outdoor(_grid(["###", "#_#", "#D#"])))
	assert_true(PunyTerrain.is_outdoor(_grid(["#.#"])))


func test_the_tint_mask_marks_ash_and_mire() -> void:
	var grid := {Vector2i(0, 0): "ash", Vector2i(1, 0): "marsh", Vector2i(2, 0): "grass"}
	var mask := PunyTerrain.tint_map(grid, Vector2i(3, 1)).get_image()
	assert_almost_eq(mask.get_pixel(0, 0).r, PunyTerrain.TINTS["ash"].r, 0.01)
	assert_almost_eq(mask.get_pixel(1, 0).g, PunyTerrain.TINTS["marsh"].g, 0.01)
	assert_eq(mask.get_pixel(2, 0).a, 0.0)
