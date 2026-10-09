extends GutTest
## Keys tell the truth (PIX-201): every key a screen names is the one the
## player's keyboard shows - an AZERTY board's Z for the physical W - and
## follows a rebinding; a key with a fixed job can't be taken by another.


func after_each() -> void:
	Controls.learned = {}


func test_a_key_reads_as_this_keyboard_names_it() -> void:
	# An AZERTY board, as its key presses taught it.
	Controls.learned = {KEY_W: KEY_Z, KEY_A: KEY_Q, KEY_Z: KEY_W}
	assert_eq(Controls.shown("W"), "Z")
	assert_eq(Controls.shown("{key:move_up}"), "Z", "the move key, where it is on this board")
	assert_eq(Controls.shown("Z"), "W", "drop all, under the AZERTY W")
	assert_eq(Controls.shown("Esc"), "Esc", "named keys read the same")
	assert_eq(Controls.shown("1-6"), "1-6")
	assert_eq(UiStyle.keyed("{key:interact}", "Play"), "E  Play")


func test_a_rebinding_follows_through() -> void:
	var bound := Controls.rebind({}, "interact", KEY_F)
	assert_eq(Controls.say("{key:interact}", bound), "F")


func test_a_fixed_key_keeps_its_job() -> void:
	assert_ne(Controls.fixed_use(KEY_X, "attack"), "", "X drops")
	assert_ne(Controls.fixed_use(KEY_1, "attack"), "", "1 casts")
	assert_ne(Controls.fixed_use(KEY_SPACE, "interact"), "", "Space attacks")
	assert_eq(Controls.fixed_use(KEY_UP, "move_up"), "", "an action's own alternate is its own")
	assert_eq(Controls.fixed_use(KEY_G, "attack"), "")


## No screen writes a movable key as a letter: W/A/S/D, E and the screen
## keys go through {key:action}, so a rebinding or another layout shows true.
func test_no_screen_names_a_movable_key_by_its_letter() -> void:
	var movable := ["W", "A", "S", "D", "E", "I", "M", "Q", "K", "J"]
	var spots := RegEx.create_from_string("(UiStyle\\.footer|UiStyle\\.screen_footer|UiStyle\\.keyed|UiStyle\\.button_keyed\\([^,]*,|Text\\.t)\\(?\\s*\"([^\"]*)\"")
	var hinted := RegEx.create_from_string("UiStyle\\.hints\\(\\[([^\\]]*)\\]")
	var bad: Array[String] = []
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd") or file == "harness.gd":
			continue
		var source := FileAccess.get_file_as_string("res://scripts/" + file)
		for found in spots.search_all(source):
			var text := found.get_string(2)
			var commands: Array = []
			if found.get_string(1) == "UiStyle.keyed":
				commands = [text + "  x"]
			elif "      " in text or found.get_string(1) == "UiStyle.footer":
				commands = Array(RegEx.create_from_string(" {4,}").sub(text.strip_edges(), "\t", true).split("\t"))
			for command: String in commands:
				var cut := command.find("  ")
				if cut <= 0:
					continue
				for key in command.substr(0, cut).replace(" / ", "/").split("/"):
					if key.strip_edges() in movable:
						bad.append("%s: %s" % [file, command])
		for found in hinted.search_all(source):
			var parts := found.get_string(1).split(",")
			for i in range(0, parts.size(), 2):
				if parts[i].strip_edges().trim_prefix("\"").trim_suffix("\"") in movable:
					bad.append("%s: %s" % [file, found.get_string()])
	assert_eq(bad, [] as Array[String])


## The number row reads as digits whatever the board: an AZERTY's 1 key
## types "&" unshifted, and a hint said "Ampersand for your skill".
func test_the_number_row_reads_as_digits() -> void:
	Controls.learned = {KEY_1: KEY_AMPERSAND, KEY_2: 233}
	assert_eq(Controls.key_label(KEY_1), "1")
	assert_eq(Controls.say("{key:skill_2} for your skill"), "2 for your skill")
