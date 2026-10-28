extends GutTest
## Pixelheim's yards and square by its age (PIX-382): every piece stands
## where it's placed at every age, clear of every villager, path, door and
## spot the story uses, never closing a way; each age is richer than the
## last and keeps what the one before had; nothing without the paid pack.

const Hamlets := preload("res://test/unit/test_hamlet.gd")


## The town at `age` as MapView plans it: its houses (their cells roof,
## what they leave open grass), its props' feet covered, and its yards
## laid: {map, kept, grown, built, planned}.
static func _town(age: int) -> Dictionary:
	var map := MapData.load_tiered("town", Town.projects_through(age), 1)
	var built := PunyTown.plan(map.grid)
	for cell: Vector2i in built["pieces"]:
		if not String(map.grid[cell]).begins_with("door"):
			map.grid[cell] = "roof"
	for cell: Vector2i in built["freed"]:
		map.grid[cell] = "grass"
	for prop: Dictionary in PunyProps.plan(map.grid)["props"]:
		if (prop["foot"] as Rect2).has_area():
			for cell: Vector2i in prop["covers"]:
				map.covered[cell] = true
	var kept := Hamlet.kept_on(map)
	kept.merge(Yards.kept(map))
	var grown := Yards.plan(map, built["pieces"], age, true)
	return {"map": map, "kept": kept, "grown": grown, "built": built, "planned": Hamlet.plan(map, kept, grown)}


func test_every_piece_stands_where_it_is_placed_at_every_age() -> void:
	for age in Town.MAX_TIER + 1:
		var town := _town(age)
		assert_eq(town["planned"]["pieces"].size(), town["grown"].size(), "age %d: no piece left out" % age)


func test_each_age_is_richer_and_keeps_the_last() -> void:
	var before := {}
	var count := -1
	for age in Town.MAX_TIER + 1:
		var cells := {}
		for piece: Dictionary in _town(age)["planned"]["pieces"]:
			cells[piece["cell"]] = true
		assert_gt(cells.size(), count, "age %d is richer than the one before" % age)
		for cell: Vector2i in before:
			assert_true(cells.has(cell), "age %d keeps %s" % [age, cell])
		before = cells
		count = cells.size()
	assert_eq(_town(0)["planned"]["pieces"].size(), 0, "the Ashes are bare")


func test_nothing_stands_in_anyone_s_way() -> void:
	for age in Town.MAX_TIER + 1:
		var town := _town(age)
		var map: MapData = town["map"]
		for cell: Vector2i in town["planned"]["blocks"]:
			assert_false(town["kept"].has(cell), "age %d: %s keeps clear of villagers, boards and the post" % [age, cell])
			assert_does_not_have(Hamlet.WAYS, map.tile_at(cell), "age %d: %s off the paths and the square" % [age, cell])
			assert_false(map.tile_at(cell + Vector2i.UP).begins_with("door"), "age %d: %s is no door's step" % [age, cell])
		var reached := Hamlets._reach(map, map.spawn)
		for cell: Vector2i in town["planned"]["blocks"]:
			map.covered[cell] = true
		var after := Hamlets._reach(map, map.spawn)
		for cell: Vector2i in reached:
			if cell not in town["planned"]["blocks"]:
				assert_true(after.has(cell), "age %d: %s still reached from the spawn" % [age, cell])


func test_every_window_is_in_flower_in_the_city() -> void:
	var windows := {}
	var city := _town(Town.MAX_TIER)
	for cell: Vector2i in city["built"]["pieces"]:
		if city["built"]["pieces"][cell] == PunyTown.WINDOW:
			windows[cell] = true
	assert_gt(windows.size(), 10, "the town has windows")
	var boxed := Yards.window_boxes(city["built"]["pieces"], Town.MAX_TIER)
	assert_eq(boxed.size(), windows.size(), "every window in flower in the City")
	assert_lt(Yards.window_boxes(city["built"]["pieces"], 1).size(), windows.size() / 2, "a few in the Hamlet")


func test_a_piece_by_a_house_waits_for_the_house() -> void:
	# In the Ashes only the hall stands: nothing by the ruins.
	var ashes := MapData.load_tiered("town", [], 1)
	for entry: Dictionary in Yards.plan(ashes, {}, Town.MAX_TIER, true):
		assert_eq(entry.get("by", Yards.HALL), Yards.HALL, "%s waits for its house" % entry["cell"])


func test_nothing_without_the_pack() -> void:
	var city := _town(Town.MAX_TIER)
	assert_eq(Yards.plan(city["map"], city["built"]["pieces"], Town.MAX_TIER, false).size(), 0)


func test_every_piece_is_drawn() -> void:
	for piece: Dictionary in _town(Town.MAX_TIER)["planned"]["pieces"]:
		if piece.has("tile"):
			assert_between(int(piece["tile"]), 0, PunyTown.COLUMNS * 132 - 1, "%s: a tile of the pack" % piece["cell"])
		elif piece.get("art", "") == "bunting":
			var drawn := HamletArt.bunting(int(piece["line"]))
			assert_eq((drawn["day"] as Texture2D).get_width(), (int(piece["line"]) + 1) * MapView.TILE, "from lamp to lamp")
			assert_gt(drawn["lights"].size(), 0, "its lanterns")
		elif piece.has("art"):
			for row: String in HamletArt.rows_of(piece["art"]):
				for ink in row:
					assert_true(ink == "." or HamletArt.INKS.has(ink), "%s: %s in Shade's inks" % [piece["art"], ink])
