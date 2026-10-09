extends GutTest
## The phone version (PIX-162): the HUD keeps to the bottom and screens to
## the middle of whatever shape the screen is (and nothing moves on a
## desktop's 1280x720), and the thumbstick presses the move actions as hard
## as it is pushed, and lets go.

const TouchControls := preload("res://scripts/touch_controls.gd")


func after_each() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func test_a_desktop_canvas_moves_nothing() -> void:
	assert_eq(Touch.hud_offset_for(Vector2(1280, 720)), Vector2.ZERO)
	assert_eq(Touch.center_offset_for(Vector2(1280, 720)), Vector2.ZERO)


func test_a_phone_keeps_the_hud_down_and_screens_centred() -> void:
	# Held sideways: wider than the design.
	assert_eq(Touch.hud_offset_for(Vector2(1560, 720)), Vector2(140, 0))
	assert_eq(Touch.center_offset_for(Vector2(1560, 720)), Vector2(140, 0))
	# Held upright: taller.
	assert_eq(Touch.hud_offset_for(Vector2(1280, 2770)), Vector2(0, 2050), "the dock on the bottom edge")
	assert_eq(Touch.center_offset_for(Vector2(1280, 2770)), Vector2(0, 1025))


func test_the_stick_presses_as_hard_as_it_is_pushed() -> void:
	var pad: Control = autofree(TouchControls.Pad.new())
	pad.stick_center = Vector2(100, 600)
	pad.stick_radius = 60.0
	pad._steer(Vector2(160, 600))
	assert_almost_eq(Input.get_action_strength("move_right"), 1.0, 0.01)
	assert_eq(Input.get_action_strength("move_left"), 0.0)
	pad._steer(Vector2(100, 570))
	assert_almost_eq(Input.get_action_strength("move_up"), 0.5, 0.01)
	assert_eq(Input.get_action_strength("move_right"), 0.0, "turning lets the old way go")
	pad._steer(Vector2(105, 600))
	assert_eq(Input.get_action_strength("move_right"), 0.0, "a nudge inside the dead zone is no step")
	pad._steer(Vector2(40, 600))
	pad._release_stick()
	assert_eq(Input.get_action_strength("move_left"), 0.0, "a lifted thumb stops the hero")


func test_a_touch_on_the_stick_is_the_sticks() -> void:
	var pad: Control = autofree(TouchControls.Pad.new())
	pad.stick_center = Vector2(100, 600)
	pad.stick_radius = 60.0
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(130, 600)
	assert_true(pad.take(touch))
	assert_eq(pad.stick_finger, 0)
	var far := InputEventScreenTouch.new()
	far.index = 1
	far.pressed = true
	far.position = Vector2(700, 100)
	assert_false(pad.take(far), "a touch nowhere near a control goes on to the game")
	touch.pressed = false
	assert_true(pad.take(touch))
	assert_eq(pad.stick_finger, -1)


## PIX-214: thumb-sized controls, every one on the screen and none on another,
## and the six skill keys - on a phone held sideways, 844x390 CSS pixels
## (its canvas 1558x720, 1.85 canvas units to a CSS pixel).
func test_the_pad_is_thumb_sized_and_fits() -> void:
	var size := Vector2(1558, 720)
	var unit := 720.0 / 390.0
	var plan := Touch.pad_plan(size, unit)
	var actions: Array = plan["buttons"].map(func(button: Dictionary) -> String: return button["action"])
	for index in 6:
		assert_has(actions, "skill_%d" % (index + 1), "skill %d is on the pad" % (index + 1))
	for button: Dictionary in plan["buttons"]:
		var at: Vector2 = button["center"]
		var radius: float = button["radius"]
		assert_gte(radius * 2.0 / unit, 52.0 - 0.01, "%s is thumb-sized" % button["action"])
		assert_true(Rect2(Vector2.ZERO, size).encloses(Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0)), "%s is on the screen" % button["action"])
		for other: Dictionary in plan["buttons"]:
			if other != button:
				assert_gte(at.distance_to(other["center"]), radius + float(other["radius"]) - 0.5, "%s and %s don't overlap" % [button["action"], other["action"]])
	assert_gte(float(plan["stick_radius"]) * 2.0 / unit, 120.0 - 0.01, "a stick a thumb can work")


func test_screens_put_their_key_only_commands_on_the_tap_bar() -> void:
	var pack: Node = autofree(preload("res://scripts/inventory_screen.gd").new())
	assert_eq(pack._tap_actions().map(func(entry: Dictionary) -> String: return entry["label"]), ["Drop", "Drop all", "Sort"])
	var skills: Node = autofree(preload("res://scripts/skills_screen.gd").new())
	assert_eq(skills._tap_actions().map(func(entry: Dictionary) -> String: return entry["label"]), ["Set key", "Forget"])


func test_a_phone_reads_large_by_default() -> void:
	var path := "user://test_touch_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Touch.forced = true
	var settings := GameSettings.new(path)
	settings.load_file()
	Touch.forced = false
	assert_true(settings.large_text, "large text on a phone")
	var desktop := GameSettings.new(path)
	desktop.load_file()
	assert_false(desktop.large_text, "not on a desktop")
