extends GutTest
## Loot and XP float up where they were won (PIX-245: Tom found the log
## "beaucoup d'écrit"): a kill's XP, gold and drops, a chest's or a patch's
## haul, a catch, a floor's hoard rise from the foe, the chest, the patch, as
## damage numbers do, and the log keeps only what the world doesn't show.
## Wins close together rise as one ("+36 XP", not three "+12 XP"); with
## motion reduced they fade in where they stand.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func after_each() -> void:
	Text.apply("en")


func _texts(gains: Dictionary) -> Array:
	return Gains.rows(gains).map(func(row: Dictionary) -> String: return row["text"])


## The purse is one line (PIX-340: a kill's gold and XP stood one over the
## other among the pack's tags): "+5 gold · +12 XP", then each item.
func test_a_win_reads_its_purse_on_one_line_then_each_item() -> void:
	var win := Gains.none()
	win["xp"] = 12
	win["gold"] = 5
	Gains.add_item(win, "wolf_pelt")
	assert_eq(_texts(win), ["+5 gold", "Wolf Pelt"])
	assert_eq(Gains.rows(win)[0]["then"], "+12 XP", "the XP after the gold, on its line")
	assert_eq(Gains.rows(win).map(func(row: Dictionary) -> String: return row["tone"]), ["gold", "common"])
	assert_eq(Gains.rows(win)[1]["item"], "wolf_pelt", "an item's row carries its icon's id")
	assert_eq(Gains.summary(win), "+5 gold · +12 XP;Wolf Pelt", "the harness's floats=")
	win["gold"] = 0
	assert_eq([_texts(win)[0], Gains.rows(win)[0]["tone"]], ["+12 XP", "xp"], "XP alone is a line of its own")


func test_nothing_won_is_no_row() -> void:
	var win := Gains.none()
	assert_true(Gains.is_empty(win))
	assert_eq(Gains.rows(win), [] as Array[Dictionary])
	win["xp"] = 3
	assert_false(Gains.is_empty(win))
	assert_eq(_texts(win), ["+3 XP"], "never +0 gold")


func test_the_same_item_counts_up_and_gear_keeps_its_rarity() -> void:
	var win := Gains.none()
	Gains.add_item(win, "forest_herb")
	Gains.add_item(win, "forest_herb", 2)
	var piece := InventoryState.create_gear("iron_sword", "fine", func() -> float: return 0.0)
	Gains.add_piece(win, piece)
	var rows := Gains.rows(win)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0]["text"], "Forest Herb x3")
	assert_eq(rows[1]["text"], InventoryState.gear_name(piece), "named as the pack names it")
	assert_string_starts_with(rows[1]["text"], "Fine Iron Sword")
	assert_eq(rows[1]["tone"], "fine", "in its rarity's colour")


func test_merging_adds_up_and_never_shares_a_row() -> void:
	var first := Gains.none()
	first["xp"] = 12
	Gains.add_item(first, "wolf_pelt")
	var second := Gains.none()
	second["xp"] = 12
	second["gold"] = 4
	Gains.add_item(second, "wolf_pelt")
	var total := Gains.merge(Gains.none(), first)
	Gains.merge(total, second)
	assert_eq(Gains.summary(total), "+4 gold · +24 XP;Wolf Pelt x2")
	assert_eq(int(first["items"][0]["count"]), 1, "what was merged in is left as it was")
	assert_eq(int(second["items"][0]["count"]), 1)


func test_wins_close_in_time_and_place_rise_as_one() -> void:
	var at := Vector2(100, 100)
	assert_true(Gains.joins(at, 10.0, at + Vector2(16, 16), 10.4), "the pack's next kill, beside it")
	assert_true(Gains.joins(at, 10.0, at + Vector2(Gains.JOIN_PIXELS, 0), 10.0 + Gains.JOIN_SECONDS), "at the edge of both")
	assert_false(Gains.joins(at, 10.0, at, 10.0 + Gains.JOIN_SECONDS + 0.1), "too late: a new float")
	assert_false(Gains.joins(at, 10.0, at + Vector2(Gains.JOIN_PIXELS + 1, 0), 10.2), "too far: a float of its own")


func test_gains_speak_french() -> void:
	Text.apply("fr")
	var win := Gains.none()
	win["xp"] = 12
	win["gold"] = 5
	Gains.add_item(win, "wolf_pelt", 2)
	var texts := _texts(win)
	assert_eq(Gains.line(Gains.rows(win)[0]), "+5 or · +12 XP", "Tom's « +36 or · +7 XP »")
	assert_string_ends_with(texts[1], " x2")
	assert_ne(texts[1], "Wolf Pelt x2", "the item's name in French")


## A kill: what it won is a win, not lines; the log keeps a tier crossed.
func test_a_kill_floats_its_spoils_and_logs_only_the_rest() -> void:
	state.hero.mastery = {"beasts": 9}
	state.roll = func() -> float: return 0.0  # every drop, every forage
	var won: Dictionary = state.spoils.defeat_monster(Bestiary.wild(Bestiary.spawn("wolf")), "forest", "", 1)
	var gains: Dictionary = won["gains"]
	assert_gt(int(gains["xp"]), 0)
	assert_gt(int(gains["gold"]), 0)
	var ids: Array = gains["items"].map(func(item: Dictionary) -> String: return item["id"])
	assert_has(ids, "wolf_pelt", "what it carries")
	assert_has(ids, "forest_herb", "what was foraged")
	var lines: Array = won["lines"]
	assert_has(lines, "Mastery: Beasts Slayer I. +5% damage against beasts.")
	for line: String in lines:
		for said: String in ["defeated", "drops", "forage", "XP", "gold", "Wolf Pelt", "Forest Herb"]:
			assert_false(line.contains(said), "%s is shown in the world, not said: %s" % [said, line])


func test_a_quests_count_and_a_bounty_stay_in_the_log() -> void:
	state.questing.resolve_quests("innkeeper")
	state.roll = func() -> float: return 0.99
	var won: Dictionary = state.spoils.defeat_monster(Bestiary.spawn("slime"), "", "", 1)
	assert_has(won["lines"], "Slime Trouble: 1/3.")
	assert_false(Gains.is_empty(won["gains"]))
	var named: Array = state.spoils.defeat_monster(Hunts.fighter("greymaw"), "forest", "", 1)["lines"]
	assert_true(named.any(func(line: String) -> bool: return line.contains("bounty on Old Greymaw")), "a bounty is a quest's end")


func test_a_level_gained_still_goes_on_the_plate() -> void:
	state.roll = func() -> float: return 0.99
	state.hero.xp = state.hero.xp_to_next - 1
	var lines: Array = state.spoils.defeat_monster(Bestiary.spawn("wolf"), "", "", 1)["lines"]
	assert_true(lines.any(func(line: String) -> bool: return line.begins_with("Level up: ")), "the level-up moment stays as it was")


func test_a_chest_floats_its_loot_and_a_mimic_still_speaks() -> void:
	var chests: Array = Interactables._data()["chests"]
	var mimic: Dictionary = chests.filter(func(chest: Dictionary) -> bool: return chest.get("mimic", false))[0]
	var bite: Dictionary = state.spoils.open_chest(mimic)
	assert_eq(bite["message"], "The chest bares its teeth — a mimic!", "not loot: words")
	assert_true(Gains.is_empty(bite["gains"]))
	var nook: Dictionary = chests.filter(func(chest: Dictionary) -> bool: return chest["id"] == "town_nook")[0]
	var opened: Dictionary = state.spoils.open_chest(nook)
	assert_eq([opened["message"], Gains.summary(opened["gains"])], ["", "+60 gold"])


## A hoard's piece floats up from its chest (PIX-257: the old floors' hoards
## went to the regions' bottom floors and the Kings' Vault, where its finds
## come forged deep).
func test_a_hoards_piece_floats_up_forged() -> void:
	var chest: Dictionary = Interactables._data()["chests"].filter(func(entry: Dictionary) -> bool: return entry["id"] == "vault_blade")[0]
	var opened: Dictionary = state.spoils.open_chest(chest)
	assert_true(opened["opened"])
	var ids: Array = opened["gains"]["items"].map(func(item: Dictionary) -> String: return item["id"])
	assert_has(ids, "obsidian_blade", "the hoard's piece")
	var piece: Dictionary = state.pack.gear[-1]
	assert_eq([piece["itemId"], int(piece["deep"]), piece["rarity"]], ["obsidian_blade", 1, "fine"], "forged as deep as its floor")
	assert_eq(opened["message"], String(chest["said"]), "and the find says what it is")


func test_a_patch_and_a_catch_float_up() -> void:
	state.roll = func() -> float: return 0.99
	state.world.steps = 50.0
	var picked: Dictionary = state.spoils.gather("forest_patch_1", "forest_herb")
	assert_eq(Gains.summary(picked["gains"]), "Forest Herb")
	state.roll = func() -> float: return 0.0
	var cast: Dictionary = state.spoils.fish("frostgate_hole")
	assert_eq([cast["message"], Gains.summary(cast["gains"])], ["", "Icefin"])


## The world's floats (WorldFx, PIX-245): three kills of a pack in a breath
## rise as one float that counts up; a kill far off rises on its own.
func test_kills_close_together_rise_as_one_float() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var win := Gains.none()
	win["xp"] = 12
	win["gold"] = 5
	for i in 3:
		fx.show_gains(win, Vector2(100 + i * 16, 50))
	assert_eq(fx.get_child_count(), 1, "one float for the three")
	var rows: Array = fx.get_child(0).get_children()
	assert_eq(rows.map(func(row: Node) -> String: return (row.get_node("text") as Label).text + " " + (row.get_node("then") as Label).text), ["+15 gold · +36 XP"], "one line")
	fx.show_gains(win, Vector2(400, 50))
	assert_eq(fx.get_child_count(), 2, "a kill far off rises on its own")
	assert_eq(Gains.summary(fx.floated), "+20 gold · +48 XP", "the harness's record of it all")


## XP first, then gold beside it: the XP's line gives way to the purse's.
func test_xp_then_gold_comes_together_on_one_line() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var xp := Gains.none()
	xp["xp"] = 7
	fx.show_gains(xp, Vector2(100, 50))
	var gold := Gains.none()
	gold["gold"] = 36
	fx.show_gains(gold, Vector2(100, 50))
	await wait_physics_frames(1)
	var rows: Array = fx.get_child(0).get_children().filter(func(row: Node) -> bool: return not row.is_queued_for_deletion())
	assert_eq(rows.size(), 1, "one line, not two")
	assert_eq((rows[0].get_node("then") as Label).text, "· +7 XP")


func test_a_win_rises_and_a_fine_piece_bursts_in() -> void:
	var was: bool = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var win := Gains.none()
	win["xp"] = 12
	Gains.add_piece(win, InventoryState.create_gear("iron_sword", "epic", func() -> float: return 0.0))
	fx.show_gains(win, Vector2(100, 50))
	var box: Node2D = fx.get_child(0)
	assert_eq((box.get_child(1) as Node2D).scale, Vector2.ONE * 2.0, "an epic piece bursts in")
	await wait_seconds(0.5)
	assert_lt(box.position.y, 50.0, "it rises")
	GameState.settings.reduce_motion = was


func test_with_motion_reduced_a_win_fades_in_where_it_stands() -> void:
	var was: bool = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = true
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var win := Gains.none()
	win["xp"] = 12
	Gains.add_piece(win, InventoryState.create_gear("iron_sword", "epic", func() -> float: return 0.0))
	fx.show_gains(win, Vector2(100, 50))
	var box: Node2D = fx.get_child(0)
	assert_eq(box.position, Vector2(100, 50 - WorldFx.GAIN_STILL_LIFT), "clear of the damage numbers' whole path")
	await wait_seconds(0.5)
	assert_eq(box.position, Vector2(100, 50 - WorldFx.GAIN_STILL_LIFT), "no float")
	for row: Node2D in box.get_children():
		assert_eq(row.scale, Vector2.ONE, "no burst")
		assert_almost_eq(row.modulate.a, 1.0, 0.01, "just a fade in")
	GameState.settings.reduce_motion = was


## PIX-484: on the sand path a gold "+10" read "+11" and a "30" "31": the
## pixel face's own outline drew only inside the letters. Every word over
## the world (a number, a word, a win's rows) is the UI's bold face at the
## label scale (PIX-549), a font pixel a screen pixel at play zoom, with a
## real outline in the dark.
func test_every_floating_word_is_the_bold_face_outlined_in_the_dark() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var win := Gains.none()
	win["gold"] = 10
	win["xp"] = 7
	fx.show_gains(win, Vector2(100, 50))
	fx.float_number(30, Vector2(40, 40), Color(1, 0.35, 0.35))
	fx.float_text("-10 gold", Vector2(60, 40), UiStyle.GOLD)
	var labels := fx.find_children("*", "Label", true, false)
	assert_eq(labels.size(), 4, "the gold, its XP, a number and a word")
	for label: Label in labels:
		var look := label.label_settings
		assert_eq(look.font, UiStyle.bold_font(), "%s: Nunito Bold" % label.text)
		assert_eq(look.font_size, 24, "%s: 24 px on the canvas" % label.text)
		assert_eq(label.scale, Vector2.ONE * CameraRig.LABEL_SCALE, "%s: at the label scale" % label.text)
		assert_eq(look.outline_size, 8, "%s: outlined, two pixels each side" % label.text)
		assert_eq(look.outline_color, UiStyle.NIGHT, "%s: in the dark" % label.text)
		assert_eq(look.stacked_shadow_count, 0, "%s: no stacked ring" % label.text)
		assert_ne(look.font, UiStyle.pixel_font(), "%s: not the pixel face" % label.text)
	assert_eq((labels[0] as Label).label_settings.font_color, WorldFx.GAIN_TONES["gold"], "in its own colour still")


## PIX-549: a label a third of its box is moved by its pivot, so a word
## bursting in (LEVEL UP, a crit) stood off its spot until _pop gave that
## back: its ink's middle stays on the spot at twice the size and at rest.
func test_a_word_bursting_in_stays_on_its_spot() -> void:
	var was: bool = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	fx.float_text("LEVEL UP", Vector2(100, 50), UiStyle.GOLD, true)
	var word: Label = fx.get_child(0).get_child(0)
	var middle := WorldFx.ink_of("LEVEL UP").get_center()
	assert_eq(word.scale, Vector2.ONE * 2.0 * CameraRig.LABEL_SCALE, "twice the size at first")
	for size: float in [2.0, 1.0]:
		word.scale = Vector2.ONE * size * CameraRig.LABEL_SCALE
		var drawn: Vector2 = word.get_global_transform() * (middle / CameraRig.LABEL_SCALE)
		assert_almost_eq(drawn.x, 100.0, 0.51, "its middle on the spot at %sx" % size)
		assert_almost_eq(drawn.y, 50.0 + middle.y, 0.01, "and no higher at %sx" % size)
	GameState.settings.reduce_motion = was


## PIX-549: the French words that ran widest over the world take no more
## room in Nunito than the pixel face gave them.
func test_the_long_french_words_are_no_wider_than_they_were() -> void:
	for words: String in ["NIVEAU SUPÉRIEUR", "Superbe casque de cuir", "Interrompu\u202f!"]:
		var before := Ink.of_text(words, UiStyle.pixel_font(), UiStyle.BODY_PX).size.x
		assert_gt(WorldFx.ink_of(words).size.x, 0.0, "%s: measured" % words)
		assert_lt(WorldFx.ink_of(words).size.x, before, "%s: narrower than in the pixel face" % words)
