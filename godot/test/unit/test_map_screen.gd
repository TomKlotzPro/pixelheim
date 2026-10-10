extends GutTest
## The map screen's waypoint list (PIX-241), driven as a player would: the
## arrows, the pad's D-pad and A, pointing and clicking. The choice is what
## the map shows - a waypoint elsewhere turns the page to its map - and what
## E or a click travels to. A stand-in world: GUT doesn't load world.gd.

const MapScreen := preload("res://scripts/map_screen.gd")

var _discovered := {}
var _settlers: Array[String] = []
var _worlds: Array[Node] = []


class StandIn extends Node2D:
	var map: MapData
	var player_cell := Vector2i(40, 30)
	var went := {}

	func load_map(map_id: String) -> MapData:
		return MapData.load_by_id(map_id)

	func travel_to(waypoint: Dictionary) -> void:
		went = waypoint


func before_each() -> void:
	Controls.apply({})
	_discovered = GameState.world.discovered.duplicate(true)
	_settlers = GameState.settlement.settlers.duplicate()
	GameState.settlement.settlers.clear()
	# Every waypoint found and nothing else; the square's post still unstaffed.
	GameState.world.discovered = {}
	for waypoint: Dictionary in Interactables.waypoints():
		Discovery.discover_around(GameState.world.discovered, MapData.load_by_id(waypoint["mapId"]), Waypoints.cell(waypoint))


func after_each() -> void:
	GameState.world.discovered = _discovered
	GameState.settlement.settlers.assign(_settlers)
	Controls.pad = false
	# The world goes with its screen, as in the game; what the screen let go
	# of goes at the frame's end.
	for world in _worlds:
		if is_instance_valid(world):
			world.queue_free()
	_worlds.clear()
	await wait_process_frames(2)
	get_tree().paused = false


func _open(map_id: String) -> Array:
	var world := StandIn.new()
	world.map = MapData.load_by_id(map_id)
	add_child(world)
	_worlds.append(world)
	# Screens stand on the world, as world.open_screen puts them.
	var screen: Node = MapScreen.new()
	screen.world = world
	world.add_child(screen)
	return [screen, world]


func _key(screen: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	screen._unhandled_input(event)


func _pad(screen: Node, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	screen._unhandled_input(event)


func _click(card: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	card.gui_input.emit(event)


func _staffed_card(screen: Node, index: int) -> Control:
	return screen.cards.filter(func(entry: Dictionary) -> bool: return entry["usable"])[index]["card"]


func test_in_town_the_map_opens_on_the_town_and_choosing_turns_the_page() -> void:
	var opened := _open("town")
	var screen: Node = opened[0]
	assert_eq(screen.destination_id(), "", "every waypoint is out on the Ashenreach: none chosen yet")
	assert_eq(screen.painting.map.id, "town", "the map opens on where you are")
	assert_null(screen.painting.tag, "nothing named")
	_key(screen, KEY_S)
	assert_eq(screen.destination_id(), "town_gate", "down takes the first")
	assert_eq(screen.painting.map.id, "overworld", "the page turns to where it leads")
	assert_eq(screen.title.text, Catalog.place_name("overworld"))
	assert_not_null(screen.painting.tag, "named on the map")
	assert_false(screen.painting.home, "the hero's mark stays on their own page")
	_key(screen, KEY_S)
	assert_eq(screen.destination_id(), "mountain_gate", "the ring moves with the choice")
	_key(screen, KEY_W)
	_key(screen, KEY_W)
	assert_eq(screen.destination_id(), "greyhold_keep", "up from the first wraps to the last, under the list's last place")
	assert_eq(screen.painting.map.id, "overworld", "on the Reach's page (PIX-269)")
	assert_true(screen.painting.holds("greyhold"), "Greyhold drawn on it")
	assert_eq(screen.title.text, Catalog.place_name("overworld"))
	screen.close()


func test_e_shows_the_first_before_it_travels() -> void:
	var opened := _open("town")
	var screen: Node = opened[0]
	var world: StandIn = opened[1]
	_key(screen, KEY_E)
	assert_eq(screen.destination_id(), "town_gate", "E with nothing chosen chooses")
	assert_true(world.went.is_empty(), "and goes nowhere yet")
	_key(screen, KEY_E)
	assert_eq(world.went.get("id", ""), "town_gate", "the second E travels to what the map shows")


func test_on_the_ashenreach_the_first_waypoint_is_chosen_as_before() -> void:
	var opened := _open("overworld")
	var screen: Node = opened[0]
	assert_eq(screen.destination_id(), "town_gate")
	assert_true(screen.painting.home, "its own page, the hero on it")
	screen.close()


func test_the_pad_chooses_and_a_travels() -> void:
	var opened := _open("overworld")
	var screen: Node = opened[0]
	var world: StandIn = opened[1]
	_pad(screen, JOY_BUTTON_DPAD_DOWN)
	_pad(screen, JOY_BUTTON_DPAD_DOWN)
	assert_eq(screen.destination_id(), "deepwood_pass")
	_pad(screen, JOY_BUTTON_DPAD_UP)
	assert_eq(screen.destination_id(), "mountain_gate")
	_pad(screen, JOY_BUTTON_A)
	assert_eq(world.went.get("id", ""), "mountain_gate")


func test_pointing_chooses_and_a_click_travels() -> void:
	var opened := _open("overworld")
	var screen: Node = opened[0]
	var world: StandIn = opened[1]
	var mirefen := _staffed_card(screen, 3)
	mirefen.mouse_entered.emit()
	assert_eq(screen.destination_id(), "mirefen_pass", "pointing at a card chooses it")
	var tag: Control = screen.painting.tag
	assert_true(Rect2(Vector2.ZERO, screen.painting.custom_minimum_size).encloses(Rect2(tag.position, tag.size)), "its tag kept on the map at the edge")
	_click(_staffed_card(screen, 1))
	assert_eq(screen.destination_id(), "mountain_gate", "a tap on another card (no pointer) chooses it first")
	assert_true(world.went.is_empty())
	_click(_staffed_card(screen, 1))
	assert_eq(world.went.get("id", ""), "mountain_gate", "a click on the chosen card travels")


func test_an_unstaffed_post_is_never_chosen() -> void:
	var opened := _open("town")
	var screen: Node = opened[0]
	assert_eq(screen.usable.size(), Interactables.waypoints().size() - 1, "the square waits on its keeper")
	assert_eq(screen.cards.size(), Interactables.waypoints().size(), "but it's listed, greyed")
	assert_false(screen.usable.any(func(waypoint: Dictionary) -> bool: return waypoint["id"] == "town_square"))
	screen.close()


func test_with_its_keeper_the_square_is_chosen_in_town() -> void:
	GameState.settlement.settlers.append("settler_wren")
	var opened := _open("town")
	var screen: Node = opened[0]
	assert_eq(screen.destination_id(), "town_square", "the waypoint where you are")
	assert_true(screen.painting.home)
	screen.close()


## The words under a card's name.
func _note(card: Control) -> String:
	var lines: Node = card.get_child(0)
	return (lines.get_child(1) as Label).text if lines.get_child_count() > 1 else ""


func test_every_map_found_is_a_page_and_each_is_drawn() -> void:
	# The caves found too: each a page of its own.
	for cave: String in ["seacave", "cellars"]:
		Discovery.discover_around(GameState.world.discovered, MapData.load_by_id(cave), MapData.load_by_id(cave).spawn)
	var opened := _open("town")
	var screen: Node = opened[0]
	var found: Array[String] = ["overworld", "town", "seacave", "cellars"]
	assert_eq(screen.pages, found, "the Reach's page, then the village and the caves, in the world's order")
	var drawn := {}
	for turn in found.size():
		var page: String = screen.page_id()
		var painting: Control = screen.painting
		assert_eq(painting.map.id, page, "the page turned to is the one drawn")
		assert_eq(screen.title.text, Catalog.place_name(page), "and named")
		assert_eq(painting.custom_minimum_size, Vector2(painting.cells * painting.tile_px), "%s drawn whole" % page)
		assert_between(painting.tile_px, 3 if page == Atlas.REACH else 7, Atlas.MAX_TILE, "%s at a size to read" % page)
		assert_false(painting._ground.is_empty(), "%s: what's been seen of it drawn" % page)
		drawn[page] = true
		_key(screen, KEY_D)
	assert_eq(drawn.size(), found.size(), "every page drawn")
	assert_eq(screen.page_id(), "town", "and round to where the hero stands")
	screen.close()


func test_turning_the_page_chooses_the_first_waypoint_there() -> void:
	var opened := _open("town")
	var screen: Node = opened[0]
	assert_eq(screen.page_id(), "town")
	_key(screen, KEY_D)
	assert_eq(screen.page_id(), "overworld", "round to the Reach's page")
	assert_eq(screen.destination_id(), "town_gate", "its first waypoint chosen")
	assert_not_null(screen.painting.tag, "named on its page")
	_key(screen, KEY_A)
	assert_eq(screen.page_id(), "town")
	assert_eq(screen.destination_id(), "", "none open in town: none chosen")
	screen.close()


func test_the_reach_and_its_regions_are_one_page() -> void:
	Atlas.walk_all(GameState.world.discovered)
	var opened := _open("saltmere")
	var screen: Node = opened[0]
	var world: StandIn = opened[1]
	var painting: Control = screen.painting
	assert_eq(screen.page_id(), "overworld", "Saltmere opens the Reach's page")
	assert_eq(screen.title.text, Catalog.place_name("overworld"))
	assert_eq(screen.destination_id(), "saltmere_hamlet", "on the waypoint where the hero is")
	assert_eq(painting.sheets.size(), ReachPlane.maps().size(), "the Ashenreach and its six regions")
	var village: Dictionary = painting.village
	for sheet: Dictionary in painting.sheets:
		var map: MapData = sheet["map"]
		var at: Vector2i = sheet["at"]
		assert_eq(at - painting.at_of("overworld"), ReachPlane.origin(map.id), "%s at its place in the plane" % map.id)
		var wrong := 0
		for cell: Vector2i in map.grid:
			if not village.has(cell + at) and painting._ground.get(cell + at) != Atlas.color(map.grid[cell]):
				wrong += 1
		assert_eq(wrong, 0, "every cell of %s drawn where it lies on the page" % map.id)
	# The hero's mark and the marks on the maps, each at its map's offset.
	assert_true(painting.home, "the hero is on this page")
	assert_eq(painting.hero_cell(), world.player_cell + painting.at_of("saltmere"))
	assert_eq(painting.destination_cell(), Waypoints.cell(screen.usable[screen.selected]) + painting.at_of("saltmere"))
	var on_page: Array = painting._waypoints().map(func(entry: Dictionary) -> String: return entry["waypoint"]["id"])
	for waypoint: Dictionary in Interactables.waypoints():
		assert_eq(waypoint["id"] in on_page, ReachPlane.holds(waypoint["mapId"]), "%s on the page if its map is" % waypoint["id"])
	screen.close()


func test_fast_travel_from_the_reachs_page_lands_where_it_did() -> void:
	var opened := _open("overworld")
	var screen: Node = opened[0]
	var world: StandIn = opened[1]
	for id: String in ["saltmere_hamlet", "greyhold_keep"]:
		screen.show_waypoint(id)
		assert_eq(screen.destination_id(), id)
		assert_eq(screen.page_id(), "overworld", "%s chosen on the same page: no page turned" % id)
	var keep: Dictionary = screen.usable[screen.selected]
	_key(screen, KEY_E)
	assert_eq(world.went.get("id", ""), "greyhold_keep", "E travels to the one ringed")
	assert_eq(Waypoints.landing(world.went), Waypoints.landing(keep), "and sets the hero down where it always did")
	assert_eq(world.went["mapId"], "greyhold", "on its own map's cells")


func test_waypoints_not_found_yet_are_listed_greyed_where_they_stand() -> void:
	# A hero who has only seen the town around the hall.
	GameState.world.discovered = {}
	Discovery.discover_around(GameState.world.discovered, MapData.load_by_id("town"), Vector2i(40, 22))
	var opened := _open("town")
	var screen: Node = opened[0]
	assert_eq(screen.cards.size(), Interactables.waypoints().size(), "every waypoint listed")
	assert_true(screen.usable.is_empty(), "none of them open yet")
	assert_eq(screen.pages, ["town"] as Array[String], "the town the only map found")
	assert_eq(_note(screen.cards[0]["card"]), Text.t("Not found yet"), "the gate not found yet")
	assert_true(screen.painting.shows_closed(), "the square's post greyed on the town's page")
	var down := InputEventKey.new()
	down.physical_keycode = KEY_S
	down.keycode = KEY_S
	down.pressed = true
	assert_true(screen._command(down).is_valid(), "with nothing to choose, down reads down the list")
	assert_eq(screen.destination_id(), "", "and chooses nothing")
	screen.close()


func test_the_list_and_the_tag_name_where_you_land_alike() -> void:
	var opened := _open("overworld")
	var screen: Node = opened[0]
	_key(screen, KEY_S)
	assert_eq(screen.destination_id(), "mountain_gate")
	var card: Control = _staffed_card(screen, screen.selected)
	var tag_lines: Node = screen.painting.tag.get_child(0)
	assert_eq(_note(card), Atlas.region_title("ash"), "the card says where you land, not the Ashenreach again")
	assert_eq((tag_lines.get_child(1) as Label).text, _note(card), "and the tag says the same")
	assert_eq(screen.cards[0]["heading"].text, Catalog.place_name("overworld"), "the place heads its waypoints")
	# On a map that is one region, the place is the region: said once.
	_key(screen, KEY_W)
	_key(screen, KEY_W)
	assert_eq(screen.destination_id(), "greyhold_keep")
	assert_eq(_note(_staffed_card(screen, screen.selected)), "", "not Greyhold under Greyhold")
	assert_eq(screen.painting.tag.get_child(0).get_child_count(), 1, "nor on its tag")
	screen.close()


func test_the_ashenreach_draws_the_village_small_in_its_walls() -> void:
	var opened := _open("overworld")
	var screen: Node = opened[0]
	var village: Dictionary = screen.painting.village
	# In the page's cells: the regions found lie round the Ashenreach.
	var at: Vector2i = screen.painting.at_of("overworld")
	assert_eq(village.get(Vector2i(48, 42) + at, ""), "door", "its gate where the road comes in")
	assert_eq(village.get(Vector2i(36, 42) + at, ""), "wall", "its rampart")
	assert_true(village.values().any(func(tile: String) -> bool: return tile.begins_with("roof")), "its houses")
	assert_true(village.values().has("water"), "its river")
	assert_eq(screen.painting._ground.get(Vector2i(50, 50) + at), Atlas.color(village[Vector2i(50, 50) + at]), "drawn though only the road to its gate was walked")
	screen.close()
