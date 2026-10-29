extends GutTest
## The loading screen (PIX-296): the title's night drawn in code
## (tools/splash.py, assets/splash.png), the desktop app's boot splash and
## the web page's picture, with the page's life in web/shell.html; no words
## but the logo, and the logo where the title draws it; a launch's title
## rises out of the same picture into its entrance (PIX-392), and the name
## is forged back where the picture showed it.

const TitleScreen := preload("res://scripts/title_screen.gd")
const SHELL := "res://web/shell.html"

var _reduce_motion: bool


func before_each() -> void:
	_reduce_motion = GameState.settings.reduce_motion


func after_each() -> void:
	GameState.settings.reduce_motion = _reduce_motion
	get_tree().paused = false
	Sound.stop_all()


func _picture() -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(TitleScreen.SPLASH))


func test_the_boot_splash_is_the_drawn_night() -> void:
	assert_eq(ProjectSettings.get_setting("application/boot_splash/image"), TitleScreen.SPLASH)
	assert_true(ProjectSettings.get_setting("application/boot_splash/show_image", true), "shown")
	assert_false(ProjectSettings.get_setting("application/boot_splash/use_filter", true), "in whole pixels, unsmoothed")
	assert_eq(ProjectSettings.get_setting("application/boot_splash/bg_color"), Color.BLACK, "black bars, like the game's canvas")
	var picture := _picture()
	assert_eq(Vector2(picture.get_size()), TitleScene.ART, "the title's art pixels: 2x on the canvas")
	var corner := picture.get_pixel(0, 0)
	assert_lt(maxf(corner.r, maxf(corner.g, corner.b)), 0.1, "the night's top corner, darker under the vignette")


func test_the_logo_is_where_the_title_draws_it() -> void:
	# PIXELHEIM's face starts at canvas (336, 84) (title_screen.gd: the word
	# centred at LOGO_Y, 64 px a letter and 4 between): art (168, 42), its
	# lighter top first, the gold under it, nothing gold above it.
	var picture := _picture()
	var left := 168
	var top := int(TitleScreen.LOGO_Y / 2.0)
	assert_eq(picture.get_pixel(left + 1, top + 1), Color("ffe08f"), "P's top, lit")
	assert_eq(picture.get_pixel(left + 1, top + 20), Color("f2c14e"), "P's stem, gold")
	assert_ne(picture.get_pixel(left + 1, top - 1), Color("ffe08f"), "nothing above the word")
	# M, the ninth letter: its last column 34 art pixels a letter on.
	assert_eq(picture.get_pixel(left + 8 * 34 + 6 * 4 + 1, top + 1), Color("ffe08f"), "M's top right")


func test_the_web_page_is_the_games_shell() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_string_contains(presets, "html/custom_html_shell=\"%s\"" % SHELL)
	assert_string_contains(presets, "html/head_include=\"\"", "everything is in the shell")
	var page := FileAccess.get_file_as_string(SHELL)
	for placeholder: String in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_SPLASH", "$GODOT_THREADS_ENABLED", "$GODOT_HEAD_INCLUDE", "$GODOT_PROJECT_NAME"]:
		assert_string_contains(page, placeholder)
	# The picture's life draws before the engine's script is even asked for.
	assert_lt(page.find("window.pixelheimShown"), page.find("<script src=\"$GODOT_URL\">"), "alive before the engine arrives")


func test_the_page_shows_no_words() -> void:
	# What a player could read: the body's markup, less its scripts, its
	# tags and the error notice (Godot's own, shown only when it fails).
	var page := FileAccess.get_file_as_string(SHELL)
	var body := page.substr(page.find("<body>"))
	for block: String in ["<script[\\s\\S]*?</script>", "<!--[\\s\\S]*?-->", "<[^>]*>"]:
		body = RegEx.create_from_string(block).sub(body, " ", true)
	assert_null(RegEx.create_from_string("[A-Za-z]{2,}").search(body), "no words: %s" % body.strip_edges())
	assert_string_contains(page, "alt=\"\"", "the picture says nothing either")


func test_the_pages_live_points_fit_the_picture() -> void:
	var page := FileAccess.get_file_as_string(SHELL)
	var found := RegEx.create_from_string("const SCENE = (\\{.*\\});").search(page)
	assert_not_null(found, "tools/splash.py wrote the scene's points")
	var scene: Dictionary = JSON.parse_string(found.get_string(1))
	var size := Rect2(Vector2.ZERO, TitleScene.ART)
	assert_gt(scene["windows"].size(), 6, "the village's windows")
	var picture := _picture()
	var last := -1.0
	for pane: Array in scene["windows"]:
		assert_true(size.encloses(Rect2(pane[0], pane[1], pane[2], pane[3])), "a window in the picture")
		assert_true(pane[0] >= last, "they light left to right")
		last = pane[0]
		assert_eq(Color(pane[5]), picture.get_pixel(int(pane[0]) + 4, int(pane[1])), "its frame is the picture's")
	for star: Array in scene["stars"]:
		assert_ne(Color(star[2]), picture.get_pixel(int(star[0]), int(star[1])), "a twinkling star shines in the picture")
	var bar: Dictionary = scene["bar"]
	assert_true(size.encloses(Rect2(bar["x"], bar["y"], bar["w"], bar["h"])), "the bar in the picture")


func test_a_launch_rises_out_of_the_picture() -> void:
	GameState.settings.reduce_motion = false
	TitleScreen._risen = false
	var title := TitleScreen.new()
	add_child(title)
	var veil: Control = null
	for child in title.get_children():
		if child is TextureRect and (child as TextureRect).texture != null and (child as TextureRect).texture.resource_path == TitleScreen.SPLASH:
			veil = child
	# The launch's entrance (PIX-392) begins under it, among the stars.
	assert_not_null(title.entrance, "a launch plays its entrance")
	if Touch.view_size(title) == Touch.DESIGN:
		assert_not_null(veil, "the loading picture over the scene")
		assert_gt(veil.get_index(), title.logo.get_index(), "over everything, the name too: it is forged later")
		assert_eq(veil.size, TitleScreen.VIEW, "the canvas, as the boot splash fills it")
		assert_eq(veil.modulate.a, 1.0, "the picture at first")
		title.entrance.hold(TitleEntrance.VEIL_S)
		assert_almost_eq(veil.modulate.a, 0.0, 0.001, "lifted as the camera comes down")
	else:
		assert_null(veil, "a phone's wider canvas rises out of the night")
	title.close()
	await get_tree().process_frame
	# Back from the saves: the night's colour, not the loading screen again.
	var again := TitleScreen.new()
	add_child(again)
	assert_null(again.entrance, "the entrance plays once a launch")
	var night := again.get_children().filter(func(child: Node) -> bool: return child is ColorRect and (child as ColorRect).color == TitleScene.SKY[1])
	assert_eq(night.size(), 1, "the night's colour")
	assert_true(again.get_children().all(func(child: Node) -> bool: return not (child is TextureRect and (child as TextureRect).texture != null and (child as TextureRect).texture.resource_path == TitleScreen.SPLASH)), "no picture")
	again.close()
	await get_tree().process_frame


func test_reduced_motion_cuts_to_the_title() -> void:
	GameState.settings.reduce_motion = true
	TitleScreen._risen = false
	var title := TitleScreen.new()
	add_child(title)
	assert_true(title.get_children().all(func(child: Node) -> bool: return not (child is TextureRect and (child as TextureRect).texture != null and (child as TextureRect).texture.resource_path == TitleScreen.SPLASH)), "no fade to hold")
	title.close()
	await get_tree().process_frame
