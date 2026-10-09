extends GutTest
## The desktop app (PIX-227): its extras run only on the desktop renderer in
## a window, never in the browser; the looks it can wear; the wider glow at
## night only, under the HUD; light colours kept true on a linear canvas;
## every pass over the world written for both canvases; and the export
## presets the CI builds the app from.

const LightRig := preload("res://scripts/light_rig.gd")
const Lookbook := preload("res://scripts/lookbook.gd")


func after_each() -> void:
	DesktopLook.look = DesktopLook.BROWSER
	DesktopLook.linear = false


func test_the_extras_need_the_desktop_renderer_in_a_window() -> void:
	assert_true(DesktopLook.available("forward_plus", false, "macOS"), "the app on a Mac")
	assert_true(DesktopLook.available("forward_plus", false, "Windows"), "and on Windows")
	assert_false(DesktopLook.available("mobile", false, "macOS"), "the mobile renderer's canvas keeps too little alpha for the glow's mark")
	assert_false(DesktopLook.available("gl_compatibility", false, "Windows"), "a desktop that fell back to the browser's renderer")
	assert_false(DesktopLook.available("gl_compatibility", true, "Web"), "the browser")
	assert_false(DesktopLook.available("forward_plus", true, "Web"), "anything in the browser")
	assert_false(DesktopLook.available("forward_plus", false, "headless"), "a quiet run draws nothing")
	if DisplayServer.get_name() == "headless":
		assert_false(DesktopLook.here(), "as these tests do in CI")


func test_the_app_wears_its_look_and_the_browser_its_own() -> void:
	assert_eq(DesktopLook.pick(false, HarnessFlags.new()), DesktopLook.BROWSER)
	assert_eq(DesktopLook.pick(false, HarnessFlags.new(PackedStringArray(["--look", "layered"]))), DesktopLook.BROWSER, "no look the renderer can't wear")
	assert_eq(DesktopLook.pick(true, HarnessFlags.new()), DesktopLook.APP)
	assert_eq(DesktopLook.pick(true, HarnessFlags.new(PackedStringArray(["--screenshot", "--look", "hdr"]))), "hdr", "a run picks another")
	assert_eq(DesktopLook.pick(true, HarnessFlags.new(PackedStringArray(["--look", "sepia"]))), DesktopLook.APP, "an unknown look is the app's")
	assert_eq(DesktopLook.pick(true, HarnessFlags.new(PackedStringArray(["--look"]))), DesktopLook.APP)


func test_every_look_says_what_it_wears() -> void:
	assert_true(DesktopLook.LOOKS.has(DesktopLook.APP))
	for look: String in DesktopLook.LOOKS:
		var spec: Dictionary = DesktopLook.LOOKS[look]
		assert_true(spec.has("hdr") and spec.has("wide"), look)
		if spec["wide"] > 0.0:
			assert_true(spec["hdr"], "%s adds light as light, on a linear canvas" % look)
	assert_false(DesktopLook.hdr(DesktopLook.BROWSER), "the browser's canvas is sRGB")
	assert_eq(DesktopLook.wide(DesktopLook.BROWSER, 1.0, true), 0.0, "with its own glow alone")
	assert_true(DesktopLook.hdr(DesktopLook.APP), "the app's canvas is HDR")
	assert_gt(DesktopLook.wide(DesktopLook.APP, 1.0, true), 0.0, "with the wider glow at night")
	assert_false(DesktopLook.hdr("sepia"), "an unknown look is the browser's")


func test_the_wider_glow_comes_with_the_dark_and_the_players_say() -> void:
	assert_eq(DesktopLook.wide(DesktopLook.APP, 0.0, true), 0.0, "none in the sun: sunlit sand is bright too")
	assert_gt(DesktopLook.wide(DesktopLook.APP, 1.0, true), DesktopLook.wide(DesktopLook.APP, 0.4, true), "more as it gets dark")
	assert_eq(DesktopLook.wide(DesktopLook.APP, 1.0, false), 0.0, "Glow off in the options")
	assert_eq(DesktopLook.wide(DesktopLook.APP, 3.0, true), DesktopLook.wide(DesktopLook.APP, 1.0, true), "no darker than night")


func test_the_glow_sits_under_the_hud() -> void:
	assert_lt(LightRig.GLOW_LAYER, 2, "the glow's layers lie under the HUD's")
	var mask := FileAccess.get_file_as_string("res://shaders/glow_mask.gdshader")
	assert_true(mask.contains("blend_disabled"), "the mark writes the screen back as it was")
	var wide := FileAccess.get_file_as_string("res://shaders/glow_wide.gdshader")
	assert_true(wide.contains("1.0 - seen.a"), "the wide glow reads the mark where the mask leaves it")


func test_light_colours_stay_true_on_a_linear_canvas() -> void:
	assert_eq(DesktopLook.canvas_color(Lights.FIRE, false), Lights.FIRE, "the browser's canvas takes them as they are")
	var fire := DesktopLook.canvas_color(Lights.FIRE, true)
	assert_almost_eq(fire.g, Lights.FIRE.srgb_to_linear().g, 0.0001, "made linear")
	assert_almost_eq(DesktopLook.shown(fire, true).g, Lights.FIRE.g, 0.001, "and shown as picked")
	assert_eq(DesktopLook.shown(Color("ae0000"), false).to_html(false), "ae0000")
	assert_eq(DesktopLook.shown(Color("ae0000").srgb_to_linear(), true).to_html(false), "ae0000", "the motion flow finds the hero's horns")
	DesktopLook.linear = true
	var lamp: PointLight2D = autofree(Lights.make(Vector2.ZERO, 64.0, Lights.LAMP, 0.4))
	assert_eq(lamp.get_meta("tint"), Lights.LAMP, "a light remembers the colour picked")
	assert_almost_eq(lamp.color.b, Lights.LAMP.srgb_to_linear().b, 0.0001, "and wears it linear")


func test_every_pass_over_the_world_reads_both_canvases() -> void:
	# A pass written for the browser's sRGB canvas reads and writes wrong
	# on the app's linear one unless it goes through shaders/linear.gdshaderinc.
	var dir := DirAccess.open("res://shaders")
	for file in dir.get_files():
		if not file.ends_with(".gdshader"):
			continue
		var code := FileAccess.get_file_as_string("res://shaders/" + file)
		if code.contains("COLOR =") or code.contains("COLOR.rgb"):
			assert_true(code.contains("#include \"res://shaders/linear.gdshaderinc\""), "%s minds the linear canvas" % file)


func test_the_look_book_shoots_the_looks_named() -> void:
	assert_eq(Lookbook.looks_from(HarnessFlags.new()), PackedStringArray())
	assert_eq(
		Lookbook.looks_from(HarnessFlags.new(PackedStringArray(["lookbook", "--looks", "browser,app,sepia,app"]))),
		PackedStringArray(["browser", "app"]),
		"the app's looks, once each, in order"
	)


func test_the_app_is_exported_for_mac_and_windows() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	var platforms := {}
	for section in presets.get_sections():
		if presets.has_section_key(section, "platform"):
			platforms[presets.get_value(section, "platform")] = section
	assert_true(platforms.has("Web"), "the browser build stays")
	assert_eq(platforms.get("Web"), "preset.0", "and stays the first, the one the deploy exports")
	for platform: String in ["macOS", "Windows Desktop"]:
		assert_true(platforms.has(platform), platform)
		var section: String = platforms[platform]
		assert_eq(presets.get_value(section, "include_filter"), presets.get_value("preset.0", "include_filter"), "%s carries what the web build does" % platform)
	assert_eq(presets.get_value(platforms["macOS"] + ".options", "binary_format/architecture"), "universal", "Intel and Apple silicon")
	assert_ne(presets.get_value(platforms["macOS"] + ".options", "application/bundle_identifier", ""), "", "a Mac app needs its id")
	assert_true(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"), "a universal Mac app needs ETC2/ASTC")
	assert_true(ProjectSettings.get_setting("application/config/use_custom_user_dir"), "the app's saves sit where every desktop run's do")
	assert_eq(ProjectSettings.get_setting("application/config/custom_user_dir_name"), "pixelheim")
