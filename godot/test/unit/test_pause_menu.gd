extends GutTest
## The pause menu's screens stand over it and hand back to it (PIX-427):
## Esc on Saves or Options goes back to the menu, never past it to play. A
## language chosen in Options rebuilds the world in it, and Options open
## again over the menu on the row they were left on (PIX-428). Runs against
## a throwaway user:// folder, with no hero in hand to save.

const PauseScreen := preload("res://scripts/pause_screen.gd")
const OptionsScreen := preload("res://scripts/options_screen.gd")
const TitleScreen := preload("res://scripts/title_screen.gd")
const DIR := "user://test_pause_menu"

var _kept: SaveSlots
var _kept_slot := 0
var _menu: Screen


func before_all() -> void:
	Controls.apply({})


func before_each() -> void:
	_kept = GameState.slots
	GameState.slots = SaveSlots.new(DIR, true)
	_kept_slot = GameState.slot
	GameState.slot = GameState.NO_SLOT


func after_each() -> void:
	if is_instance_valid(_menu):
		_menu.close()
	OptionsScreen.back_at = -1
	GameState.slots = _kept
	GameState.slot = _kept_slot
	await get_tree().process_frame
	get_tree().paused = false


func _pause() -> Screen:
	_menu = PauseScreen.new()
	add_child(_menu)
	return _menu


## The screen standing over the menu, or null.
func _over(menu: Screen) -> Screen:
	for child in menu.get_children():
		if child is Screen and not child.is_queued_for_deletion():
			return child
	return null


## A key as the player's lands: through the viewport, to whichever screen takes it.
func _key(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func test_esc_on_saves_or_options_goes_back_to_the_menu() -> void:
	for index: int in [1, 2]:
		var menu := _pause()
		menu.selected = index
		_key(&"interact")
		var screen := _over(menu)
		assert_not_null(screen, "%s opens over the menu" % menu.options[index]["label"])
		assert_true(screen.on_top(), "and takes the keys")
		assert_false(menu.keys.visible, "its keys stand in the menu's")
		assert_false(menu.card.visible, "and nothing of the menu shows round it")
		_key(&"ui_cancel")
		await wait_physics_frames(1)
		assert_true(is_instance_valid(menu) and menu.on_top(), "Esc on %s goes back to the menu" % menu.options[index]["label"])
		assert_null(_over(menu))
		assert_true(menu.keys.visible and menu.card.visible, "the menu shows again")
		assert_true(get_tree().paused, "the world still waits")
		menu.close()
		await wait_physics_frames(1)


## The keycaps under `root`, in order.
func _caps(root: Node) -> Array[String]:
	var out: Array[String] = []
	for node in root.find_children("*", "", true, false):
		if node is Keycap:
			out.append((node as Keycap).label.text)
	return out


## PIX-480: Journal rebound to W swaps Move up to Q, and the footer kept
## "W S choose" till Options were reopened. It names the new keys at once,
## after the swap back and a reset too, and so does the menu under it.
func test_the_footers_follow_a_rebind() -> void:
	var settings := GameState.settings
	var was_read_only := settings.read_only
	var was_bound := settings.bindings
	settings.read_only = true
	settings.bindings = {}
	var menu := _pause()
	assert_eq(_caps(menu.keys).slice(0, 2), ["W", "S"])
	menu.selected = 2
	_key(&"interact")
	var options := _over(menu)
	for step: Array in [["journal", KEY_W, "Q"], ["journal", KEY_Q, "W"], ["move_up", KEY_Q, "Q"]]:
		options.listening = step[0]
		var press := InputEventKey.new()
		press.physical_keycode = step[1]
		press.pressed = true
		options._input(press)
		assert_eq(_caps(options.footer).slice(0, 2), [step[2], "S"], "%s to %s" % [step[0], OS.get_keycode_string(step[1])])
		assert_true(options.footer.visible)
	options._reset_keys()
	assert_eq(_caps(options.footer).slice(0, 2), ["W", "S"], "the defaults again")
	settings.bindings = Controls.rebind({}, "journal", KEY_W)
	Controls.apply(settings.bindings)
	_key(&"ui_cancel")
	await wait_physics_frames(1)
	assert_eq(_caps(menu.keys).slice(0, 2), ["Q", "S"], "the menu's keys, as Options close")
	assert_true(menu.keys.visible)
	settings.bindings = was_bound
	settings.read_only = was_read_only
	Controls.apply({})


func test_playing_the_hero_in_hand_from_its_saves_resumes() -> void:
	var menu := _pause()
	menu._take(1)
	var saves := _over(menu)
	saves.on_play_current.call()
	assert_true(menu.is_queued_for_deletion(), "Continue on the hero in hand is Resume")


func test_a_language_chosen_in_options_opens_them_again_on_its_row() -> void:
	OptionsScreen.back_at = 7
	var menu := _pause()
	var options := _over(menu)
	assert_not_null(options, "Options open again over the rebuilt menu")
	assert_eq(options.get_script(), OptionsScreen)
	assert_eq(options.rows[options._choosable()[options.selected]]["label"], "Language", "on the row left")
	assert_eq(menu.selected, 2, "the menu's choice is Options")
	assert_true(options.on_top())
	assert_eq(OptionsScreen.back_at, -1, "once: the next Options open on their first row")


## The same from the title: the world rebuilt in the language opens on the
## title, and its _open puts Options over it again on that row.
func test_a_language_chosen_over_the_title_opens_options_again_there() -> void:
	OptionsScreen.back_at = 7
	_menu = TitleScreen.new()
	add_child(_menu)
	var options := _over(_menu)
	assert_not_null(options, "Options open again over the rebuilt title")
	assert_eq(options.get_script(), OptionsScreen)
	assert_eq(options.rows[options._choosable()[options.selected]]["label"], "Language", "on the row left")
	assert_eq(_menu.options[_menu.selected]["label"], "Options", "the title's choice is Options")
	assert_true(options.on_top())
	assert_eq(OptionsScreen.back_at, -1, "once")
