extends GutTest
## Big moments (PIX-211): a quest's end and the level it brings go up as two
## messages, read at the subtitle pace, and a fine or epic drop has a colour
## to rise in.

const WorldScript := preload("res://scripts/world.gd")


func after_each() -> void:
	GameState.settings.large_text = false


func test_a_quests_end_and_its_level_are_two_messages() -> void:
	var tags := ["Quest complete", "Level up"]
	var parts := WorldScript.split_messages("Quest complete: Slimes. +40 XP.\nLevel up: you are now level 3.", tags)
	assert_eq(parts, ["Quest complete: Slimes. +40 XP.", "Level up: you are now level 3."] as Array[String])
	assert_eq(WorldScript.split_messages("The gate is barred.\nFind the five relics.", tags).size(), 1, "an untagged line stays with its message")


func test_a_tag_is_found_in_french_too() -> void:
	assert_eq(WorldScript.tag_of("Quête terminée : Les slimes.", ["Quête terminée"]), "Quête terminée")
	assert_eq(WorldScript.tag_of("Quest complete: Slimes.", ["Quest complete"]), "Quest complete")
	assert_eq(WorldScript.tag_of("Nothing to say.", ["Quest complete"]), "")


func test_a_line_stays_long_enough_to_read() -> void:
	assert_eq(UiStyle.reading_seconds("Short."), 2.5, "never under 2.5 s")
	assert_almost_eq(UiStyle.reading_seconds("x".repeat(150)), 10.0, 0.001, "fifteen characters a second")
	assert_eq(UiStyle.reading_seconds("x".repeat(400)), 12.0, "never over 12 s")
	GameState.settings.large_text = true
	assert_almost_eq(UiStyle.reading_seconds("x".repeat(150)), 15.0, 0.001, "half again with large text")


func test_fine_and_epic_drops_rise_in_their_colour() -> void:
	assert_true(WorldFx.LOOT_GLOW.has("fine"))
	assert_true(WorldFx.LOOT_GLOW.has("epic"))
	assert_false(WorldFx.LOOT_GLOW.has("common"), "a common piece stays in the log")
