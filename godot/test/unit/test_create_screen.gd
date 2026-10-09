extends GutTest
## Hero creation (PIX-228): the first night reads as a setting - its own
## card, its two states with the one in force marked, flipped by Tab, the
## pad's Y or a click - and Begin as the start: the one lit plank, on the
## row below, apart from it. The pad reaches every control, and the keys
## on screen are the device's.

var screen: Node


func before_each() -> void:
	Controls.apply({})


func after_each() -> void:
	if is_instance_valid(screen):
		screen.close()
	screen = null
	Controls.pad = false
	# What a redraw cleared, and the screen itself, go at the frame's end.
	await get_tree().process_frame


func _open() -> Node:
	screen = preload("res://scripts/create_screen.gd").new()
	add_child(screen)
	return screen


func _shown(choice: PanelContainer) -> Color:
	return (choice.get_child(0) as Label).get_theme_color("font_color")


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var press := InputEventJoypadButton.new()
	press.button_index = button
	press.pressed = true
	return press


func _caps(root: Node) -> Array[String]:
	var out: Array[String] = []
	for node in root.find_children("*", "", true, false):
		if node is Keycap:
			out.append((node as Keycap).label.text)
	return out


func test_the_first_night_is_a_setting_with_its_state_marked() -> void:
	_open()
	assert_true(screen.play_night, "a new hero plays the first night unless told otherwise")
	assert_eq((screen.night_play.get_child(0) as Label).text, "Play")
	assert_eq((screen.night_skip.get_child(0) as Label).text, "Skip")
	assert_eq(_shown(screen.night_play), UiStyle.LAMP, "the state in force is marked")
	assert_eq(_shown(screen.night_skip), UiStyle.FADED)
	assert_eq(screen.night_play.get_parent(), screen.night_skip.get_parent(), "both states on one row")
	assert_ne(screen.night_play.get_parent(), screen.begin.get_parent(), "not beside Begin")


func test_tab_the_pads_y_and_a_click_flip_it() -> void:
	_open()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	screen._command(tab).call()
	assert_false(screen.play_night, "Tab skips it")
	assert_eq(_shown(screen.night_skip), UiStyle.LAMP, "and the mark moves")
	screen._command(_pad(JOY_BUTTON_Y)).call()
	assert_true(screen.play_night, "the pad's Y plays it")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.night_skip.gui_input.emit(click)
	assert_false(screen.play_night, "a click on Skip skips it")
	screen.night_skip.gui_input.emit(click)
	assert_false(screen.play_night, "a state is chosen, not toggled, by the mouse")
	screen.night_play.gui_input.emit(click)
	assert_true(screen.play_night)


func test_begin_is_the_one_lit_plank_and_waits_for_a_name() -> void:
	_open()
	var words := screen.begin.get_node("keyed").get_child(1) as Label
	assert_eq(words.text, "Begin the adventure")
	assert_eq(words.get_theme_color("font_color"), UiStyle.GOLD, "its words lit")
	assert_eq((screen.begin.get_theme_stylebox("normal") as StyleBoxTexture).texture, UiStyle.plank(true).texture, "its plank lit")
	assert_true(screen.begin.disabled, "no name, no hero")
	screen.name_field.text = "Robin"
	screen._refresh()
	assert_false(screen.begin.disabled)


func test_begin_stands_apart_from_the_first_night() -> void:
	_open()
	await get_tree().process_frame
	await get_tree().process_frame
	var night: Rect2 = screen.night_play.get_parent().get_parent().get_parent().get_global_rect()
	var start: Rect2 = screen.begin.get_global_rect()
	assert_false(night.intersects(start), "no plank on the setting's card")
	assert_gt(start.position.y, night.end.y, "on the row below it")


func test_the_pad_reaches_every_control() -> void:
	_open()
	screen._command(_pad(JOY_BUTTON_DPAD_DOWN)).call()
	assert_eq(screen.role_index, 1, "down picks the next role")
	screen._command(_pad(JOY_BUTTON_DPAD_UP)).call()
	assert_eq(screen.role_index, 0, "up the one before")
	screen._command(_pad(JOY_BUTTON_DPAD_RIGHT)).call()
	assert_eq(screen.look, wrapi(1, 0, PunyArt.looks(screen._role())), "right the next look")
	assert_eq(screen._command(_pad(JOY_BUTTON_A)).get_method(), &"_begin", "A begins")
	var back := _pad(JOY_BUTTON_B)
	assert_false(screen._command(back).is_valid(), "B is left to go back")
	assert_true(screen._closes_on(back))


func test_the_keys_shown_are_the_devices() -> void:
	_open()
	var caps := _caps(screen)
	assert_has(caps, "Tab", "the keyboard flips the first night with Tab")
	assert_has(caps, "Enter")
	assert_has(caps, "PgUp")
	screen.close()
	Controls.pad = true
	_open()
	caps = _caps(screen)
	assert_does_not_have(caps, "Tab", "a pad has no Tab")
	assert_does_not_have(caps, "PgUp")
	assert_has(caps, "Y", "the pad flips it with Y")
	assert_has(caps, "A", "and begins with A")
	assert_has(caps, "B")
