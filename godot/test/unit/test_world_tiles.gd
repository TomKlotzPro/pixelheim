extends GutTest
## WorldTiles says what the hero may walk on; Shade's layers draw it all
## (PIX-137). Its walkability must stay the web's (src/world/tiles.ts).


func test_walkability_is_the_webs() -> void:
	for tile: String in ["grass", "path", "floor", "door", "bridge", "flowers", "shrine", "cave", "crops"]:
		assert_true(WorldTiles.is_walkable(tile), tile)
	for tile: String in ["wall", "water", "mountain", "roof_slate", "fence", "well", "lamp", "counter", "door_shut", "bed"]:
		assert_false(WorldTiles.is_walkable(tile), tile)


func test_ground_tiles_are_known_tiles() -> void:
	for tile: String in WorldTiles.GROUND_TILES:
		assert_true(WorldTiles.TILE_INFO.has(tile), "unknown ground tile %s" % tile)


func test_unknown_tile_is_not_walkable() -> void:
	assert_false(WorldTiles.is_walkable(""))
	assert_false(WorldTiles.is_walkable("lava"))
