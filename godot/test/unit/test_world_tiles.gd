extends GutTest
## WorldTiles tables must stay coherent with the shipped sprites — these are
## the same invariants parseMap.ts enforces at module load on the web side.


func test_every_map_char_resolves_to_a_known_tile() -> void:
	for character: String in WorldTiles.CHAR_TILES:
		var tile: String = WorldTiles.CHAR_TILES[character]
		assert_true(
			WorldTiles.TILE_INFO.has(tile),
			"char %s maps to unknown tile %s" % [character, tile]
		)


func test_unknown_chars_fall_back_to_grass() -> void:
	assert_eq(WorldTiles.tile_for_char("?"), "grass")


func test_every_tile_sprite_exists() -> void:
	var missing := []
	for tile: String in WorldTiles.TILE_INFO:
		if not ResourceLoader.exists(WorldTiles.sprite_path(tile)):
			missing.append(tile)
	assert_eq(missing, [], "tiles with missing sprite files")


func test_mob_habitats_are_walkable_tiles() -> void:
	for tile: String in WorldTiles.MOB_HABITATS:
		assert_true(WorldTiles.is_walkable(tile), "mobs cannot roam unwalkable %s" % tile)


func test_unknown_tile_is_not_walkable() -> void:
	assert_false(WorldTiles.is_walkable(""))
	assert_false(WorldTiles.is_walkable("lava"))
