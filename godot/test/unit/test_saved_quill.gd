extends GutTest
## When the game saves, and what shows it (PIX-302 step 4): a moment (a
## door, a chest, a step of a quest, buying, funding, a skill, a screen left
## after a change, the title, the language) is saved at once and the quill
## by the clock writes; the autosave every few seconds and the saves on
## leaving are quiet; a night's sleep shows the quill with "Saved" under it.
## The pause menu says how long ago the last save was.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node
## How each save made showed, in order.
var shown: Array[int] = []


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	shown.clear()
	state.saved.connect(func(how: int) -> void: shown.append(how))


func after_each() -> void:
	get_tree().paused = false
	GameState.settings.reduce_motion = false
	Text.apply("en")


func test_the_autosave_is_quiet() -> void:
	state.move_to(MapData.load_by_id("town"), Vector2i(40, 30), Vector2.DOWN)
	state._process(GameStateScript.AUTOSAVE_SECONDS - 0.5)
	assert_eq(shown, [] as Array[int], "not yet")
	state._process(1.0)
	assert_eq(shown, [GameStateScript.QUIET] as Array[int], "walking is kept within seconds, quietly")
	assert_false(state.dirty)
	state._process(10.0)
	assert_eq(shown.size(), 1, "nothing new, nothing saved")


func test_leaving_saves_quietly() -> void:
	state.mark_dirty()
	state._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(shown, [GameStateScript.QUIET] as Array[int])


func test_a_chest_is_a_moment() -> void:
	var chest: Dictionary = Interactables.chests_on("town")[0]
	state.spoils.open_chest(chest)
	assert_eq(shown, [GameStateScript.MOMENT] as Array[int])
	assert_false(state.dirty)


func test_a_night_at_the_inn_says_saved() -> void:
	state.pack.gold = 500
	state.upkeep.rest_at_inn()
	assert_eq(shown, [GameStateScript.SLEPT] as Array[int], "once, as the hero wakes")
	assert_false(state.dirty, "the rest it gave kept too")


func test_a_night_in_your_own_bed_says_saved() -> void:
	state.settlement.house["owned"] = true
	state.world.map_id = "town_house"
	state.household.house_interact(Vector2i(-1, -1), "bed")
	assert_eq(shown, [GameStateScript.SLEPT] as Array[int])


func test_buying_is_kept_at_once() -> void:
	state.pack.gold = 500
	state.trade.stall_shop = "odo"
	var wares: Array = state.trade.shop_wares("odo")
	assert_false(wares.is_empty())
	assert_true(state.trade.buy_item(String(wares[0])))
	assert_eq(shown, [GameStateScript.MOMENT] as Array[int])


func test_the_clock_and_the_count_of_saves() -> void:
	var made: int = state.saves_made
	state.save_now(GameStateScript.QUIET)
	assert_eq(state.saves_made, made + 1)
	assert_almost_eq(state.saved_clock, GameClock.seconds(), 0.001, "when, by the game's clock")


## A screen let go after a change saves, even when the autosave kept it
## while the screen was open: leaving it is the moment the quill shows.
func test_leaving_a_screen_after_a_change_is_a_moment() -> void:
	var seen: Array[int] = []
	var note := func(how: int) -> void: seen.append(how)
	GameState.saved.connect(note)
	var screen := Screen.new()
	add_child_autofree(screen)
	GameState.mark_dirty()
	GameState.save_now(GameState.QUIET)
	screen.close()
	GameState.saved.disconnect(note)
	assert_eq(seen, [GameState.QUIET, GameState.MOMENT] as Array[int])


func test_leaving_a_screen_with_nothing_changed_saves_nothing() -> void:
	var seen: Array[int] = []
	var note := func(how: int) -> void: seen.append(how)
	GameState.saved.connect(note)
	var screen := Screen.new()
	add_child_autofree(screen)
	screen.close()
	GameState.saved.disconnect(note)
	assert_eq(seen, [] as Array[int])


# ---- The quill ---------------------------------------------------------------------

func _quill() -> Hud.Quill:
	var quill := Hud.Quill.new()
	add_child_autofree(quill)
	return quill


func test_the_quill_writes_for_about_a_second_then_goes() -> void:
	var quill := _quill()
	assert_false(quill.visible, "away until a moment is saved")
	quill.write(false)
	assert_true(quill.writing())
	assert_true(quill.visible)
	quill._process(0.5)
	assert_true(quill.writing(), "still writing")
	assert_eq(quill.modulate.a, 1.0)
	quill._process(Hud.Quill.WRITES - 0.5 + Hud.Quill.STAYS / 2.0)
	assert_between(quill.modulate.a, 0.1, 0.9, "fading once the line is written")
	quill._process(Hud.Quill.STAYS)
	assert_false(quill.writing())
	assert_false(quill.visible)
	assert_eq(quill.writes, 1)


func test_with_reduce_motion_it_simply_appears_and_goes() -> void:
	GameState.settings.reduce_motion = true
	var quill := _quill()
	quill.write(false)
	quill._process(0.05)
	assert_eq(quill._step, Hud.Quill.LINE.size() - 1, "the line written at once")
	quill._process(Hud.Quill.WRITES + Hud.Quill.STAYS - 0.2)
	assert_eq(quill.modulate.a, 1.0, "no fading")
	quill._process(0.3)
	assert_false(quill.visible)


func test_a_nights_sleep_says_saved_under_it() -> void:
	var quill := _quill()
	quill.write(true)
	assert_true(quill.slept)
	assert_true(quill._word.visible)
	assert_eq((quill._word.get_child(0) as Label).text, "Saved")
	quill._process(Hud.Quill.WRITES + Hud.Quill.STAYS)
	assert_true(quill.writing(), "the word stays to be read")
	quill.write(false)
	assert_false(quill._word.visible, "a moment after it has no word")


func test_the_quill_is_pixel_art_ringed_in_the_night() -> void:
	var art := Marks.lettered(Marks.QUILL, Marks.QUILL_INKS)
	assert_eq(art.get_pixelv(Marks.QUILL_NIB), UiStyle.BRASS_DARK, "the nib's point where it writes")
	assert_eq(Marks.quill().get_width(), String(Marks.QUILL[0]).length() * UiStyle.UI_SCALE)
	for row: String in Marks.QUILL:
		assert_eq(row.length(), String(Marks.QUILL[0]).length())


# ---- The pause menu's line ---------------------------------------------------------

func test_the_pause_line_says_how_long_ago() -> void:
	assert_eq(SlotCard.saved_ago(0), "Saved just now")
	assert_eq(SlotCard.saved_ago(12), "Saved 12 s ago")
	assert_eq(SlotCard.saved_ago(59), "Saved 59 s ago")
	assert_eq(SlotCard.saved_ago(3 * 60 + 20), "Saved 3 min ago")
	assert_eq(SlotCard.saved_ago(2 * 3600 + 5), "Saved 2 h ago")


func test_the_pause_line_reads_in_french() -> void:
	Text.apply("fr")
	assert_eq(SlotCard.saved_ago(0), "Sauvegardé à l'instant")
	assert_eq(SlotCard.saved_ago(12), "Sauvegardé il y a 12 s")
	assert_eq(SlotCard.saved_ago(3 * 60), "Sauvegardé il y a 3 min")
	assert_eq(SlotCard.saved_ago(2 * 3600), "Sauvegardé il y a 2 h")


func test_the_pause_menu_shows_the_line_under_its_title() -> void:
	GameState.save_now(GameState.QUIET)
	var pause := preload("res://scripts/pause_screen.gd").new()
	add_child_autofree(pause)
	assert_true(pause.saved_line.visible)
	assert_eq(pause.saved_line.text, "Saved just now")
	assert_eq(pause.saved_line.get_parent().get_child(1), pause.saved_line, "right under the title")
	pause.close()
