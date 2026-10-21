extends GutTest
## The ledgers read in the world (PIX-338, Tom's playtest: « ça ressemble
## pas à un registre »): Captain Hale's order book was a pair of jugs on his
## table, under the prompt. Each lies open on a table now, drawn in code
## (RoomArt) with the paid pack and without it: Hale's beside his map under
## his dagger, the village's in the hall by its rolled plans (E there opens
## it), Mirelle's on her counting table by the hall with her coin stacks and
## strongbox (E there opens her bank). And the prompt stands over what it's
## for, never on it.

## The order book's table in Hale's hall, and the village's in the hall.
const HALE := ["keep", "captain_table", "open_book+map_dagger"]
const HALL := ["town_hall", "ledger_desk", "open_book+plans"]

var _withheld := false


func before_each() -> void:
	_withheld = PunyTown.withheld


func after_each() -> void:
	PunyTown.withheld = _withheld


func test_each_ledger_lies_open_on_its_table_with_or_without_the_pack() -> void:
	for ledger: Array in [HALE, HALL]:
		var map := MapData.load_tiered(ledger[0], [], 1)
		var table := PunyInterior.placed(ledger[0], ledger[1])
		assert_true(table.has_area(), "%s has its %s" % ledger.slice(0, 2))
		var reserved := PunyInterior.reserved(map, [])
		var paid := PunyInterior.furnish(ledger[0], map.grid, reserved)
		assert_does_not_have(paid["skipped"], ledger[1], "%s: its table fits" % ledger[0])
		# Laid over the table's top, a cell under the candle's row in the keep.
		var found: Variant = paid["art"].find_key(ledger[2])
		assert_not_null(found, "%s: the book over the table" % ledger[0])
		if found == null:
			continue
		var at: Vector2i = found
		assert_true(table.has_point(at), "%s: on its table" % ledger[0])
		assert_has(paid["tops"].values(), 588, "%s: its candle, to read it by at night" % ledger[0])
		var free := PunyInterior.furnish_free(ledger[0], map.grid, reserved)
		assert_eq(free["objects"].get(at, ""), "r:desk+" + ledger[2], "%s: the same on a table drawn in code" % ledger[0])
		assert_has(free["flames"], Vector2(at * MapView.TILE) + PunyInterior.FREE_FLAMES["r:desk"], "%s: and its candle" % ledger[0])
		assert_true(RoomArt.has("desk+" + ledger[2]))
		assert_eq(RoomArt.texture("desk+" + ledger[2]).get_size(), Vector2(32, 32))
	var keep: Dictionary = PunyInterior.interiors()["vignettes"]["captain_table"]
	assert_false(keep["tops"].any(func(top: Array) -> bool: return int(top[2]) == 2340), "the jugs that stood for the book are gone")


func test_the_ledger_is_a_book_open_at_two_ruled_pages() -> void:
	var book: Array = RoomArt.PIECES["open_book"]
	var pages := 0
	var ruled := 0
	for row: String in book:
		pages += row.count("B")
		if row.count("D") >= 16:
			ruled += 1
	assert_gt(pages, 60, "white pages")
	assert_gte(ruled, 4, "lines ruled across both pages")
	assert_true(book.any(func(row: String) -> bool: return "R" in row), "a ribbon")
	assert_true(book.any(func(row: String) -> bool: return "y" in row), "a quill's feather")


func test_mirelles_table_stands_by_the_hall_below_her() -> void:
	var desk := Town.bank_desk()
	assert_eq(desk.size, Vector2i(1, 2), "a cell wide, two long")
	var mirelle := Npcs.by_id("settler_mirelle", ["settler_mirelle"])
	assert_eq(Vector2i(int(mirelle["x"]), int(mirelle["y"])), desk.position + Vector2i.UP, "she stands at its head")
	# Open ground at every age she can come home in, the City's flower beds
	# round it.
	var recruit: Dictionary = Npcs._data()["recruits"].filter(func(entry: Dictionary) -> bool: return entry["id"] == "settler_mirelle")[0]
	for tier in range(int(recruit["minTownTier"]), Town.ages().size() + 1):
		var town := MapData.load_tiered("town", Town.projects_through(tier), 1)
		for y in range(desk.position.y, desk.end.y):
			assert_true(town.is_walkable(Vector2i(desk.position.x, y)), "age %d: %s" % [tier, Vector2i(desk.position.x, y)])
	assert_eq(RoomArt.cells("bank_desk"), desk.size)


func test_the_prompt_never_hides_what_its_for() -> void:
	var cap := UiStyle.world_keycap("Shift")
	add_child_autofree(cap)
	cap.reset_size()
	var size := cap.size
	assert_gt(size.y, 0.0)
	# Hale's order book: E reads it from any of the table's cells (chair and
	# stools too), and the prompt stands over the book drawn on it.
	var hale := Letters.reading_rect(Letters.reading("hale_order_book"))
	for pack: bool in [false, true]:
		PunyTown.withheld = not pack
		if pack and not PunyTown.available():
			continue
		var book := _view(HALE[0]).drawn_in(hale)
		assert_true(book.has_area(), "the book on Hale's table, the pack %s" % pack)
		var drawn: String = HALE[2] if pack else "desk+" + HALE[2]
		_assert_clear(_cells(hale), book, _drawn(drawn, Vector2i(book.position) / MapView.TILE), size, drawn)
	# The village's on its table.
	var desk := PunyInterior.placed(HALL[0], HALL[1])
	for drawn: String in [HALL[2], "desk+" + HALL[2]]:
		_assert_clear(_cells(desk), _pixels(desk), _drawn(drawn, desk.position), size, drawn)
	# Mirelle's: the prompt over her at its head, as when she's spoken to.
	var bank := Town.bank_desk()
	_assert_clear(_cells(bank), _pixels(bank.grow_side(SIDE_TOP, 1)), _drawn("bank_desk", bank.position), size, "bank_desk")
	# Anything a cell big (a chest, the stairs down) is clear of its cell.
	var cell := Vector2i(5, 5)
	_assert_clear([cell], _pixels(Rect2i(cell, Vector2i.ONE)), _pixels(Rect2i(cell, Vector2i.ONE)), size, "a cell")


## The prompt, `size` big, over `target` (pixels) faced from each of
## `faced`: clear of the pixels `sprite` covers, bobbed a pixel down too.
func _assert_clear(faced: Array, target: Rect2, sprite: Rect2, size: Vector2, what: String) -> void:
	assert_true(target.encloses(sprite), "%s: drawn inside what the prompt stands over" % what)
	for cell: Vector2i in faced:
		var prompt := Rect2(Interaction.prompt_spot(target, cell, size) + Vector2(0, 1), size)
		assert_false(prompt.intersects(sprite), "%s: the prompt %s faced at %s clear of it %s" % [what, prompt, cell, sprite])


func _pixels(cells: Rect2i) -> Rect2:
	return Rect2(Vector2(cells.position * MapView.TILE), Vector2(cells.size * MapView.TILE))


## `map_id` drawn as a door draws it, in the tree.
func _view(map_id: String) -> MapView:
	var map := MapData.load_tiered(map_id, [], 1)
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	return view


## The pixels `name` is drawn in, its top left on `cell`.
func _drawn(name: String, cell: Vector2i) -> Rect2:
	var used := RoomArt.texture(name).get_image().get_used_rect()
	return Rect2(Vector2(cell * MapView.TILE + used.position), Vector2(used.size))


func _cells(rect: Rect2i) -> Array:
	var out := []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out
