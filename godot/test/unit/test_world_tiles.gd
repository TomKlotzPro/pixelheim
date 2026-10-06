extends GutTest
## WorldTiles tables must stay coherent with the shipped sprites — the same
## invariants the web game enforces at module load.


func test_every_tile_has_art() -> void:
	var missing := []
	for tile: String in WorldTiles.TILE_INFO:
		var puny_ground := WorldTiles.GROUND_TILES.has(tile)
		var sprite: String = WorldTiles.TILE_INFO[tile][0]
		if puny_ground:
			if sprite != "":
				missing.append("%s names a sprite the Puny ground never draws" % tile)
		elif not ResourceLoader.exists(WorldTiles.sprite_path(tile)):
			missing.append(tile)
	assert_eq(missing, [], "tiles without art")


func test_ground_tiles_are_known_tiles() -> void:
	for tile: String in WorldTiles.GROUND_TILES:
		assert_true(WorldTiles.TILE_INFO.has(tile), "unknown ground tile %s" % tile)


func test_props_lose_the_web_grass_they_were_painted_on() -> void:
	var lamp := WorldTiles.cutout(WorldTiles.sprite_path("lamp")).get_image()
	assert_eq(lamp.get_pixel(0, 0).a, 0.0, "grass corner keyed out")
	var opaque := 0
	for y in lamp.get_height():
		for x in lamp.get_width():
			if lamp.get_pixel(x, y).a > 0.5:
				opaque += 1
	assert_eq(opaque, 38, "the lamp itself stays (post, glass, base)")


func test_unknown_tile_is_not_walkable() -> void:
	assert_false(WorldTiles.is_walkable(""))
	assert_false(WorldTiles.is_walkable("lava"))
