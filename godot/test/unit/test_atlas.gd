extends GutTest
## The map screen's pages (PIX-266): every map found is a page, in the
## world's order; each is drawn whole at a size to read; the waypoints are
## listed by the place they stand in; a page names its regions over what's
## been seen of them and its ways to other places once their doors are seen;
## the village is drawn small in its walls on the Ashenreach.


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
	Discovery.discover_around(discovered, MapData.load_by_id("overworld"), Vector2i(48, 40))
	assert_eq(Atlas.pages(discovered, "town"), ["overworld", "town", "greyhold"] as Array[String], "the hero's map is a page, found or not")
	assert_eq(Atlas.pages(discovered, "town_inn"), ["town_inn", "overworld", "greyhold"] as Array[String], "a room comes first")
	assert_true(Atlas.found(discovered, "greyhold"))
	assert_false(Atlas.found(discovered, "frostgate"))
	for map_id: String in Atlas.ORDER:
		assert_true(FileAccess.file_exists("res://assets/maps/%s.json" % map_id), "%s is a map" % map_id)


func test_the_pages_turn_round() -> void:
	var pages: Array[String] = ["overworld", "town", "greyhold"]
	assert_eq(Atlas.turn(pages, "town", 1), "greyhold")
	assert_eq(Atlas.turn(pages, "greyhold", 1), "overworld", "round from the last to the first")
	assert_eq(Atlas.turn(pages, "overworld", -1), "greyhold", "and back")
	assert_eq(Atlas.turn(pages, "frostgate", 1), "overworld", "from nowhere, the first")


func test_every_page_is_drawn_at_a_size_to_read() -> void:
	for map_id: String in Atlas.ORDER:
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
