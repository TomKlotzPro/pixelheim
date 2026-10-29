extends GutTest
## Hero creation (PIX-228): the first night reads as a setting - its own
## card, its two states with the one in force marked, flipped by Tab, the
## pad's Y or a click - and Begin as the start: the one lit plank, on the
## row below, apart from it. The pad reaches every control, and the keys
## on screen are the device's. PIX-391: no look to pick, the hero shown as
## they start, the stats with icons and pips, the skills as chips.

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
	assert_eq(words.get_theme_color("font_color"), UiStyle.plank_ink(true), "its words lit")
	# Lit as focus() lights a plank: drawn here, or GegX's chosen one (PIX-385).
	var lit: Button = autofree(Button.new())
	UiStyle.focus(lit)
	assert_eq((screen.begin.get_theme_stylebox("normal") as StyleBoxTexture).texture, (lit.get_theme_stylebox("normal") as StyleBoxTexture).texture, "its plank lit")
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
	assert_eq(screen.skill_index, 1, "right reads the next skill")
	screen._command(_pad(JOY_BUTTON_DPAD_LEFT)).call()
	assert_eq(screen.skill_index, 0, "left the one before")
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


func _key(code: Key) -> InputEventKey:
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	return press


func _labels(root: Node) -> Array[String]:
	var out: Array[String] = []
	for node in root.find_children("*", "Label", true, false):
		out.append((node as Label).text)
	return out


## The stats' cells: the rows holding a tooltip.
func _stat_cells() -> Array:
	return screen.details.find_children("*", "HBoxContainer", true, false).filter(
		func(node: Control) -> bool: return node.tooltip_text != ""
	)


# PIX-391: Tom - "pointless to have heroes of different colours on the start
# menu when we all start in the same skin, and the stats look ugly like that".

## No look to pick: the one figure on the screen is the hero as a new hero
## of the role is drawn in play, and no role's card shows a figure.
func test_the_hero_shown_is_the_hero_who_starts() -> void:
	_open()
	assert_false("look" in screen, "no look to pick")
	var figures := screen.find_children("*", "AnimatedSprite2D", true, false)
	assert_eq(figures.size(), 1, "the one figure, on the hero's card")
	assert_true(screen.details.is_ancestor_of(figures[0]))
	for role_id: String in screen.ROLES:
		var started: Node = autofree(preload("res://scripts/state/game_state.gd").new())
		started.new_game("Robin", role_id)
		var spec: Dictionary = screen.starting_look(role_id)
		assert_eq(spec, started.upkeep.hero_art(), "%s as they start" % role_id)
		# A tinted blade makes an outfit of the plain clothes: its body says so.
		assert_eq(spec.get("body", spec["sheet"]), PunyArt.PLAIN, "%s in the same clothes as everyone" % role_id)
	assert_eq(screen.starting_look("ranger")["attack"], "bow", "the role's own weapon")


## Six stats, each an icon (or its short name without the paid art), pips
## lit against the roster's best, its number, and its name in the tooltip.
func test_each_stat_has_its_icon_pips_number_and_name() -> void:
	_open()
	screen._pick_role(screen.ROLES.find("warrior"))
	var cells := _stat_cells()
	assert_eq(cells.size(), 6, "six stats")
	assert_eq(cells[0].tooltip_text, "Health", "named in full")
	assert_eq(cells[1].tooltip_text, "Energy", "a warrior's pool is energy")
	assert_true(cells[2].tooltip_text.begins_with("Strength\n"), "with what it does")
	for cell: Control in cells:
		var art := cell.get_child(0)
		assert_true(art is TextureRect or art is Label, "an icon first, or its short name")
		if art is TextureRect:
			assert_not_null((art as TextureRect).texture, "icons.json names it and it's here")
		assert_eq(cell.get_child(1).get_child_count(), screen.PIPS)
	assert_eq((cells[0].get_child(2) as Label).text, "42", "the number")
	screen._pick_role(screen.ROLES.find("mage"))
	assert_eq(_stat_cells()[1].tooltip_text, "Mana", "a mage's is mana")
	# Each pool against its own kind's best: the most energy fills them all, though a mage has more mana.
	var best := ""
	for role: String in screen.ROLES:
		if Catalog.role(role)["resource"] != "mana" and (best == "" or int(Catalog.role(role)["baseStats"]["maxMp"]) > int(Catalog.role(best)["baseStats"]["maxMp"])):
			best = role
	screen._pick_role(screen.ROLES.find(best))
	var lit: Array = _stat_cells()[1].get_child(1).get_children().filter(func(pip: ColorRect) -> bool: return (pip.get_child(0) as ColorRect).color == UiStyle.BRASS)
	assert_eq(lit.size(), screen.PIPS, "the most energy lights every pip")


func test_pips_compare_with_the_rosters_best() -> void:
	var script := preload("res://scripts/create_screen.gd")
	assert_eq(script.lit_pips(10, 10), 10, "the best fills them all")
	assert_eq(script.lit_pips(5, 10), 5)
	assert_eq(script.lit_pips(34, 44), 8)
	assert_eq(script.lit_pips(1, 44), 1, "anything shows")
	assert_eq(script.lit_pips(0, 10), 0)


## The skills they start with as chips with their icons and names, the
## first read by default; PgUp/PgDn, the pad or a click read another, and a
## new role reads its first again.
func test_the_starting_skills_are_chips_and_one_is_read() -> void:
	_open()
	screen._pick_role(screen.ROLES.find("rogue"))
	var skills: Array = Catalog.role("rogue")["skills"]
	assert_eq(screen.skill_chips.size(), skills.size())
	assert_eq(screen.skill_index, 0, "the first by default")
	assert_has(_labels(screen.details), skills[0]["description"])
	screen._command(_key(KEY_PAGEDOWN)).call()
	assert_eq(screen.skill_index, 1)
	assert_has(_labels(screen.details), skills[1]["description"], "its words under the chips")
	assert_does_not_have(_labels(screen.details), skills[0]["description"])
	screen._command(_key(KEY_PAGEUP)).call()
	screen._command(_key(KEY_PAGEUP)).call()
	assert_eq(screen.skill_index, skills.size() - 1, "round from the first to the last")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.skill_chips[1].gui_input.emit(click)
	assert_eq(screen.skill_index, 1, "a click reads it")
	screen._command(_key(KEY_DOWN)).call()
	assert_eq(screen.skill_index, 0, "a new role reads its first")


## The name under the hero only once there is one (a red "..." stood there).
func test_no_stand_in_for_the_name() -> void:
	_open()
	assert_does_not_have(_labels(screen.details), "...")
	screen.name_field.text = "Robin"
	screen._refresh()
	assert_has(_labels(screen.details), "Robin")
