extends GutTest
## The game in more than one language (PIX-195): English is the source and
## its own key; the data's words translate as they load, ids never do; a
## format string is translated before it is filled; the catalogue
## (locale/messages.pot) holds what there is to translate.

var fake: Translation


func before_each() -> void:
	fake = Translation.new()
	fake.locale = "xx"
	fake.add_message("Slime Trouble", "Ennuis gluants")
	fake.add_message("Quest accepted: %s. %s", "Quête acceptée : %s. %s")
	fake.add_message("Merchant Odo", "Marchand Odo")
	TranslationServer.add_translation(fake)


func after_each() -> void:
	TranslationServer.remove_translation(fake)
	Text.apply("en")


func _speak_fake() -> void:
	TranslationServer.set_locale("xx")
	Text.forget()


func test_the_datas_words_translate_as_they_load_and_ids_never_do() -> void:
	_speak_fake()
	var quest := Quests.by_id("slime_trouble")
	assert_eq(quest["name"], "Ennuis gluants")
	assert_eq(quest["giver"], "innkeeper", "an id stays an id")
	assert_eq(quest["objective"]["monsterId"], "slime")
	assert_eq(Economy._data()["shops"]["odo"]["keeper"], "Marchand Odo")
	assert_eq(quest["brief"], "Sela's cellar smells of slime. Thin the forest's supply of them.", "untranslated words stay English")


func test_a_format_is_translated_before_it_is_filled() -> void:
	_speak_fake()
	assert_eq(Text.t("Quest accepted: %s. %s") % ["Ennuis gluants", "x"], "Quête acceptée : Ennuis gluants. x")
	assert_eq(Text.t(""), "")


func test_english_reads_as_written() -> void:
	Text.apply("en")
	assert_eq(Quests.by_id("slime_trouble")["name"], "Slime Trouble")
	assert_eq(Text.t("Quest accepted: %s. %s"), "Quest accepted: %s. %s")


func test_the_language_follows_the_choice_or_the_system() -> void:
	assert_eq(Text.language_for("fr"), "fr")
	assert_eq(Text.language_for("en"), "en")
	assert_true(Text.LANGUAGES.has(Text.language_for("")), "the system's, or English")
	assert_true(Text.LANGUAGES.has(Text.language_for("klingon")))
	var registered: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations")
	for code: String in Text.LANGUAGES:
		if code != "en":
			assert_has(registered, "res://locale/%s.po" % code, "%s's catalogue is loaded" % code)


func test_the_catalogue_holds_the_datas_words() -> void:
	var catalogue := {}
	for line in FileAccess.get_file_as_string("res://locale/messages.pot").split("\n"):
		if line.begins_with("msgid \""):
			catalogue[JSON.parse_string(line.substr(6))] = true
	for quest: Dictionary in Quests.all():
		assert_true(catalogue.has(quest["name"]), "the quest %s" % quest["name"])
		assert_true(catalogue.has(quest["brief"]), "its brief")
	for npc: Dictionary in Npcs._data()["npcs"]:
		for line: String in npc.get("lines", []):
			assert_true(catalogue.has(line), "%s's line" % npc["id"])
	assert_true(catalogue.has("Quest accepted: %s. %s"), "a format the game fills")
	assert_true(catalogue.has("close"), "a footer's word")


func test_no_prose_format_skips_the_translation() -> void:
	var template := RegEx.create_from_string("(?<![\\w.])(\"(?:[^\"\\\\\\n]|\\\\.)*%[sdf0-9.+-]*[sdf](?:[^\"\\\\\\n]|\\\\.)*\")\\s*%")
	var wrapped := RegEx.create_from_string("(tr|Text\\.t|tr_n)\\(\\s*$")
	var words := RegEx.create_from_string("[A-Za-z]{2,}")
	var missed: Array[String] = []
	for folder in ["res://scripts", "res://scripts/state"]:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".gd") or file == "harness.gd":
				continue
			var number := 0
			for line in FileAccess.get_file_as_string(folder + "/" + file).split("\n"):
				number += 1
				if line.strip_edges().begins_with("#") or "print(" in line or "push_" in line:
					continue
				for found in template.search_all(line):
					var inner := found.get_string(1)
					if "res://" in inner or "puny-skills/" in inner or not " " in inner.strip_edges():
						continue
					if words.search(inner) == null:
						continue  # "%s: %s" - no words to translate
					if inner.begins_with("\"window %") or inner.begins_with("\"card %") or inner.begins_with("\"plank %") or inner.begins_with("\"keycap %"):
						continue
					if wrapped.search(line.substr(0, found.get_start())) == null:
						missed.append("%s:%d %s" % [file, number, inner])
	assert_eq(missed, [] as Array[String], "every sentence built from a format goes through Text.t")
