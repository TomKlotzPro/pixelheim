extends GutTest
## The bridge tools/play.py plays through (PIX-423): a command's keys held
## as the game's actions for its time and let go, the game's clock spent by
## that time alone, the answer written and the page frozen; under the game's
## own pause too, never touching it; not before a harness run's steps are
## done; a key Godot doesn't know plays nothing; a name field takes letters
## and Backspace; and the words read off a screen are the ones a player
## sees, the chosen row's apart.

const Bridge := preload("res://scripts/play_bridge.gd")
const Harness := preload("res://scripts/harness.gd")


## window.pixelheimPlay's stand-in.
class Page:
	var command: Variant = null
	var state: Variant = null
	var frozen := false


var page: Page


func before_each() -> void:
	Controls.apply({})
	page = Page.new()
	var bridge: Node = add_child_autofree(Bridge.new())
	bridge.page = page


func after_each() -> void:
	Harness.stepping = false
	get_tree().paused = false
	Input.action_release("move_right")


## The bridge's answer once it has frozen the page, counted in the tree's
## ticks, which go on under a pause (GUT's own waits stop with the tree).
func _answer() -> Dictionary:
	for _tick in 300:
		if page.frozen:
			break
		await get_tree().physics_frame
	assert_true(page.frozen, "answered")
	return JSON.parse_string(page.state)


func test_a_hold_presses_its_action_for_its_time_then_freezes() -> void:
	var from := GameClock.seconds()
	page.command = JSON.stringify([{"keys": ["Right"], "seconds": 0.5}])
	await wait_physics_frames(5)
	assert_null(page.command, "the command is taken")
	assert_true(Input.is_action_pressed("move_right"), "held as the keyboard's right arrow is")
	assert_false(page.frozen, "the game runs during the command")
	var said: Dictionary = await _answer()
	assert_false(Input.is_action_pressed("move_right"), "let go")
	assert_almost_eq(float(said["seconds"]) - from, 0.5 + Bridge.AFTER_TICKS / 60.0, 0.06, "the game's time is the command's")
	for field: String in ["level", "hp", "maxHp", "mana", "gold", "hour", "paused"]:
		assert_true(said.has(field), field)
	assert_false(said.has("error"))


func test_a_harness_run_answers_once_its_steps_are_done() -> void:
	Harness.stepping = true
	page.command = JSON.stringify([{"keys": [], "seconds": 0.1}])
	await wait_physics_frames(5)
	assert_not_null(page.command, "not taken while the presets' steps go on")
	Harness.stepping = false
	await _answer()


func test_it_runs_under_the_games_own_pause_and_leaves_it() -> void:
	get_tree().paused = true
	page.command = JSON.stringify([{"keys": [], "seconds": 0.2}])
	var said: Dictionary = await _answer()
	assert_true(said["paused"], "the game's pause, as it was")
	assert_true(get_tree().paused, "never lifted by the bridge")


func test_a_key_godot_does_not_know_plays_nothing() -> void:
	var from := GameClock.seconds()
	page.command = JSON.stringify([{"keys": ["Right"], "seconds": 2}, {"keys": ["jump"], "seconds": null}])
	var said: Dictionary = await _answer()
	assert_eq(said.get("error"), "no key named jump")
	assert_lt(float(said["seconds"]) - from, 0.2, "nothing was held")
	page.frozen = false
	page.command = "{}"
	said = await _answer()
	assert_eq(said.get("error"), "not a list of steps")


## PIX-435: the newcomer's `e` stayed in the hero's name ("eTom"), as the
## harness's keys matched none of Godot's ui_text_* actions.
func test_a_name_typed_and_backspaced() -> void:
	var field := LineEdit.new()
	add_child_autofree(field)
	field.grab_focus()
	for typed: Array in [[["e", "T", "o", "m", "backspace"], "eTo"], [["home", "delete"], "To"], [["end", "left", "backspace"], "o"]]:
		page.frozen = false
		page.command = JSON.stringify(typed[0].map(func(key: String) -> Dictionary: return {"keys": [key], "seconds": null}))
		await _answer()
		assert_eq(field.text, typed[1], str(typed[0]))


## PIX-435: the chosen row's words, as UiStyle draws it - a plank lit, or a
## row in the gold rim - and none when nothing is chosen.
func test_the_chosen_ones_words() -> void:
	var root := VBoxContainer.new()
	var rows: Array[PanelContainer] = []
	for words: Array in [["Glow", "On"], ["Sound", "Off"]]:
		var row := PanelContainer.new()
		var line := HBoxContainer.new()
		for word: String in words:
			var label := Label.new()
			label.text = word
			line.add_child(label)
		row.add_child(line)
		root.add_child(row)
		rows.append(row)
	assert_eq(Bridge.chosen(root), PackedStringArray(), "nothing chosen")
	rows[1].add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.LAMP))
	assert_eq(Bridge.chosen(root), PackedStringArray(["Sound", "Off"]))
	rows[0].add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM))
	var plank := Button.new()
	plank.text = "Saves"
	root.add_child(plank)
	UiStyle.focus(plank)
	rows[1].visible = false
	assert_eq(Bridge.chosen(root), PackedStringArray(["Saves"]), "the lit plank, the hidden row passed over")
	UiStyle.focus(plank, false)
	assert_eq(Bridge.chosen(root), PackedStringArray())
	root.free()


func test_the_words_are_those_shown_and_not_a_screen_under_it() -> void:
	var root := VBoxContainer.new()
	for text: String in ["Hello", "Hidden", "Faded", "Typing"]:
		var label := Label.new()
		label.text = text
		root.add_child(label)
	root.get_child(1).visible = false
	root.get_child(2).modulate.a = 0.0
	root.get_child(3).visible_characters = 3
	var button := Button.new()
	button.text = "OK"
	root.add_child(button)
	var inside := Screen.new()
	var under := Label.new()
	under.text = "Another screen's"
	inside.add_child(under)
	root.add_child(inside)
	var out: PackedStringArray = []
	Bridge.words(root, out)
	assert_eq(out, PackedStringArray(["Hello", "Typ [still typing]", "OK"]))
	# As drawn: a French player's title plank says "Nouvelle partie".
	button.text = "New Game"
	Text.apply("fr")
	out.clear()
	Bridge.words(button, out)
	Text.apply("en")
	assert_eq(out, PackedStringArray(["Nouvelle partie"]))
	root.free()
