extends GutTest
## The maps are edited by hand (assets/maps/*.json, or a sketch in maps-src
## run through tools/mapgen.py) and nothing regenerates them, so this is what
## keeps them whole (PIX-301: the checks the web edition's exporter ran as it
## wrote them): every file is a rectangle of known tiles with its spawn on
## open ground and its regions known; every way between maps leads to a map
## that exists and lands on open ground; every pack stands on open ground in
## an encounter region. Every map file is checked, not a list: a new map is
## covered the day it is added. The village through its ages, and the ways
## and roads round them, are test_ways'; chests are test_interactables'.

const MAPS_DIR := "res://assets/maps"
## The file in the maps' folder that isn't a map.
const NOT_MAPS := ["interactables.json"]


## Every map file's name less ".json": "overworld", "town_house@2".
func _files() -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(MAPS_DIR):
		if file.ends_with(".json") and not file in NOT_MAPS:
			out.append(file.trim_suffix(".json"))
	return out


## A map file as the game loads it: a bigger house's drawing by its file, any
## other through load_by_id (a dungeon floor dressed with its stairs).
func _load(file_id: String) -> MapData:
	if "@" in file_id:
		return MapData.load_from("%s/%s.json" % [MAPS_DIR, file_id])
	return MapData.load_by_id(file_id)


## Every map a hero can stand on: each file, and each dungeon floor the
## depths plan rather than draw.
func _every_map() -> Array[String]:
	var out := _files()
	for dungeon_id: String in Depths.dungeons():
		for floor_def: Dictionary in Depths.floors(dungeon_id):
			if Depths.is_planned(String(floor_def["mapId"])):
				out.append(String(floor_def["mapId"]))
	return out


func _exists(map_id: String) -> bool:
	return FileAccess.file_exists("%s/%s.json" % [MAPS_DIR, map_id]) or Depths.is_planned(map_id)


func test_the_maps_folder_holds_every_map() -> void:
	var files := _files()
	assert_gt(files.size(), 30, "the maps were found")
	for map_id: String in ["overworld", "town", "town_house@3", "saltmere", "seacave", "keep"]:
		assert_has(files, map_id)


func test_every_map_file_is_a_whole_rectangle_of_known_tiles() -> void:
	for file_id: String in _files():
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [MAPS_DIR, file_id]))
		assert_eq(String(doc["id"]), file_id.get_slice("@", 0), "%s: its id is its file's name" % file_id)
		var width := int(doc["width"])
		var rows: Array = doc["tiles"]
		assert_eq(rows.size(), int(doc["height"]), "%s: as many rows as it is high" % file_id)
		var ragged := rows.filter(func(row: Array) -> bool: return row.size() != width)
		assert_eq(ragged.size(), 0, "%s: every row as wide as the map" % file_id)
		var unknown := {}
		for row: Array in rows:
			for tile: Variant in row:
				if not WorldTiles.TILE_INFO.has(tile):
					unknown[tile] = true
		assert_eq(unknown.keys(), [], "%s: only known tiles (WorldTiles.TILE_INFO)" % file_id)
		var map := _load(file_id)
		assert_true(map.is_walkable(map.spawn), "%s: its spawn %s is open ground" % [file_id, map.spawn])


func test_every_map_files_regions_are_its_size_and_known() -> void:
	for file_id: String in _files():
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [MAPS_DIR, file_id]))
		if not doc.has("regions"):
			continue
		var rows: Array = doc["regions"]
		assert_eq(rows.size(), int(doc["height"]), "%s: a region row for every row" % file_id)
		var unknown := {}
		for row: Array in rows:
			assert_eq(row.size(), int(doc["width"]), "%s: every region row as wide as the map" % file_id)
			for region: Variant in row:
				if region != null and Bestiary.region(String(region)).is_empty():
					unknown[region] = true
		assert_eq(unknown.keys(), [], "%s: only regions combat.json knows" % file_id)


func test_every_way_between_maps_lands_on_open_ground_of_a_map_that_exists() -> void:
	var ways := 0
	for file_id: String in _every_map():
		var map := _load(file_id)
		for cell: Vector2i in map.portals:
			ways += 1
			var target: Dictionary = map.portals[cell]
			assert_eq(String(target["kind"]), "map", "%s %s: a way leads to a map" % [file_id, cell])
			assert_true(Rect2i(Vector2i.ZERO, map.size).has_point(cell), "%s: the way at %s is on the map" % [file_id, cell])
			assert_true(WorldTiles.is_walkable(map.tile_at(cell)), "%s: the way at %s can be stepped on" % [file_id, cell])
			var to_id := String(target["mapId"])
			if not _exists(to_id):
				fail_test("%s %s leads to %s, which is no map" % [file_id, cell, to_id])
				continue
			var landing := Vector2i(int(target["x"]), int(target["y"]))
			assert_true(
				MapData.load_by_id(to_id).is_walkable(landing),
				"%s %s strands the hero at %s in %s" % [file_id, cell, landing, to_id]
			)
	assert_gt(ways, 80, "every map's ways were walked through")


func test_every_pack_stands_on_open_ground_in_an_encounter_region() -> void:
	var seen := {}
	var maps := {}
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		var spawn_id := String(spawn["id"])
		assert_false(seen.has(spawn_id), "%s: a pack's id is its own" % spawn_id)
		seen[spawn_id] = true
		var map_id := String(spawn["mapId"])
		if not _exists(map_id):
			fail_test("%s stands on %s, which is no map" % [spawn_id, map_id])
			continue
		if not maps.has(map_id):
			maps[map_id] = MapData.load_by_id(map_id)
		var map: MapData = maps[map_id]
		var cell := Vector2i(int(spawn["x"]), int(spawn["y"]))
		assert_true(map.is_walkable(cell), "%s: open ground at %s %s" % [spawn_id, map_id, cell])
		assert_ne(map.region_at(cell), "", "%s: in an encounter region at %s %s" % [spawn_id, map_id, cell])
		assert_false(map.portals.has(cell), "%s: not on a way out at %s %s" % [spawn_id, map_id, cell])
		if spawn.has("species"):
			assert_false(Bestiary.monster(String(spawn["species"])).is_empty(), "%s: a known species" % spawn_id)
	assert_gt(seen.size(), 80, "every pack was looked at")
