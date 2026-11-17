extends GutTest
## The Night of Ash's story holds together (PIX-509 to PIX-514, the
## 2026-11-16 opening playtest): the night keeps its hour until its dawn,
## only its survivors are about and a shut gate says the night's own line,
## and an opening caption takes a press as a talk's line does.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior", true)


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## PIX-511: a hero who wandered saw a sun on the clock while Maren said
## "we'll talk at dawn".
func test_the_night_keeps_its_hour_however_far_the_hero_walks() -> void:
	var night: float = state.world.steps
	state.walk(DayNight.DAY_CYCLE_STEPS * 0.4)
	assert_eq(state.world.steps, night, "no step turns the clock that night")
	assert_true(DayNight.is_night(state.world.steps))
	state.questing.finish_prologue()
	assert_eq(state.world.steps, Prologue.dawn_steps(), "its dawn sets the hour, once")
	state.walk(5.0)
	assert_eq(state.world.steps, Prologue.dawn_steps() + 5.0, "and the day turns as days do")


## PIX-510: the banker stood by the road talking of caravans, and the mayor
## in his hall of rebuilding, hours before anyone decided to.
func test_only_the_survivors_are_about_that_night() -> void:
	assert_eq(Prologue.folk("town").size(), Prologue.survivors().size())
	for map_id: String in ["overworld", "town_hall", "town_inn", "town_shop"]:
		assert_eq(Prologue.folk(map_id), [], "nobody on %s" % map_id)
	assert_ne(Prologue.later_line(), "", "the board and the ledgers have the night's line")
	assert_false("rebuild" in Prologue.later_line().to_lower())
	for survivor: Dictionary in Prologue.folk("town"):
		for key: String in ["lines", "before", "after"]:
			for line: String in survivor["prologue"].get(key, []):
				assert_false("rebuild" in line.to_lower(), "%s speaks of rebuilding before the dawn decides it: %s" % [survivor["id"], line])


## PIX-514: on the night itself the bridge "burned on the Night of Ash" and
## wanted Saltmere's rope.
func test_a_shut_gate_says_the_nights_line_until_the_dawn() -> void:
	for gate: Dictionary in Gates.all():
		assert_eq(Gates.line(gate, state.progression, state.settlement), Prologue.gate_line(), "%s that night" % gate["id"])
	assert_false("Night of Ash" in Prologue.gate_line(), "the night isn't over to be named")
	state.questing.finish_prologue()
	assert_string_contains(Gates.line(Gates.by_id("bridge"), state.progression, state.settlement), "Saltmere", "by day, the story's line")


## PIX-509: the dawn's first word is the telling of the fires out and the
## survivors gathered; the screen says it once both are so (flows
## `dawn-pan`, `dawn-told`).
func test_the_dawn_opens_on_the_telling_of_what_is_then_seen() -> void:
	var first: Dictionary = Prologue.dawn()[0]
	assert_eq(String(first["who"]), "")
	assert_string_contains(String(first["line"]), "the fires gave up")
	assert_false(first.get("tagline", false))


func _scene(steps: Array) -> Cutscene:
	var scene := Cutscene.new()
	get_tree().root.add_child(scene)
	# Before its first step is played (deferred).
	scene.steps = steps
	scene.still = false
	return scene


func _end(scene: Cutscene) -> void:
	scene.finish()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false


## PIX-513: a press on a typing caption showed it whole, and a second later
## the next began, unread.
func test_a_press_on_a_typing_caption_shows_it_whole_and_waits_for_the_next() -> void:
	var scene := _scene([
		{"kind": "caption", "text": "A village under a mountain, and glad of it, most days of the week.", "hold": 30.0},
		{"kind": "caption", "text": "Second.", "hold": 30.0},
	])
	for i in 3:
		await get_tree().process_frame
	assert_lt(scene.caption.visible_ratio, 1.0, "typing")
	scene._command(_press("interact")).call()
	for i in 12:
		await get_tree().process_frame
	assert_eq(scene.caption.visible_ratio, 1.0, "the press shows it whole")
	assert_string_starts_with(scene.caption.text, "A village", "and it stays to be read")
	scene._command(_press("interact")).call()
	for i in 3:
		await get_tree().process_frame
	assert_eq(scene.caption.text, "Second.", "the next press moves on")
	await _end(scene)


## PIX-513: the mountain path's sky lay over the click catcher, and its
## caption heard no click. Whatever the stage, the catcher lies over
## everything, and nothing else of the scene takes the mouse from it.
func test_a_click_is_heard_on_every_stage() -> void:
	for stage: String in Cutscene.STAGES:
		var scene := _scene([{"kind": "stage", "stage": stage}, {"kind": "wait", "seconds": 30.0}])
		for i in 2:
			await get_tree().process_frame
		var catcher := scene.catcher
		assert_eq(catcher.get_index(), scene.get_child_count() - 1, "%s: the catcher lies over everything" % stage)
		scene.advance = false
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		catcher.gui_input.emit(click)
		assert_true(scene.advance, "%s: a click moves on" % stage)
		await _end(scene)


## PIX-515: a hound that "crumbles into cinders" left a wolf's pelt, an
## ember an imp's horn, its own or the floor's; by day a wolf is a wolf.
## Still so once the night has moved past their beat: a hound may outlive it.
func test_a_thing_of_ash_leaves_nothing_of_the_kind_it_borrows() -> void:
	for step: int in [Prologue.HOUNDS, Prologue.EMBERS]:
		var wave := Prologue.wave(step)
		for at: int in [step, Prologue.MAREN]:
			state.progression.prologue = at
			var foe := Bestiary.spawn(wave["monsterId"])
			foe["name"] = wave["name"]
			assert_gt(Bestiary.drops_of(foe["id"]).size(), 0, "%s carries something by day" % foe["id"])
			for rolls: Array in [[0.0], [0.0, 0.9, 0.9]]:
				# [0.0]: everything drops, the floor's as gear. The other: the
				# floor's drop is a stack (a pelt, bread), three rolls in all.
				var calls: Array[int] = [0]
				state.roll = func() -> float:
					calls[0] += 1
					return rolls[mini(calls[0], rolls.size()) - 1]
				var before: Dictionary = state.pack.items.duplicate(true)
				state.spoils.defeat_monster(foe.duplicate(true), "", "", 1)
				assert_eq(state.pack.items, before, "%s leaves no pelt, horn or bread (step %d, rolls %s)" % [wave["name"], at, rolls])
				if rolls.size() == 3:
					assert_eq(calls[0], 3, "the floor's drop was rolled, and was a stack")
	state.roll = func() -> float: return 0.0
	state.questing.finish_prologue()
	# The mountain road's wolves are called Ash Hounds too, and are wolves.
	var wolf := Bestiary.spawn("wolf")
	wolf["name"] = Prologue.wave(Prologue.HOUNDS)["name"]
	state.spoils.defeat_monster(wolf, "", "", 1)
	assert_true(state.pack.items.has("wolf_pelt"), "a wolf's pelt is a wolf's")


## PIX-515: the night's level-up named no key, where its other lines do.
func test_the_nights_level_up_names_its_keys() -> void:
	state.progression.prologue = Prologue.EMBERS
	var line: String = state.spoils.earn_xp(100000)
	assert_string_contains(line, "Press C for your stats and K for your skills.")
	state.questing.finish_prologue()
	assert_false("for your stats" in state.spoils.earn_xp(10000000), "by day the red Menu plank says it")
