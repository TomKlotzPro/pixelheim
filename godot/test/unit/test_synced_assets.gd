extends GutTest
## Assets synced from the web game (pnpm godot:sync) must be complete and
## coherent: every animated tile has its sheet + atlas metadata, and every
## synced map parses into a rectangular grid of known tiles.


func test_animated_tiles_have_sheets_and_atlas_entries() -> void:
	var animations := WorldTiles.atlas_animations()
	for tile: String in WorldTiles.TILE_ANIMATIONS:
		var sheet: String = WorldTiles.TILE_ANIMATIONS[tile]
		assert_true(WorldTiles.TILE_INFO.has(tile), "unknown animated tile %s" % tile)
		assert_true(
			ResourceLoader.exists("res://assets/sprites/%s.png" % sheet),
			"missing sheet %s" % sheet
		)
		assert_true(animations.has(sheet), "atlas.json lacks %s" % sheet)
		assert_gt(int(animations[sheet]["frames"]), 1)
		assert_gt(float(animations[sheet]["fps"]), 0.0)


func test_all_synced_maps_parse_into_known_tiles() -> void:
	for map_name in ["overworld", "frontier", "demo"]:
		var map := MapData.load_from("res://assets/maps/%s.txt" % map_name)
		assert_gt(map.size.x, 0, "%s is empty" % map_name)
		assert_eq(map.grid.size(), map.size.x * map.size.y, "%s not rectangular" % map_name)
		var unknown := 0
		for cell: Vector2i in map.grid:
			if not WorldTiles.TILE_INFO.has(map.grid[cell]):
				unknown += 1
		assert_eq(unknown, 0, "%s holds unknown tiles" % map_name)
