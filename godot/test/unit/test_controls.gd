extends GutTest
## Keys and device settings (src/app/settings.ts bindings, Options.tsx):
## one rebindable primary per action, fixed alternates, no shared keys.

const DIR := "user://test_controls"


func after_all() -> void:
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file])
	DirAccess.remove_absolute(DIR)
	Controls.apply({})


func test_defaults_until_the_player_rebinds() -> void:
	assert_eq(Controls.key_for("move_up", {}), KEY_W)
	assert_eq(Controls.key_for("move_up", {"move_up": KEY_Z}), KEY_Z)


func test_a_taken_key_swaps_rather_than_doubles() -> void:
	var bindings := Controls.rebind({}, "attack", KEY_E)
	assert_eq(Controls.key_for("attack", bindings), KEY_E)
	assert_eq(Controls.key_for("interact", bindings), KEY_J, "interact takes attack's old key")
	var again := Controls.rebind(bindings, "journal", KEY_L)
	assert_eq(Controls.key_for("journal", again), KEY_L)
	assert_eq(again.size(), 3, "a free key moves nobody else")


func test_the_input_map_holds_primaries_alternates_and_the_pad() -> void:
	Controls.apply({"move_up": KEY_Z})
	var keys := InputMap.action_get_events("move_up").filter(func(e: InputEvent) -> bool: return e is InputEventKey).map(
		func(e: InputEventKey) -> int: return e.physical_keycode
	)
	assert_eq(keys, [KEY_Z, KEY_UP], "the rebound key, and the arrow still works")
	assert_true(InputMap.action_get_events("attack").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton))
	assert_true(InputMap.has_action("menu"))
	Controls.apply({})
	assert_eq((InputMap.action_get_events("move_up")[0] as InputEventKey).physical_keycode, KEY_W, "rebuilt, not stacked")


func test_settings_keep_keys_and_video_outside_the_save() -> void:
	var settings := GameSettings.new(DIR + "/settings.cfg")
	settings.scanlines = true
	settings.fullscreen = true
	settings.bindings = {"attack": KEY_K, "nonsense": KEY_P}
	settings.save_file()
	var reread := GameSettings.new(DIR + "/settings.cfg")
	reread.load_file()
	assert_true(reread.scanlines)
	assert_true(reread.fullscreen)
	assert_eq(reread.bindings, {"attack": KEY_K}, "only real actions come back")
