extends GutTest
## WorldTiles tables must stay coherent with the shipped sprites — the same
## invariants the web game enforces at module load.


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
