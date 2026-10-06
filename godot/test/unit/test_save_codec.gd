extends GutTest
## The web save contract, ported assertion for assertion from
## src/state/save.test.ts and the migration cases of e2e/saves.spec.ts, plus
## a frozen save code produced by the web game itself (fixtures/).

## A frozen v1-era save: bare state, no envelope, item-id equipment, no world.
const V1 := {
	"screen": "hub",
	"hero": {
		"name": "OldTimer", "roleId": "warrior", "level": 3, "xp": 10, "xpToNext": 74,
		"hp": 40, "mp": 5,
		"stats": {
			"maxHp": 56, "maxMp": 10, "strength": 15, "intelligence": 5, "dexterity": 7,
			"defense": 9,
		},
	},
	"gold": 123,
	"inventory": {"potion_hp": 2, "gem": 1},
	"equipped": {"weapon": "iron_sword"},
	"unlockedLevel": 4,
	"clearedLevels": [1, 2, 3],
	"battle": null,
	"openPanel": null,
}


func _v1() -> Dictionary:
	return V1.duplicate(true)


func test_v1_save_upgrades_all_the_way_to_the_current_shape() -> void:
	var s := SaveCodec.migrate(_v1())
	assert_false(s.is_empty())
	# never resume mid-menu; the world is the game now
	assert_eq(s["screen"], "world")
	assert_null(s["battle"])
	assert_null(s["openPanel"])
	# v3: heroes without a world wake up in the village
	assert_eq(s["world"]["position"]["mapId"], "town")
	# v4: the equipped item id became a gear instance
	assert_eq(s["gear"].size(), 1)
	assert_eq(s["gear"][0]["itemId"], "iron_sword")
	assert_eq(s["equipped"]["weapon"], s["gear"][0]["uid"])
	# compat seeding: banked points, the old level-gated skills, and grit
	var hero: Dictionary = s["hero"]
	assert_eq(hero["statPoints"], 0)
	assert_eq(hero["stats"]["endurance"], 8, "warrior base")
	assert_eq(hero["jobs"]["smithing"]["level"], 1, "professions seeded")
	assert_eq(hero["skillNodes"].size(), 2, "level 3 owned the level-1 and level-3 skills")
	assert_eq(hero["skillPoints"], 1, "2 earned, 1 spent on the second skill")
	# progress preserved
	assert_eq(s["gold"], 123)
	assert_eq(s["unlockedLevel"], 4)
	assert_eq(s["clearedLevels"], [1, 2, 3])


func test_cleared_floors_reopen_new_content() -> void:
	var capped := _v1()
	capped["unlockedLevel"] = 10
	capped["clearedLevels"] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	assert_eq(SaveCodec.migrate(capped)["unlockedLevel"], 11)


func test_v2_flat_world_position_becomes_v3_world_memory() -> void:
	var state := _v1()
	state["world"] = {"mapId": "demo", "x": 10, "y": 16, "facing": "left"}
	var s := SaveCodec.migrate({"version": 2, "state": state})
	assert_eq(s["world"]["position"], {"mapId": "demo", "x": 10, "y": 16, "facing": "left"})
	assert_eq(s["world"]["openedChests"], [])
	assert_eq(s["world"]["slain"], [])


func test_v3_gear_counts_and_equipped_ids_become_instances() -> void:
	var state := _v1()
	state["world"] = null
	state["inventory"] = {"potion_hp": 2, "iron_armor": 1, "hunting_bow": 2}
	state["equipped"] = {"weapon": "rusty_sword"}
	var s := SaveCodec.migrate({"version": 3, "state": state})
	# 1 armor + 2 bows + the equipped sword = 4 instances, all common
	assert_eq(s["gear"].size(), 4)
	for instance: Dictionary in s["gear"]:
		assert_eq(instance["rarity"], "common")
	assert_eq(s["inventory"], {"potion_hp": 2})
	var uids: Array = s["gear"].map(func(g: Dictionary) -> String: return g["uid"])
	assert_has(uids, s["equipped"]["weapon"])


func test_rejects_saves_from_the_future_and_garbage() -> void:
	assert_eq(SaveCodec.migrate({"version": 999, "state": {"hero": {}}}), {})
	assert_eq(SaveCodec.migrate("PXH1.not-json"), {})
	assert_eq(SaveCodec.migrate(null), {})
	assert_eq(SaveCodec.migrate({"version": 4, "state": {"noHero": true}}), {})
	assert_eq(SaveCodec.migrate({"version": 4, "state": {"hero": {"name": "Ghost"}}}), {})


func test_save_codes_round_trip_byte_for_byte() -> void:
	var state := SaveCodec.migrate(_v1())
	var code := SaveCodec.encode_code(state)
	assert_true(code.begins_with("PXH1."))
	assert_eq(SaveCodec.decode_code(code), state)


func test_rejects_invalid_codes() -> void:
	assert_eq(SaveCodec.decode_code("PXH1.@@@not-base64@@@"), {})
	assert_eq(SaveCodec.decode_code("nonsense"), {})
	assert_eq(SaveCodec.decode_code(""), {})
	assert_eq(SaveCodec.decode_code("PXH1." + Marshalls.utf8_to_base64("not json")), {})


func test_a_code_copied_from_the_web_game_loads_intact() -> void:
	var code := FileAccess.get_file_as_string("res://test/fixtures/web_save_v4.txt")
	var s := SaveCodec.decode_code(code)
	assert_false(s.is_empty())
	assert_eq(s["hero"]["name"], "Brann")
	assert_eq(s["hero"]["roleId"], "ranger")
	assert_eq(s["hero"]["path"], ["beastmaster"])
	assert_eq(s["gold"], 4321)
	assert_eq(s["gear"][0]["itemId"], "hunting_bow")
	assert_eq(s["equipped"]["weapon"], s["gear"][0]["uid"])
	assert_eq(s["world"]["position"], {"mapId": "town", "x": 27, "y": 28, "facing": "left"})
	assert_eq(s["settlers"], ["settler_mirelle"])
	assert_eq(s["investments"]["savings"]["principal"], 500)
	assert_eq(s["worldSteps"], 777)
	assert_typeof(s["gold"], TYPE_INT, "integers survive the JSON trip")


func test_godot_serializes_integers_the_way_the_web_wrote_them() -> void:
	var code := FileAccess.get_file_as_string("res://test/fixtures/web_save_v4.txt")
	var json := SaveCodec.serialize(SaveCodec.decode_code(code))
	assert_false(json.contains(".0,"), "no float-formatted integers")
	assert_true(json.contains("\"gold\":4321"))


## A late-game save made by the web game's own reducer at v0.65: the balance
## sim's bot played a warrior through all fifteen floors, then bought the
## house, funded the village, bought the general store, banked some gold and
## stored a potion. What a veteran player brings across.
const LATE := "res://test/fixtures/web_save_late.txt"


func test_a_late_game_web_save_loads_intact() -> void:
	var s := SaveCodec.decode_code(FileAccess.get_file_as_string(LATE))
	assert_false(s.is_empty())
	assert_eq(s["hero"]["name"], "Hrafna")
	assert_eq(s["hero"]["level"], 18)
	assert_eq(s["hero"]["path"], ["juggernaut", "bastion", "unbroken"])
	assert_eq(s["hero"]["skillNodes"].size(), 12)
	assert_eq(s["clearedLevels"].size(), 15)
	assert_eq(s["unlockedLevel"], 15)
	assert_eq(s["house"], {"owned": true, "storage": {"potion_hp": 1}})
	assert_eq(s["properties"], ["town_shop"])
	assert_eq(s["townTier"], 2)
	assert_eq(s["investments"]["savings"]["principal"], 200)
	assert_eq(s["gear"].size(), 4)
	assert_eq(s["gold"], 2234)


## The web decoding that same code and writing it back (decodeSaveCode, then
## encodeSaveCode): Godot must write the very same text.
func test_a_late_game_web_save_reencodes_byte_for_byte() -> void:
	var web_json := FileAccess.get_file_as_string("res://test/fixtures/web_save_late_reencoded.json").strip_edges()
	var godot_json := SaveCodec.serialize(SaveCodec.decode_code(FileAccess.get_file_as_string(LATE)))
	assert_eq(godot_json, web_json)
