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
	# Every waypoint found; the square's post still unstaffed.
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
	assert_eq(screen.destination_id(), "undermountain_cave", "up from the first wraps to the last")
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
	assert_eq(screen.usable.size(), 5, "the square waits on its keeper")
	assert_false(screen.usable.any(func(waypoint: Dictionary) -> bool: return waypoint["id"] == "town_square"))
	screen.close()


func test_with_its_keeper_the_square_is_chosen_in_town() -> void:
	GameState.settlement.settlers.append("settler_wren")
	var opened := _open("town")
	var screen: Node = opened[0]
	assert_eq(screen.destination_id(), "town_square", "the waypoint where you are")
	assert_true(screen.painting.home)
	screen.close()
