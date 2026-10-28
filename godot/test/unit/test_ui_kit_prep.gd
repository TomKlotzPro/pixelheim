extends GutTest
## The UI kit's prep pass (PIX-385, tools/ui_kit_prep.gd): its colours land on
## UiStyle's ramps, and its cut keeps clear of a baked label.

const Prep := preload("res://tools/ui_kit_prep.gd")


func test_the_palette_is_ui_styles() -> void:
	var ui := Prep.palette()
	assert_eq(ui["NIGHT"], UiStyle.NIGHT)
	assert_eq(ui["WOOD_DARK"], UiStyle.WOOD_DARK)
	assert_eq(ui["BRASS_LIGHT"], UiStyle.BRASS_LIGHT)
	assert_eq(ui["WINDOW"], UiStyle.WINDOW)
	assert_eq(ui["EPIC"], UiStyle.EPIC)


func test_the_kits_colours_fall_in_their_families() -> void:
	assert_eq(Prep.family_of(Color("060504")), "night", "near-black outline")
	assert_eq(Prep.family_of(Color("864c3a")), "wood", "maroon wood")
	assert_eq(Prep.family_of(Color("3f2c34")), "wood", "the parchment's plum frame")
	assert_eq(Prep.family_of(Color("f6c67a")), "brass")
	assert_eq(Prep.family_of(Color("e2c19a")), "page")


func test_luminance_places_a_colour_on_its_ramp() -> void:
	var spans := {"wood": Vector2(Color("5a2f2e").get_luminance(), Color("b2714c").get_luminance())}
	assert_eq(Prep.on_ramps(Color("5a2f2e"), spans), UiStyle.WOOD_DARK)
	assert_eq(Prep.on_ramps(Color("b2714c"), spans), UiStyle.WOOD_LIGHT)
	assert_eq(Prep.on_ramps(Color("b2714c"), spans, {}, 1), UiStyle.WOOD_LIGHT, "a shift stops at the ramp's end")
	assert_eq(Prep.on_ramps(Color("b2714c"), spans, {}, -1), UiStyle.WOOD)
	assert_eq(Prep.on_ramps(Color("5a2f2e"), spans, {"wood": "brass"}), UiStyle.BRASS_DARK, "a colourway")
	assert_eq(Prep.on_ramps(Color(0, 0, 0, 0), spans), Color(0, 0, 0, 0), "clear stays clear")


func test_the_cut_leaves_the_label_out() -> void:
	# A page between two-pixel margins, with a word inked on columns 6..8.
	var img := Image.create(12, 3, false, Image.FORMAT_RGBA8)
	img.fill(UiStyle.WINDOW)
	for x in [6, 7, 8]:
		img.set_pixel(x, 1, UiStyle.NIGHT)
	var m := [2, 1, 2, 1]
	var runs := Prep.runs_of(img, m, [6, 9], 1)
	assert_true(runs[0].x + runs[0].y <= 6 or runs[0].x >= 9, "the run %s keeps clear of the label" % runs[0])
	var out := Prep.assemble(img, m, runs)
	assert_eq(Prep.stray_in_middle(out, m), 0, "nothing but the page between the margins")
	assert_gte(out.get_width() - 4, Prep.WIDEN, "a short run is copied wider")


func test_the_cut_takes_the_run_that_repeats_cleanly() -> void:
	# Stripes every 3 columns, then noise: a whole stripe repeats, the noise doesn't.
	var lines: Array[PackedColorArray] = []
	for i in 12:
		var tone := UiStyle.WOOD if i < 9 and i % 3 == 0 else UiStyle.WOOD_DARK
		if i >= 9:
			tone = [UiStyle.NIGHT, UiStyle.BRASS, UiStyle.CARD][i - 9]
		lines.append(PackedColorArray([tone, tone]))
	var run := Prep.best_run(lines, 0, 11, [], 2)
	assert_eq(run.y % 3, 0, "a whole number of stripes: %s" % run)
	assert_lte(run.x + run.y, 9, "inside the stripes")
