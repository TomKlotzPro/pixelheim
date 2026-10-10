extends GutTest
## The journal (PIX-239), driven as a player would: what you're on now at the
## top in the words of the line above the dock, the threads below it, and
## choosing which to follow - the arrows and E, the pad's D-pad and A,
## pointing and clicking. Liane's pages and the feats a tab away. Played on
## a throwaway hero lent to GameState, given back after each test.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const JournalScreen := preload("res://scripts/journal_screen.gd")

var screen: Node
var _lent: Node
var _kept := {}


func before_each() -> void:
	Controls.apply({})
	_kept = {
		"hero": GameState.hero, "pack": GameState.pack, "settlement": GameState.settlement,
		"progression": GameState.progression, "dirty": GameState.dirty,
	}
	_lent = GameStateScript.new()
	_lent.new_game("Robin", "warrior")
	GameState.hero = _lent.hero
	GameState.pack = _lent.pack
	GameState.settlement = _lent.settlement
	GameState.progression = _lent.progression
	# The harness's `journal`: the slimes part done, the cheese ready, the
	# rum; Maren's relics and the Black Seam carrying the story; a bounty up.
	GameState.progression.quests.merge({
		"slime_trouble": {"progress": 2, "done": false},
		"cheese_run": {"progress": 0, "done": false},
		"maren_relics": {"progress": 0, "done": false},
		"garrick_seam": {"progress": 0, "done": false},
		"sela_rum": {"progress": 0, "done": false},
	})
	GameState.progression.cleared_levels.append(2)


func after_each() -> void:
	if is_instance_valid(screen):
		screen.close()
	screen = null
	for key: String in ["hero", "pack", "settlement", "progression"]:
		GameState.set(key, _kept[key])
	GameState.dirty = _kept["dirty"]
	_lent.free()
	Controls.pad = false
	await get_tree().process_frame
	get_tree().paused = false


func _open(tab := "") -> Node:
	screen = JournalScreen.new()
	if tab != "":
		screen.tab = tab
	add_child(screen)
	return screen


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	screen._unhandled_input(event)


func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	screen._unhandled_input(event)


func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	control.gui_input.emit(event)


func _lead() -> Dictionary:
	return Bearing.active(GameState.progression, GameState.settlement, GameState.pack.items)


func _row_of(id: String) -> int:
	return screen.rows.map(func(row: Dictionary) -> String: return row["id"]).find(id)


## Which rows wear FOLLOWING.
func _marked() -> Array:
	var out := []
	for at in screen.cards.size():
		if screen.cards[at]["tag"].visible:
			out.append(screen.rows[at]["id"])
	return out


func test_the_top_says_what_the_line_above_the_dock_says() -> void:
	_open()
	var lead := _lead()
	assert_true(lead["main"], "nothing chosen: the main story leads")
	assert_eq(screen.now_step.text, lead["step"], "the step, word for word")
	assert_string_starts_with(Bearing.line(lead), screen.now_step.text, "as the line above the dock begins")
	assert_eq(screen.followed, Journal.STORY)
	assert_eq(_marked(), [Journal.STORY], "the story's row is marked followed")
	assert_eq(screen.selected, 0, "and chosen")


func test_the_keys_choose_and_e_follows() -> void:
	_open()
	var slimes := _row_of("slime_trouble")
	for i in slimes:
		_key(KEY_S)
	assert_eq(screen.selected, slimes)
	assert_eq(screen.detail.text, screen.rows[slimes]["detail"], "the strip under the list says what was asked")
	assert_eq(GameState.progression.tracked, "", "choosing isn't following")
	_key(KEY_E)
	assert_eq(GameState.progression.tracked, "slime_trouble", "E follows it")
	assert_true(GameState.dirty, "and the save will keep it")
	assert_eq(_marked(), ["slime_trouble"], "the mark moves to it")
	assert_eq(screen.now_step.text, _lead()["step"], "the top turns to it")
	assert_eq(_lead()["quest_id"], "slime_trouble", "and so does the line above the dock")
	assert_eq(screen.now_place.text, _lead()["place"], "with where to go")


func test_following_the_story_again_follows_nothing_else() -> void:
	GameState.progression.tracked = "sela_rum"
	_open()
	assert_eq(screen.selected, _row_of("sela_rum"), "the journal opens on the thread followed")
	_key(KEY_W)
	while screen.selected != 0:
		_key(KEY_W)
	_key(KEY_ENTER)
	assert_eq(GameState.progression.tracked, "", "the main story again")
	assert_eq(_marked(), [Journal.STORY])


func test_up_from_the_first_wraps_to_the_last() -> void:
	_open()
	_key(KEY_UP)
	assert_eq(screen.selected, screen.rows.size() - 1)
	assert_eq(screen.rows[screen.selected]["group"], "bounties", "the board's notice comes last")


func test_the_pad_chooses_and_a_follows() -> void:
	_open()
	_pad(JOY_BUTTON_DPAD_UP)
	_pad(JOY_BUTTON_A)
	assert_eq(GameState.progression.tracked, "greymaw", "a bounty followed")
	assert_eq(_lead()["named"], "greymaw")
	assert_string_contains(screen.now_step.text, Hunts.named("greymaw")["name"])


func test_pointing_chooses_and_a_click_follows() -> void:
	_open()
	var cheese := _row_of("cheese_run")
	var card: Control = screen.cards[cheese]["card"]
	card.mouse_entered.emit()
	assert_eq(screen.selected, cheese, "pointing chooses")
	assert_eq(GameState.progression.tracked, "")
	_click(card)
	assert_eq(GameState.progression.tracked, "cheese_run", "a click follows")
	assert_eq(_marked(), ["cheese_run"])


func test_ready_says_so_at_the_top_and_on_its_row() -> void:
	GameState.progression.tracked = "cheese_run"
	_open()
	var labels: Array = screen.now_box.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_true(Text.t("READY") in labels, "READY at the top")
	assert_string_starts_with(screen.now_step.text, "Hand it in to", "and to whom")
	var row: Control = screen.cards[_row_of("cheese_run")]["card"]
	var on_row: Array = row.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_true(Text.t("READY") in on_row, "and on its row")


func test_the_tabs_turn_and_hold_the_letters_and_feats() -> void:
	_open()
	_key(KEY_D)
	assert_eq(screen.tab, "letters")
	assert_null(screen.now_step, "the quests' top is the quests'")
	_key(KEY_D)
	assert_eq(screen.tab, "feats")
	_key(KEY_D)
	assert_eq(screen.tab, "quests", "round again")
	_click(screen.tabs_row.get_child(2))
	assert_eq(screen.tab, "feats", "a click on a tab opens it")
	_key(KEY_E)
	assert_eq(GameState.progression.tracked, "", "E follows nothing off the quests")


func test_the_old_chapters_open_their_new_pages() -> void:
	_open("story")
	assert_eq(screen.tab, "letters", "Story was Liane's pages, and they're under the letters now")
	screen.close()
	_open("pages")
	assert_eq(screen.tab, "letters", "so are Liane's pages")
	screen.close()
	_open("bounties")
	assert_eq(screen.tab, "quests", "the bounties are threads among the rest")


func test_older_papers_turn() -> void:
	GameState.progression.cleared_levels.assign(range(1, 16))
	_open("letters")
	assert_eq(screen.pages.size(), Story.found_pages(GameState.progression.cleared_levels).size(), "no letters yet: every page found, in its order")
	assert_gt(screen.pages.size(), 1)
	# Laid out, so the page knows how far it runs.
	await wait_process_frames(2)
	var runs_over: bool = screen.pages[-1].get_parent().size.y > screen.scroll.size.y
	_key(KEY_S)
	assert_eq(screen.from, 1 if runs_over else 0, "S turns to the next while there's more below")
	_key(KEY_W)
	assert_eq(screen.from, 0, "W turns back")


## Every Label's words on the page shown.
func _words() -> Array:
	return screen.content.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)


func _says(fragment: String) -> bool:
	return _words().any(func(text: String) -> bool: return fragment in text)


# ---- The courier's satchel (PIX-253 step 2) ------------------------------------

func test_the_main_story_is_the_satchel() -> void:
	GameState.questing.open_tin()
	GameState.questing.deliver("saltmere_wenna")
	_open()
	var story: Array = screen.rows.filter(func(row: Dictionary) -> bool: return row["group"] == "story").map(func(row: Dictionary) -> String: return row["id"])
	assert_eq(story.slice(0, 5), [Journal.STORY, "letter_wenna", "letter_pell", "letter_hale", "letter_aske"])
	assert_true(_says("The courier's satchel"), "named over the letters")
	assert_true(_says("Letter to Old Wenna, Saltmere"))
	assert_true(_says("Letter to Morvax: Maren keeps this one."), "and the fifth, that she keeps")
	var wenna := _row_of("letter_wenna")
	var on_row: Array = screen.cards[wenna]["card"].find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_true(Text.t("DELIVERED") in on_row, "delivered, on its row")
	assert_true("Wenna answered, with Tam's last postcard." in on_row, "and who answered")
	for i in wenna:
		_key(KEY_S)
	assert_string_contains(screen.detail.text, "I've brought cheese.", "chosen, its answer under the list")
	_key(KEY_E)
	assert_eq(GameState.progression.tracked, "", "a letter delivered isn't followed")
	assert_eq(_marked(), [Journal.STORY])
	for i in _row_of("letter_pell") - wenna:
		_key(KEY_S)
	_key(KEY_E)
	assert_eq(GameState.progression.tracked, "letter_pell", "one to deliver is")
	assert_eq(_lead()["who"], "mines_pell", "to Old Pell")


func test_the_letters_tab_reads_a_letter_only_once_it_is_delivered() -> void:
	_open("letters")
	assert_true(_says("Nothing in your satchel yet"), "before the tin")
	assert_true(screen.pages.is_empty(), "nothing to turn")
	assert_false(_says("Older papers"), "no pages found, no older papers")
	screen.close()
	GameState.questing.open_tin()
	GameState.questing.deliver("saltmere_wenna")
	_open("letters")
	assert_true(_says("Maren's letters - 1 of 4 delivered"))
	assert_eq(screen.pages.size(), 5, "four letters and the fifth")
	var wenna: Dictionary = Quests.by_id("letter_wenna")
	for line: String in wenna["letter"]:
		assert_true(_says(line), "Maren's words to Wenna, delivered: %s" % line)
	assert_true(_says(wenna["answered"]))
	for line: String in wenna["answer"]:
		assert_true(_says(line), "and Wenna's answer: %s" % line)
	var pell: Dictionary = Quests.by_id("letter_pell")
	assert_false(_says(pell["letter"][0]), "a sealed letter isn't read")
	assert_false(_says(pell["answer"][0]))
	assert_true(_says("A courier never reads the post."))
	assert_true(_says("Maren keeps this one. It has no address."))
	assert_false(_says("Older papers"), "no pages found, no older papers")


func test_older_papers_are_kept_for_a_hero_who_found_pages() -> void:
	GameState.questing.open_tin()
	GameState.progression.cleared_levels.assign([1, 2, 3])
	_open("letters")
	assert_true(_says("Older papers"), "under the letters")
	assert_true(_says("Pages of Liane's journal, found on the mountain: 2 of 10."))
	for page: Dictionary in Story.found_pages([1, 3]):
		assert_true(_says(page["title"]), page["title"])
	assert_eq(screen.pages.size(), 5 + 2, "the letters, then each page to turn to")
	assert_false(_says(Story.lore()[2]["title"]), "only the pages of floors cleared")


func test_q_closes_it() -> void:
	_open()
	_key(KEY_Q)
	assert_true(screen.is_queued_for_deletion(), "its own key closes it")
