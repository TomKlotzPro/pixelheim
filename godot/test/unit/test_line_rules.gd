extends GutTest
## The words as a line sets them (PIX-478, PIX-484): the house's dash holds
## to the word before it in either language (in the catalogues' own words,
## no object set in the engine's server), a mark never starts a wrapped
## line (only the dash can in the editor's build: ICU's rules, built into it
## and shipped with the exports since PIX-471, never break before ? ! ; :),
## and a percent and a plural are written as the language writes them.

var nbsp := char(0xa0)
var narrow := char(0x202f)


func after_each() -> void:
	Text.apply("en")


func _wrapped(text: String, width: float) -> Label:
	var label := UiStyle.label(text, 14, UiStyle.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child_autofree(label)
	# After it wraps: a label that hasn't yet is as wide as its one line.
	await wait_process_frames(2)
	label.size = Vector2(width, 0)
	await wait_process_frames(1)
	return label


## The width at which `text` breaks just before its last `tail` characters.
func _width_before(text: String, tail: int) -> float:
	var label: Label = autofree(UiStyle.label(text, 14, UiStyle.INK))
	return label.get_theme_font(&"font").get_string_size(text.left(text.length() - tail), HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x + 2.0


func test_the_dash_holds_to_the_word_before_it_in_both_languages() -> void:
	Text.apply("en")
	assert_eq(Text.t("%s howls - the forest answers!"), "%s howls" + nbsp + "- the forest answers!", "English's own catalogue holds only its set lines")
	assert_eq(Text.t("Craft"), "Craft", "every other string is its own key")
	assert_string_contains(String(Quests.by_id("slime_trouble")["brief"]), "fields east", "the data's words still load")
	assert_string_contains(Bearing.line({"step": "See Sela.", "place": "Town", "progress": ""}), "See Sela" + nbsp + "- Town")
	Text.apply("fr")
	assert_eq(Text.t("Craft"), "Artisanat")
	assert_string_contains(Text.t("%s howls - the forest answers!"), nbsp + "- ")
	assert_true(Text.t("You came up the road as the fire came down the mountain. Who are you?").ends_with("êtes" + char(0x2011) + "vous" + narrow + "?"), "« êtes-vous ? » stays whole: a question's last word keeps the one hyphened to it")
	# No GDScript object stands in the engine's server (it outlived the scripts and crashed every quit).
	for code: String in Text.LANGUAGES:
		assert_null(TranslationServer.get_translation_object(code).get_script(), code)


func test_a_mark_alone_at_a_lines_start_is_found() -> void:
	Text.apply("fr")
	var plain := "Qui va là, sur la route" + narrow + "?"
	assert_false(Layout.stranded(await _wrapped(plain, _width_before(plain, 1))), "the narrow no-break space keeps the mark")
	var dash := "Signature : Fournaise - la pièce brûle"
	assert_true(Layout.stranded(await _wrapped(dash, _width_before(dash, 16))), "a dash typed with plain spaces starts the line")
	var held := dash.replace(" - ", nbsp + "- ")
	assert_false(Layout.stranded(await _wrapped(held, _width_before(held, 16))), "held as the catalogues hold it, the dash ends the line before")
	assert_false(Layout.stranded(UiStyle.label(plain, 14, UiStyle.INK)), "one line has no second line to start")


func test_a_percent_and_a_plural_follow_the_language() -> void:
	Text.apply("en")
	assert_eq(Text.percent(70), "70%")
	assert_eq([Text.s(0), Text.s(1), Text.s(2)], ["s", "", "s"], "0 points, 1 point, 2 points")
	Text.apply("fr")
	assert_eq(Text.percent(70), "70" + narrow + "%")
	assert_eq([Text.s(0), Text.s(1), Text.s(2)], ["", "", "s"], "0 point, 1 point, 2 points")
	assert_eq(Text.t("%d skill point%s") % [0, Text.s(0)], "0 point de compétence")


## PIX-474, PIX-479, PIX-484: one place for Sela's slimes, one name for her
## helmet, no article on a family's name.
func test_the_french_names_one_thing_one_way() -> void:
	Text.apply("fr")
	var brief := String(Quests.by_id("slime_trouble")["brief"])
	assert_string_contains(brief, "champs à l'est")
	assert_false("forêt" in brief)
	assert_string_contains(Text.t("Wear the cap Sela gave you (press {key:inventory} to open your pack)"), "le casque")
	for family: String in Bestiary.family_names().values():
		assert_false(family.begins_with("Les "), family)
