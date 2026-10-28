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


## One box of words at a time (PIX-343, Tom: « y'a trop d'infos qui pop
## d'un coup »): the log shows a line at a time, the rest in turn; the
## plate goes first, the log's line stepping aside and coming back in full
## once the plate has faded, counted once.
func test_one_box_of_words_at_a_time() -> void:
	var hud: CanvasLayer = add_child_autofree(CanvasLayer.new())
	var messages: Messages = add_child_autofree(Messages.new())
	messages.build_log(hud)
	messages.build_plate(hud)
	var chips := func() -> Array:
		return messages.log_box.get_children().filter(func(chip: Node) -> bool: return not chip.is_queued_for_deletion()).map(
			func(chip: Node) -> String: return (chip.get_child(0) as Label).text)
	messages.log_lines(["A wolf howls.", "Greymaw has seen you."])
	assert_eq(chips.call(), ["A wolf howls."], "one line at a time")
	messages.flash("The gate is barred.")
	assert_eq(chips.call(), [], "the plate's turn: the log's line steps aside")
	messages.message_fade.custom_step(30.0)
	assert_eq(chips.call(), ["A wolf howls."], "back once the plate has gone, in full")
	assert_eq(messages.logged, 1, "counted once")


## What the plate asks of the world: no fight on, and whether a title card
## is up.
class CalmFoes extends RefCounted:
	func in_fight(_linger: float) -> bool:
		return false


class CardHud extends RefCounted:
	var card := true

	func card_up() -> bool:
		return card


class FellWorld extends Node:
	var foes := CalmFoes.new()
	var hud := CardHud.new()


## PIX-378: the Hollow King's fall ended the fight, and the level's plate
## came up under the Victory card, LEVEL UP rising over the hero and the
## win beside it: four texts at once. What can wait waits out the card too,
## then says the level; said as the boss fell, before its card came up (no
## fight on: felled at a blow), it makes way for the card.
func test_a_level_waits_out_a_victory_card() -> void:
	var world: FellWorld = add_child_autofree(FellWorld.new())
	var hud: CanvasLayer = add_child_autofree(CanvasLayer.new())
	var messages: Messages = add_child_autofree(Messages.new())
	messages.world = world
	messages.build_log(hud)
	messages.build_plate(hud)
	var level := "Level up: you are now level 17. +3 stat points and +1 skill point to spend."
	messages.log_lines([level], true)
	assert_eq(messages._message_now, "", "not under the Victory card")
	world.hud.card = false
	messages.update()
	assert_eq(messages._message_now, level, "said once it has gone")
	messages.clear()
	messages.log_lines([level], true)
	assert_eq(messages._message_now, level, "no card yet: said at once")
	world.hud.card = true
	messages.make_way()
	assert_eq(messages._message_now, "", "the card up: it makes way")
	assert_eq(messages.message_box.modulate.a, 0.0, "its plate gone")
	world.hud.card = false
	messages.update()
	assert_eq(messages._message_now, level, "said in full after the card")
