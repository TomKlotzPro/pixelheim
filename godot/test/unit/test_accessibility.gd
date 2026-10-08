extends GutTest
## Accessibility (PIX-160): the three settings are kept between runs, the
## large type is the big size, every hint the game gives has words, and a
## skill learned is announced so its hint can say what it does.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const PATH := "user://test_accessibility.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_the_settings_are_kept() -> void:
	var settings := GameSettings.new(PATH)
	assert_false(settings.large_text)
	assert_false(settings.clear_warnings)
	assert_true(settings.hints, "hints are on for a new player")
	settings.large_text = true
	settings.clear_warnings = true
	settings.hints = false
	settings.hints_seen.append("dodge")
	settings.save_file()
	var back := GameSettings.new(PATH)
	back.load_file()
	assert_true(back.large_text)
	assert_true(back.clear_warnings)
	assert_false(back.hints)
	assert_eq(back.hints_seen, ["dodge"] as Array[String])


func test_reading_text_takes_the_big_type() -> void:
	var before: bool = GameState.settings.large_text
	GameState.settings.large_text = false
	assert_eq(UiStyle.reading(16), 16)
	GameState.settings.large_text = true
	assert_eq(UiStyle.reading(16), UiStyle.BIG)
	GameState.settings.large_text = before


func test_every_hint_has_a_title_and_words() -> void:
	var hints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hints.json"))
	for id: String in ["dodge", "skill", "board", "bounty"]:
		assert_true(hints.has(id), id)
		assert_ne(String(hints[id]["title"]), "")
		assert_gt(String(hints[id]["text"]).length(), 20)
	assert_string_contains(hints["dodge"]["text"], "{key}", "names the player's own key")


func test_a_skill_learned_is_announced() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.hero.skill_points = 2
	var heard: Array = []
	state.skill_learned.connect(func(entry: Dictionary) -> void: heard.append(entry["id"]))
	var bought: bool = state.buy_skill_node("warrior_shield_slam")
	assert_true(bought)
	assert_eq(heard, ["warrior_shield_slam"])
	# A passive is no button to press: no hint.
	state.hero.skill_points = 2
	state.buy_skill_node("warrior_iron_skin")
	assert_eq(heard.size(), 1)
