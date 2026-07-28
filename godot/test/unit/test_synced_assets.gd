extends GutTest
## Assets synced from the web game (pnpm godot:sync) must be complete and
## coherent: every animated tile has its sheet + atlas metadata, every
## exported map parses into known tiles, and every portal link resolves —
## the same validation src/world/maps/index.ts runs at module load.

const MAP_IDS := [
	"overworld", "deepwood", "mirefen", "town", "town_shop", "town_inn",
	"town_smith", "town_alchemist", "town_house", "town_hall", "demo", "demo_hut",
]


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


func test_every_exported_map_parses_into_known_tiles() -> void:
	for map_id: String in MAP_IDS:
		var map := MapData.load_by_id(map_id)
		assert_eq(map.id, map_id)
		assert_eq(map.grid.size(), map.size.x * map.size.y, "%s not rectangular" % map_id)
		assert_true(map.is_walkable(map.spawn), "%s spawn not walkable" % map_id)
		var unknown := 0
		for cell: Vector2i in map.grid:
			if not WorldTiles.TILE_INFO.has(map.grid[cell]):
				unknown += 1
		assert_eq(unknown, 0, "%s holds unknown tiles" % map_id)


func test_every_map_portal_resolves_to_a_walkable_cell() -> void:
	for map_id: String in MAP_IDS:
		var map := MapData.load_by_id(map_id)
		for cell: Vector2i in map.portals:
			var target: Dictionary = map.portals[cell]
			if target["kind"] != "map":
				continue
			var destination := MapData.load_by_id(target["mapId"])
			assert_true(
				destination.is_walkable(Vector2i(int(target["x"]), int(target["y"]))),
				"%s portal at %s strands the hero in %s" % [map_id, cell, target["mapId"]]
			)
