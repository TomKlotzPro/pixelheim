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
