extends GutTest
## Every outdoor map holds together (PIX-164): its tiles are known, its
## regions exist, every road out lands on open ground and back, and every
## pack and patch stands where the hero can reach it.

const OUTDOOR := ["overworld", "deepwood", "mirefen", "saltmere", "seacave", "blackiron", "shafts", "greyhold", "cellars", "frostgate", "icecave"]


func test_every_tile_is_known_and_every_region_exists() -> void:
	for map_id: String in OUTDOOR:
		var map := MapData.load_by_id(map_id)
		for cell: Vector2i in map.grid:
			assert_true(WorldTiles.TILE_INFO.has(map.grid[cell]), "%s: %s at %s" % [map_id, map.grid[cell], cell])
		for cell: Vector2i in map.regions:
			var region: String = map.regions[cell]
			assert_false(Bestiary.region(region).is_empty(), "%s: region %s" % [map_id, region])


func test_every_road_lands_on_open_ground() -> void:
	for map_id: String in OUTDOOR:
		var map := MapData.load_by_id(map_id)
		for cell: Vector2i in map.portals:
			var to: Dictionary = map.portals[cell]
			if to["kind"] != "map":
				continue
			var there := MapData.load_by_id(to["mapId"])
			var at := Vector2i(int(to["x"]), int(to["y"]))
			assert_true(there.is_walkable(at), "%s %s -> %s %s" % [map_id, cell, to["mapId"], at])


func test_saltmere_and_the_overworld_lead_to_each_other() -> void:
	var coast := MapData.load_by_id("saltmere")
	var back: Array = coast.portals.values().map(func(to: Dictionary) -> String: return to.get("mapId", ""))
	assert_has(back, "overworld")
	assert_true(coast.is_walkable(coast.spawn))
	assert_eq(Catalog.place_name("saltmere"), "Saltmere")


func test_packs_and_patches_stand_on_their_ground() -> void:
	for map_id: String in OUTDOOR:
		var map := MapData.load_by_id(map_id)
		for spawn: Dictionary in Bestiary.spawns_on(map_id):
			var at := Vector2i(int(spawn["x"]), int(spawn["y"]))
			assert_true(map.is_walkable(at), "%s: pack %s" % [map_id, spawn["id"]])
			assert_ne(map.region_at(at), "", "%s: pack %s has a region" % [map_id, spawn["id"]])
		for spot: Dictionary in Gathering.spots_on(map_id):
			var at := Vector2i(int(spot["x"]), int(spot["y"]))
			assert_true(map.is_walkable(at), "%s: patch %s" % [map_id, spot["id"]])
			assert_ne(Gathering.material_at(map, at), "", "%s: patch %s grows something" % [map_id, spot["id"]])
