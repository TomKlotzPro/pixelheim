extends GutTest
## Screen (PIX-136): the world holds still while any screen is open and runs
## again only when the last one lets go; Esc, the menu key and a screen's own
## key close it, unless the screen claims the key first.


class Probe:
	extends Screen
	var claims_esc := false

	func _command(event: InputEvent) -> Callable:
		if claims_esc and event.is_action_pressed("ui_cancel"):
			return func() -> void: pass
		return Callable()


func after_each() -> void:
	get_tree().paused = false


func _screen() -> Probe:
	var screen := Probe.new()
	add_child_autofree(screen)
	return screen


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_the_world_runs_when_the_last_screen_closes() -> void:
	var before := Screen.holds()
	var first := _screen()
	var second := _screen()
	assert_true(get_tree().paused, "a screen holds the world")
	assert_eq(Screen.holds(), before + 2)
	first.close()
	assert_true(get_tree().paused, "the other screen still holds it")
	second.close()
	assert_eq(Screen.holds(), before)
	assert_false(get_tree().paused, "the last one let go")


func test_closing_twice_lets_go_once() -> void:
	var before := Screen.holds()
	var first := _screen()
	var second := _screen()
	first.close()
	first.close()
	assert_eq(Screen.holds(), before + 1)
	assert_true(get_tree().paused, "the second screen's hold stands")
	second.close()


func test_a_screen_freed_without_closing_lets_go() -> void:
	var before := Screen.holds()
	var screen := Probe.new()
	add_child(screen)
	screen.free()
	assert_eq(Screen.holds(), before)
	assert_false(get_tree().paused)


func test_esc_the_menu_key_and_its_own_key_close_it() -> void:
	for action: StringName in [&"ui_cancel", &"menu", &"journal"]:
		var screen := _screen()
		screen.closing_actions = [&"journal"]
		screen._unhandled_input(_press(action))
		assert_true(screen.is_queued_for_deletion(), "%s closes it" % action)


func test_another_screens_key_does_not_close_it() -> void:
	var screen := _screen()
	screen.closing_actions = [&"journal"]
	screen._unhandled_input(_press(&"codex"))
	assert_false(screen.is_queued_for_deletion())
	screen.close()


func test_a_key_the_screen_claims_does_not_close_it() -> void:
	var screen := _screen()
	screen.claims_esc = true
	screen._unhandled_input(_press(&"ui_cancel"))
	assert_false(screen.is_queued_for_deletion(), "its own use of Esc comes first")
	screen.close()


func test_every_screen_is_a_screen_and_compiles() -> void:
	var scripts := Array(DirAccess.get_files_at("res://scripts")).filter(func(file: String) -> bool:
		return file.ends_with("_screen.gd") or file == "dialogue_box.gd"
	)
	assert_gt(scripts.size(), 15)
	for file: String in scripts:
		var script: GDScript = load("res://scripts/" + file)
		assert_not_null(script, file)
		assert_true(script.can_instantiate(), "%s compiles" % file)
		var base := script.get_base_script()
		while base != null and base.resource_path != "res://scripts/screen.gd":
			base = base.get_base_script()
		assert_not_null(base, "%s extends Screen" % file)
