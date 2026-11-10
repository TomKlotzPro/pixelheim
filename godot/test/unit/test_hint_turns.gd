extends GutTest
## The dodge's card opened over L'Appelle-Marée's entrance (PIX-341): over
## his bar, his name and his first words. A first-time hint waits while a
## boss makes its entrance, and shows once it falls (or the hero gets away,
## or the fight has gone on a while); and one hint at a time, the next in
## its turn, nothing lost. PIX-433: a hint is one short line on the battle
## log's place, never a box over the view, never two boxes at once. PIX-345:
## a title card stands clear of what rises over the world.


## Foes as the HUD asks them: the boss hunting the hero, and since when.
class FakeFoes extends RefCounted:
	var boss: Node = null
	var boss_noticed_at := -100.0

	func boss_hunting() -> Node:
		return boss

	func in_fight(_calm := 0.0) -> bool:
		return false


## What rises over the world, as far as it may yet go (WorldFx.reach).
class FakeFx extends RefCounted:
	var rising: Array[Rect2] = []

	func reach() -> Array[Rect2]:
		return rising


class FakeWorld extends Node:
	var foes := FakeFoes.new()
	var fx := FakeFx.new()
	var messages: Messages = null
	var hud: Hud = null


var world: FakeWorld
var hud: Hud
var kept: GameSettings


func before_each() -> void:
	# A new player's hints, never written over the real settings.
	kept = GameState.settings
	GameState.settings = GameSettings.new("user://test_hint_turns.cfg")
	GameState.settings.read_only = true
	world = add_child_autofree(FakeWorld.new())
	hud = Hud.new()
	hud.world = world
	world.add_child(hud)
	hud.root = CanvasLayer.new()
	world.add_child(hud.root)
	hud.boss_bar = preload("res://scripts/boss_bar.gd").new()
	hud.root.add_child(hud.boss_bar)
	world.hud = hud
	world.messages = Messages.new()
	world.messages.world = world
	world.add_child(world.messages)
	world.messages.build_log(hud.root)
	world.messages.build_plate(hud.root)


func after_each() -> void:
	GameState.settings = kept


func _up() -> String:
	return world.messages.hint_up()


func test_a_hint_waits_out_a_boss_entrance_and_shows_once_it_falls() -> void:
	world.foes.boss = autofree(Node.new())
	world.foes.boss_noticed_at = GameClock.seconds()
	hud.hint("dodge")
	assert_eq([_up(), hud.hint_held()], ["", "dodge"], "held, not over the entrance")
	hud.next_hint()
	assert_eq(hud.hint_held(), "dodge", "still held while the entrance plays")
	assert_false("dodge" in GameState.settings.hints_seen, "not seen until it shows")
	world.foes.boss = null
	hud.next_hint()
	assert_eq([_up(), hud.hint_held()], ["dodge", ""], "the boss down: it shows")
	assert_true("dodge" in GameState.settings.hints_seen)


func test_a_long_boss_fight_lets_the_hint_show() -> void:
	world.foes.boss = autofree(Node.new())
	world.foes.boss_noticed_at = GameClock.seconds() - Hud.BOSS_HINT_S - 0.1
	hud.hint("dodge")
	assert_eq(_up(), "dodge", "past the entrance, in a calm moment")


func test_one_hint_at_a_time_the_next_in_its_turn() -> void:
	hud.hint("dodge")
	hud.hint("fright")
	hud.hint("fright")
	assert_eq([_up(), hud.hint_held()], ["dodge", "fright"], "the second waits, once")
	world.messages.clear()
	hud.next_hint()
	assert_eq(_up(), "fright", "its turn")


func test_a_hint_waits_for_a_title_card() -> void:
	var card := hud.title_card("La Grotte marine", "")
	hud.hint("dodge")
	assert_eq(hud.hint_held(), "dodge", "not over the place's name")
	card.free()
	hud.next_hint()
	assert_eq(_up(), "dodge")


func test_a_title_card_holds_a_hint_already_up() -> void:
	var chips := world.messages.log_box
	hud.hint("dodge")
	var first: Node = chips.get_child(0)
	var card := hud.title_card("Saltmere", "")
	world.messages.update()
	assert_true(first.is_queued_for_deletion(), "not beside the card")
	assert_eq(_up(), "dodge", "waiting, not lost")
	card.free()
	world.messages.update()
	var back := chips.get_children().filter(func(chip: Node) -> bool: return not chip.is_queued_for_deletion())
	assert_eq(back.size(), 1, "back as the card goes")


## PIX-433: "Quest accepted" and the journal's hint stood as two boxes at
## once. The plate goes first and the hint's line waits until it has gone.
func test_a_hint_is_a_line_of_the_log_and_waits_behind_the_plate() -> void:
	var chips := world.messages.log_box
	world.messages.flash(Text.t("Quest accepted") + ": A letter.")
	assert_eq(_up(), "journal", "the first quest brings the journal's hint")
	assert_eq(chips.get_child_count(), 0, "not beside the plate")
	world.messages.message_fade.custom_step(30.0)
	assert_eq(chips.get_child_count(), 1, "its turn, the plate gone")
	var line: String = (chips.get_child(0).get_child(0) as Label).text
	assert_string_contains(line, Controls.say("{key:journal}"), "the player's own key")


## PIX-446: what a quest pays, on the "Quest accepted" plate, made a third
## of them a line taller. It stands where "It's in your journal (Q)." stood,
## and no plate is a line taller than it was then, in English or French.
func test_what_a_quest_pays_adds_no_line_to_its_plate() -> void:
	var then := {"en": "It's in your journal (Q).", "fr": "Elle est dans votre journal (Q)."}
	for lang: String in then:
		Text.apply(lang)
		for quest: Dictionary in Quests.all():
			if quest["objective"]["kind"] != "deliverTo":
				var before := _plate_lines(Text.t("Quest accepted: %s. %s") % [quest["name"], quest["brief"]] + " " + then[lang])
				assert_lte(_plate_lines(Quests.accepted(quest)), before, "%s (%s): %s" % [quest["id"], lang, Quests.accepted(quest)])
	Text.apply("en")


## How many lines a message takes on the plate.
func _plate_lines(text: String) -> int:
	world.messages.clear()
	world.messages.flash(text)
	return world.messages.message_label.get_line_count()


## PIX-433: on a phone the log's line ran under the thumbstick.
func test_on_a_phone_the_log_starts_past_the_stick() -> void:
	hud.sky_overlay = ColorRect.new()
	hud.root.add_child(hud.sky_overlay)
	Touch.forced = true
	hud.place()
	Touch.forced = false
	assert_eq(world.messages.log_box.position.x + hud.root.offset.x, Touch.log_left(Touch.view_size(world), Touch.css(world, 1.0)))
	var size := Vector2(1280, 720)
	var pad := Touch.pad_plan(size, 1.0)
	assert_gt(Touch.log_left(size, 1.0), pad["stick_center"].x + pad["stick_radius"], "past the stick")
	# A headless window's unit is 5: the stick's edge alone is past the middle.
	assert_lte(Touch.log_left(size, 5.0) + Messages.LOG_WIDTH + 16.0, size.x, "a whole line on the canvas")


func _wide(line: String, font_size: int) -> float:
	return UiStyle.body_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Every hint as the game says it, a skill's by the longest name there is.
func _hints() -> Array[String]:
	var trees: Dictionary = Text.localize(JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/combat.json")))["skillTrees"]
	var longest := ""
	for tree: Array in trees.values():
		for node: Dictionary in tree:
			if String(node.get("name", "")).length() > longest.length():
				longest = node["name"]
	var doc: Dictionary = Text.localize(JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hints.json")))
	var out: Array[String] = []
	for id: String in doc:
		for line: String in doc[id].values():
			out.append(Controls.say(line).replace("{skill}", longest).replace("{slot}", "1"))
	return out


## PIX-433: one short line. English and French fit the log's width at the
## game's size; a phone's large type and a language a third longer than
## English (--pseudo) wrap to two lines at most (the log's chip wraps).
func test_every_hint_is_one_short_line() -> void:
	var locale := TranslationServer.get_locale()
	for lang: String in ["en", "fr"]:
		TranslationServer.set_locale(lang)
		for line: String in _hints():
			assert_lte(_wide(line, UiStyle.TEXT), Messages.LOG_WIDTH, "one line: %s" % line)
			assert_lte(_wide(line, UiStyle.BIG), Messages.LOG_WIDTH * 2.0, "two in large type: %s" % line)
	TranslationServer.set_locale("en")
	var ratio := "internationalization/pseudolocalization/expansion_ratio"
	var kept_ratio: Variant = ProjectSettings.get_setting(ratio)
	ProjectSettings.set_setting(ratio, 0.35)
	TranslationServer.pseudolocalization_enabled = true
	for line: String in _hints():
		assert_lte(_wide(line, UiStyle.TEXT), Messages.LOG_WIDTH * 2.0, "two stretched: %s" % line)
	TranslationServer.pseudolocalization_enabled = false
	ProjectSettings.set_setting(ratio, kept_ratio)
	TranslationServer.set_locale(locale)


## PIX-436: « Appuyez sur Shift » on a phone, which has no Shift. Every hint
## that names a key has a line for what the phone has on screen, naming none.
func test_on_a_phone_a_hint_names_what_is_on_the_screen() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hints.json"))
	for id: String in doc:
		if "{key:" in String(doc[id]["text"]) or "{slot}" in String(doc[id]["text"]):
			assert_true(doc[id].has("touch"), "a phone's line: %s" % id)
			assert_false("{key:" in String(doc[id].get("touch", "")) or "{slot}" in String(doc[id].get("touch", "")), "names no key: %s" % id)
	Touch.forced = true
	hud.hint("dodge")
	Touch.forced = false
	var words: String = (world.messages.log_box.get_child(0).get_child(0) as Label).text
	assert_eq(words, Text.t(doc["dodge"]["touch"]))


## PIX-345: at a boss's fall the Victory card stood where its gold, its
## drops and LEVEL UP rose. A title card stands at its height with nothing
## in the way, and clear of what rises otherwise.
func test_a_title_card_stands_clear_of_what_rises() -> void:
	var alone := hud.title_card("Victoire", "L'Appelle-Marée n'est plus.")
	assert_eq(alone.position.y, Hud.CARD_TOP, "nothing in the way: where it stands")
	alone.free()
	var win := Rect2(500, 20, 280, 180)
	world.fx.rising = [win] as Array[Rect2]
	var card := hud.title_card("Victoire", "L'Appelle-Marée n'est plus.")
	assert_false(card.get_rect().intersects(win), "clear of the win and LEVEL UP")
	assert_gt(card.position.y, win.end.y, "under them")


## PIX-378: « Rect2 size is negative » at the start of fights. A message's
## plate not laid out yet (Messages.fit sets it to no size, and its wrapping
## words measure at no width, a letter a line) stood far over the top of the
## screen, and the arrow's area under it came out of a negative height. Only
## a plate on the screen counts, and the area is never negative.
func test_a_plate_not_laid_out_leaves_the_arrow_room() -> void:
	world.messages.message_label.text = "Le Roi Creux se dresse sur son trône et tire son épée de cendre."
	world.messages.message_label.size = Vector2.ZERO
	world.messages.message_box.modulate.a = 1.0
	world.messages.fit()
	# Where Hud.update_objective stands it: grown upward from the line.
	world.messages.message_box.position.y = 682.0 - world.messages.message_box.size.y
	assert_gte(hud._words_top(), 0.0, "on the screen")
	assert_gte(hud.arrow_area().size.y, 0.0, "never negative")
