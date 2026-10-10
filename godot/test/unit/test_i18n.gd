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
	assert_eq(quest["brief"], "Slimes have crept into what's left of Sela's stores. Thin the forest's supply of them.", "untranslated words stay English")


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
			if not file.ends_with(".gd") or file in ["harness.gd", "harness_report.gd"]:
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


## PIX-196: the words the screens glue together - tags, compact gold, the
## pack's order, an ailment's name, a stat - speak the player's language.
func test_tags_and_compact_gold_speak_french() -> void:
	const InventoryScreen := preload("res://scripts/inventory_screen.gd")
	Text.apply("fr")
	assert_eq(Text.coins(55), "55 o")
	assert_eq(InventoryScreen.sort_name("kind"), "type")
	assert_eq(Ailments.label("burn"), "brûlure")
	assert_string_contains(InventoryScreen.stat_line(Catalog.item("iron_sword"), 0, 120), "FOR")
	# The journal's tags (PIX-239: FOLLOWING and READY, where its chapters said DONE and NEXT).
	for tag: String in ["EQUIPPED", "SLAIN", "CLEARED", "FOLLOWING", "READY", "NEW", "BUILT", "COMMISSIONED", "SKILL", "UPGRADE", "PASSIVE", "locked"]:
		assert_ne(Text.t(tag), tag, "%s is translated" % tag)
	assert_eq(Text.listed(["la place", "les loyers"]), "la place\u202f; les loyers", "a narrow space before French's semicolon")
	Text.apply("en")
	assert_eq(Text.coins(55), "55g")
	assert_eq(Text.listed(["the square", "the rents"]), "the square; the rents")
	assert_eq(InventoryScreen.sort_name("kind"), "kind")


## PIX-196: French is whole - every string the catalogue holds has its
## translation, with the same placeholders, so a new line can't ship in
## English only.
func test_french_is_complete() -> void:
	var french := {}
	var msgid := ""
	for line in FileAccess.get_file_as_string("res://locale/fr.po").split("\n"):
		if line.begins_with("msgid \""):
			msgid = JSON.parse_string(line.substr(6))
		elif line.begins_with("msgstr \"") and msgid != "":
			french[msgid] = JSON.parse_string(line.substr(7))
			msgid = ""
	var holes: Array[String] = []
	var placeholder := RegEx.create_from_string("%[-+0#]*\\d*(?:\\.\\d+)?[sdfixX%]")
	for line in FileAccess.get_file_as_string("res://locale/messages.pot").split("\n"):
		if not line.begins_with("msgid \""):
			continue
		var english: String = JSON.parse_string(line.substr(6))
		if english == "":
			continue
		var said: String = french.get(english, "")
		var wanted := placeholder.search_all(english).map(func(found: RegExMatch) -> String: return found.get_string())
		var given := placeholder.search_all(said).map(func(found: RegExMatch) -> String: return found.get_string())
		if said == "" or wanted != given:
			holes.append(english.left(60))
	assert_eq(holes, [] as Array[String], "every string has its French, placeholders kept")


## PIX-208: the corners French still missed.
func test_french_reaches_signs_the_deep_and_the_cutscenes() -> void:
	Text.apply("fr")
	var owned: Dictionary = Interactables._data()["signsHouseOwned"]
	for map_id: String in owned:
		for sign_def: Dictionary in owned[map_id]:
			assert_true(ShopSign.ICONS.has(sign_def["label"]), "%s keeps its icon" % sign_def["label"])
	var english_deep: String = Dungeons.floor_def(Dungeons.floor_count() + 1)["name"]
	Text.apply("en")
	assert_ne(Dungeons.floor_def(Dungeons.floor_count() + 1)["name"], english_deep, "the Deep Hunt's name follows the language")
	Text.apply("fr")
	var titles: Array = []
	for scene: String in Cutscene.scenes():
		for step: Dictionary in Cutscene.scenes()[scene]:
			if step.get("kind", "") == "card":
				titles.append(step["text"])
	assert_false(titles.is_empty())
	assert_false(titles.has("Fafnyr the Ashen"), "the title cards speak French")
