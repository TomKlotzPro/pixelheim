extends GutTest
## One voice for what the game tells the player (PIX-194): guidance names keys
## by action (so a rebound key is never wrong), never shouts in capitals,
## writes an objective as a sentence without a full stop, and spells gold
## out in its messages.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## A key written into text instead of {key:action}.
const HARD_KEY := "\\((E|Space|J|I|Q|M|K|C|B|L|Tab|Shift|Enter) to |\\bPress (E|Space|J|I|Q|M|K|C|B|L|Tab|Shift|Enter)\\b|\\b(E|J|I|Q|M|K) (reads|takes|opens|to [a-z]+)\\b"
## Capitals that may stand: numerals, the stats' and pools' abbreviations.
const CAPS_OK := ["XP", "HP", "MP", "EN", "STR", "INT", "DEX", "DEF", "END", "II", "III", "IV"]


func _guidance() -> Array[String]:
	var out: Array[String] = []
	var progression: Dictionary = Quests._data()
	for chapter: Dictionary in progression["mainQuest"]["chapters"]:
		for step: Dictionary in chapter.get("steps", []):
			out.append(String(step["text"]))
	for step: Dictionary in progression["prologue"]["steps"]:
		out.append(String(step["text"]))
	out.append(String(progression["prologue"]["pouch"]))
	for quest: Dictionary in Quests.all():
		out.append_array([String(quest["name"]), String(quest["brief"]), String(quest["accepted"]), String(quest["completed"])])
	var hints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hints.json"))
	for id: String in hints:
		out.append_array([String(hints[id]["title"]), String(hints[id]["text"])])
	return out


func _objectives() -> Array[String]:
	var out: Array[String] = []
	var progression: Dictionary = Quests._data()
	for chapter: Dictionary in progression["mainQuest"]["chapters"]:
		for step: Dictionary in chapter.get("steps", []):
			out.append(String(step["text"]))
	for step: Dictionary in progression["prologue"]["steps"]:
		out.append(String(step["text"]))
	return out


func test_the_model_reads_every_line() -> void:
	assert_gt(_guidance().size(), 200)
	assert_gt(_objectives().size(), 20)


func test_no_line_names_a_key_the_player_may_have_moved() -> void:
	var hard := RegEx.create_from_string(HARD_KEY)
	for line in _guidance():
		assert_null(hard.search(line), "names a key outright: %s" % line)
	var token := RegEx.create_from_string("\\{key:([a-z_]+)\\}")
	for line in _guidance():
		for found in token.search_all(line):
			assert_true(Controls.BINDABLE.has(found.get_string(1)), "a key for an action that exists: %s" % line)


func test_a_key_token_reads_the_binding() -> void:
	assert_eq(Controls.say("Press {key:dodge} to roll", {}), "Press Shift to roll")
	assert_eq(Controls.say("{key:interact} to help", {"interact": KEY_F}), "F to help")
	assert_eq(Controls.say("No keys here", {}), "No keys here")


func test_nothing_shouts() -> void:
	var caps := RegEx.create_from_string("\\b[A-Z]{2,}\\b")
	for line in _guidance():
		for found in caps.search_all(line):
			assert_true(found.get_string() in CAPS_OK, "shouts %s: %s" % [found.get_string(), line])


func test_an_objective_is_a_sentence_without_a_full_stop() -> void:
	for line in _objectives():
		assert_eq(line[0], line[0].to_upper(), "starts with a capital: %s" % line)
		assert_false(line.ends_with("."), "no full stop: %s" % line)
		assert_false(" - " in line, "a colon, not a dash, joins its parts: %s" % line)


func test_messages_spell_gold_out() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/state/game_state.gd")
	for pattern in ["+%dg", "%dg)", "%dg.", "LEVEL UP", ".to_upper()"]:
		assert_false(pattern in source, "game_state.gd's messages: %s" % pattern)


func test_a_quest_line_leads_with_its_tag() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior", 0, false)
	var accepted: String = state.questing.resolve_quests("innkeeper")
	assert_string_starts_with(accepted, "Quest accepted: ")
	var tag := accepted.get_slice(":", 0)
	assert_true(tag in Messages.MESSAGE_TAGS, "the world sets it in gold")
