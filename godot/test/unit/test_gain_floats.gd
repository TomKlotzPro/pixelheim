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


func test_a_win_reads_xp_then_gold_then_each_item() -> void:
	var win := Gains.none()
	win["xp"] = 12
	win["gold"] = 5
	Gains.add_item(win, "wolf_pelt")
	assert_eq(_texts(win), ["+12 XP", "+5 gold", "Wolf Pelt"])
	assert_eq(Gains.rows(win).map(func(row: Dictionary) -> String: return row["tone"]), ["xp", "gold", "common"])
	assert_eq(Gains.rows(win)[2]["item"], "wolf_pelt", "an item's row carries its icon's id")
	assert_eq(Gains.summary(win), "+12 XP;+5 gold;Wolf Pelt", "the harness's floats=")


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
	assert_eq(_texts(total), ["+24 XP", "+4 gold", "Wolf Pelt x2"])
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
	assert_eq(texts.slice(0, 2), ["+12 XP", "+5 or"])
	assert_string_ends_with(texts[2], " x2")
	assert_ne(texts[2], "Wolf Pelt x2", "the item's name in French")


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


func test_a_floors_hoard_floats_with_the_way_downs_xp() -> void:
	var result: Dictionary = state.spoils.clear_floor(5)
	var floor_def := Dungeons.floor_def(5)
	var gains: Dictionary = result["gains"]
	assert_eq(int(gains["gold"]), int(floor_def["rewardGold"]))
	assert_eq(int(gains["xp"]), Dungeons.clear_xp(5))
	var ids: Array = gains["items"].map(func(item: Dictionary) -> String: return item["id"])
	assert_has(ids, "wyrm_visor", "the hoard's piece")
	var lines: Array = result["lines"]
	assert_eq(lines[0], "%s is cleared!" % floor_def["name"], "the moment is still said")
	assert_false(lines.any(func(line: String) -> bool: return line.contains("hoard") or line.contains("way down")), "the hoard isn't: %s" % [lines])


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
	assert_eq(rows.map(func(row: Node) -> String: return (row.get_node("text") as Label).text), ["+36 XP", "+15 gold"])
	fx.show_gains(win, Vector2(400, 50))
	assert_eq(fx.get_child_count(), 2, "a kill far off rises on its own")
	assert_eq(Gains.summary(fx.floated), "+48 XP;+20 gold", "the harness's record of it all")


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
