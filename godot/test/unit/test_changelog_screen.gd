extends GutTest
## What's new (PIX-444): the "Behind the scenes" notes, nothing a player
## sees, stay out of it, and its first release is still the game's version.

const ChangelogScreen := preload("res://scripts/changelog_screen.gd")


func test_whats_new_leaves_out_behind_the_scenes() -> void:
	var raw: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/changelog.json"))
	var behind := 0
	for release: Dictionary in raw["releases"]:
		behind += release["notes"].filter(func(note: String) -> bool: return note.begins_with(ChangelogScreen.BEHIND)).size()
	assert_gt(behind, 0, "the changelog has some to leave out")
	var shown := ChangelogScreen.releases()
	for release: Dictionary in shown:
		for note: String in release["notes"]:
			assert_false(note.begins_with(ChangelogScreen.BEHIND), "v%s: %s" % [release["version"], note])
	assert_eq(shown[0]["version"], raw["releases"][0]["version"], "newest first, the game's version")
