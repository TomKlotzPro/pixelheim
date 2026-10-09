extends GutTest
## The pad (PIX-215): A answers, B only goes back, X swings; the D-pad
## walks, the shoulder and the triggers cast; Back opens the dock's menu;
## and the keycaps show the pad's buttons once it's in hand.


func before_each() -> void:
	Controls.apply({})


func after_each() -> void:
	Controls.pad = false


func _pad_buttons(action: String) -> Array:
	return InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool: return event is InputEventJoypadButton).map(func(event: InputEventJoypadButton) -> int: return event.button_index)


func test_a_answers_and_b_only_goes_back() -> void:
	assert_eq(_pad_buttons("interact"), [JOY_BUTTON_A])
	assert_eq(_pad_buttons("attack"), [JOY_BUTTON_X])
	assert_has(_pad_buttons("ui_cancel"), JOY_BUTTON_B, "B goes back")
	assert_does_not_have(_pad_buttons("interact"), JOY_BUTTON_B, "and only that")


func test_the_dpad_walks_and_the_shoulders_cast() -> void:
	assert_has(_pad_buttons("move_up"), JOY_BUTTON_DPAD_UP)
	assert_has(_pad_buttons("move_right"), JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_pad_buttons("skill_1"), [JOY_BUTTON_LEFT_SHOULDER])
	var triggers := InputMap.action_get_events("skill_2").filter(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion)
	assert_eq(triggers.size(), 1)
	assert_eq((triggers[0] as InputEventJoypadMotion).axis, JOY_AXIS_TRIGGER_LEFT)
	assert_eq(_pad_buttons("dock_menu"), [JOY_BUTTON_BACK], "Back opens the dock's menu")


func test_keycaps_show_the_pad_once_it_is_in_hand() -> void:
	assert_eq(Controls.say("{key:interact}"), Controls.key_label(Controls.key_for("interact", {})), "the keyboard's key first")
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	Controls.note_device(press)
	assert_true(Controls.pad)
	assert_eq(Controls.say("{key:interact} to talk"), "A to talk")
	assert_eq(Controls.shown("Esc"), "B")
	assert_eq(Controls.say("{key:skill_2}"), "LT")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	Controls.note_device(key)
	assert_false(Controls.pad, "a key puts the keyboard's back")
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.1
	Controls.note_device(drift)
	assert_false(Controls.pad, "a stick's drift is no hand on the pad")


## Found on the way: "{key:skill_1}" was never replaced (its digit fell
## outside the pattern), so the first night's line showed the token.
func test_a_skill_key_is_named_too() -> void:
	assert_eq(Controls.say("{key:skill_1} for your skill"), "1 for your skill")
	assert_false(Controls.say(String(Prologue.objective(Prologue.EMBERS, 0, false))).contains("{key:"), "the first night's line names its keys")
