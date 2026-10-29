extends GutTest
## GegX's UI kit in UiStyle (PIX-385): each piece ui_kit.json names keeps its
## nine slices inside its art; withheld (the harness's `cc0`, a build without
## the private art) every builder still draws its own frame, and installed
## they wear the kit's pieces, at scale 1.

var _withheld := false


func before_each() -> void:
	_withheld = UiStyle.withheld


func after_each() -> void:
	UiStyle.withheld = _withheld


func _pieces() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(UiStyle.KIT))["pieces"]


func _installed() -> bool:
	return ResourceLoader.exists(UiStyle.KIT_ART + "window.png")


## The art of `piece`, as the kit installs it.
func _art(piece: String) -> Texture2D:
	return load(UiStyle.KIT_ART + String(_pieces()[piece]["file"]))


## Every builder that may wear the kit, by the piece it wears then.
func _built() -> Dictionary:
	var drawn := UiStyle.box(UiStyle.CARD, UiStyle.RIM, 4)
	var shown := {
		"window": UiStyle.window(16),
		"panel": UiStyle.window(8),
		"button": UiStyle.plank(false),
		"button_hover": UiStyle.plank(true),
		"button_disabled": UiStyle.plank(false, 6, true),
		"tab": UiStyle.tab(false),
		"tab_selected": UiStyle.tab(true),
		"slot": UiStyle.slot("", drawn),
	}
	for colourway: String in ["ready", "spent", "focus", "fine", "epic"]:
		shown["slot_" + colourway] = UiStyle.slot(colourway, drawn)
	# A roomy card is a window; a page is too.
	shown["box"] = UiStyle.box(UiStyle.CARD, UiStyle.RIM, 16)
	var page: Panel = autofree(UiStyle.page(Rect2(0, 0, 100, 100)))
	shown["page"] = page.get_theme_stylebox("panel")
	return shown


func test_every_piece_keeps_its_slices_inside_its_art() -> void:
	var pieces := _pieces()
	for name: String in pieces:
		var piece: Dictionary = pieces[name]
		for key: String in ["margins", "content"]:
			assert_eq((piece[key] as Array).size(), 4, "%s: %s left, top, right, bottom" % [name, key])
		assert_true(piece["axis"] in ["tile", "stretch"], "%s: tile or stretch" % name)
	if not _installed():
		pass_test("GegX's kit isn't installed here (scripts/fetch-private-art.sh)")
		return
	for name: String in pieces:
		var m: Array = pieces[name]["margins"]
		var size := _art(name).get_size()
		assert_lt(m[0] + m[2], size.x, "%s: its left and right slices leave a middle" % name)
		assert_lt(m[1] + m[3], size.y, "%s: its top and bottom slices leave a middle" % name)


func test_withheld_every_builder_draws_its_own() -> void:
	UiStyle.withheld = true
	var built := _built()
	for name: String in built:
		var style: StyleBox = built[name]
		assert_true(style is StyleBoxTexture, "%s: a frame" % name)
		assert_false(_is_kit((style as StyleBoxTexture).texture), "%s: drawn in code" % name)
	assert_null(UiStyle.bar_frame(), "the boss bar keeps its outline")
	var button: Button = autofree(UiStyle.button("Go", func() -> void: pass))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		assert_false(_is_kit((button.get_theme_stylebox(state) as StyleBoxTexture).texture), state)
	assert_eq(button.get_theme_color("font_color"), UiStyle.CREAM, "cream on the wood")
	assert_false(UiStyle.kit_shown())


func test_installed_the_builders_wear_the_kit() -> void:
	if not _installed():
		pass_test("GegX's kit isn't installed here (scripts/fetch-private-art.sh)")
		return
	UiStyle.withheld = false
	var built := _built()
	for name: String in built:
		var piece := "window" if name in ["box", "page"] else name
		assert_eq((built[name] as StyleBoxTexture).texture, _art(piece), "%s wears the kit's %s" % [name, piece])
	assert_eq(UiStyle.bar_frame().texture, _art("bar_frame"))
	# At scale 1: the manifest's margins as they are, not doubled.
	var window := UiStyle.window(16)
	assert_eq(window.texture_margin_left, float(_pieces()["window"]["margins"][0]))
	assert_eq(window.content_margin_left, float(_pieces()["window"]["content"][0]), "the words keep off the frame")
	assert_eq(UiStyle.window(30).content_margin_left, 30.0, "a roomier padding wins")
	var button: Button = autofree(UiStyle.button("Go", func() -> void: pass))
	for pair: Array in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"], ["disabled", "button_disabled"]]:
		assert_eq((button.get_theme_stylebox(pair[0]) as StyleBoxTexture).texture, _art(pair[1]), pair[0])
	assert_eq(button.get_theme_color("font_color"), UiStyle.INK, "ink on the kit's page-faced plank")
	UiStyle.focus(button)
	assert_eq((button.get_theme_stylebox("normal") as StyleBoxTexture).texture, _art("button_chosen"), "the chosen one")
	assert_eq(button.get_theme_color("font_color"), UiStyle.LAMP)
	UiStyle.tab_button(button, false)
	assert_eq((button.get_theme_stylebox("normal") as StyleBoxTexture).texture, _art("tab"), "a tab")
	assert_eq((button.get_theme_stylebox("hover") as StyleBoxTexture).texture, _art("tab_selected"), "lit under the mouse")


## The boss bar's strips stand inside the kit's frame, not over it.
func test_the_boss_bar_fills_inside_its_frame() -> void:
	if not _installed():
		pass_test("GegX's kit isn't installed here (scripts/fetch-private-art.sh)")
		return
	UiStyle.withheld = false
	var bar: Control = add_child_autofree(preload("res://scripts/boss_bar.gd").new())
	var frame: Panel = bar.fill.get_parent()
	var style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	assert_eq(style.texture, _art("bar_frame"))
	var inside := Rect2(Vector2(style.content_margin_left, style.content_margin_top), frame.custom_minimum_size - style.get_minimum_size())
	for strip: Control in [bar.fill, bar.ghost]:
		assert_true(inside.encloses(Rect2(strip.position, strip.size)), "%s inside %s" % [Rect2(strip.position, strip.size), inside])
	for notch: Control in bar.notches:
		assert_true(inside.encloses(Rect2(notch.position, notch.size)), "a notch inside")


## PIX-395: a keyed plank's cap stands inside the kit's face (22 px between
## its trims, the content box's top row being trim), a pixel clear of it,
## not over its frame; the plank stays PLANK tall.
func test_a_keyed_planks_cap_fits_inside_the_kits_face() -> void:
	if not _installed():
		pass_test("GegX's kit isn't installed here (scripts/fetch-private-art.sh)")
		return
	UiStyle.withheld = false
	var button: Button = add_child_autofree(UiStyle.button("Continue", func() -> void: pass, "Esc"))
	await wait_process_frames(1)
	assert_eq(button.size.y, float(UiStyle.PLANK))
	var frame := button.get_theme_stylebox("normal") as StyleBoxTexture
	var face := Rect2(frame.content_margin_left, frame.content_margin_top + 2, button.size.x - frame.content_margin_left - frame.content_margin_right, UiStyle.PLANK - frame.content_margin_top - frame.content_margin_bottom - 2)
	var cap: Keycap = button.get_node("keyed").get_child(0)
	for pressed: bool in [false, true]:
		var style := UiStyle.keycap_style(pressed, true, UiStyle.UI_SCALE, cap.slim)
		var drawn := Rect2(cap.get_parent().position + cap.position, cap.size).grow_individual(style.expand_margin_left, style.expand_margin_top, style.expand_margin_right, style.expand_margin_bottom)
		assert_true(face.encloses(drawn), "pressed %s: the cap %s inside the face %s" % [pressed, drawn, face])


func _is_kit(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.begins_with(UiStyle.KIT_ART)
