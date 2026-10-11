extends GutTest
## The harness's flags (PIX-262): one table, no name in it twice, every flag
## the scripts read and the tools and the README pass declared there, and
## nothing in it that nobody reads. Two features once read the same word
## (`motion`, the walking check, froze the hero in every look book clip
## until the book's filming became `film`); this keeps it from happening
## again unnoticed.

## Passed to the game but read by macOS, not by any script.
const NOT_OURS := ["-NSAppSleepDisabled"]
## A flag read through the parse: `flags.has("x")`, `flags.value("x", ...)`,
## `flags.list("x")`, or the same on `HarnessFlags.given()`.
const READ := "(?:flags|HarnessFlags\\.given\\(\\))\\.(?:has|value|list)\\(\\s*\"([^\"]+)\""


func test_no_flag_is_declared_twice() -> void:
	var seen := {}
	for row: Dictionary in HarnessFlags.TABLE:
		var flag: String = row["flag"]
		assert_false(seen.has(flag), "%s is declared once" % flag)
		seen[flag] = true
		assert_true(flag != "" and " " not in flag and "," not in flag, "%s is one word" % flag)
		assert_true(row.has("takes"), "%s says what it takes" % flag)
		assert_ne(String(row.get("does", "")), "", "%s says what it does" % flag)
	assert_gt(seen.size(), 90, "the whole harness is here")


func test_an_argument_never_reads_as_a_flag() -> void:
	var flags := HarnessFlags.new(PackedStringArray(["--screenshot", "--story", "ending", "fight", "--foe", "mimic"]))
	assert_eq(flags.value("--story"), "ending")
	assert_false(flags.has("ending"), "the ending's story scene, not the ending step too")
	assert_eq(flags.value("--foe", "orc"), "mimic")
	assert_false(flags.has("mimic"), "a fight with a mimic, not the mire's chest")
	assert_true(flags.has("fight"))
	assert_eq(flags.value("--foe-distance", "2"), "2", "the default when it isn't given")
	assert_true(flags.problems.is_empty())


func test_the_first_of_a_flag_given_twice_counts() -> void:
	# FLOWS_EXTRA comes last: a flow's own `--lang` stands.
	var flags := HarnessFlags.new(PackedStringArray(["--screenshot", "--lang", "fr", "--lang", "en"]))
	assert_eq(flags.value("--lang"), "fr")


func test_a_flag_without_its_argument_is_not_given() -> void:
	var flags := HarnessFlags.new(PackedStringArray(["--screenshot", "--level"]))
	assert_false(flags.has("--level"))
	assert_eq(flags.value("--level", "1"), "1")
	assert_eq(flags.problems, PackedStringArray(["--level takes <n>"]))


func test_a_word_the_table_does_not_know_is_reported() -> void:
	var flags := HarnessFlags.new(PackedStringArray(["--screenshot", "fihgt", "--mpa", "town"]))
	assert_false(flags.has("fight"))
	assert_eq(flags.problems.size(), 3, "each unknown word, the misspelt flag's argument too")


func test_a_list_splits_on_its_commas() -> void:
	var flags := HarnessFlags.new(PackedStringArray(["--screenshot", "--keys", "e,esc", "--at", "40,27"]))
	assert_eq(flags.list("--keys"), PackedStringArray(["e", "esc"]))
	assert_eq(flags.list("--at"), PackedStringArray(["40", "27"]))
	assert_eq(flags.list("--walk"), PackedStringArray(), "nothing when it isn't given")


func test_help_lists_every_flag_with_what_it_takes() -> void:
	var help := HarnessFlags.help()
	for row: Dictionary in HarnessFlags.TABLE:
		var usage := String(row["flag"]) + ("" if row["takes"] == "" else " " + String(row["takes"]))
		assert_true(help.contains("  " + usage + " "), "%s is in --help" % usage)
		assert_true(help.contains(String(row["does"])))


func test_no_script_reads_the_command_line_itself() -> void:
	var direct := RegEx.create_from_string("get_cmdline_(user_)?args|\\bargs\\.(has|find)\\(")
	var scripts := _scripts("res://scripts")
	assert_gt(scripts.size(), 50)
	for path: String in scripts:
		if path.ends_with("/harness_flags.gd"):
			continue
		assert_null(direct.search(scripts[path]), "%s asks HarnessFlags, not the command line" % path)


func test_every_flag_the_scripts_read_is_in_the_table() -> void:
	var read := _read_flags()
	assert_gt(read.size(), 90, "the reads were found")
	for flag: String in read:
		assert_false(HarnessFlags.row_of(flag).is_empty(), "%s (read in %s) is in HarnessFlags.TABLE" % [flag, read[flag]])


func test_every_flag_in_the_table_is_read() -> void:
	var read := _read_flags()
	for row: Dictionary in HarnessFlags.TABLE:
		if row["flag"] in NOT_OURS:
			continue
		assert_true(read.has(row["flag"]), "%s is read somewhere (or it's a dead flag)" % row["flag"])


func test_every_flag_the_tools_and_the_readme_pass_is_in_the_table() -> void:
	var checked := 0
	# The release flows, a line each in flows.txt (PIX-273): `name | harness
	# arguments | expected | tags`; and FLOWS_EXTRA in flows.sh.
	var entries := RegEx.create_from_string("(?m)^[\\w-]+\\s*\\|([^|]*)\\|").search_all(FileAccess.get_file_as_string("res://tools/flows.txt"))
	assert_gt(entries.size(), 50, "the flows were found")
	for found in entries:
		checked += _check(found.get_string(1).split(" ", false), "tools/flows.txt")
	var flows := FileAccess.get_file_as_string("res://tools/flows.sh")
	for found in RegEx.create_from_string("FLOWS_EXTRA=\"([^\"]*)\"").search_all(flows):
		checked += _check(found.get_string(1).split(" ", false), "tools/flows.sh")
	# The look book's options, each turned into the harness's flags.
	var lookbook := FileAccess.get_file_as_string("res://tools/lookbook.sh")
	for found in RegEx.create_from_string("extra\\+=\\(([^)]*)\\)").search_all(lookbook):
		checked += _check(found.get_string(1).split(" ", false), "tools/lookbook.sh")
	# Every Godot command line in the tools and the README.
	for path in ["res://tools/flows.sh", "res://tools/lookbook.sh", "res://README.md"]:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var at := line.find(" -- --")
			if at < 0:
				continue
			var command := line.substr(at + 4)
			for end in ["#", " 2>&1", " |"]:
				if command.contains(end):
					command = command.substr(0, command.find(end))
			checked += _check(command.split(" ", false), path)
	assert_gt(checked, 200, "the tools' flags were checked")


## Checks `words` as the game parses them (a flag that takes an argument
## takes the next word; shell expansions are skipped) and says how many
## flags it checked.
func _check(words: PackedStringArray, where: String) -> int:
	var checked := 0
	var at := 0
	while at < words.size():
		var word := words[at].trim_prefix("\"").trim_suffix("\"")
		at += 1
		if word == "" or word.contains("$"):
			continue
		var row := HarnessFlags.row_of(word)
		assert_false(row.is_empty(), "%s (in %s) is in HarnessFlags.TABLE" % [word, where])
		checked += 1
		if not row.is_empty() and row["takes"] != "":
			at += 1
	return checked


## flag -> the script that reads it, from every script's source.
func _read_flags() -> Dictionary:
	var reads := RegEx.create_from_string(READ)
	var out := {}
	var scripts := _scripts("res://scripts")
	for path: String in scripts:
		for found in reads.search_all(scripts[path]):
			out[found.get_string(1)] = path.get_file()
	return out


## path -> source of every script under `folder`.
func _scripts(folder: String) -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			out[folder + "/" + file] = FileAccess.get_file_as_string(folder + "/" + file)
	for sub in DirAccess.get_directories_at(folder):
		out.merge(_scripts(folder + "/" + sub))
	return out
