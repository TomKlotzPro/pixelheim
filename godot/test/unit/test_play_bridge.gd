extends GutTest
## The bridge tools/play.py plays through (PIX-423): a command's keys held
## as the game's actions for its time and let go, the game's clock spent by
## that time alone, the answer written and the page frozen; under the game's
## own pause too, never touching it; not before a harness run's steps are
## done; a key Godot doesn't know plays nothing; a name field takes letters
## and Backspace; the words read off a screen are the ones a player sees,
## the chosen ones' apart; and the folk and doors near are listed. PIX-485:
## a foe's wind-up by its name, ailments on the hero and each foe, the state
## read after the tick's own work, a fade waited out or said, and `played`
## counting no paused tick.

const Bridge := preload("res://scripts/play_bridge.gd")


## window.pixelheimPlay's stand-in.
class Page:
	var command: Variant = null
	var state: Variant = null
	var frozen := false


var page: Page
var bridge: Node


func before_each() -> void:
	Controls.apply({})
	page = Page.new()
	bridge = add_child_autofree(Bridge.new())
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
	assert_eq(said.get("error"), "no key named jump (keys are named as e, enter, pgdn; a word is typed a letter a key, as A,r,i,a)")
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


## PIX-468: a name with capitals, a letter a key or under Shift; a whole
## word is no key, so it types nothing and the answer says how to type one.
func test_a_name_typed_with_capitals() -> void:
	var field := LineEdit.new()
	add_child_autofree(field)
	field.grab_focus()
	page.command = JSON.stringify([["A"], ["r"], ["shift", "i"], ["a"]].map(func(keys: Array) -> Dictionary: return {"keys": keys, "seconds": null}))
	await _answer()
	assert_eq(field.text, "ArIa")
	page.frozen = false
	page.command = JSON.stringify([{"keys": ["Aria"], "seconds": null}])
	var said: Dictionary = await _answer()
	assert_string_contains(said.get("error", ""), "no key named Aria")
	assert_eq(field.text, "ArIa", "nothing typed")


## The chosen ones' words under `node`, one list apiece.
func _chosen(node: Node) -> Array:
	var out := []
	Bridge.chosen(node, out)
	return out


## PIX-435: the chosen ones' words, as UiStyle draws them - a plank lit, a
## row in the gold rim, a lit tab before the chosen row (the pack's and the
## counter's: `focus` said only "All") - and none when nothing is chosen.
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
	assert_eq(_chosen(root), [], "nothing chosen")
	rows[1].add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.LAMP))
	assert_eq(_chosen(root), [PackedStringArray(["Sound", "Off"])])
	var tab := Button.new()
	tab.text = "All"
	root.add_child(tab)
	root.move_child(tab, 0)
	UiStyle.tab_button(tab, true)
	assert_eq(_chosen(root), [PackedStringArray(["All"]), PackedStringArray(["Sound", "Off"])], "the lit tab, then the chosen row")
	UiStyle.tab_button(tab, false)
	rows[0].add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM))
	var plank := Button.new()
	plank.text = "Saves"
	root.add_child(plank)
	UiStyle.focus(plank)
	rows[1].visible = false
	assert_eq(_chosen(root), [PackedStringArray(["Saves"])], "the lit plank, the hidden row passed over")
	UiStyle.focus(plank, false)
	assert_eq(_chosen(root), [])
	root.free()


## The world as state() reads it: its HUD, its map, the hero and their cell.
class FakeWorld extends "res://test/bare_world.gd":
	func _init() -> void:
		map = MapData.new()
		player_cell = Vector2i(10, 10)


## A foe as state() reads one, its brain and its trick too.
class FakeFighter extends Node2D:
	var ailments := Ailments.new()
	var fighter := {}
	var dying := false
	var mode := "chase"
	var guarding := false
	var aim_left := -1.0
	var tell_left := -1.0
	var trick: FakeBrain
	var brain: FakeBrain


class FakeBrain extends Node:
	var state := ""
	var telling := ""


## A world of fakes as the scene, its HUD bare; _leave() puts the scene back.
func _enter() -> FakeWorld:
	var world := FakeWorld.new()
	world.hud = autofree(Hud.new())
	world.hud.root = CanvasLayer.new()
	world.add_child(world.hud.root)
	world.hud.objective_label = autofree(Label.new())
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	return world


func _leave(world: FakeWorld) -> void:
	get_tree().current_scene = null
	world.free()


## PIX-485 (a fighter spent a dozen looks telling a glow from a chase): a
## wind-up by its name, where the enemy's own mode says "chase" or "cast".
func test_a_foes_mode_names_its_wind_up() -> void:
	var foe: FakeFighter = autofree(FakeFighter.new())
	assert_eq(Bridge.mode_of(foe), "chase")
	foe.tell_left = 0.2
	assert_eq(Bridge.mode_of(foe), "bite", "a bite told")
	foe.aim_left = 0.4
	assert_eq(Bridge.mode_of(foe), "aim", "a shooter's glow")
	foe.guarding = true
	assert_eq(Bridge.mode_of(foe), "guard", "an undead elite's guard")
	foe.brain = autofree(FakeBrain.new())
	foe.brain.telling = "cleave"
	assert_eq(Bridge.mode_of(foe), "guard", "a move told a while ago is no cast")
	foe.mode = "cast"
	assert_eq(Bridge.mode_of(foe), "cleave", "an elite's band")
	foe.trick = autofree(FakeBrain.new())
	for named: Array in [["crouch", "crouch"], ["in", "dart"], ["shimmer", "shimmer"], ["gone", "faded"], ["raise", "raise"], ["up", "guard"]]:
		foe.trick.state = named[0]
		assert_eq(Bridge.mode_of(foe), named[1], "a trick's " + named[0])
	foe.mode = "flee"
	assert_eq(Bridge.mode_of(foe), "flee", "any other mode is the enemy's own")
	# The brains' own word for it: what an elite and a boss last told.
	for brain: String in ["elite_brain", "boss_brain"]:
		assert_eq(autofree(load("res://scripts/%s.gd" % brain).new()).telling, "", brain)


## PIX-485 (the hero's poison was read off hp ticks): the ailments on the
## hero and on each foe, and the foe's wind-up, in the state itself.
func test_ailments_on_the_hero_and_each_foe() -> void:
	var world := _enter()
	world.player = preload("res://test/bare_hero.gd").new()
	world.add_child(world.player)
	world.player.ailments.effects.append({"kind": "poison", "turnsLeft": 3, "power": 1})
	var wolf := FakeFighter.new()
	wolf.fighter = Bestiary.spawn("wolf")
	wolf.position = MapView.center(Vector2i(12, 10))
	wolf.ailments.stun_for(1)
	wolf.ailments.effects.append({"kind": "burn", "turnsLeft": 2, "power": 1})
	wolf.trick = FakeBrain.new()
	wolf.trick.state = "crouch"
	wolf.add_child(wolf.trick)
	wolf.add_to_group("mobs")
	world.add_child(wolf)
	var said: Dictionary = bridge.state()
	_leave(world)
	assert_eq(said["ailments"], ["poison"])
	assert_eq(said["foes"].size(), 1)
	assert_eq(said["foes"][0]["ailments"], ["stun", "burn"])
	assert_eq(said["foes"][0]["mode"], "crouch")


## What a tick does to the game's numbers, as a blow that lands in it does.
class Earner extends Node:
	func _physics_process(_delta: float) -> void:
		GameState.pack.gold = Engine.get_physics_frames()


## PIX-485: the picture showed the orc dead and gold 44, the state hp 11 and
## gold 30 - the state was read as a tick began, before the blow it held.
func test_the_state_is_read_after_the_ticks_own_work() -> void:
	var kept: int = GameState.pack.gold
	add_child_autofree(Earner.new())
	page.command = JSON.stringify([{"keys": [], "seconds": 0.1}])
	var said: Dictionary = await _answer()
	GameState.pack.gold = kept
	assert_eq(int(said["gold"]), roundi(float(said["seconds"]) * 60) + GameClock.origin, "the gold of the tick the clock says")


## PIX-485 (Enter on Begin answered mid-reload and the next key was lost):
## a fade is waited out; one that outlasts the wait is said.
func test_a_fade_is_waited_out_or_said() -> void:
	var world := _enter()
	var dark := ColorRect.new()
	dark.set_meta("fade", true)
	world.hud.root.add_child(dark)
	page.command = JSON.stringify([{"keys": [], "seconds": 0.05}])
	await wait_physics_frames(30)
	assert_false(page.frozen, "no answer while the dark is up")
	dark.free()
	var said: Dictionary = await _answer()
	assert_false(said["fading"], "answered once it has gone")
	# A screen that asked for a reload takes nothing more till the world is new.
	var leaving := Screen.new()
	world.add_child(leaving)
	leaving.process_mode = Node.PROCESS_MODE_DISABLED
	bridge.settle_ticks = 10
	page.frozen = false
	page.command = JSON.stringify([{"keys": [], "seconds": 0.05}])
	said = await _answer()
	assert_true(said["fading"], "a fade that outlasts the wait is said, not hung on")
	# The title back after a reload, its veil still lifting.
	leaving.process_mode = Node.PROCESS_MODE_ALWAYS
	assert_false(bridge.fading())
	var veil := ColorRect.new()
	veil.set_meta("fade", true)
	leaving.add_child(veil)
	assert_true(bridge.fading(), "a screen's own veil")
	# No scene at all, after a world: the gap of a reload.
	_leave(world)
	assert_true(bridge.fading())
	assert_false(add_child_autofree(Bridge.new()).fading(), "but nothing to wait for where no world ever stood")


## PIX-485 (`seconds` moved 2 s with the codex open): `played` counts the
## ticks in play, none while a screen pauses the tree.
func test_played_counts_no_paused_tick() -> void:
	page.command = JSON.stringify([{"keys": [], "seconds": 0.2}])
	var before: Dictionary = await _answer()
	get_tree().paused = true
	page.frozen = false
	page.command = JSON.stringify([{"keys": [], "seconds": 0.5}])
	var said: Dictionary = await _answer()
	assert_gt(float(said["seconds"]) - float(before["seconds"]), 0.45, "the clock ran on under the pause")
	assert_almost_eq(float(said["played"]), float(before["played"]), 0.04, "play did not")


## A villager as state() reads one.
## A villager as state() reads one: never built or stepped.
class FakeVillager extends Npc:
	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


## PIX-435 (finding a villager took 40 calls): the folk and the ways out
## within 12 cells of the hero; one gone home for the night isn't listed.
func test_the_folk_and_doors_near_are_listed() -> void:
	var tree := get_tree()
	var kept := tree.current_scene
	var world := FakeWorld.new()
	world.hud = autofree(Hud.new())
	world.hud.root = autofree(CanvasLayer.new())
	world.hud.objective_label = autofree(Label.new())
	world.map.portals = {Vector2i(12, 10): {"mapId": "inn"}, Vector2i(40, 10): {"mapId": "far"}}
	for one: Array in [["Maren", Vector2i(9, 10), false], ["Hessa", Vector2i(10, 30), false], ["Ana", Vector2i(11, 11), true]]:
		var villager := FakeVillager.new()
		villager.data = {"name": one[0]}
		villager.position = MapView.center(one[1])
		villager.away = one[2]
		villager.add_to_group("npcs")
		world.add_child(villager)
	tree.root.add_child(world)
	tree.current_scene = world
	var said: Dictionary = bridge.state()
	tree.current_scene = kept
	world.free()
	assert_eq(said["npcs"], [{"name": "Maren", "cell": [9, 10]}], "Hessa 20 cells off, Ana gone home")
	assert_eq(said["doors"], [{"cell": [12, 10], "to": "inn"}])


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
