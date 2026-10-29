extends GutTest
## The v5 save format (PIX-302): every fixture comes back from a save as it
## went in, the card, the play time, the packed fog, and the PXH2 codes that
## check themselves. Saves from before v5 load nowhere until the beta.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const FIXTURES := "res://test/fixtures/"
## The sections a file holds, beside its card, version and times.
const SECTIONS := ["hero", "pack", "home", "town", "story", "quests", "world", "buffs"]


func _game() -> Node:
	return autofree(GameStateScript.new())


## Every fixture holding a hero: the loose ones and the slots' that read.
func _fixtures() -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(FIXTURES):
		if file.ends_with(".json"):
			out.append(FIXTURES + file)
	for folder in ["slots", "slots_backup", "slots_older", "slots_room"]:
		for file in DirAccess.get_files_at(FIXTURES + folder):
			var path: String = FIXTURES + folder + "/" + file
			if SaveCodec.decodes(FileAccess.get_file_as_string(path)):
				out.append(path)
	return out


## A state loaded as the game loads one: read, then played.
func _loaded(text: String) -> Node:
	var game := _game()
	var state := SaveCodec.parse_any(text)
	assert_false(state.is_empty(), "a hero to play")
	if not state.is_empty():
		game.apply(state)
	return game


func test_every_fixture_comes_back_from_a_save_the_same() -> void:
	var fixtures := _fixtures()
	assert_gt(fixtures.size(), 10, "the loose fixtures and the slots' heroes")
	for path in fixtures:
		var first := _loaded(FileAccess.get_file_as_string(path))
		var saved := SaveCodec.serialize(SaveCodec.to_file(first.to_dict(), 1))
		var second := _loaded(saved)
		assert_eq(second.to_dict(), first.to_dict(), path)


func test_a_fixture_saved_again_is_the_file_it_was() -> void:
	# Its sections, field for field: the card and the version are written
	# afresh with every save.
	for path in _fixtures():
		var raw: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(path))
		var again := SaveCodec.to_file(_loaded(FileAccess.get_file_as_string(path)).to_dict(), raw["savedAt"])
		for key: String in SECTIONS + ["pixelheim", "savedAt", "playSeconds"]:
			assert_eq(again.get(key), raw.get(key), "%s: %s" % [path, key])


func test_a_file_has_its_sections_in_order_and_nothing_left_over() -> void:
	var doc := SaveCodec.to_file(_game().to_dict(), 7)
	assert_eq(doc.keys(), ["pixelheim", "game", "savedAt", "playSeconds", "card"] + SECTIONS)
	assert_eq(doc["pixelheim"], SaveCodec.VERSION)
	assert_eq(doc["game"], SaveCodec.game_version())
	assert_eq(doc["savedAt"], 7)
	# The web edition's screens and menus, and its unused intro, are gone,
	# and the old mountain's floors and the Deep Hunt with the old saves
	# (PIX-319).
	for gone in ["screen", "battle", "openPanel", "dungeonSelect", "worldMessage", "dialogue", "introSeen", "clearedLevels", "unlockedLevel", "deepHunt", "legacy"]:
		assert_eq(_holding(doc, gone), [], gone)
	for gone in ["screen", "battle", "openPanel", "dungeonSelect", "worldMessage", "dialogue", "clearedLevels", "unlockedLevel", "deepHunt"]:
		assert_false(_game().to_dict().has(gone), "%s: not in play either" % gone)


## The sections holding `key` as a field of their own ("" the file itself).
func _holding(doc: Dictionary, key: String) -> Array:
	var out := [""] if doc.has(key) else []
	return out + SECTIONS.filter(func(section: String) -> bool: return doc[section].has(key))


func test_every_field_a_hero_can_have_finds_its_place_and_comes_back() -> void:
	var game := _game()
	game.hero.skill_dock.assign(["warrior_power_strike"])
	game.hero.beyond = {"blade": 2}
	game.hero.forgot.assign([Skills.FORGOT_SKILLS, Skills.FORGOT_TRAINING])
	game.hero.path = ["juggernaut"]
	game.hero.spec = "juggernaut"
	game.hero.mastery = {"beasts": 3}
	game.settlement.house["rested"] = 4
	game.settlement.house["tier"] = 2
	game.settlement.bard_song = true
	game.settlement.projects.assign(["street_lamps"])
	game.settlement.festival = {"until": 900, "age": 2, "won": false}
	game.settlement.investments = {"expansions": ["town_shop"], "savings": {"principal": 5, "earned": 1, "at": 2}, "tills": {"town_shop": {"gold": 1, "earned": 2, "at": 3}}, "venture": {"x": 1}, "keepsake": 9}
	game.progression.story_seen.assign(["chapter_1", "ending_home"])
	game.progression.prologue = 3
	game.progression.prologue_doused.assign([1, 2])
	game.progression.hunted.assign(["cinderjaw"])
	game.progression.deeds.assign(["full_set"])
	game.progression.firsts.assign(["fafnyr_scale"])
	game.progression.met = {"wolf": 3}
	game.progression.crafted = {"potion_hp": 2}
	game.progression.tracked = "cheese_run"
	game.progression.bells = Bells.EMBERS
	game.progression.bells_lit.assign([0, 1, 2, 3, 4])
	game.progression.bells_doused.assign([2])
	game.progression.bells_embers = 3
	game.world.slain_at = {"ash_1": 12}
	game.world.gathered_at = {"herb_1": 13}
	game.play_seconds = 4321.7
	var state: Dictionary = game.to_dict()
	var doc := SaveCodec.to_file(state)
	assert_eq(doc["buffs"], {"rested": 4, "song": true}, "the inn's rest and the bard's song are buffs")
	assert_false(doc["home"].has("rested"))
	assert_eq(doc["town"]["bank"], {"principal": 5, "earned": 1, "at": 2})
	assert_eq(doc["town"]["tills"], {"town_shop": {"gold": 1, "earned": 2, "at": 3}})
	assert_eq(doc["town"]["invested"], {"keepsake": 9}, "the rest of the purse rides along")
	assert_eq(doc["story"]["seen"], ["chapter_1", "ending_home"])
	assert_eq(doc["story"]["night"], {"beat": Bells.EMBERS, "lit": [0, 1, 2, 3, 4], "doused": [2], "embers": 3}, "the Night of Bells as it stands (PIX-302 step 4)")
	assert_eq(doc["quests"]["named"], ["cinderjaw"])
	assert_eq(doc["quests"]["deeds"], ["full_set"])
	assert_eq(doc["playSeconds"], 4321)
	assert_eq(doc["hero"]["skills"]["forgot"], ["skills", "training"], "what the shrine's keeper made the hero forget (PIX-331)")
	assert_eq_deep(SaveCodec.from_file(SaveCodec.parse_json(SaveCodec.serialize(doc))), state)


func test_what_a_hero_never_had_stays_out_of_the_file() -> void:
	var doc := SaveCodec.to_file(_game().to_dict())
	assert_false(doc["town"].has("bank"), "no purse yet")
	assert_false(doc["hero"]["skills"].has("forgot"), "nothing forgotten yet")
	assert_false(doc["town"].has("invested"))
	assert_false(doc["story"].has("seen"))
	assert_false(doc["story"].has("night"), "no Night of Bells running")
	assert_false(doc["buffs"].has("rested"))
	var back := SaveCodec.reread(_game().to_dict())
	assert_false(back.has("investments"))
	assert_false(back.has("storySeen"))


# ---- The card ------------------------------------------------------------------------

func test_the_card_is_what_the_saves_screen_shows() -> void:
	var game := _game()
	game.new_game("Bryn", "ranger")
	var armour := InventoryState.create_gear("iron_armor")
	game.pack.gear.append(armour)
	game.pack.equipped["body"] = armour["uid"]
	game.play_seconds = 125.0
	var card := SaveCodec.card(game.to_dict())
	assert_eq(card["name"], "Bryn")
	assert_eq(card["role"], "ranger")
	assert_eq(card["worn"]["body"], "iron_armor", "the portrait dressed as they left")
	assert_eq(card["level"], 1)
	assert_eq(card["place"], "town")
	assert_eq(card["chapter"], 1, "a hero in town, the story ahead")
	assert_eq(card["playSeconds"], 125)
	assert_eq(SaveCodec.to_file(game.to_dict())["card"], card, "written with every save")


func test_the_cards_chapter_runs_from_the_night_of_ash_to_after_the_story() -> void:
	var game := _game()
	game.new_game("Bryn", "ranger", true)
	assert_eq(SaveCodec.card(game.to_dict())["chapter"], 0, "the Night of Ash")
	var told := _game()
	told.mark_seen(Story.ending_scene(Homecoming.HOME))
	assert_eq(SaveCodec.card(told.to_dict())["chapter"], MainQuest.chapters().size() + 1, "the story told")


# ---- Play time -----------------------------------------------------------------------

func test_play_time_counts_past_the_title_for_a_hero_in_hand() -> void:
	var game := _game()
	game._process(5.0)
	assert_eq(game.play_seconds, 0.0, "the title still up")
	game.title_seen = true
	game.standing_in = true
	game._process(5.0)
	assert_eq(game.play_seconds, 0.0, "a stand-in plays no one's time")
	game.standing_in = false
	game._process(2.5)
	game._process(2.5)
	assert_eq(game.play_seconds, 5.0)
	var state: Dictionary = game.to_dict()
	assert_eq(state["playSeconds"], 5, "saved whole")
	var back := _game()
	back.apply(SaveCodec.reread(state))
	assert_eq(back.play_seconds, 5.0, "and comes back")


# ---- The fog -------------------------------------------------------------------------

func test_the_fog_packs_a_bit_a_cell_and_unpacks_the_same() -> void:
	var seen := {}
	for cell in [Vector2i(3, 4), Vector2i(4, 4), Vector2i(12, 9), Vector2i(3, 9), Vector2i(7, 6)]:
		seen[cell] = true
	var packed := WorldState.pack_fog(seen)
	assert_eq([packed["x"], packed["y"], packed["w"], packed["h"]], [3, 4, 10, 6], "the box the cells lie in")
	assert_eq(Marshalls.base64_to_raw(packed["bits"]).size(), 8, "60 cells, 8 bytes")
	assert_eq(WorldState.unpack_fog(packed), seen)
	assert_eq(WorldState.unpack_fog(WorldState.pack_fog({})), {}, "a map with nothing seen")


func test_a_whole_map_seen_is_a_few_hundred_bytes() -> void:
	var map := MapData.load_by_id("overworld")
	var seen := {}
	for cell: Vector2i in map.grid:
		seen[cell] = true
	var packed := WorldState.pack_fog(seen)
	assert_lte(packed["bits"].length(), (map.size.x * map.size.y / 8 + 3) * 4 / 3 + 4)
	assert_eq(WorldState.unpack_fog(packed).size(), seen.size())


func test_a_save_packs_again_only_the_map_seen_more_of() -> void:
	var game := _game()
	var town: Dictionary = game.world.discovered["town"]
	var first: Dictionary = game.to_dict()["world"]["discovered"]["town"]
	assert_same(game.world._packed["town"]["fog"]["bits"], first["bits"], "the same packing")
	town[Vector2i(0, 0)] = true
	var then: Dictionary = game.to_dict()["world"]["discovered"]["town"]
	assert_ne(then, first, "packed again once more was seen")
	assert_true(WorldState.unpack_fog(then).has(Vector2i(0, 0)))


func test_a_fully_explored_heros_save_is_small() -> void:
	var game := _game()
	for file in DirAccess.get_files_at("res://assets/maps"):
		# Every map on disk: the town's house tiers and the chests' table aside.
		if not file.ends_with(".json") or "@" in file or file == "interactables.json":
			continue
		var map := MapData.load_by_id(file.get_basename())
		var seen: Dictionary = game.world.discovered.get_or_add(map.id, {})
		for cell: Vector2i in map.grid:
			seen[cell] = true
	var text := SaveCodec.serialize(SaveCodec.to_file(game.to_dict()))
	# 291 KB in the first edition's format, the fog an "x,y" a cell.
	assert_lt(text.length(), 16 * 1024, "%d bytes" % text.length())
	assert_lt(game.save_code().length(), 16 * 1024)
	var back := _game()
	back.apply(SaveCodec.parse_any(text))
	for id: String in game.world.discovered:
		assert_eq(back.world.discovered[id].size(), game.world.discovered[id].size(), id)


# ---- What a file is ------------------------------------------------------------------

func test_a_file_says_its_age() -> void:
	var doc := SaveCodec.to_file(_game().to_dict())
	assert_eq(SaveCodec.age(doc), SaveCodec.CURRENT)
	doc["pixelheim"] = SaveCodec.VERSION + 1
	assert_eq(SaveCodec.age(doc), SaveCodec.NEWER)
	var older: Variant = SaveCodec.parse_json(FileAccess.get_file_as_string(FIXTURES + "slots_older/slot_1.json"))
	assert_eq(SaveCodec.age(older), SaveCodec.OLDER, "the first edition's envelope")
	assert_eq(SaveCodec.age(older["state"]), SaveCodec.OLDER, "and its bare state, from before it")
	assert_eq(SaveCodec.age({"hello": 1}), "")
	assert_eq(SaveCodec.age(null), "")


## Nothing reads what only an old save held (PIX-319): a v5 file written
## before it, its `legacy` section holding the old mountain's floors, the
## Deep Hunt's depth and the old throne's ending, plays a hero who never
## climbed, and its next save leaves the section out.
func test_a_files_old_legacy_section_is_read_no_more() -> void:
	var doc := SaveCodec.to_file(_game().to_dict(), 3)
	doc["legacy"] = {"unlockedLevel": 15, "clearedLevels": [10, 15], "deepHunt": 12, "endings": ["ending"]}
	var game := _loaded(SaveCodec.serialize(doc))
	assert_false(game.to_dict().has("clearedLevels"))
	assert_eq(Story.ending_of(game.progression.story_seen), "", "no ending seen")
	assert_false(Relics.gate_open(game.progression), "the mountain's gate shut")
	assert_false(Vault.door_open(game.progression, game.settlement), "the Vault's door shut")
	assert_eq(MainQuest.next_step(game.progression, game.settlement)["id"], "tin", "the story from its start")
	assert_false(SaveCodec.to_file(game.to_dict()).has("legacy"), "and gone from the next save")


## A hero missing a field the game reads is refused, not patched up
## (PIX-319: the first edition's heroes caught up as they loaded).
func test_a_hero_missing_a_field_is_refused() -> void:
	for key: String in ["statPoints", "skillPoints", "jobs"]:
		var doc := SaveCodec.to_file(_game().to_dict())
		doc["hero"].erase(key)
		assert_eq(SaveCodec.from_file(doc), {}, "%s missing: no hero to play" % key)
		assert_false(SaveCodec.decodes(SaveCodec.serialize(doc)), "%s missing: no write lands" % key)


func test_only_this_versions_files_load() -> void:
	var older: Variant = SaveCodec.parse_json(FileAccess.get_file_as_string(FIXTURES + "slots_older/slot_1.json"))
	assert_eq(SaveCodec.from_file(older), {}, "no migration until the beta")
	var newer := SaveCodec.to_file(_game().to_dict())
	newer["pixelheim"] = SaveCodec.VERSION + 1
	assert_eq(SaveCodec.from_file(newer), {})
	var stranger := SaveCodec.to_file(_game().to_dict())
	stranger["hero"]["role"] = "no_such_role"
	assert_eq(SaveCodec.from_file(stranger), {}, "a hero this version can't play")


func test_decodes_takes_a_whole_v5_file_alone() -> void:
	var text := SaveCodec.serialize(SaveCodec.to_file(_game().to_dict()))
	assert_true(SaveCodec.decodes(text))
	assert_false(SaveCodec.decodes(text.left(text.length() / 2)), "cut short")
	assert_false(SaveCodec.decodes(FileAccess.get_file_as_string(FIXTURES + "slots_older/slot_1.json")), "an older version's")
	var no_card := SaveCodec.to_file(_game().to_dict())
	no_card.erase("card")
	assert_false(SaveCodec.decodes(SaveCodec.serialize(no_card)))
	var nowhere := SaveCodec.to_file(_game().to_dict())
	nowhere["world"].erase("at")
	assert_false(SaveCodec.decodes(SaveCodec.serialize(nowhere)), "a hero standing nowhere")


# ---- PXH2 codes ----------------------------------------------------------------------

func test_a_code_carries_the_hero_whole() -> void:
	var game := _loaded(FileAccess.get_file_as_string(FIXTURES + "frostweave_mage.json"))
	game.play_seconds = 99.0
	var code: String = game.save_code()
	assert_true(code.begins_with("PXH2."))
	var read := SaveCodec.pasted(code)
	assert_eq(read["problem"], "")
	assert_eq(read["state"], game.to_dict())


func test_a_code_cut_short_is_caught() -> void:
	var code: String = _game().save_code()
	for cut in [code.length() / 2, code.length() - 4, code.length() - 1, 12]:
		assert_eq(SaveCodec.pasted(code.left(cut)), {"state": {}, "problem": SaveCodec.DAMAGED}, "cut at %d" % cut)


func test_a_code_changed_is_caught() -> void:
	var code: String = _game().save_code()
	var middle := code.length() / 2
	var changed := code.left(middle) + ("A" if code[middle] != "A" else "B") + code.substr(middle + 1)
	assert_eq(SaveCodec.pasted(changed)["problem"], SaveCodec.DAMAGED)


func test_spaces_and_line_breaks_in_a_code_are_forgiven() -> void:
	var code: String = _game().save_code()
	var broken := "  " + code.left(40) + "\n" + code.substr(40, 40) + " \r\n " + code.substr(80) + "\n"
	assert_eq(SaveCodec.pasted(broken)["problem"], "")


func test_a_code_is_the_file_deflated_behind_a_checksum() -> void:
	# The format, pinned: another tool can read and write it.
	var state: Dictionary = _game().to_dict()
	var bytes := Marshalls.base64_to_raw(SaveCodec.encode_code(state).substr(5))
	var body := bytes.slice(4)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(body)
	assert_eq(bytes.slice(0, 4), hashing.finish().slice(0, 4), "4 bytes of the rest's SHA-256")
	var size := body.decode_u32(0)
	var text := body.slice(4).decompress(size, FileAccess.COMPRESSION_DEFLATE).get_string_from_utf8()
	assert_eq(SaveCodec.age(SaveCodec.parse_json(text)), SaveCodec.CURRENT, "a v5 file inside")


func test_a_newer_versions_code_says_so() -> void:
	var doc := SaveCodec.to_file(_game().to_dict())
	doc["pixelheim"] = SaveCodec.VERSION + 1
	var raw := SaveCodec.serialize(doc).to_utf8_buffer()
	var body := PackedByteArray()
	body.resize(4)
	body.encode_u32(0, raw.size())
	body.append_array(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(body)
	var code := "PXH2." + Marshalls.raw_to_base64(hashing.finish().slice(0, 4) + body)
	assert_eq(SaveCodec.pasted(code), {"state": {}, "problem": SaveCodec.NEWER})


func test_a_pxh1_code_is_an_older_versions_and_loads_nothing() -> void:
	var old := "PXH1." + Marshalls.utf8_to_base64(FileAccess.get_file_as_string(FIXTURES + "slots_older/slot_1.json"))
	assert_eq(SaveCodec.pasted(old), {"state": {}, "problem": SaveCodec.OLDER})
	assert_eq(SaveCodec.parse_any(old), {})


func test_anything_else_is_no_save() -> void:
	for text in ["", "hello", "PXH3.abcd", "[1, 2, 3]", "{ broken"]:
		assert_eq(SaveCodec.pasted(text), {"state": {}, "problem": SaveCodec.NOT_A_SAVE}, text)
	assert_eq(SaveCodec.pasted("PXH2.@@@not-base64@@@")["problem"], SaveCodec.DAMAGED)
