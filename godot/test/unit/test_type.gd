extends GutTest
## The game's type (PIX-533): Nunito for every word read, its line box cut to
## the pixel face's so pages keep their room; every character the catalogues
## hold drawn by Nunito or the pixel face behind it, never a box or a system
## font; French's narrow space and no-break hyphen as Nunito draws them; the
## pixel face at its own 9 px for the floats and the keycaps.


func _glyphs(text: String, font: Font, size := UiStyle.TEXT) -> Array[Dictionary]:
	var line := TextLine.new()
	line.add_string(text, font, size)
	return TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid())


func test_each_size_keeps_the_pixel_faces_line() -> void:
	for font: Font in [UiStyle.body_font(), UiStyle.bold_font()]:
		assert_eq(font.get_ascent(UiStyle.TEXT), 18.0, "the baseline where it was")
		assert_eq(font.get_height(UiStyle.TEXT), 22.0, "a line of 22")
	for font: Font in [UiStyle.body_font(true), UiStyle.bold_font(true)]:
		assert_eq(font.get_ascent(UiStyle.BIG), 27.0, "the big baseline where it was")
		assert_eq(font.get_height(UiStyle.BIG), 33.0, "a big line of 33")


func test_a_control_nobody_sized_reads_in_the_trimmed_face() -> void:
	UiStyle.setup()
	var words: Label = add_child_autofree(Label.new())
	var press: Button = add_child_autofree(Button.new())
	for control: Control in [words, press]:
		assert_eq(control.get_theme_font("font"), UiStyle.body_font(), "%s: the trimmed cut, not the bare file" % control.get_class())
		assert_eq(control.get_theme_font_size("font_size"), UiStyle.TEXT)


func test_every_character_of_the_catalogues_has_a_glyph() -> void:
	var chars := {}
	for path: String in ["res://locale/fr.po", "res://locale/en.po"]:
		for c in FileAccess.get_file_as_string(path):
			if c.unicode_at(0) >= 0x20:
				chars[c] = true
	assert_gt(chars.size(), 100, "the catalogues were read")
	for font: Font in [UiStyle.body_font(), UiStyle.bold_font()]:
		var own := font.get_rids()
		assert_eq(own.size(), 2, "Nunito and the pixel face behind it")
		var missing: Array[String] = []
		for c: String in chars:
			for glyph in _glyphs(c, font):
				if glyph["font_rid"] not in own:
					missing.append("U+%04X" % c.unicode_at(0))
		assert_eq(missing, [] as Array[String], "drawn by the game's own faces")


func test_the_narrow_space_is_narrow() -> void:
	var font := UiStyle.body_font()
	var width := func(text: String) -> float: return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT).x
	assert_gt(width.call("a\u202fb"), width.call("ab"), "a gap")
	assert_lt(width.call("a\u202fb"), width.call("a b"), "narrower than a space")


func test_the_no_break_hyphen_is_nunitos_hyphen() -> void:
	var font := UiStyle.body_font()
	assert_eq(font.get_string_size("êtes\u2011vous", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT),
		font.get_string_size("êtes-vous", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT))
	assert_eq(_glyphs("\u2011", font).size(), 1, "shaped")
	for glyph in _glyphs("\u2011", font):
		assert_eq(glyph["font_rid"], font.get_rids()[0], "Nunito's own")


func test_an_arrow_comes_from_the_pixel_face() -> void:
	var pixel: Array[RID] = []
	pixel.assign((load("res://assets/fonts/PixeloidSans.ttf") as Font).get_rids())
	assert_eq(_glyphs("↑", UiStyle.body_font()).size(), 1, "shaped")
	for glyph in _glyphs("↑", UiStyle.body_font()):
		assert_has(pixel, glyph["font_rid"])
	for glyph in _glyphs("↑", UiStyle.bold_font()):
		assert_has(UiStyle.pixel_font().get_rids(), glyph["font_rid"])


func test_the_pixel_face_keeps_its_own_pixels() -> void:
	assert_eq(UiStyle.pixel_font().fixed_size, UiStyle.BODY_PX)
	assert_eq(UiStyle.pixel_font().antialiasing, TextServer.FONT_ANTIALIASING_NONE)
