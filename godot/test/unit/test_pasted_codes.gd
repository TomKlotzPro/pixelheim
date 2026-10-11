extends GutTest
## Whatever a player pastes into the saves screen's Save code should land: a
## PXH1 code, the raw JSON of a save, or a pre-envelope save from the oldest
## versions.

const FIXTURE := "res://test/fixtures/web_save_v4.txt"
const SavesScreen := preload("res://scripts/saves_screen.gd")


func _code() -> String:
	return FileAccess.get_file_as_string(FIXTURE)


func test_a_save_code_parses() -> void:
	var state := SaveCodec.parse_any(_code())
	assert_eq(state["hero"]["name"], "Brann")


func test_surrounding_whitespace_is_forgiven() -> void:
	assert_false(SaveCodec.parse_any("\n  " + _code() + "  \n").is_empty())


func test_the_raw_json_of_a_save_parses() -> void:
	# The envelope, uncoded: what a slot file holds.
	var raw := Marshalls.base64_to_utf8(_code().strip_edges().substr(SaveCodec.CODE_PREFIX.length()))
	assert_true(raw.begins_with("{"))
	assert_eq(SaveCodec.parse_any(raw), SaveCodec.parse_any(_code()))


func test_a_pre_envelope_save_still_parses() -> void:
	var bare := JSON.stringify({
		"hero": {
			"name": "OldTimer", "roleId": "warrior", "level": 3, "xp": 10, "xpToNext": 74,
			"hp": 40, "mp": 5, "stats": {"maxHp": 56, "maxMp": 10, "strength": 15},
		},
		"gold": 123, "inventory": {}, "equipped": {}, "unlockedLevel": 1, "clearedLevels": [],
	})
	assert_eq(SaveCodec.parse_any(bare)["gold"], 123)


func test_anything_else_is_refused() -> void:
	assert_eq(SaveCodec.parse_any(""), {})
	assert_eq(SaveCodec.parse_any("hello"), {})
	assert_eq(SaveCodec.parse_any("{ broken"), {})
	assert_eq(SaveCodec.parse_any("[1, 2, 3]"), {})


func test_describe_names_hero_level_and_role() -> void:
	assert_eq(SavesScreen.describe(SaveCodec.parse_any(_code())), "Brann, level 1 ranger")
