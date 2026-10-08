extends GutTest
## Keycaps that look like keys (PIX-193): every key the game names is drawn
## by UiStyle as a raised cap, pairs side by side, alternatives with a slash,
## the arrows as their glyphs; a cap dips when its key is pressed.

## The names a footer may give a key: one letter or digit, or one of these.
const NAMED := ["Esc", "Enter", "Space", "Tab", "Shift", "PgUp", "PgDn", "Arrows", "Up", "Down", "Left", "Right"]


func _caps(row: Control) -> Array:
	return row.get_children().filter(func(node: Node) -> bool: return node is Keycap).map(
		func(cap: Keycap) -> String: return cap.label.text)


func test_a_pair_sits_side_by_side_and_alternatives_take_a_slash() -> void:
	assert_eq(_caps(autofree(UiStyle.keys("W/S"))), ["W", "S"])
	var either: HBoxContainer = autofree(UiStyle.keys("I / Esc"))
	assert_eq(_caps(either), ["I", "Esc"])
	assert_eq((either.get_child(1) as Label).text, "/")
	assert_eq(_caps(autofree(UiStyle.keys("Up/Down"))), ["↑", "↓"])
	assert_eq(_caps(autofree(UiStyle.keys("Arrows"))), ["←", "↑", "↓", "→"])


func test_a_footer_draws_every_key_as_a_cap() -> void:
	var footer: HBoxContainer = autofree(UiStyle.footer("A/D  tabs      E  equip / use      I / Esc  close", Vector2.ZERO))
	var caps: Array = []
	for row in footer.get_children():
		if row is HBoxContainer:
			caps.append_array(_caps(row))
	assert_eq(caps, ["A", "D", "E", "I", "Esc"])


func test_every_footer_names_its_keys_the_same_way() -> void:
	var literal := RegEx.create_from_string('UiStyle\\.footer\\(\\s*"([^"]+)"')
	var checked := 0
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string("res://scripts/" + file)
		for found in literal.search_all(source):
			for command in RegEx.create_from_string(" {4,}").sub(found.get_string(1).strip_edges(), "\t", true).split("\t"):
				var cut := command.find("  ")
				if cut <= 0:
					continue
				for choice in command.substr(0, cut).split(" / "):
					for key in choice.strip_edges().split("/"):
						assert_true(key.length() == 1 or key in NAMED, "%s: a key named %s" % [file, key])
						checked += 1
	assert_gt(checked, 40, "the footers were read")


func test_a_cap_dips_when_its_key_is_pressed() -> void:
	var cap: Keycap = autofree(UiStyle.keycap("Esc"))
	add_child(cap)
	var up := cap.get_theme_stylebox("panel").content_margin_top
	var press := InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.pressed = true
	cap._input(press)
	assert_gt(cap.get_theme_stylebox("panel").content_margin_top, up, "the face drops")
	cap._process(1.0)
	assert_eq(cap.get_theme_stylebox("panel").content_margin_top, up, "and comes back up")
	var other := InputEventKey.new()
	other.keycode = KEY_E
	other.pressed = true
	cap._input(other)
	assert_eq(cap.get_theme_stylebox("panel").content_margin_top, up, "another key leaves it be")


func test_a_rebound_key_relabels_its_cap() -> void:
	var cap: Keycap = autofree(UiStyle.keycap("E"))
	UiStyle.keycap_text(cap, "F")
	assert_eq(cap.label.text, "F")
	assert_true("F" in cap.keys)
