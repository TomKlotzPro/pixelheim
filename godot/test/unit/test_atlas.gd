extends GutTest
## The map screen's pages (PIX-266): every map found is a page, in the
## world's order; each is drawn whole at a size to read; the waypoints are
## listed by the place they stand in; a page names its regions over what's
## been seen of them and its ways to other places once their doors are seen;
## the village is drawn small in its walls on the Ashenreach. The Reach and
## its six regions are one page (PIX-269 step 7), each map at its place in
## the plane, none over another, the ridge seen between them.


func _seen_all(map: MapData) -> Dictionary:
	var seen := {}
	for cell: Vector2i in map.grid:
		seen[cell] = true
	return seen


func _texts(labels: Array[Dictionary], way: bool) -> Array:
	return labels.filter(func(label: Dictionary) -> bool: return label["way"] == way).map(func(label: Dictionary) -> String: return label["text"])


func test_the_pages_are_the_maps_found_in_the_worlds_order() -> void:
	var discovered := {}
	Discovery.discover_around(discovered, MapData.load_by_id("greyhold"), Vector2i(2, 30))
	Discovery.discover_around(discovered, MapData.load_by_id("cellars"), Vector2i(2, 2))
	Discovery.discover_around(discovered, MapData.load_by_id("overworld"), Vector2i(48, 40))
	assert_eq(Atlas.pages(discovered, "town"), ["overworld", "town", "cellars"] as Array[String], "the hero's map is a page, found or not; Greyhold is on the Reach's")
	assert_eq(Atlas.pages(discovered, "town_inn"), ["town_inn", "overworld", "cellars"] as Array[String], "a room comes first")
	assert_eq(Atlas.pages(discovered, "greyhold"), ["overworld", "cellars"] as Array[String], "standing in a region, the Reach's page is theirs")
	assert_true(Atlas.found(discovered, "greyhold"))
	assert_false(Atlas.found(discovered, "frostgate"))
	for map_id: String in Atlas.ORDER:
		# A region dungeon's planned floor is laid out, not read (PIX-255).
		assert_true(FileAccess.file_exists("res://assets/maps/%s.json" % map_id) or Depths.is_planned(map_id), "%s is a map" % map_id)


func test_the_reach_and_its_regions_are_one_page() -> void:
	assert_eq(ReachPlane.maps()[0], Atlas.REACH, "the page goes by the plane's middle")
	for map_id: String in ReachPlane.maps():
		assert_eq(Atlas.page_of(map_id), Atlas.REACH, "%s is on the Reach's page" % map_id)
	for map_id: String in ["town", "seacave", "shafts", "cellars", "icecave", "town_inn", "keep"]:
		assert_eq(Atlas.page_of(map_id), map_id, "%s keeps a page of its own" % map_id)
	assert_eq(Atlas.sheets("town", {}, "town"), [{"id": "town", "at": Vector2i.ZERO}] as Array[Dictionary], "a page of one map")


func test_every_map_of_the_plane_lies_at_its_offset_and_none_overlap() -> void:
	var everywhere := {}
	Atlas.walk_all(everywhere)
	var sheets := Atlas.sheets(Atlas.REACH, everywhere, "town")
	var ids: Array = sheets.map(func(sheet: Dictionary) -> String: return sheet["id"])
	assert_eq(ids, ReachPlane.maps(), "every map of the plane, the Ashenreach first")
	var sizes := {}
	for sheet: Dictionary in sheets:
		sizes[sheet["id"]] = ReachPlane.size_of(sheet["id"])
		assert_eq(sheet["at"] - sheets[0]["at"], ReachPlane.origin(sheet["id"]), "%s where the plane puts it" % sheet["id"])
		assert_true(sheet["at"].x >= 0 and sheet["at"].y >= 0, "%s on the page" % sheet["id"])
	var page := Atlas.page_size(sheets, sizes)
	var low := Vector2i(1 << 20, 1 << 20)
	for sheet: Dictionary in sheets:
		low = low.min(sheet["at"])
		assert_true(Rect2i(Vector2i.ZERO, page).encloses(Rect2i(sheet["at"], sizes[sheet["id"]])), "%s whole on the page" % sheet["id"])
	assert_eq(low, Vector2i.ZERO, "the page framed to its maps")
	for i in sheets.size():
		for j in range(i + 1, sheets.size()):
			var a := Rect2i(sheets[i]["at"], sizes[sheets[i]["id"]])
			var b := Rect2i(sheets[j]["at"], sizes[sheets[j]["id"]])
			assert_false(a.intersects(b), "%s and %s drawn apart" % [sheets[i]["id"], sheets[j]["id"]])
	var px := Atlas.tile_px(page, Vector2(760, 540))
	assert_gte(px, 3, "the whole Reach at %d px a tile" % px)
	assert_lte(page.x * px, 760, "fits the window across")
	assert_lte(page.y * px, 540, "and down")


func test_the_page_frames_the_regions_found() -> void:
	var discovered := {}
	Discovery.discover_around(discovered, MapData.load_by_id("overworld"), Vector2i(16, 60))
	var alone := Atlas.sheets(Atlas.REACH, discovered, "overworld")
	assert_eq(alone, [{"id": "overworld", "at": Vector2i.ZERO}] as Array[Dictionary], "the Ashenreach alone, as its page always was")
	Discovery.discover_around(discovered, MapData.load_by_id("saltmere"), Vector2i(16, 2))
	var south := Atlas.sheets(Atlas.REACH, discovered, "overworld")
	assert_eq(south.size(), 2)
	assert_eq(south[1], {"id": "saltmere", "at": ReachPlane.origin("saltmere")}, "Saltmere under its road")
	var sizes := {"overworld": Vector2i(96, 64), "saltmere": ReachPlane.size_of("saltmere")}
	assert_eq(Atlas.page_size(south, sizes), Vector2i(96, 64 + sizes["saltmere"].y), "no room kept for a region not found")
	assert_eq(Atlas.sheets(Atlas.REACH, {}, "deepwood").size(), 2, "the region the hero stands in, found or not")


func test_the_ridge_is_drawn_where_it_was_in_sight() -> void:
	var discovered := {}
	var overworld := MapData.load_by_id("overworld")
	# In the middle of the Ashenreach: no edge, no ridge.
	Discovery.discover_around(discovered, overworld, Vector2i(48, 30))
	assert_eq(Atlas.ridge(Atlas.sheets(Atlas.REACH, discovered, "overworld"), discovered), {})
	assert_eq(Atlas.ridge(Atlas.sheets("town", discovered, "town"), discovered), {}, "no ridge on a page of its own")
	# Every map walked: the ridge seen all round, never on a map.
	var everywhere := {}
	Atlas.walk_all(everywhere)
	var sheets := Atlas.sheets(Atlas.REACH, everywhere, "overworld")
	var ridge := Atlas.ridge(sheets, everywhere)
	assert_gt(ridge.size(), 100, "the cliffs between the maps")
	var corner: Vector2i = ReachPlane.origin("overworld") - sheets[0]["at"]
	for cell: Vector2i in ridge:
		assert_eq(ReachPlane.at(cell + corner), {}, "%s is ridge, no map's" % cell)


func test_the_reachs_page_names_its_regions_not_its_roads() -> void:
	var everywhere := {}
	Atlas.walk_all(everywhere)
	var sheets := Atlas.sheets(Atlas.REACH, everywhere, "overworld")
	var sizes := {}
	for sheet: Dictionary in sheets:
		sheet["map"] = MapData.load_by_id(sheet["id"])
		sizes[sheet["id"]] = sheet["map"].size
	var labels := Atlas.page_labels(sheets, everywhere)
	var places := _texts(labels, false)
	for region: String in ["saltmere", "mirefen", "blackiron", "frostgate", "greyhold", "deepwood"]:
		assert_true(Catalog.place_name(region) in places, "%s named on its ground" % region)
	assert_false(Catalog.place_name("overworld") in places, "the title names the Ashenreach")
	assert_true(Atlas.region_title("ash") in places, "and its own regions as before")
	var ways := _texts(labels, true)
	assert_true(Catalog.place_name("town") in ways, "the village's gate")
	for cave: String in ["seacave", "shafts", "cellars", "icecave"]:
		assert_true(Catalog.place_name(cave) in ways, "the way down to %s" % cave)
	assert_eq(ways.size(), 5, "no road between two maps on the page named")
	var page := Rect2(Vector2.ZERO, Vector2(Atlas.page_size(sheets, sizes)))
	for label: Dictionary in labels:
		assert_true(page.has_point(label["at"]), "%s on the page" % label["text"])


func test_a_way_off_the_page_leaves_from_its_last_map() -> void:
	var reach: Array = ReachPlane.maps()
	var gate := Bearing.way_out("overworld", "town")
	assert_eq(Atlas.way_off(reach, "greyhold", "town"), {"map": "overworld", "cell": gate}, "from Greyhold, the village's gate on the Ashenreach")
	assert_eq(Atlas.way_off(reach, "overworld", "cellars"), {"map": "greyhold", "cell": Bearing.way_out("greyhold", "cellars")}, "the cellars' door in Greyhold")
	assert_eq(Atlas.way_off(["town"], "town", "greyhold"), {"map": "town", "cell": Bearing.way_out("town", "greyhold")}, "a page of one map: its door that starts the way")
	assert_eq(Atlas.way_off(reach, "overworld", "nowhere"), {}, "no way there")


func test_the_pages_turn_round() -> void:
	var pages: Array[String] = ["overworld", "town", "greyhold"]
	assert_eq(Atlas.turn(pages, "town", 1), "greyhold")
	assert_eq(Atlas.turn(pages, "greyhold", 1), "overworld", "round from the last to the first")
	assert_eq(Atlas.turn(pages, "overworld", -1), "greyhold", "and back")
	assert_eq(Atlas.turn(pages, "frostgate", 1), "overworld", "from nowhere, the first")


func test_every_page_is_drawn_at_a_size_to_read() -> void:
	for map_id: String in Atlas.ORDER:
		if ReachPlane.holds(map_id) and map_id != Atlas.REACH:
			continue
		var map := MapData.load_by_id(map_id)
		var px := Atlas.tile_px(map.size, Vector2(760, 540))
		assert_between(px, 7, Atlas.MAX_TILE, "%s at %d px a tile" % [map_id, px])
		assert_lte(map.size.x * px, 760, "%s fits the window across" % map_id)
		assert_lte(map.size.y * px, 540, "%s fits it down" % map_id)
	assert_eq(Atlas.tile_px(Vector2i(96, 64), Vector2(760, 540)), 7, "the Ashenreach")


func test_the_waypoints_are_listed_by_their_place() -> void:
	var listed := Atlas.listed(Interactables.waypoints())
	assert_eq(listed.size(), Interactables.waypoints().size(), "every one")
	var places: Array[String] = []
	for waypoint: Dictionary in listed:
		if places.is_empty() or places[-1] != waypoint["mapId"]:
			assert_false(waypoint["mapId"] in places, "%s's waypoints together" % waypoint["mapId"])
			places.append(waypoint["mapId"])
	assert_eq(places, ["overworld", "town", "saltmere", "blackiron", "frostgate", "greyhold"] as Array[String], "in the world's order")
	assert_eq(listed[0]["id"], "town_gate", "the gate home first, as before")


func test_regions_are_named_only_where_a_map_has_several() -> void:
	assert_true(Atlas.names_regions(MapData.load_by_id("overworld")), "the ash, the woods and the marsh")
	for map_id: String in ["town", "greyhold", "frostgate", "saltmere", "blackiron", "cellars"]:
		assert_false(Atlas.names_regions(MapData.load_by_id(map_id)), "%s is its region" % map_id)
	assert_eq(Atlas.region_title("ash"), "The Ash Fields", "a name on a line of its own")


func test_a_page_names_its_regions_and_ways_out_once_seen() -> void:
	var overworld := MapData.load_by_id("overworld")
	assert_eq(Atlas.labels(overworld, {}), [] as Array[Dictionary], "nothing seen, nothing named")
	var everything := Atlas.labels(overworld, _seen_all(overworld))
	var ways := _texts(everything, true)
	for map_id: String in ["town", "mirefen", "deepwood", "saltmere", "blackiron", "greyhold", "frostgate"]:
		assert_true(Catalog.place_name(map_id) in ways, "the way to %s" % map_id)
	assert_eq(ways.size(), 7, "each once")
	assert_eq(_texts(everything, false), ["The Ash Fields", "The Whispering Forest", "The Sunken Marsh"], "its three regions")
	# Seen from the Mirefen Pass: its road, and only a corner of the marsh.
	var by_the_pass := {}
	Discovery.discover_around(by_the_pass, overworld, Vector2i(2, 32))
	var glimpsed := Atlas.labels(overworld, by_the_pass["overworld"])
	assert_eq(_texts(glimpsed, true), [Catalog.place_name("mirefen")])
	assert_eq(_texts(glimpsed, false), [], "a corner of the marsh isn't the marsh")
	# A region is named over what's been seen of it.
	var road := {}
	for x in range(30, 60):
		for y in range(8, 14):
			road[Vector2i(x, y)] = true
	var ash: Dictionary = Atlas.labels(overworld, road).filter(func(label: Dictionary) -> bool: return not label["way"])[0]
	assert_true(Rect2(30, 8, 30, 6).has_point(ash["at"]), "the Ash Fields named where they were walked")


func test_a_region_names_its_way_home_and_its_cave() -> void:
	var greyhold := MapData.load_by_id("greyhold")
	var labels := Atlas.labels(greyhold, _seen_all(greyhold))
	assert_eq(_texts(labels, true), [Catalog.place_name("overworld"), Catalog.place_name("cellars")])
	assert_eq(_texts(labels, false), [], "Greyhold is the title's")
	var inn := Atlas.labels(MapData.load_by_id("town"), _seen_all(MapData.load_by_id("town")))
	assert_eq(_texts(inn, true), [Catalog.place_name("overworld")], "the town's doors into its rooms aren't ways out")


func test_labels_stay_on_the_page_and_clear_of_the_marks() -> void:
	var bounds := Vector2(672, 448)
	var size := Vector2(180, 18)
	for spot: Vector2 in [Vector2(3.5, 227), Vector2(661, 227), Vector2(339, 3), Vector2(115, 444), Vector2(339, 297), Vector2(10, 10)]:
		for way: bool in [true, false]:
			var at := Atlas.label_at(spot, size, bounds, way, 11.2)
			assert_true(Rect2(Vector2.ZERO, bounds).encloses(Rect2(at, size)), "%s on the page" % spot)
	var left := Atlas.label_at(Vector2(3.5, 227), size, bounds, true, 11.2)
	assert_gt(left.x, 3.5 + 11.2 / 2.0, "a way off the left edge named beside its door")
	var mark := Rect2(Vector2(339, 297), Vector2.ZERO).grow(8)
	var region := Atlas.label_at(Vector2(339, 297), size, bounds, false, 11.2, [mark])
	assert_false(Rect2(region, size).intersects(mark), "a region's name moves off a mark")
	var crowded: Array[Rect2] = [Rect2(Vector2.ZERO, bounds)]
	assert_eq(Atlas.label_at(Vector2(339, 297), size, bounds, false, 11.2, crowded), Atlas.NOWHERE, "or goes unsaid")


func test_the_village_is_drawn_small_in_its_walls() -> void:
	var overworld := MapData.load_by_id("overworld")
	var town := MapData.load_by_id("town")
	var village := Atlas.village(overworld, town, [])
	var block := Skyline.block(overworld.grid)
	assert_eq(village.size(), block.get_area(), "every cell of its block")
	assert_eq(village[Vector2i(48, 42)], "door", "its gate")
	for x in range(block.position.x, block.end.x):
		assert_true(village[Vector2i(x, block.end.y - 1)] in ["wall", "door"], "its rampart along the bottom")
	var roofs := village.values().filter(func(tile: String) -> bool: return tile.begins_with("roof"))
	assert_gt(roofs.size(), 20, "its houses")
	assert_ne(Atlas.color("roof_slate"), Atlas.color("roof"), "each in its roof's colour")
	assert_true(village.values().has("water"), "its river")
	assert_eq(Atlas.village(MapData.load_by_id("greyhold"), town, []), {}, "only where the village stands as a block")
