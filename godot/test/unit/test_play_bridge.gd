extends GutTest
## The bridge tools/play.py plays through (PIX-423): a command's keys held
## as the game's actions for its time and let go, the game's clock spent by
## that time alone, the answer written and the page frozen; under the game's
## own pause too, never touching it; a key Godot doesn't know plays nothing;
## and the words read off a screen are the ones a player sees.

const Bridge := preload("res://scripts/play_bridge.gd")


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
	assert_eq(out, PackedStringArray(["Hello", "Typ", "OK"]))
	root.free()
