extends GutTest
## Whatever a player pastes into the saves screen's Save code: a PXH2 code
## lands, the raw JSON of a save too; a code or a save from before v5 says
## it's from an older version (PIX-302: no migration until the beta), and
## anything else is refused.

const FIXTURE := "res://test/fixtures/web_save_v4.json"
const OLDER := "res://test/fixtures/slots_older/slot_1.json"
const SavesScreen := preload("res://scripts/saves_screen.gd")


func _code() -> String:
	return SaveCodec.encode_code(SaveCodec.parse_any(FileAccess.get_file_as_string(FIXTURE)))


func test_a_save_code_parses() -> void:
	var state := SaveCodec.parse_any(_code())
	assert_eq(state["hero"]["name"], "Brann")


func test_surrounding_whitespace_is_forgiven() -> void:
	assert_false(SaveCodec.parse_any("\n  " + _code() + "  \n").is_empty())


func test_the_raw_json_of_a_save_parses() -> void:
	# What a slot file holds, uncoded.
	var raw := FileAccess.get_file_as_string(FIXTURE)
	assert_true(raw.begins_with("{"))
	assert_eq(SaveCodec.parse_any(raw), SaveCodec.parse_any(_code()))


func test_an_older_versions_save_or_code_is_said_older() -> void:
	var raw := FileAccess.get_file_as_string(OLDER)
	assert_eq(SaveCodec.pasted(raw), {"state": {}, "problem": SaveCodec.OLDER}, "its JSON")
	assert_eq(SaveCodec.pasted("PXH1." + Marshalls.utf8_to_base64(raw))["problem"], SaveCodec.OLDER, "its code")


func test_anything_else_is_refused() -> void:
	assert_eq(SaveCodec.parse_any(""), {})
	assert_eq(SaveCodec.parse_any("hello"), {})
	assert_eq(SaveCodec.parse_any("{ broken"), {})
	assert_eq(SaveCodec.parse_any("[1, 2, 3]"), {})


func test_describe_names_hero_level_and_role() -> void:
	assert_eq(SavesScreen.describe(SaveCodec.parse_any(_code())), "Brann, level 1 ranger")
