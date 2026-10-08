extends GutTest
## PunyProps stands Shade's Medieval Age props where the web's were (PIX-137).
## The plan is pure tile ids and feet, so it is checked here without the paid
## pack: which prop each web tile becomes, how big ones claim their cells,
## fences joined to their neighbours, and that every foot keeps the hero's
## position out of the cells it blocks, on every town tier.

const TIERS := ["town", "town@2", "town@3", "town@4"]
## The part of each blocked cell a foot must cover (see PunyProps).
const CORE := Rect2(4, 7, 8, 8)


## A grid from rows of letters.
func _grid(rows: Array) -> Dictionary:
	var names := {
		".": "grass", "=": "path", "W": "well", "L": "lamp", "S": "shrine", "b": "barrel",
		"c": "crate", "C": "counter", "#": "fence", "*": "flowers", "R": "roof",
	}
	var grid := {}
	for y in rows.size():
		for x in String(rows[y]).length():
			grid[Vector2i(x, y)] = names[rows[y][x]]
	return grid


func _only(plan: Dictionary) -> Dictionary:
	assert_eq(plan["props"].size(), 1)
	return plan["props"][0]


func test_a_well_in_the_paving_is_the_fountain() -> void:
	var fountain := _only(PunyProps.plan(_grid([
		"=====",
		"==W==",
		"=====",
		"=====",
	])))
	assert_eq(fountain["kind"], "fountain")
	assert_eq(fountain["cell"], Vector2i(2, 1))
	assert_eq(fountain["covers"], [Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 2), Vector2i(3, 2)], "a 2x2 basin")


func test_a_well_on_the_grass_is_the_roofed_well() -> void:
	var well := _only(PunyProps.plan(_grid([
		"....",
		"....",
		".W..",
	])))
	assert_eq(well["kind"], "well")
	assert_eq(well["tiles"], PunyProps.WELL)
	assert_eq(well["covers"], [Vector2i(1, 2), Vector2i(2, 2)], "only the base blocks: the roof overhangs")


func test_a_cramped_well_stays_one_cell() -> void:
	var well := _only(PunyProps.plan(_grid(["=W="])))
	assert_eq(well["tiles"], [[Vector2i.ZERO, PunyProps.SMALL_WELL]])
	assert_eq(well["covers"], [Vector2i(1, 0)])


func test_a_counter_and_its_crate_are_one_stall() -> void:
	var plan := PunyProps.plan(_grid(["Cc.Cb.C"]))
	var stalls: Array = plan["props"]
	assert_eq(stalls.size(), 3, "the crate and barrel joined their counters")
	assert_eq(stalls[0]["tiles"], [[Vector2i.ZERO, PunyProps.STALLS[0][0]], [Vector2i.RIGHT, PunyProps.STALLS[0][1]]])
	assert_eq(stalls[1]["tiles"][0][1], PunyProps.STALLS[1][0], "the next stall sells something else")
	assert_eq(stalls[2]["tiles"], [[Vector2i.ZERO, PunyProps.STALL_SINGLE]], "a lone counter")


func test_fences_join_their_neighbours() -> void:
	var tiles := {}
	for prop: Dictionary in PunyProps.plan(_grid([
		"###.",
		"#...",
		"###.",
	]))["props"]:
		tiles[prop["cell"]] = prop["tiles"][0][1]
	assert_eq(tiles[Vector2i(0, 0)], PunyProps.FENCE[6], "corner: east and south")
	assert_eq(tiles[Vector2i(1, 0)], PunyProps.FENCE[10], "a run")
	assert_eq(tiles[Vector2i(2, 0)], PunyProps.FENCE[8], "the run's end")
	assert_eq(tiles[Vector2i(0, 1)], PunyProps.FENCE[5], "upright")
	assert_eq(tiles[Vector2i(0, 2)], PunyProps.FENCE[3], "corner: north and east")


func test_flowers_lie_flat_and_never_block() -> void:
	var plan := PunyProps.plan(_grid(["*.*"]))
	assert_eq(plan["props"], [])
	assert_true(plan["flat"][Vector2i(0, 0)] in PunyProps.FLOWERS)
	assert_true(plan["drawn"].has(Vector2i(2, 0)), "the web's flowers are replaced")


func test_the_shrine_is_the_dungeon_sheets_stone_knight_and_blocks() -> void:
	var shrine := _only(PunyProps.plan(_grid([".S."])))
	assert_eq(shrine["sheet"], "dungeon")
	assert_eq(shrine["tiles"], [[Vector2i.ZERO, PunyProps.STATUE]])
	assert_true((shrine["foot"] as Rect2).has_area())


func test_treasure_shows_as_the_web_shows_it() -> void:
	assert_eq(PunyProps.treasure_tile("chest", false), PunyProps.CHEST)
	assert_eq(PunyProps.treasure_tile("chest", true), PunyProps.CHEST_OPEN)
	assert_eq(PunyProps.treasure_tile("glint", false), PunyProps.POUCH)
	assert_eq(PunyProps.treasure_tile("herb", false), PunyProps.HERB)
	assert_eq(PunyProps.treasure_tile("herb", true), -1, "picked: nothing left")


## The rule every foot keeps: each cell it blocks has its middle-bottom inside
## the foot, so the hero's position never ends up inside a blocked cell.
func test_every_foot_covers_the_core_of_each_cell_it_blocks_on_every_tier() -> void:
	for id: String in TIERS:
		var data := _load(id)
		var plan := PunyProps.plan(data.grid)
		assert_gt(plan["props"].size(), 10, id)
		for prop: Dictionary in plan["props"]:
			var foot: Rect2 = prop["foot"]
			var origin := Vector2(prop["cell"] * 16)
			for cell: Vector2i in prop["covers"]:
				var core := Rect2(Vector2(cell * 16) + CORE.position, CORE.size)
				assert_true(Rect2(origin + foot.position, foot.size).encloses(core), "%s %s at %s" % [id, prop["kind"], cell])


func test_the_grown_town_has_its_fountain_and_both_stalls() -> void:
	var kinds := {}
	for prop: Dictionary in PunyProps.plan(_load("town@4").grid)["props"]:
		kinds[prop["kind"]] = kinds.get(prop["kind"], 0) + 1
	assert_eq(kinds.get("fountain", 0), 1)
	assert_eq(kinds.get("well", 0), 1, "the old well by the square, roofed")
	assert_eq(kinds.get("stall", 0), 2)
	assert_eq(kinds.get("lamp", 0), 16, "the web's twelve and the grand avenue's four")


func test_covered_cells_stop_walkers() -> void:
	var data := _load("town@4")
	var fountain := Vector2i(31, 18)
	assert_true(data.is_walkable(fountain), "the web paves it")
	data.covered[fountain] = true
	assert_false(data.is_walkable(fountain), "the basin stands on it")


## A town as grown through an age ("town@3"), or any other map by id.
func _load(id: String) -> MapData:
	if id.begins_with("town@"):
		return MapData.load_tiered("town", Town.projects_through(int(id.get_slice("@", 1))), 1)
	return MapData.load_by_id(id)
