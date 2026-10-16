extends GutTest
## The Saves screen (PIX-302 step 3): each hero's card says who they are,
## where, how far into the story, how long played and when last saved;
## Duplicate copies a hero into an empty slot or says there's none; Delete
## asks, keeps the hero aside, and R brings them back until another hero
## takes the slot; Copy and Paste carry a hero as a code, and a code pasted
## over a hero asks first. Runs against a throwaway user:// folder.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const SavesScreen := preload("res://scripts/saves_screen.gd")
const DIR := "user://test_saves_screen"
## A clock for the "saved ... ago" line: 2026-10-16, noon.
const NOW := 1792152000

var slots: SaveSlots
var _kept: SaveSlots
var _kept_slot := 0
var _screen: Screen


func before_each() -> void:
	_wipe()
	slots = SaveSlots.new(DIR)
	_kept = GameState.slots
	GameState.slots = slots
	# No hero in hand in these slots: nothing here plays one or reloads.
	_kept_slot = GameState.slot
	GameState.slot = GameState.NO_SLOT
	Text.apply("en")


func after_each() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.close()
		_screen = null
	GameState.slots = _kept
	GameState.slot = _kept_slot
	Text.apply("en")
	await get_tree().process_frame
	get_tree().paused = false


func after_all() -> void:
	_wipe()


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file])
	DirAccess.remove_absolute(DIR)


## A hero's save: `name`, a ranger with `gold`.
func _hero(name: String, gold := 30) -> Dictionary:
	var game: Node = autofree(GameStateScript.new())
	game.new_game(name, "ranger")
	game.pack.gold = gold
	return game.to_dict()


## The screen open over the slots, `index` chosen.
func _open(index := 0) -> Screen:
	_screen = SavesScreen.new()
	add_child(_screen)
	await wait_process_frames(2)
	_screen._select(index)
	return _screen


## A summary as a slot's card gives it.
func _card(chapter: int, play_seconds: int, saved_at := NOW) -> Dictionary:
	return {
		"kind": SaveSlots.HERO, "name": "Bryn", "roleId": "ranger", "level": 13, "mapId": "saltmere",
		"chapter": chapter, "playSeconds": play_seconds, "savedAt": saved_at,
	}


# ---- The card's lines ---------------------------------------------------------

func test_the_card_says_class_and_level() -> void:
	assert_eq(SlotCard.who(_card(3, 0)), "Ranger, level 13")


func test_the_card_names_the_place_and_the_chapter() -> void:
	assert_eq(SlotCard.where(_card(3, 0)), "Saltmere · Chapter 3: The Letter to Blackiron")
	assert_eq(SlotCard.chapter(0), "The Night of Ash", "the prologue")
	assert_eq(SlotCard.chapter(1), "Chapter 1: Out of the Ashes")
	assert_eq(SlotCard.chapter(8), "Chapter 8: Coming Home")
	assert_eq(SlotCard.chapter(MainQuest.chapters().size() + 1), "After the story", "the story told")


func test_play_time_reads_in_hours_and_minutes() -> void:
	assert_eq(SlotCard.played(0), "Just begun")
	assert_eq(SlotCard.played(59), "Just begun")
	assert_eq(SlotCard.played(60), "1 min played")
	assert_eq(SlotCard.played(12 * 60 + 30), "12 min played")
	assert_eq(SlotCard.played(4 * 3600 + 12 * 60), "4 h 12 min played")
	assert_eq(SlotCard.played(2 * 3600), "2 h played", "no 0 min")
	assert_eq(SlotCard.played(31 * 3600 + 40 * 60), "31 h played", "the hours alone past ten")


func test_the_last_save_reads_how_long_ago() -> void:
	assert_eq(SlotCard.ago(NOW - 20, NOW), "just now")
	assert_eq(SlotCard.ago(NOW + 3600, NOW), "just now", "a clock set back")
	assert_eq(SlotCard.ago(0, NOW), "just now", "no time written")
	assert_eq(SlotCard.ago(NOW - 5 * 60, NOW), "5 min ago")
	assert_eq(SlotCard.ago(NOW - 3600, NOW), "1 hour ago")
	assert_eq(SlotCard.ago(NOW - 7 * 3600, NOW), "7 hours ago")
	assert_eq(SlotCard.ago(NOW - 86400, NOW), "yesterday")
	assert_eq(SlotCard.ago(NOW - 9 * 86400, NOW), "9 days ago")
	assert_eq(SlotCard.when(_card(3, 4 * 3600 + 12 * 60, NOW - 30), NOW), "4 h 12 min played · saved just now")


func test_the_card_reads_in_french() -> void:
	Text.apply("fr")
	assert_eq(SlotCard.who(_card(3, 0)), "Rôdeur, niveau 13")
	assert_eq(SlotCard.chapter(0), "La Nuit des Cendres")
	assert_eq(SlotCard.chapter(3), "Chapitre 3 : La lettre pour Fernoir")
	assert_eq(SlotCard.chapter(MainQuest.chapters().size() + 1), "Après l'histoire")
	assert_eq(SlotCard.when(_card(3, 4 * 3600 + 12 * 60, NOW - 30), NOW), "4 h 12 min de jeu · sauvegardé à l'instant")
	assert_eq(SlotCard.played(5), "Tout juste commencé")


func test_a_saved_heros_card_carries_its_chapter_and_hours() -> void:
	var state := _hero("Bryn")
	state["playSeconds"] = 15120
	slots.write(1, state)
	var summary := slots.summary(1)
	assert_eq(summary["chapter"], 1)
	assert_eq(SlotCard.when(summary, int(Time.get_unix_time_from_system())), "4 h 12 min played · saved just now")


func test_the_delete_question_names_the_hero_level_and_hours() -> void:
	var summary := _card(3, 31 * 3600)
	assert_eq(SlotCard.asking(summary, false), "Delete Bryn? Ranger, level 13. 31 h played.")
	assert_string_starts_with(SlotCard.asking(summary, true), "Delete Bryn, the hero you're playing?")


# ---- Duplicate --------------------------------------------------------------------

func test_duplicate_copies_the_hero_into_the_first_empty_slot() -> void:
	slots.write(2, _hero("Hrafna", 444))
	var screen := await _open(1)
	screen._duplicate()
	assert_eq(screen.said, "copied")
	assert_string_contains(screen.status.text, "slot 1")
	assert_eq(slots.read(1)["hero"]["name"], "Hrafna")
	assert_eq(slots.read(1)["gold"], 444, "the whole hero")
	assert_eq(slots.read(2)["gold"], 444, "the first stays as it was")
	assert_eq(screen._slots[0]["kind"], SaveSlots.HERO, "the copy's card drawn")
	screen._duplicate()
	assert_eq(slots.read(3)["hero"]["name"], "Hrafna", "then the next one")


func test_duplicate_with_no_empty_slot_says_so_and_writes_nothing() -> void:
	for slot in [1, 2]:
		slots.write(slot, _hero("Hero %d" % slot))
	_put(slots.path_for(3), "{ damaged")
	var screen := await _open(0)
	screen._duplicate()
	assert_eq(screen.said, "full")
	assert_string_contains(screen.status.text, "no empty slot")
	assert_eq(FileAccess.get_file_as_string(slots.path_for(3)), "{ damaged", "never over a save it can't read")
	# Nor from an empty slot or one it can't read: there's no one to copy.
	screen._select(2)
	screen._duplicate()
	assert_eq(screen.said, "")
	assert_string_contains(screen.status.text, "no one to copy")


func test_duplicate_spares_a_slot_where_a_deleted_hero_waits() -> void:
	slots.write(1, _hero("Kept"))
	slots.write(2, _hero("Gone"))
	slots.erase(2)
	var screen := await _open(0)
	screen._duplicate()
	assert_eq(slots.read(3)["hero"]["name"], "Kept")
	assert_eq(slots.deleted(2)["name"], "Gone", "still there to bring back")


# ---- Delete and bring back ----------------------------------------------------------

func test_delete_asks_then_keeps_the_hero_aside_and_r_brings_them_back() -> void:
	var state := _hero("Hrafna", 777)
	state["playSeconds"] = 31 * 3600
	slots.write(2, state)
	var screen := await _open(1)
	screen._delete()
	assert_eq(screen.said, "ask")
	assert_string_contains(screen.status.text, "Delete Hrafna? Ranger, level 1. 31 h played.")
	assert_string_contains(screen.status.text, "Press X again to delete. Esc: keep.")
	assert_eq(slots.summary(2)["kind"], SaveSlots.HERO, "asked, not deleted")
	screen._delete()
	assert_eq(screen.said, "deleted")
	assert_true(slots.is_free(2), "an empty slot: New Game may take it")
	assert_eq(slots.deleted(2)["name"], "Hrafna")
	assert_true(screen.planks["restore"].visible, "the plank to bring them back")
	assert_eq(screen._slots[1]["deleted"]["name"], "Hrafna", "the card says who waits")
	screen._restore()
	assert_eq(screen.said, "back")
	assert_eq(slots.read(2)["gold"], 777, "back as they were")
	assert_eq(slots.deleted(2), {})
	assert_false(screen.planks["restore"].visible)


func test_esc_keeps_the_hero_a_question_is_about() -> void:
	slots.write(1, _hero("Hrafna"))
	var screen := await _open(0)
	# The game's keys, which a key is checked against: Esc is the menu key.
	Controls.apply({})
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	assert_false(screen._command(esc).is_valid(), "asked nothing, Esc closes the screen")
	screen._delete()
	assert_true(screen._command(esc).is_valid(), "Esc answers the question, not the screen")
	screen._command(esc).call()
	assert_eq(screen.pending, "")
	screen._delete()
	assert_eq(slots.summary(1)["kind"], SaveSlots.HERO, "asked again, not deleted")
	# The pad's B too.
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	assert_true(screen._command(back).is_valid())


func test_a_deleted_hero_is_gone_once_another_takes_the_slot() -> void:
	slots.write(1, _hero("Hrafna"))
	slots.erase(1)
	assert_eq(slots.deleted(1)["name"], "Hrafna")
	slots.write(1, _hero("Robin"))
	assert_false(FileAccess.file_exists(slots.deleted_for(1)))
	slots.erase(1)
	assert_true(slots.restore(1))
	assert_eq(slots.read(1)["hero"]["name"], "Robin", "the last one deleted")
	var screen := await _open(0)
	screen._select(1)
	screen._restore()
	assert_string_contains(screen.status.text, "no deleted hero in slot 2")


# ---- Copy and Paste ---------------------------------------------------------------

func test_copy_and_paste_carry_a_hero_as_a_code() -> void:
	slots.write(1, _hero("Brann", 321))
	var screen := await _open(0)
	screen._copy()
	assert_eq(screen.said, "code")
	assert_string_contains(screen.status.text, "Brann's save code is copied")
	var code := SaveCodec.encode_code(screen._hero())
	assert_true(code.begins_with(SaveCodec.CODE_PREFIX))
	# Pasted into an empty slot: written there at once, no question.
	screen._select(2)
	screen.paste_text(code)
	assert_eq(screen.said, "pasted")
	assert_eq(slots.read(3)["gold"], 321)
	assert_eq(slots.read(3)["hero"]["name"], "Brann")


func test_paste_over_a_hero_asks_first() -> void:
	slots.write(1, _hero("Hrafna", 10))
	var code := SaveCodec.encode_code(_hero("Brann", 99))
	var screen := await _open(0)
	screen.paste_text(code)
	assert_eq(screen.said, "ask")
	assert_string_contains(screen.status.text, "Replace Hrafna in slot 1 with Brann")
	assert_string_contains(screen.status.text, "Press V again to confirm. Esc: keep.")
	assert_eq(slots.read(1)["gold"], 10, "asked, not replaced")
	# Esc keeps Hrafna; V again after asking anew replaces her.
	screen._keep()
	screen.paste_text(code)
	assert_eq(slots.read(1)["gold"], 10)
	screen.paste_text("")
	assert_eq(slots.read(1)["hero"]["name"], "Brann", "the hero the question named")
	assert_eq(slots.read(1)["gold"], 99)


func test_a_bad_code_says_why_and_writes_nothing() -> void:
	var screen := await _open(0)
	var code := SaveCodec.encode_code(_hero("Brann"))
	screen.paste_text(code.left(code.length() - 6))
	assert_string_contains(screen.status.text, "cut short")
	screen.paste_text("PXH2.not-a-code")
	assert_string_contains(screen.status.text, "cut short")
	screen.paste_text("a shopping list")
	assert_string_contains(screen.status.text, "no save code")
	assert_true(slots.is_free(1))


func test_the_screen_offers_its_planks_and_keys() -> void:
	slots.write(1, _hero("Brann"))
	var screen := await _open(0)
	var words: Array = screen.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	for plank in ["Continue", "Duplicate", "Delete", "Copy", "Paste"]:
		assert_has(words, plank)
	for key in [KEY_D, KEY_X, KEY_R, KEY_C, KEY_V]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		assert_true(screen._command(event).is_valid(), OS.get_keycode_string(key))
	# An empty slot's planks for a hero stand dim; Paste still takes a code.
	screen._select(1)
	assert_true(screen.planks["continue"].disabled)
	assert_true(screen.planks["duplicate"].disabled)
	assert_true(screen.planks["copy"].disabled)
	assert_true(screen.planks["delete"].disabled)
	assert_false(screen.planks["paste"].disabled)


## `text` as a file's whole contents, the folder made first.
func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
