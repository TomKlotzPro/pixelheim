extends GutTest
## Slots on disk, settings, and the boot rule that picks what to play. Runs
## against a throwaway user:// folder so real saves are never touched.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const DIR := "user://test_saves"

var slots: SaveSlots


func before_each() -> void:
	_wipe()
	slots = SaveSlots.new(DIR)


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


func test_a_slot_file_is_a_web_save_envelope() -> void:
	slots.write(2, _fresh_state().to_dict())
	var raw: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(slots.path_for(2)))
	assert_eq(raw["version"], 4)
	assert_true(raw.has("state"))
	assert_typeof(raw["savedAt"], TYPE_INT)
	assert_false(FileAccess.file_exists(slots.path_for(2) + ".tmp"), "temp file renamed away")


func test_empty_and_corrupt_slots_read_as_nothing() -> void:
	assert_eq(slots.read(3), {})
	assert_eq(slots.summary(3), {})
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(slots.path_for(3), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_eq(slots.read(3), {})


func test_summary_names_the_hero_and_place() -> void:
	slots.write(1, _fresh_state().to_dict())
	var summary := slots.summary(1)
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


func test_boot_starts_a_new_game_in_the_last_slot_then_resumes_it() -> void:
	var first := _fresh_state()
	first.boot(PackedStringArray())
	assert_eq(first.slot, 1)
	assert_false(FileAccess.file_exists(slots.path_for(1)), "the title's stand-in isn't written")
	first.new_hero_in(first.free_slot(), "Robin", "warrior")
	assert_true(FileAccess.file_exists(slots.path_for(1)), "the hero made at the title is")
	first.pack.gold = 999
	first.save_now()
	var second := _fresh_state()
	second.boot(PackedStringArray())
	assert_eq(second.pack.gold, 999)


func test_boot_honors_a_named_slot_and_remembers_it() -> void:
	var state := _fresh_state()
	state.boot(PackedStringArray(["--slot", "2"]))
	assert_eq(state.slot, 2)
	var settings := GameSettings.new(DIR + "/settings.cfg")
	settings.load_file()
	assert_eq(settings.last_slot, 2)


func test_harness_runs_never_touch_saves() -> void:
	var state := _fresh_state()
	state.boot(PackedStringArray(["--screenshot"]))
	assert_eq(state.slot, GameStateScript.NO_SLOT)
	state.pack.gold = 5
	state.save_now()
	for slot in range(1, SaveSlots.SLOT_COUNT + 1):
		assert_false(FileAccess.file_exists(slots.path_for(slot)))


func test_boot_runs_once_per_session() -> void:
	var state := _fresh_state()
	state.boot(PackedStringArray(["--slot", "1"]))
	state.play_slot(2)
	state.boot(PackedStringArray(["--slot", "1"]))  # the world scene reloaded
	assert_eq(state.slot, 2, "a reload must not undo the switch")


func test_a_first_visit_lasts_until_a_hero_is_made() -> void:
	var first := _fresh_state()
	first.boot(PackedStringArray())
	assert_true(first.first_run)
	first.save_now()
	var second := _fresh_state()
	second.boot(PackedStringArray())
	assert_true(second.first_run, "the stand-in behind the title is never written")
	assert_eq(second.free_slot(), second.slot, "the new hero takes the slot in hand")
	second.new_hero_in(second.free_slot(), "Robin", "ranger", 1)
	var third := _fresh_state()
	third.boot(PackedStringArray())
	assert_false(third.first_run)
	assert_eq(third.hero.hero_name, "Robin")
	assert_eq(third.hero.role_id, "ranger")
	assert_eq(third.hero.look, 1)
	assert_eq(third.free_slot(), 2, "the next hero would take the first empty slot")


func test_playing_an_empty_slot_starts_a_hero_and_keeps_the_last_one() -> void:
	var state := _fresh_state()
	state.boot(PackedStringArray(["--slot", "1"]))
	state.pack.gold = 777
	state.play_slot(3)
	assert_eq(state.slot, 3)
	assert_eq(state.pack.gold, 30, "a fresh hero")
	assert_eq(slots.summary(1)["gold"], 777, "the hero left behind was saved")
	assert_eq(slots.summary(3)["gold"], 30)
	state.play_slot(1)
	assert_eq(state.pack.gold, 777)


func test_importing_writes_the_slot_and_plays_it() -> void:
	var state := _fresh_state()
	state.boot(PackedStringArray(["--slot", "1"]))
	var imported := WebImport.parse_any(FileAccess.get_file_as_string("res://test/fixtures/web_save_v4.txt"))
	state.import_into(2, imported)
	assert_eq(state.slot, 2)
	assert_eq(state.hero.hero_name, "Brann")
	assert_eq(slots.read(2), imported)
	var settings := GameSettings.new(DIR + "/settings.cfg")
	settings.load_file()
	assert_eq(settings.last_slot, 2, "the next launch continues the imported hero")


func test_new_hero_replaces_a_slot() -> void:
	var state := _fresh_state()
	state.boot(PackedStringArray(["--slot", "1"]))
	state.pack.gold = 500
	state.save_now()
	state.new_hero_in(1)
	assert_eq(slots.summary(1)["gold"], 30)


func test_the_slot_in_play_cannot_be_cleared() -> void:
	var state := _fresh_state()
	state.boot(PackedStringArray(["--slot", "1"]))
	state.play_slot(2)
	assert_false(state.clear_slot(2))
	assert_true(state.clear_slot(1))
	assert_eq(slots.read(1), {})


func test_save_code_carries_the_hero_to_the_web() -> void:
	var state := _fresh_state()
	state.pack.gold = 321
	var decoded := SaveCodec.decode_code(state.save_code())
	assert_eq(decoded, state.to_dict())
