extends GutTest
## Big moments (PIX-211): a quest's end and the level it brings go up as two
## messages, read at the subtitle pace, and a fine or epic drop has a colour
## to rise in.

const WorldScript := preload("res://scripts/world.gd")


func after_each() -> void:
	GameState.settings.large_text = false


func test_a_quests_end_and_its_level_are_two_messages() -> void:
	var tags := ["Quest complete", "Level up"]
	var parts := Messages.split_messages("Quest complete: Slimes. +40 XP.\nLevel up: you are now level 3.", tags)
	assert_eq(parts, ["Quest complete: Slimes. +40 XP.", "Level up: you are now level 3."] as Array[String])
	assert_eq(Messages.split_messages("The gate is barred.\nFind the five relics.", tags).size(), 1, "an untagged line stays with its message")


func test_a_tag_is_found_in_french_too() -> void:
	assert_eq(Messages.tag_of("Quête terminée : Les slimes.", ["Quête terminée"]), "Quête terminée")
	assert_eq(Messages.tag_of("Quest complete: Slimes.", ["Quest complete"]), "Quest complete")
	assert_eq(Messages.tag_of("Nothing to say.", ["Quest complete"]), "")


func test_a_line_stays_long_enough_to_read() -> void:
	assert_eq(UiStyle.reading_seconds("Short."), 2.5, "never under 2.5 s")
	assert_almost_eq(UiStyle.reading_seconds("x".repeat(150)), 10.0, 0.001, "fifteen characters a second")
	assert_eq(UiStyle.reading_seconds("x".repeat(400)), 12.0, "never over 12 s")
	GameState.settings.large_text = true
	assert_almost_eq(UiStyle.reading_seconds("x".repeat(150)), 15.0, 0.001, "half again with large text")


## PIX-245: every drop rises now, a common one too, in cream.
func test_fine_and_epic_drops_rise_in_their_colour() -> void:
	for tone: String in ["xp", "gold", "common", "fine", "epic"]:
		assert_true(WorldFx.GAIN_TONES.has(tone), tone)
	assert_ne(WorldFx.GAIN_TONES["fine"], WorldFx.GAIN_TONES["common"])
	assert_ne(WorldFx.GAIN_TONES["epic"], WorldFx.GAIN_TONES["fine"])
	assert_eq(WorldFx.GAIN_TONES["common"], UiStyle.CREAM, "on the dark, as words over the world are")
