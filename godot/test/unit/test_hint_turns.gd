extends GutTest
## The dodge's card opened over L'Appelle-Marée's entrance (PIX-341): over
## his bar, his name and his first words. A first-time hint waits while a
## boss makes its entrance, and shows once it falls (or the hero gets away,
## or the fight has gone on a while); and one hint at a time, the next in
## its turn, nothing lost. PIX-433: a hint is one short line on the battle
## log's place, never a box over the view, never two boxes at once. PIX-345:
## a title card stands clear of what rises over the world. PIX-462: a hint
## shows while what it is about is there, or not at all, left unseen.


## The tallest a "Quest accepted" plate may stand (a line more in large
## reading text, French's longest): past that it is the big box over the
## view Tom can't stand (PIX-446, PIX-471: four lines with the quest's
## story, now its name and its pay).
const PLATE_LINES := 2


## Foes as the HUD asks them: the boss hunting the hero, and since when.
class FakeFoes extends RefCounted:
	var boss: Node = null
	var boss_noticed_at := -100.0
	## A foe still on the map (Foes.about).
	var left := true

	func boss_hunting() -> Node:
		return boss

	func about() -> bool:
		return left

	func in_fight(_calm := 0.0) -> bool:
		return false


## What rises over the world, as far as it may yet go (WorldFx.reach).
class FakeFx extends RefCounted:
	var rising: Array[Rect2] = []

	func reach() -> Array[Rect2]:
		return rising


## The map the hero is on, by its id.
class FakeMap extends RefCounted:
	var id := "town"


## What the camera has on the screen, all or nothing, the dock at the foot.
class FakeCamera extends RefCounted:
	var sees := true

	func in_view(_at: Vector2, _margin := 0.0) -> bool:
		return sees

	func dock_top() -> float:
		return 720.0


class FakeWorld extends Node:
	var foes := FakeFoes.new()
	var fx := FakeFx.new()
	var map := FakeMap.new()
	var camera_rig := FakeCamera.new()
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


## PIX-462: the roll's tip came up after the hounds were dead, behind the
## plate all the fight. Its moment gone, it never shows and stays unseen,
## held or waiting; the next foe brings it.
func test_a_hint_past_its_moment_is_not_shown_and_stays_unseen() -> void:
	var chips := world.messages.log_box
	world.messages.flash("The slime was carrying a traveller's pouch.")
	hud.hint("dodge")
	assert_eq([_up(), chips.get_child_count()], ["dodge", 0], "behind the plate")
	world.foes.left = false
	world.messages.update()
	world.messages.message_fade.custom_step(30.0)
	assert_eq([_up(), chips.get_child_count()], ["", 0], "gone with the hounds")
	var card := hud.title_card("Pixelheim", "")
	world.foes.left = true
	hud.hint("dodge")
	world.foes.left = false
	card.free()
	hud.next_hint()
	assert_eq([_up(), hud.hint_held()], ["", ""], "held past its moment: gone")
	assert_false("dodge" in GameState.settings.hints_seen, "unseen, for the next time")
	world.foes.left = true
	hud.hint("dodge")
	assert_eq([_up(), chips.get_child_count()], ["dodge", 1], "the next foe brings it")
	assert_true("dodge" in GameState.settings.hints_seen)


## PIX-462: the board's tip, up as the hero walked past to the hall door,
## came back after the hall's card, inside, where there is no board.
func test_the_board_tip_stays_by_the_board() -> void:
	var chips := world.messages.log_box
	hud.hint("board")
	assert_eq([_up(), chips.get_child_count()], ["board", 1], "the board in sight")
	var card := hud.title_card("Town Hall", "")
	world.messages.update()
	world.map.id = "town_hall"
	world.messages.update()
	card.free()
	world.messages.update()
	var back := chips.get_children().filter(func(chip: Node) -> bool: return not chip.is_queued_for_deletion())
	assert_eq([_up(), back.size()], ["", 0], "not in the hall")
	world.map.id = "town"
	world.camera_rig.sees = false
	assert_false(hud.hint_there("board"), "nor off the screen")


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


## PIX-446: the "Quest accepted" plate says what a quest pays in full.
## PIX-471: and not the quest's story, which the journal holds. The longest,
## the journal's key after its name, fits the plate in English and French,
## in large reading text too, its tag the size of its words.
func test_every_quest_accepted_plate_is_its_name_and_its_pay() -> void:
	for large: bool in [false, true]:
		GameState.settings.large_text = large
		world.messages.message_box.free()
		world.messages.build_plate(hud.root)
		for lang: String in ["en", "fr"]:
			Text.apply(lang)
			var most := 0
			for quest: Dictionary in Quests.all():
				var said := Quests.accepted(quest, true)
				assert_false(String(quest["brief"]) in said, "%s (%s): its story is the journal's" % [quest["id"], lang])
				assert_string_contains(said, String(quest["name"]) + Controls.say(" ({key:journal})."), "where it went, hints off or on")
				assert_false(Controls.say(" ({key:journal})") in Quests.accepted(quest), "the hint seen: the name alone")
				if Quests.pay(quest) != "":
					assert_string_contains(said, Quests.pay(quest), "%s (%s): its pay in full" % [quest["id"], lang])
				var lines := _plate_lines(said)
				assert_lte(lines, PLATE_LINES + int(large), "%s (%s, large %s): %s" % [quest["id"], lang, large, said])
				most = maxi(most, lines)
			gut.p("%s, large text %s: the longest plate %d lines" % [lang, large, most])
		assert_eq(world.messages.message_tag.get_theme_font_size("font_size"), world.messages.message_label.get_theme_font_size("font_size"),
			"the tag as big as the words")
	Text.apply("en")
	Text.apply("fr")
	assert_string_contains(Quests.pay({"reward": {"gold": 70, "xp": 25}}), "70\u202for, 25\u202fXP", "a no-break space between a number and its unit")
	Text.apply("en")
	# The space alone proves no wrap: this binary has ICU's line-break rules
	# built in, an export only with this setting (without it « Rapporte 70 »
	# / « or » parted again on the web build, in large text).
	assert_true(ProjectSettings.get_setting("internationalization/locale/include_text_server_data"), "the export ships the rules that keep them together")


## PIX-471: Maren's tin said who each letter is for and where Bram's crew
## was, four lines over the village. One short line with the journal's key;
## the journal's satchel names them.
func test_marens_letters_are_one_short_line() -> void:
	var given: Array[String] = []
	for quest: Dictionary in Letters.all():
		given.append(quest["objective"]["itemId"])
	for lang: String in ["en", "fr"]:
		Text.apply(lang)
		var said := Controls.say(Letters.taken_line(given))
		assert_eq(_plate_lines(said), 1, "%s: %s" % [lang, said])
		assert_string_contains(said, Controls.say("{key:journal}"), "where they are read")
		assert_lte(said.length(), 60, said)
	Text.apply("en")


# ---- A line shows at its moment or not at all (PIX-476) -------------------

## The log's lines on the screen.
func _lines() -> Array:
	var chips := world.messages.log_box.get_children().filter(func(chip: Node) -> bool: return not chip.is_queued_for_deletion())
	return chips.map(func(chip: Node) -> String: return (chip.get_child(0) as Label).text)


## Poison landed at 2.97 s and its line came up at 6.32 s, behind the roll's
## hint, the orc dead. An ailment's line shows as it lands, the hint stepping
## aside; and goes with its foe.
func test_an_ailment_shows_as_it_lands_and_goes_with_its_foe() -> void:
	var alive := [true]
	hud.hint("dodge")
	assert_eq(_lines().size(), 1, "the roll's hint up")
	world.messages.log_now("Orc Raider is afflicted by burn!", func() -> bool: return alive[0])
	assert_eq(_lines(), ["Orc Raider is afflicted by burn!"], "at once, the hint out of its way")
	assert_eq(_up(), "dodge", "the hint barely shown: back after it")
	world.messages.log_now("Orc Raider is afflicted by poison!", func() -> bool: return alive[0])
	assert_eq(_lines(), ["Orc Raider is afflicted by poison!"], "the newest news has the line")
	alive[0] = false
	world.foes.left = false
	world.messages.update()
	assert_eq([_lines(), _up()], [[], ""], "the orc dead: nothing said of it, no hint for no foe")
	assert_eq(world.messages._log.waiting.size(), 0, "and nothing waits to come back")


## The roll's hint held the log for 5 to 7 s of every fight. Read (up
## HINT_READ_S), it is gone for good when a line of the fight comes; and it
## stays no longer than any line, when every other hint keeps its 5 s.
func test_a_hint_read_gives_its_place_to_the_fight() -> void:
	hud.hint("dodge")
	world.messages._log.showing[0]["since"] -= Messages.HINT_READ_S
	world.messages.log_now("Orc Raider is afflicted by burn!")
	assert_eq([_lines(), _up()], [["Orc Raider is afflicted by burn!"], ""])
	assert_true("dodge" in GameState.settings.hints_seen, "shown once")
	world.messages.clear()
	hud.hint("fright")
	var said: String = _lines()[0]
	var chip: Node = world.messages.log_box.get_child(-1)
	(chip.get_meta("fade") as Tween).custom_step(Messages.HINT_SECONDS - 0.1)
	assert_eq(_up(), "fright", "any hint but the roll's stays HINT_SECONDS at least (PIX-433): %s" % said)
	(chip.get_meta("fade") as Tween).custom_step(0.8)
	assert_eq(_up(), "", "and no longer")
	# The roll's reads as long as a line.
	world.messages.clear()
	GameState.settings.hints_seen.erase("dodge")
	hud.hint("dodge")
	said = _lines()[0]
	chip = world.messages.log_box.get_child(-1)
	(chip.get_meta("fade") as Tween).custom_step(UiStyle.reading_seconds(said) + 0.7)
	assert_eq(_up(), "", "the roll's: as long as a line, no longer: %s" % said)


## A named foe's first notice says the roll's hint, then its « seen » line,
## which waited 3 s behind the hint: the line goes first, the hint unread
## after it; a hint already read goes.
func test_the_rolls_hint_holds_no_line_of_the_fight_back() -> void:
	hud.hint("dodge")
	world.messages.log_line("Greymaw has seen you.")
	assert_eq([_lines(), _up()], [["Greymaw has seen you."], "dodge"])
	world.messages.clear()
	GameState.settings.hints_seen.erase("dodge")
	hud.hint("dodge")
	world.messages._log.showing[0]["since"] -= Messages.HINT_READ_S
	world.messages.log_line("Greymaw has seen you.")
	assert_eq([_lines(), _up()], [["Greymaw has seen you."], ""])


## The burn's line stepped aside for « Not enough MP » and came back 10 s
## after the orc died. A line of the moment the plate kept off the screen
## past NOW_S is dropped, not shown late; any other line still has its turn.
func test_a_line_of_the_moment_is_never_shown_late() -> void:
	world.messages.flash("Not enough MP for Absolution.")
	world.messages.log_now("Orc Raider is afflicted by burn!")
	world.messages.log_line("Greymaw has seen you.")
	assert_eq(_lines(), [], "one box at a time: the plate")
	world.messages._log.waiting[0]["at"] -= Messages.NOW_S + 0.1
	world.messages.message_fade.custom_step(30.0)
	assert_eq(_lines(), ["Greymaw has seen you."], "the burn's moment went; what a player needs is kept")
	# Up when the plate came: it steps aside, and is not back after it.
	world.messages.clear()
	world.messages.log_now("Orc Raider is afflicted by stun!")
	world.messages.flash("No skill on that key yet.")
	world.messages._log.waiting[0]["at"] -= Messages.NOW_S + 0.1
	world.messages.message_fade.custom_step(30.0)
	assert_eq(_lines(), [], "not back 10 s on")


## The Cheese Run handed in 2.4 s after it was taken: the plate kept « Quest
## accepted » 8 s more, the reward unseen. « Quest complete » takes its
## place at once; another quest's stays, and a level is still read.
func test_quest_complete_replaces_its_quest_accepted_at_once() -> void:
	var messages := world.messages
	var taken := Text.t("Quest accepted")
	# With the journal's key after its name, as a first quest's has it.
	messages.flash(taken + ": The Cheese Run (Q). Pays 25 gold, 10 XP.")
	messages.flash(taken + ": Slime Trouble. Pays 40 gold.")
	assert_eq(messages.message_label.text, "The Cheese Run (Q). Pays 25 gold, 10 XP.")
	messages.flash(Text.t("Quest complete") + ": The Cheese Run. +25 gold, +10 XP. \u201cGood.\u201d\n" + Text.t("Level up") + ": you reached level 2.")
	assert_eq(messages.message_tag.text, taken, "another quest's is read out")
	assert_eq(messages.message_label.text, "Slime Trouble. Pays 40 gold.", "the done quest's is gone at once")
	messages.message_fade.custom_step(30.0)
	assert_eq(messages.message_tag.text, Text.t("Quest complete"))
	messages.message_fade.custom_step(30.0)
	assert_eq(messages.message_tag.text, Text.t("Level up"), "what a player needs to read is kept")
	# Still waiting its turn when its quest is done: never shown.
	messages.clear()
	messages.flash(Text.t("Level up") + ": you reached level 3.")
	messages.flash(taken + ": The Cheese Run. Pays 25 gold, 10 XP.")
	messages.flash(Text.t("Quest complete") + ": The Cheese Run. +25 gold, +10 XP.")
	messages.message_fade.custom_step(30.0)
	assert_eq(messages.message_tag.text, Text.t("Quest complete"), "straight to the reward")


## How many lines a message takes on the plate.
func _plate_lines(text: String) -> int:
	world.messages.clear()
	world.messages.flash(text)
	return world.messages.message_label.get_line_count()


## PIX-433: on a phone the log's line ran under the thumbstick.
func test_on_a_phone_the_log_starts_past_the_stick() -> void:
	hud.sky_overlay = ColorRect.new()
	hud.root.add_child(hud.sky_overlay)
	hud.hurt_edge = TextureRect.new()
	hud.root.add_child(hud.hurt_edge)
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
