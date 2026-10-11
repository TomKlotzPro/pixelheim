extends GutTest
## Lamps that read as lamps, windows that glow like windows, and rooms with
## character (PIX-311, PIX-315). By day a street lamp was Shade's cold wall
## torch, a dark speck that read as a bug on the road; at night a lit window
## was a round orb on the wall and a lamp's halo a filled disc; rooms were
## lit flat, their rugs flat teal, the dark round them twinkling, and
## Liane's observatory a bedroom. Now: a post with its lantern drawn in
## Shade's palette, its glass alone lit at night; a window's own glass lit
## and its light thrown on the ground below it; a room's day through its
## windows and its candles at night; patterned rugs; a telescope, a chart
## of the sky and a globe of it in the observatory.

## The rug bands of the Medieval Age atlas that are a plain colour, by their
## first row (each four rows, columns 119 to 130): green, red, teal.
const PLAIN_RUG_ROWS := [24, 36, 48]
const RUG_COLUMNS := Vector2i(119, 130)
## The rooms and their furnished layouts (interiors.json's keys).
const ROOMS := {
	"town_inn": ["town_inn", 1], "town_shop": ["town_shop", 1], "town_smith": ["town_smith", 1],
	"town_alchemist": ["town_alchemist", 1], "town_hall": ["town_hall", 1],
	"town_house": ["town_house", 1], "town_house@2": ["town_house", 2], "town_house@3": ["town_house", 3],
	"observatory": ["observatory", 1], "keep": ["keep", 1], "morvax_forge": ["morvax_forge", 1],
}

var _saved := {}


func before_each() -> void:
	_saved = {
		"steps": GameState.world.steps,
		"prologue": GameState.progression.prologue,
		"tier": GameState.settlement.town_tier,
		"projects": GameState.settlement.projects.duplicate(),
	}


func after_each() -> void:
	GameState.world.steps = _saved["steps"]
	GameState.progression.prologue = _saved["prologue"]
	GameState.settlement.town_tier = _saved["tier"]
	GameState.settlement.projects.assign(_saved["projects"])


## Each cell of `rows` that isn't clear.
static func _drawn(rows: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in rows.size():
		for x in String(rows[y]).length():
			if String(rows[y])[x] != ".":
				out.append(Vector2i(x, y))
	return out


func test_a_lamp_is_a_post_with_its_lantern() -> void:
	var size := LampArt.size()
	assert_eq(size, Vector2i(16, 32), "a cell wide, two tall: taller than the hero, standing in its cell")
	for row: String in LampArt.POST:
		assert_eq(row.length(), size.x)
		for key in row:
			assert_true(key == "." or LampArt.PALETTE.has(key), "%s is in Shade's palette" % key)
	# What stands on the ground is inside the foot the hero is stopped by.
	var pixels := _drawn(LampArt.POST)
	var bottom := pixels.map(func(at: Vector2i) -> int: return at.y).max() as int
	for at: Vector2i in pixels:
		if at.y == bottom:
			assert_between(at.x, int(PunyProps.LAMP_FOOT.position.x), int(PunyProps.LAMP_FOOT.end.x) - 1, "its foot at x %d" % at.x)
	assert_eq(bottom, size.y - 2, "on the ground: the post's foot on its cell's bottom")
	assert_eq(LampArt.post().get_size(), Vector2(size))


func test_only_the_lanterns_glass_lights_up() -> void:
	var glass := Rect2i(LampArt.GLASS_AT, Vector2i(4, LampArt.LIT[0].size()))
	assert_true(Rect2(glass).has_point(LampArt.HALO_AT), "the halo round the glass")
	var frames := LampArt.glass()
	assert_eq(frames.get_frame_count("default"), LampArt.LIT.size(), "the flame's beats")
	for i in frames.get_frame_count("default"):
		var image := frames.get_frame_texture("default", i).get_image()
		assert_eq(image.get_size(), LampArt.size(), "laid over the post")
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.0:
					assert_true(glass.has_point(Vector2i(x, y)), "beat %d lights (%d, %d), on the glass" % [i, x, y])
	# The post's glass is cold glass by day: no flame drawn into it.
	for y in range(glass.position.y, glass.end.y):
		for x in range(glass.position.x, glass.end.x):
			assert_false(String(LampArt.POST[y])[x] in ["y", "Y", "a", "r"], "cold at (%d, %d)" % [x, y])


func test_a_camp_torch_stands_on_a_stake() -> void:
	var pixels := _drawn(LampArt.STAKE)
	assert_eq(LampArt.stake().get_size(), Vector2(16, 16))
	var top := pixels.map(func(at: Vector2i) -> int: return at.y).min() as int
	assert_lte(top, 16 - LampArt.STAKE_LIFT - 2, "it reaches up to the raised torch's handle")
	for at: Vector2i in pixels:
		assert_between(at.x, 2, 13, "inside its cell")


func test_a_windows_light_falls_on_the_ground_below_it() -> void:
	for shape: Texture2D in [Lights.spill(), Lights.shaft()]:
		assert_eq(shape.get_size(), Vector2(Lights.TEXTURE_PX, Lights.TEXTURE_PX), "a light's texture, so its reach is counted as every light's")
	var spill := Lights.spill().get_image()
	var half := Lights.TEXTURE_PX / 2
	var below := spill.get_pixel(half, half + half / 4).a
	var far := spill.get_pixel(half, Lights.TEXTURE_PX - 4).a
	var beside := spill.get_pixel(Lights.TEXTURE_PX / 16, half + half / 4).a
	var above := spill.get_pixel(half, half / 3).a
	assert_gt(below, 0.3, "bright on the ground just below the window")
	assert_lt(far, below / 4.0, "fading as it goes")
	assert_lt(beside, 0.05, "the window's width, not a ball of light round it")
	assert_lt(above, 0.05, "not up over the roof")
	# The day through a room's window slants down the floor as it goes.
	var shaft := Lights.shaft().get_image()
	var row := half + half / 2
	var weight := 0.0
	var sum := 0.0
	for x in Lights.TEXTURE_PX:
		weight += shaft.get_pixel(x, row).a
		sum += shaft.get_pixel(x, row).a * x
	assert_gt(sum / weight, half + 8.0, "leaning away from the sun")
	assert_eq(shaft.get_pixel(half, half / 2).a, 0.0, "nothing up the wall")


func test_the_day_through_a_window_follows_the_sky() -> void:
	var sun := Lights.daylight(Vector2.ZERO, 64.0, Lights.SUN, Lights.SUN_ENERGY, Lights.shaft())
	autofree(sun)
	assert_true(sun.get_meta("by_day", false), "the rig brings it up by day")
	assert_true(sun.is_in_group("lights"))
	assert_eq(sun.texture, Lights.shaft())
	assert_gt(Lights.darkness(Lights.INDOOR_DAY), 0.1, "a room by day a little dim, so the day pools in it")
	assert_gt(Lights.darkness(Lights.INDOOR_NIGHT), 0.85, "and dark at night but for its candles")


func test_every_room_has_a_patterned_rug() -> void:
	var families: Dictionary = PunyInterior.interiors()["rugFamilies"]
	for room_key: String in ROOMS:
		var rugs: Array = PunyInterior.interiors()["rooms"][room_key].get("rugs", [])
		assert_gt(rugs.size(), 0, "%s has a rug" % room_key)
		for rug: Array in rugs:
			assert_true(families.has(rug[0]), "%s: %s is a rug" % [room_key, rug[0]])
	for family: String in families:
		for tile: int in families[family]:
			var row := tile / PunyTown.COLUMNS
			var column := tile % PunyTown.COLUMNS
			assert_between(column, RUG_COLUMNS.x, RUG_COLUMNS.y, "%s is a rug tile" % family)
			for plain: int in PLAIN_RUG_ROWS:
				assert_false(row >= plain and row < plain + 4, "%s: tile %d is one of the plain bands" % [family, tile])


func test_lianes_observatory_keeps_the_stars() -> void:
	var map := MapData.load_tiered("observatory", [], 1)
	var dressed := PunyInterior.furnish("observatory", map.grid, PunyInterior.reserved(map, []))
	assert_eq(dressed["skipped"], [], "every piece fits")
	var art: Dictionary = dressed["art"]
	for piece: String in ["telescope", "star_chart", "star_globe"]:
		assert_true(art.values().has(piece), "the %s" % piece)
	for cell: Vector2i in art:
		var big := RoomArt.cells(art[cell])
		for dy in big.y:
			for dx in big.x:
				var at: Vector2i = cell + Vector2i(dx, dy)
				if art[cell] == "star_chart":
					assert_eq(map.grid[at], "wall", "the chart hangs on the back wall")
				else:
					assert_has(dressed["blocked"], at, "the %s stands in the way at %s" % [art[cell], at])


func test_pieces_drawn_in_code_take_whole_cells_in_shades_palette() -> void:
	for piece: String in RoomArt.PIECES:
		var rows: Array = RoomArt.PIECES[piece]
		var size := Vector2i(String(rows[0]).length(), rows.size())
		assert_eq(size.x % 16, 0, piece)
		assert_eq(size.y % 16, 0, piece)
		assert_eq(RoomArt.cells(piece), size / 16, piece)
		for row: String in rows:
			assert_eq(row.length(), size.x, piece)
			for key in row:
				assert_true(key == "." or LampArt.PALETTE.has(key), "%s: %s is in Shade's palette" % [piece, key])
		assert_eq(RoomArt.texture(piece).get_size(), Vector2(size))


func test_a_rooms_dust_floats_over_its_floor() -> void:
	var map := MapData.load_tiered("observatory", [], 1)
	var floor := Motes.room_rect(map)
	assert_eq(floor, Rect2(32, 32, 256, 144), "the room's cells, door row and all, not the dark round them")
	for cell: Vector2i in map.grid:
		var inside := floor.has_point(Vector2(cell * MapView.TILE) + Vector2.ONE * 8.0)
		if map.grid[cell] != "wall":
			assert_true(inside, "%s" % cell)
	assert_eq(Motes.room_rect(MapData.new()), Rect2(), "nothing over no room")


## `map_id` drawn as a door draws it, in the tree.
func _view(map: MapData) -> MapView:
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	return view


func test_a_rooms_windows_and_candles() -> void:
	if not PunyTown.available():
		pass_test("no rooms without Shade's paid pack (scripts/fetch-private-art.sh)")
		return
	GameState.world.steps = 0.2 * DayNight.DAY_CYCLE_STEPS
	var view := _view(MapData.load_tiered("town_inn", [], 1))
	var windows: Array = view.buildings["walls"].values().filter(func(tile: int) -> bool: return tile == PunyTown.WINDOW)
	assert_gt(windows.size(), 0)
	assert_eq(view.beams.size(), windows.size(), "the day in through every window")
	assert_eq(view.day_glows.size(), windows.size(), "every window's glass full of the sky")
	assert_gt(view.flames.size(), 0, "the inn's candles")
	for flame: Node2D in view.flames:
		assert_false(flame.visible, "out by day")
		assert_true(flame.get_meta("light") is PointLight2D, "each warms the floor round it")
	view.set_night(true)
	for pane: Node2D in view.day_glows:
		assert_false(pane.visible, "no day in the glass at night")
	for flame: Node2D in view.flames:
		assert_true(flame.visible, "lit at night")


func test_a_lit_window_is_its_glass_not_an_orb() -> void:
	if not PunyTown.available():
		pass_test("no houses without Shade's paid pack (scripts/fetch-private-art.sh)")
		return
	GameState.world.steps = 0.75 * DayNight.DAY_CYCLE_STEPS
	GameState.progression.prologue = Prologue.DONE
	GameState.settlement.town_tier = Town.MAX_TIER
	GameState.settlement.projects.assign(Town.projects_through(Town.MAX_TIER))
	var view := _view(MapData.load_tiered("town", Town.projects_through(Town.MAX_TIER), 1))
	var windows: Array = view.buildings["pieces"].keys().filter(func(cell: Vector2i) -> bool: return view.buildings["pieces"][cell] == PunyTown.WINDOW)
	assert_gt(windows.size(), 0)
	assert_eq(view.panes.size(), windows.size(), "every window's glass lit")
	for pane: Sprite2D in view.panes:
		assert_eq(pane.texture, LampArt.panes(), "the window's own glass, lit")
		assert_true(windows.has(Vector2i(pane.position / MapView.TILE)), "over its window")
		var light: PointLight2D = pane.get_meta("light")
		assert_eq(light.texture, Lights.spill(), "its light thrown on the ground below it")
		assert_gt(light.position.y, pane.position.y + MapView.TILE - 1.0, "from the foot of the wall")
	assert_eq(view.lamps.size(), view.outdoor_props["props"].filter(func(prop: Dictionary) -> bool: return prop["kind"] == "lamp").size(), "every lamp a post")
	for lamp: Dictionary in view.lamps:
		assert_eq((lamp["unlit"] as Sprite2D).texture, LampArt.post())
