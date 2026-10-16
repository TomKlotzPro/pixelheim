extends GutTest
## Rooms without the paid pack (PIX-318). MapView's rooms needed the
## Medieval Age pack: without it (a fork, a build without the private art)
## the inn, the hall, the keep, the observatory and every other room drew no
## walls, floor or stairwell, and the hero stood on grass. Now each is drawn
## from Shade's CC0 sheets in the repository (PunyInterior.plan_free and
## furnish_free): walls, floor, door, the stair down, windows with the day
## in them, a hearth's fire and its sconces, by the rules the pack's rooms
## keep; with the pack, nothing changes. PunyTown.withheld holds the pack
## back here even where it's installed, as the harness's `cc0` does.

const ROOMS := {
	"town_inn": ["town_inn", 1], "town_shop": ["town_shop", 1], "town_smith": ["town_smith", 1],
	"town_alchemist": ["town_alchemist", 1], "town_hall": ["town_hall", 1],
	"town_house": ["town_house", 1], "town_house@2": ["town_house", 2], "town_house@3": ["town_house", 3],
	"observatory": ["observatory", 1], "keep": ["keep", 1], "morvax_forge": ["morvax_forge", 1],
}
## How many tiles each of Shade's free sheets holds (columns x rows).
const DUNGEON_TILES := 26 * 20
const WORLD_TILES := 27 * 65

var _saved := {}


func before_each() -> void:
	_saved = {"withheld": PunyTown.withheld, "steps": GameState.world.steps}
	PunyTown.withheld = true


func after_each() -> void:
	PunyTown.withheld = _saved["withheld"]
	GameState.world.steps = _saved["steps"]


func _map(key: String) -> MapData:
	var room: Array = ROOMS[key]
	return MapData.load_tiered(room[0], [], int(room[1]))


## `map` drawn as a door draws it, in the tree.
func _view(map: MapData) -> MapView:
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	return view


func test_the_pack_can_be_held_back() -> void:
	assert_false(PunyTown.available(), "withheld, the pack is as good as missing")
	assert_false(PunyProps.available())
	PunyTown.withheld = false
	assert_eq(PunyTown.available(), ResourceLoader.exists(PunyTown.SHEET), "otherwise it's there when its sheet is")


func test_every_room_has_walls_a_floor_and_its_door() -> void:
	for key: String in ROOMS:
		var map := _map(key)
		var room := PunyInterior.plan_free(map.id, map.grid)
		assert_true(room["free"], key)
		assert_gt(room["walls"].size(), 10, "%s is walled" % key)
		assert_gt(room["windows"].size(), 0, "%s has windows for the day" % key)
		for cell: Vector2i in map.grid:
			var tile: String = map.grid[cell]
			if tile != "wall":
				assert_true(room["floor"].has(cell), "%s: floor under %s at %s" % [key, tile, cell])
			if tile == "door":
				assert_eq(room["pieces"].get(cell, ""), PunyInterior.FREE_DOOR, "%s: the door at %s" % [key, cell])
			if tile == "stairwell":
				assert_eq(room["pieces"].get(cell, ""), PunyInterior.FREE_STAIRWELL, "%s: the way down at %s" % [key, cell])
			# The walls touching the room are drawn, the rest is the dark.
			if tile == "wall":
				assert_ne(room["walls"].has(cell), room["void"].has(cell), "%s: %s is wall or dark" % [key, cell])
		for cell: Vector2i in room["windows"]:
			assert_true(room["walls"].has(cell), "%s: a window in the wall" % key)
			assert_ne(map.grid.get(cell + Vector2i.DOWN, "wall"), "wall", "%s: the day falls into the room below %s" % [key, cell])


func test_the_way_down_is_drawn_where_the_rooms_have_one() -> void:
	for key: String in ["observatory", "keep"]:
		var map := _map(key)
		var room := PunyInterior.plan_free(map.id, map.grid)
		var stairs: Array = room["pieces"].keys().filter(func(cell: Vector2i) -> bool: return room["pieces"][cell] == PunyInterior.FREE_STAIRWELL)
		assert_eq(stairs.size(), 1, "%s has its stair down" % key)
		var stair: Vector2i = stairs[0]
		assert_eq(room["rug"].size(), 8, "%s: a rug laid round it" % key)
		assert_eq(room["rug"].get(stair + Vector2i(-1, -1), ""), "a:rug_0", "its corner")
		assert_eq(room["rug"].get(stair + Vector2i(1, 1), ""), "a:rug_8", "its other corner")


func test_every_piece_is_shades_free_art_or_drawn_in_code() -> void:
	for key: String in ROOMS:
		var map := _map(key)
		var room := PunyInterior.plan_free(map.id, map.grid)
		var dressed := PunyInterior.furnish_free(map.id + map.variant, map.grid, PunyInterior.reserved(map, []))
		var pieces: Array = []
		for part: String in ["floor", "walls", "rug", "pieces"]:
			pieces.append_array(room[part].values())
		pieces.append_array(dressed["rug"].values())
		pieces.append_array(dressed["objects"].values())
		pieces.append(PunyInterior.FREE_WINDOW)
		for piece: String in pieces:
			var where := PunyInterior.free_piece(piece)
			match String(where[0]):
				"d":
					assert_between(int(where[1]), 0, DUNGEON_TILES - 1, "%s: %s on the Puny Dungeon sheet" % [key, piece])
				"w":
					assert_between(int(where[1]), 0, WORLD_TILES - 1, "%s: %s on the Puny World sheet" % [key, piece])
				"a":
					assert_has(DungeonArt.PIECES, where[1], "%s: %s is DungeonArt's" % [key, piece])
				"h":
					assert_true(HamletArt.PIECES.has(where[1]), "%s: %s is HamletArt's" % [key, piece])
				"r":
					assert_true(RoomArt.PIECES.has(where[1]), "%s: %s is RoomArt's" % [key, piece])
				_:
					fail_test("%s: %s is on no free sheet" % [key, piece])
	for name: String in PunyInterior.FREE_VIGNETTES:
		assert_true(PunyInterior.interiors()["vignettes"].has(name), "%s stands for one of the pack's corners" % name)


func test_the_dressing_leaves_the_room_walkable() -> void:
	for key: String in ROOMS:
		var map := _map(key)
		var dressed := PunyInterior.furnish_free(map.id + map.variant, map.grid, PunyInterior.reserved(map, []))
		assert_gt(dressed["objects"].size(), 0, "%s has something in it" % key)
		var floor := map.grid.values().filter(func(tile: String) -> bool: return tile == "floor").size()
		for cell: Vector2i in dressed["blocked"]:
			map.grid[cell] = "wall"
		var door: Vector2i = map.portals.keys()[0]
		var seen := {door + Vector2i.UP: true}
		var queue: Array[Vector2i] = [door + Vector2i.UP]
		while not queue.is_empty():
			var at: Vector2i = queue.pop_front()
			for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = at + side
				if not seen.has(next) and map.is_walkable(next):
					seen[next] = true
					queue.append(next)
		assert_true(seen.has(map.spawn), "%s: the spawn" % key)
		assert_gt(seen.size(), floor / 2, "%s keeps its floor" % key)


func test_a_room_is_drawn_and_lit_without_the_pack() -> void:
	GameState.world.steps = 0.2 * DayNight.DAY_CYCLE_STEPS
	var view := _view(_map("town_inn"))
	var drawn := view.room_drawn()
	assert_eq(drawn["art"], "free")
	assert_gt(drawn["walls"], 0)
	assert_gt(drawn["floor"], 0)
	var windows: Array = view.buildings["windows"]
	assert_gt(windows.size(), 0)
	assert_eq(view.beams.size(), windows.size(), "the day in through every window")
	assert_eq(view.day_glows.size(), windows.size(), "every window's recess full of the sky")
	for pane: Sprite2D in view.day_glows:
		assert_eq(pane.texture, LampArt.recess_panes())
		assert_true(pane.visible, "by day")
	assert_gt(view.flames.size(), 0, "the inn's sconce")
	for flame: Node2D in view.flames:
		assert_false(flame.visible, "out by day")
		assert_true(flame.get_meta("light") is PointLight2D, "each warms the floor round it")
	view.set_night(true)
	for pane: Node2D in view.day_glows:
		assert_false(pane.visible, "no day in the recess at night")
	for flame: Node2D in view.flames:
		assert_true(flame.visible, "lit at night")


func test_lianes_stair_keeps_its_frost() -> void:
	var view := _view(_map("observatory"))
	assert_eq(view.room_drawn()["stairs"], 1, "the stair down to the ice cave")
	var frosted := 0
	for node: Node in view.ground.get_children():
		if node is TileMapLayer and node.material is ShaderMaterial and (node.material as ShaderMaterial).shader == preload("res://shaders/stair_frost.gdshader"):
			frosted += 1
	# The boards and the stair's stone, the rugs, the stair and the door.
	assert_eq(frosted, 4, "the frost over the floor, the rugs and the stair")


func test_with_the_pack_nothing_changes() -> void:
	PunyTown.withheld = false
	if not PunyTown.available():
		pass_test("the pack's rooms need Shade's paid pack (scripts/fetch-private-art.sh)")
		return
	var map := _map("town_inn")
	var view := _view(map)
	assert_eq(view.room_drawn()["art"], "paid")
	assert_false(view.buildings.has("free"))
	var room := PunyInterior.plan(map.id, MapData.load_tiered("town_inn", [], 1).grid)
	assert_eq(view.buildings["walls"], room["walls"], "the pack's walls and windows")
	assert_eq(view.buildings["floor"], room["floor"], "the pack's floor")
