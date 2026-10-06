extends GutTest
## Whatever a player pastes from the web game should land: a PXH1 code, the
## raw localStorage JSON, or a pre-envelope save from the oldest versions.

const FIXTURE := "res://test/fixtures/web_save_v4.txt"


func _code() -> String:
	return FileAccess.get_file_as_string(FIXTURE)


func test_a_save_code_parses() -> void:
	var state := WebImport.parse_any(_code())
	assert_eq(state["hero"]["name"], "Brann")


func test_surrounding_whitespace_is_forgiven() -> void:
	assert_false(WebImport.parse_any("\n  " + _code() + "  \n").is_empty())


func test_the_raw_local_storage_json_parses() -> void:
	# What localStorage holds under pixelheim-save-v1: the envelope, uncoded.
	var raw := Marshalls.base64_to_utf8(_code().strip_edges().substr(SaveCodec.CODE_PREFIX.length()))
	assert_true(raw.begins_with("{"))
	assert_eq(WebImport.parse_any(raw), WebImport.parse_any(_code()))


func test_a_pre_envelope_save_still_parses() -> void:
	var bare := JSON.stringify({
		"hero": {
			"name": "OldTimer", "roleId": "warrior", "level": 3, "xp": 10, "xpToNext": 74,
			"hp": 40, "mp": 5, "stats": {"maxHp": 56, "maxMp": 10, "strength": 15},
		},
		"gold": 123, "inventory": {}, "equipped": {}, "unlockedLevel": 1, "clearedLevels": [],
	})
	assert_eq(WebImport.parse_any(bare)["gold"], 123)


func test_anything_else_is_refused() -> void:
	assert_eq(WebImport.parse_any(""), {})
	assert_eq(WebImport.parse_any("hello"), {})
	assert_eq(WebImport.parse_any("{ broken"), {})
	assert_eq(WebImport.parse_any("[1, 2, 3]"), {})


func test_describe_names_hero_level_and_role() -> void:
	assert_eq(WebImport.describe(WebImport.parse_any(_code())), "Brann, level 1 ranger")


func test_no_browser_no_web_save() -> void:
	# Desktop and headless runs have no localStorage to read.
	assert_eq(WebImport.find_in_browser(), {})
