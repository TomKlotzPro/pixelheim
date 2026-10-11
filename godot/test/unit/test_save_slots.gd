extends GutTest
## Slots on disk, settings, and the boot rule that picks what to play. Runs
## against a throwaway user:// folder so real saves are never touched.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const DIR := "user://test_saves"

var slots: SaveSlots


func before_each() -> void:
	_wipe()
	slots = SaveSlots.new(DIR)


func after_each() -> void:
	# Booting follows the system's language (PIX-195); a French machine
	# would leave every later test reading French.
	Text.apply("en")


func after_all() -> void:
	_wipe()


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file])
	DirAccess.remove_absolute(DIR)


func _fresh_state() -> Node:
	var state: Node = autofree(GameStateScript.new())
	state.slots = slots
	state.settings = GameSettings.new(DIR + "/settings.cfg")
	return state


func test_a_written_slot_reads_back_the_same_state() -> void:
	var state := _fresh_state()
	assert_true(slots.write(1, state.to_dict()))
	assert_eq(slots.read(1), state.to_dict())


func test_a_slot_file_is_the_save_envelope() -> void:
	slots.write(2, _fresh_state().to_dict())
	var raw: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(slots.path_for(2)))
	assert_eq(raw["version"], 4)
	assert_true(raw.has("state"))
	assert_typeof(raw["savedAt"], TYPE_INT)
	assert_false(FileAccess.file_exists(slots.path_for(2) + ".tmp"), "temp file renamed away")


func test_an_empty_slot_is_free_and_a_corrupt_one_is_not() -> void:
	assert_eq(slots.read(3), {})
	assert_eq(slots.summary(3), {"kind": SaveSlots.EMPTY})
	assert_true(slots.is_free(3))
	_put(slots.path_for(3), "{ not json")
	assert_eq(slots.read(3), {}, "no hero to play")
	assert_eq(slots.summary(3), {"kind": SaveSlots.DAMAGED}, "but no empty slot either (PIX-303)")
	assert_false(slots.is_free(3))


func test_summary_names_the_hero_and_place() -> void:
	slots.write(1, _fresh_state().to_dict())
	var summary := slots.summary(1)
	assert_eq(summary["kind"], SaveSlots.HERO)
	assert_false(summary["backup"])
	assert_eq(summary["name"], "Wanderer")
	assert_eq(summary["level"], 1)
	assert_eq(summary["gold"], 30)
	assert_eq(summary["mapId"], "town")
	assert_gt(summary["savedAt"], 0)


func test_erase_empties_a_slot() -> void:
	slots.write(1, _fresh_state().to_dict())
	slots.erase(1)
	assert_eq(slots.read(1), {})


func test_settings_persist_and_clamp() -> void:
	var settings := GameSettings.new(DIR + "/settings.cfg")
	DirAccess.make_dir_recursive_absolute(DIR)
	settings.music_volume = 0.25
	settings.reduce_motion = true
	settings.last_slot = 3
	settings.save_file()
	var reread := GameSettings.new(DIR + "/settings.cfg")
	reread.load_file()
	assert_eq(reread.music_volume, 0.25)
	assert_eq(reread.sfx_volume, 0.7)
	assert_true(reread.reduce_motion)
	assert_eq(reread.last_slot, 3)


func test_the_notes_read_are_remembered_and_a_harness_run_writes_nothing() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var settings := GameSettings.new(DIR + "/settings.cfg")
	assert_eq(settings.seen_version, "", "nothing read yet: the title flags What's new")
	settings.seen_version = "0.73.0"
	settings.save_file()
	var reread := GameSettings.new(DIR + "/settings.cfg")
	reread.load_file()
	assert_eq(reread.seen_version, "0.73.0")
	reread.read_only = true
	reread.seen_version = "9.9.9"
	reread.save_file()
	var again := GameSettings.new(DIR + "/settings.cfg")
	again.load_file()
	assert_eq(again.seen_version, "0.73.0", "a read-only run leaves the player's file alone")


func test_boot_starts_a_new_game_in_the_last_slot_then_resumes_it() -> void:
	var first := _fresh_state()
	first.boot(HarnessFlags.new())
	assert_eq(first.slot, 1)
	assert_false(FileAccess.file_exists(slots.path_for(1)), "the title's stand-in isn't written")
	first.new_hero_in(first.free_slot(), "Robin", "warrior")
	assert_true(FileAccess.file_exists(slots.path_for(1)), "the hero made at the title is")
	first.pack.gold = 999
	first.save_now()
	var second := _fresh_state()
	second.boot(HarnessFlags.new())
	assert_eq(second.pack.gold, 999)


func test_boot_honors_a_named_slot_and_remembers_it() -> void:
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "2"])))
	assert_eq(state.slot, 2)
	var settings := GameSettings.new(DIR + "/settings.cfg")
	settings.load_file()
	assert_eq(settings.last_slot, 2)


func test_harness_runs_never_touch_saves() -> void:
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--screenshot"])))
	assert_eq(state.slot, GameStateScript.NO_SLOT)
	state.pack.gold = 5
	state.save_now()
	for slot in range(1, SaveSlots.SLOT_COUNT + 1):
		assert_false(FileAccess.file_exists(slots.path_for(slot)))


func test_boot_runs_once_per_session() -> void:
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "1"])))
	state.new_hero_in(2, "Robin", "warrior")
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "1"])))  # the world scene reloaded
	assert_eq(state.slot, 2, "a reload must not undo the switch")


func test_a_first_visit_lasts_until_a_hero_is_made() -> void:
	var first := _fresh_state()
	first.boot(HarnessFlags.new())
	assert_true(first.standing_in)
	first.save_now()
	var second := _fresh_state()
	second.boot(HarnessFlags.new())
	assert_true(second.standing_in, "the stand-in behind the title is never written")
	for slot in range(1, SaveSlots.SLOT_COUNT + 1):
		assert_false(FileAccess.file_exists(slots.path_for(slot)), "slot %d stays empty" % slot)
	assert_eq(second.free_slot(), second.slot, "the new hero takes the slot in hand")
	second.new_hero_in(second.free_slot(), "Robin", "ranger", 1)
	var third := _fresh_state()
	third.boot(HarnessFlags.new())
	assert_false(third.standing_in)
	assert_eq(third.hero.hero_name, "Robin")
	assert_eq(third.hero.role_id, "ranger")
	assert_eq(third.hero.look, 1)
	assert_eq(third.free_slot(), 2, "the next hero would take the first empty slot")


func test_an_empty_slot_is_no_hero_to_play() -> void:
	# Tom: playing an empty slot dropped a nameless warrior into the world,
	# past creation and the Night of Ash. Now it's refused (the saves screen
	# opens creation for it instead).
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "1"])))
	state.pack.gold = 777
	assert_false(state.play_slot(3))
	assert_eq(state.slot, 1, "the hero in hand stays")
	assert_eq(state.pack.gold, 777)
	assert_eq(slots.read(3), {}, "nothing written to the empty slot")
	state.new_hero_in(3, "Robin", "mage")
	assert_eq(state.slot, 3)
	assert_eq(state.progression.prologue, Prologue.SCAVENGER, "a made hero starts on the Night of Ash")
	assert_eq(slots.summary(1)["gold"], 777, "the hero left behind was saved")
	assert_true(state.play_slot(1))
	assert_eq(state.pack.gold, 777)


func test_importing_writes_the_slot_and_plays_it() -> void:
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "1"])))
	var imported := SaveCodec.parse_any(FileAccess.get_file_as_string("res://test/fixtures/web_save_v4.txt"))
	state.import_into(2, imported)
	assert_eq(state.slot, 2)
	assert_eq(state.hero.hero_name, "Brann")
	assert_eq(slots.read(2), imported)
	var settings := GameSettings.new(DIR + "/settings.cfg")
	settings.load_file()
	assert_eq(settings.last_slot, 2, "the next launch continues the imported hero")


func test_new_hero_replaces_a_slot() -> void:
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "1"])))
	state.pack.gold = 500
	state.save_now()
	state.new_hero_in(1)
	assert_eq(slots.summary(1)["gold"], 30)


func test_any_slot_clears_and_the_hero_in_hand_becomes_a_stand_in() -> void:
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "1"])))
	state.new_hero_in(2, "Robin", "warrior")
	assert_true(state.clear_slot(1))
	assert_eq(slots.read(1), {})
	assert_false(state.clear_slot(1), "already empty")
	# The hero in hand (Tom couldn't clear the slot Continue loads): gone for
	# good, and the stand-in left behind is never written back.
	state.pack.gold = 999
	assert_true(state.clear_slot(2))
	assert_eq(slots.read(2), {})
	assert_true(state.standing_in)
	state.mark_dirty()
	state.save_now()
	assert_eq(slots.read(2), {}, "nothing writes the cleared hero back")
	assert_eq(state.free_slot(), 2, "the next hero takes the cleared slot")


func test_save_code_carries_the_hero_whole() -> void:
	var state := _fresh_state()
	state.pack.gold = 321
	var decoded := SaveCodec.decode_code(state.save_code())
	assert_eq(decoded, state.to_dict())


## PIX-175: the slot's portrait wears what the hero wore.
func test_summary_says_what_the_hero_wears() -> void:
	var state := _fresh_state()
	var armor := InventoryState.create_gear("iron_armor")
	state.pack.gear.append(armor)
	state.pack.equipped["body"] = armor["uid"]
	slots.write(1, state.to_dict())
	assert_eq(slots.summary(1)["worn"].get("body"), "iron_armor")
	var spec := PunyArt.dressed(slots.summary(1)["roleId"], 0, slots.summary(1)["worn"])
	assert_true(spec.has("body"), "drawn in the armour")
	assert_not_null(PunyArt.sheet_texture(spec), "the portrait's sheet")
	assert_typeof(spec["tint"], TYPE_COLOR)


# PIX-303: no hero is lost to a file. Every case below keeps the hero, or
# the bytes of a save the game can't read, safe.

## `text` as a file's whole contents, the folder made first.
func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## A state with `gold`, as a hero's save holds it.
func _state(gold: int) -> Dictionary:
	var state := _fresh_state()
	state.pack.gold = gold
	return state.to_dict()


## A save a later version wrote: this one's envelope, version 5.
func _newer_text() -> String:
	return JSON.stringify({"version": SaveCodec.SAVE_VERSION + 1, "state": _state(64), "savedAt": 1})


func test_each_write_keeps_the_save_before() -> void:
	assert_true(slots.write(1, _state(100)))
	assert_false(FileAccess.file_exists(slots.backup_for(1)), "a first save has none before it")
	assert_true(slots.write(1, _state(200)))
	assert_eq(slots.read(1)["gold"], 200)
	assert_eq(SaveCodec.migrate(SaveCodec.parse_json(_text(slots.backup_for(1))))["gold"], 100, "the save before")
	assert_true(slots.write(1, _state(300)))
	assert_eq(SaveCodec.migrate(SaveCodec.parse_json(_text(slots.backup_for(1))))["gold"], 200)
	assert_false(FileAccess.file_exists(slots.temp_for(1)))


func test_a_write_that_does_not_read_back_replaces_nothing() -> void:
	slots.write(1, _state(100))
	var before := _text(slots.path_for(1))
	# A bug's state: no hero at all, or one this version can't play.
	var broken := _state(5)
	broken["hero"] = null
	assert_false(slots.write(1, broken))
	var stranger := _state(5)
	stranger["hero"]["roleId"] = "no_such_role"
	assert_false(slots.write(1, stranger))
	assert_eq(_text(slots.path_for(1)), before, "the last good save stands")
	assert_false(FileAccess.file_exists(slots.temp_for(1)), "the bad write is gone")
	assert_false(FileAccess.file_exists(slots.backup_for(1)), "and rotated nothing")


func test_a_damaged_file_is_never_empty_and_keeps_its_bytes() -> void:
	_put(slots.path_for(1), "{\"version\":4,\"state\":{\"hero\":")
	assert_eq(slots.summary(1)["kind"], SaveSlots.DAMAGED)
	assert_false(slots.is_free(1))
	assert_eq(slots.read(1), {})
	assert_eq(_text(slots.path_for(1)), "{\"version\":4,\"state\":{\"hero\":", "reading changes nothing")


func test_a_truncated_save_is_damaged_not_empty() -> void:
	slots.write(2, _state(400))
	var whole := _text(slots.path_for(2))
	DirAccess.remove_absolute(slots.path_for(2))
	_put(slots.path_for(2), whole.left(whole.length() / 2))
	assert_eq(slots.summary(2)["kind"], SaveSlots.DAMAGED)
	assert_false(slots.is_free(2))


func test_a_newer_versions_save_is_kept_and_never_written_over() -> void:
	var newer := _newer_text()
	_put(slots.path_for(1), newer)
	assert_eq(slots.summary(1)["kind"], SaveSlots.NEWER)
	assert_false(slots.is_free(1))
	assert_eq(slots.read(1), {}, "this version can't play it")
	assert_false(slots.write(1, _state(1)), "nor replace it")
	assert_eq(_text(slots.path_for(1)), newer)
	assert_false(FileAccess.file_exists(slots.temp_for(1)))
	# Even with an older save before it: falling back would lose its progress.
	slots.write(2, _state(2))
	_put(slots.backup_for(1), _text(slots.path_for(2)))
	assert_eq(slots.summary(1)["kind"], SaveSlots.NEWER)


func test_a_leftover_temp_file_spoils_nothing() -> void:
	slots.write(1, _state(100))
	# A write cut off mid-file left half a temp file behind.
	_put(slots.temp_for(1), "{\"version\":4,\"sta")
	assert_eq(slots.read(1)["gold"], 100, "the save itself reads")
	assert_true(slots.write(1, _state(200)))
	assert_eq(slots.read(1)["gold"], 200)
	assert_false(FileAccess.file_exists(slots.temp_for(1)))
	# Alone (a first write cut off), it was never a save.
	_put(slots.temp_for(3), "{\"version\":4,\"sta")
	assert_true(slots.is_free(3))


func test_a_write_cut_off_between_its_renames_loses_nothing() -> void:
	slots.write(1, _state(100))
	slots.write(1, _state(200))
	# The new save decoded in the temp file, the slot's file already the
	# backup, then the power went.
	slots.write(2, _state(300))
	DirAccess.rename_absolute(slots.path_for(2), slots.temp_for(1))
	DirAccess.rename_absolute(slots.path_for(1), slots.backup_for(1))
	assert_false(FileAccess.file_exists(slots.path_for(1)))
	var seen := slots.look(1)
	assert_eq(seen["state"]["gold"], 300, "the newest save, from the temp file")
	assert_false(seen.get("backup", false), "nothing was lost, so nothing to say")


func test_a_missing_file_falls_back_to_the_save_before() -> void:
	slots.write(1, _state(100))
	slots.write(1, _state(200))
	DirAccess.remove_absolute(slots.path_for(1))
	var seen := slots.look(1)
	assert_eq(seen["kind"], SaveSlots.HERO)
	assert_eq(seen["state"]["gold"], 100)
	assert_true(seen["backup"], "said: this is the save before")
	assert_true(slots.summary(1)["backup"])


func test_a_good_save_with_a_bad_backup_plays_and_mends_it() -> void:
	slots.write(1, _state(100))
	_put(slots.backup_for(1), "garbage")
	assert_eq(slots.read(1)["gold"], 100)
	assert_false(slots.summary(1)["backup"])
	assert_true(slots.write(1, _state(200)))
	assert_eq(SaveCodec.migrate(SaveCodec.parse_json(_text(slots.backup_for(1))))["gold"], 100, "a good backup again")


func test_a_bad_save_with_a_good_backup_plays_the_backup_and_keeps_both() -> void:
	slots.write(1, _state(100))
	slots.write(1, _state(200))
	DirAccess.remove_absolute(slots.path_for(1))
	_put(slots.path_for(1), "{ broken")
	var seen := slots.look(1)
	assert_eq(seen["state"]["gold"], 100)
	assert_true(seen["backup"])
	# The hero saved again: the good backup stays, the bad bytes go aside.
	assert_true(slots.write(1, _state(150)))
	assert_eq(slots.read(1)["gold"], 150)
	assert_false(slots.summary(1)["backup"])
	assert_eq(SaveCodec.migrate(SaveCodec.parse_json(_text(slots.backup_for(1))))["gold"], 100)
	assert_eq(_text(slots.aside_for(1)), "{ broken")


func test_a_save_spoiled_since_it_was_written_never_becomes_the_backup() -> void:
	slots.write(1, _state(100))
	slots.write(1, _state(200))
	# This session wrote it; something else spoiled it since.
	DirAccess.remove_absolute(slots.path_for(1))
	_put(slots.path_for(1), "{ spoiled")
	assert_true(slots.write(1, _state(300)))
	assert_eq(SaveCodec.migrate(SaveCodec.parse_json(_text(slots.backup_for(1))))["gold"], 100, "the good one kept")
	assert_eq(_text(slots.aside_for(1)), "{ spoiled")


func test_erasing_a_slot_takes_every_file_of_it() -> void:
	slots.write(1, _state(100))
	slots.write(1, _state(200))
	_put(slots.temp_for(1), "x")
	_put(slots.aside_for(1), "y")
	slots.erase(1)
	for path in [slots.path_for(1), slots.backup_for(1), slots.temp_for(1), slots.aside_for(1)]:
		assert_false(FileAccess.file_exists(path), path)
	assert_true(slots.is_free(1))


func test_read_only_slots_are_never_written_or_erased() -> void:
	slots.write(1, _state(100))
	var fixtures := SaveSlots.new(DIR, true)
	assert_false(fixtures.write(1, _state(5)))
	assert_false(fixtures.write(2, _state(5)))
	fixtures.erase(1)
	assert_eq(slots.read(1)["gold"], 100)
	assert_false(FileAccess.file_exists(slots.path_for(2)))


func test_a_launch_that_cant_read_its_slot_never_writes_over_it() -> void:
	_put(slots.path_for(1), "{ damaged")
	var first := _fresh_state()
	first.boot(HarnessFlags.new())
	assert_eq(first.slot, 1, "the last slot played")
	assert_true(first.standing_in, "a stand-in, no Continue")
	assert_string_contains(first.slot_note, "1")
	first.mark_dirty()
	first.save_now()
	assert_eq(_text(slots.path_for(1)), "{ damaged", "nothing written over it")
	# The title's New Game: the hero goes to the first free slot.
	assert_eq(first.free_slot(), 2)
	first.new_hero_in(first.free_slot(), "Robin", "rogue")
	assert_eq(first.slot, 2)
	assert_eq(slots.read(2)["hero"]["name"], "Robin")
	assert_eq(_text(slots.path_for(1)), "{ damaged", "still untouched")


func test_a_named_slot_it_cant_read_stands_in_too() -> void:
	var newer := _newer_text()
	_put(slots.path_for(1), newer)
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "1"])))
	assert_true(state.standing_in)
	assert_string_contains(state.slot_note, "1")
	state.save_now()
	assert_eq(_text(slots.path_for(1)), newer)


func test_new_game_skips_every_slot_it_cant_read() -> void:
	_put(slots.path_for(1), "{ damaged")
	_put(slots.path_for(2), _newer_text())
	var state := _fresh_state()
	state.boot(HarnessFlags.new())
	assert_eq(state.free_slot(), 3)
	_put(slots.path_for(3), "{ damaged too")
	assert_eq(state.free_slot(), 0, "none free: creation says so")


func test_an_unread_slot_is_no_hero_to_play_but_clears() -> void:
	var state := _fresh_state()
	state.boot(HarnessFlags.new(PackedStringArray(["--slot", "1"])))
	state.pack.gold = 777
	_put(slots.path_for(2), "{ damaged")
	_put(slots.path_for(3), _newer_text())
	assert_false(state.play_slot(2))
	assert_false(state.play_slot(3))
	assert_eq([state.slot, state.pack.gold], [1, 777], "the hero in hand stays")
	assert_true(state.clear_slot(2), "cleared, once the screen has asked twice")
	assert_true(slots.is_free(2))


func test_a_hero_from_the_save_before_is_told_and_saved_back() -> void:
	slots.write(1, _state(100))
	slots.write(1, _state(200))
	DirAccess.remove_absolute(slots.path_for(1))
	_put(slots.path_for(1), "{ broken")
	var state := _fresh_state()
	state.boot(HarnessFlags.new())
	assert_false(state.standing_in)
	assert_eq(state.pack.gold, 100, "the save before")
	assert_string_contains(state.slot_note, "Wanderer")
	state.mark_dirty()
	state.save_now()
	assert_eq(slots.read(1)["gold"], 100)
	assert_false(slots.summary(1)["backup"], "a good save again")
	assert_eq(_text(slots.aside_for(1)), "{ broken", "the bad bytes kept aside")
	# Switching to it from another slot says so too.
	state.new_hero_in(2, "Robin", "mage")
	assert_eq(state.slot_note, "")
	DirAccess.remove_absolute(slots.path_for(1))
	_put(slots.path_for(1), "{ broken again")
	assert_true(state.play_slot(1))
	assert_eq(state.pack.gold, 100)
	assert_string_contains(state.slot_note, "Wanderer")


func test_the_saves_screen_writes_nothing_over_an_unread_slot() -> void:
	_put(slots.path_for(1), "{ damaged")
	var kept: SaveSlots = GameState.slots
	GameState.slots = slots
	var screen: Screen = preload("res://scripts/saves_screen.gd").new()
	add_child(screen)
	await wait_process_frames(2)
	screen._select(0)
	# E and N make no hero over it, a code goes nowhere near it.
	screen._play()
	screen._new_hero()
	screen.code_field.text = SaveCodec.encode_code(_state(9))
	screen._load_code()
	assert_false(screen.get_children().any(func(child: Node) -> bool: return child.get_script() == preload("res://scripts/create_screen.gd")), "no creation opened")
	assert_eq(_text(slots.path_for(1)), "{ damaged")
	# X asks twice, then clears.
	screen._clear()
	screen._clear()
	assert_true(FileAccess.file_exists(slots.path_for(1)), "asked twice")
	screen._clear()
	assert_true(slots.is_free(1), "then cleared")
	screen.close()
	GameState.slots = kept
	await get_tree().process_frame
	get_tree().paused = false
