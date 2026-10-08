extends Screen
## The title (PIX-139): Pixelheim's street at night under the Ashen Mountain
## (TitleScene), PIXELHEIM cut in gold above it, and the menu: Continue, New
## Game (hero creation), the saves, options, or What's new. W/S choose, E or
## Enter takes it. The world waits paused behind.

const VIEW := Vector2(1280, 720)
const LOGO_Y := 84.0
## The shine crosses the logo this long after the title opens, then this often (s).
const SHINE_FIRST_S := 0.7
const SHINE_EVERY_S := 8.0

var world: Node
var scene: TitleScene
var options: Array[Dictionary] = []
var selected := 0
var menu: VBoxContainer
## Per line: [button, left marker, right marker].
var lines: Array = []
var footer: Label
var shine: ColorRect
## The game's version: the newest release in What's new.
var version := ""


func _open() -> void:
	layer = 7
	Sound.play_track("title")
	Sound.set_ambience("")
	scene = TitleScene.new()
	add_child(scene)
	_vignette()
	_logo()
	_card()
	_arrive()


## The corners fall into night, so the eye rests on the middle.
func _vignette() -> void:
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	shade.colors = PackedColorArray([Color(0.02, 0.01, 0.05, 0.0), Color(0.02, 0.01, 0.05, 0.12), Color(0.02, 0.01, 0.05, 0.6)])
	var texture := GradientTexture2D.new()
	texture.gradient = shade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.15, 0.45)
	var vignette := TextureRect.new()
	vignette.texture = texture
	vignette.size = VIEW
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)


## PIXELHEIM cut deep in gold: a block of letters stepping back into dark
## bronze, a lighter top to the face, and a shine that crosses it now and then.
func _logo() -> void:
	var font := FontVariation.new()
	font.base_font = UiStyle.logo_font()
	font.spacing_glyph = 4
	var logo := Control.new()
	logo.position = Vector2(0, LOGO_Y)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var depth := 8
	for step in range(depth, 0, -2):
		var back := _logo_word(font, Color("4a2408") if step > depth / 2 else Color("8a4f14"))
		back.position.y = step
		if step == depth:
			back.add_theme_color_override("font_outline_color", Color("140a03"))
			back.add_theme_constant_override("outline_size", 14)
		logo.add_child(back)
	var face := _logo_word(font, UiStyle.GOLD)
	face.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	logo.add_child(face)
	var top := ColorRect.new()
	top.color = Color("ffe08f")
	top.size = Vector2(VIEW.x, 30)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(top)
	shine = ColorRect.new()
	shine.color = Color(1, 0.98, 0.9, 0.75)
	shine.size = Vector2(18, 140)
	shine.position = Vector2(-200, -30)
	shine.rotation = 0.4
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(shine)
	var tagline := UiStyle.label("Fifteen floors. One dragon. Worse things below.", 18, UiStyle.CREAM, Vector2(0, LOGO_Y + 92))
	tagline.custom_minimum_size = Vector2(VIEW.x, 0)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.05, 0.9))
	tagline.add_theme_constant_override("shadow_offset_x", 2)
	tagline.add_theme_constant_override("shadow_offset_y", 2)
	add_child(tagline)


func _logo_word(font: Font, color: Color) -> Label:
	var word := Label.new()
	word.text = "PIXELHEIM"
	word.add_theme_font_override("font", font)
	word.add_theme_font_size_override("font_size", 64)
	word.add_theme_color_override("font_color", color)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.size = Vector2(VIEW.x, 72)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return word


## The one entrance: the scene is already there (it is the boot splash), the
## menu rises in line by line, then the shine crosses the name.
func _arrive() -> void:
	if GameState.settings.reduce_motion:
		return
	# The menu's container rises (the menu itself is placed by it), line by line.
	var middle: Control = menu.get_parent()
	create_tween().tween_property(middle, "position:y", middle.position.y, 0.5).from(middle.position.y + 12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	for i in menu.get_child_count():
		var line: Control = menu.get_child(i)
		line.modulate.a = 0.0
		var show := create_tween()
		show.tween_interval(0.08 * i)
		show.tween_property(line, "modulate:a", 1.0, 0.3)
	footer.modulate.a = 0.0
	create_tween().tween_property(footer, "modulate:a", 1.0, 0.6).set_delay(0.4)
	var sweep := create_tween().set_loops()
	sweep.tween_interval(SHINE_FIRST_S)
	sweep.tween_property(shine, "position:x", VIEW.x + 200, 1.1).from(-200.0).set_trans(Tween.TRANS_SINE)
	sweep.tween_interval(SHINE_EVERY_S - SHINE_FIRST_S)


func _card() -> void:
	# The menu is centred by a full-width container, so a long first line
	# ("Continue - name, Lv N") widens it both ways instead of to the right.
	var middle := CenterContainer.new()
	middle.position = Vector2(0, 268)
	middle.custom_minimum_size = Vector2(VIEW.x, 0)
	add_child(middle)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	middle.add_child(menu)
	version = load("res://scripts/changelog_screen.gd").releases()[0]["version"]
	if not GameState.standing_in:
		options.append({"label": "Continue  %s, Lv %d" % [GameState.hero.hero_name, GameState.hero.level], "action": _continue})
	options.append({"label": "New Game", "action": _new_game})
	options.append({"label": "Saves", "action": _saves})
	options.append({"label": "Options", "action": _options})
	options.append({"label": "What's new", "action": _whats_new})
	_draw_menu()
	# The version line opens What's new (the web's changelog link).
	footer = UiStyle.label("v%s  ·  What's new" % version, 13, UiStyle.DUSK, Vector2(0, 690))
	footer.custom_minimum_size = Vector2(VIEW.x, 0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.mouse_filter = Control.MOUSE_FILTER_STOP
	footer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	footer.mouse_entered.connect(func() -> void: footer.add_theme_color_override("font_color", UiStyle.GOLD))
	footer.mouse_exited.connect(func() -> void: footer.add_theme_color_override("font_color", UiStyle.DUSK))
	footer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_whats_new()
	)
	add_child(footer)


## The boot splash (tools/splash.sh renders it): the scene and the name the
## title opens on, with nothing yet to press and no one about, so loading
## hands over to the title without a jump.
func as_splash() -> void:
	menu.visible = false
	footer.visible = false
	scene.as_splash()


## The menu as words over the scene, in the name's pixel type: cream, the
## chosen line gold between two gold markers. The mouse chooses by pointing.
func _draw_menu() -> void:
	for child in menu.get_children():
		child.queue_free()
	lines.clear()
	for index in options.size():
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.custom_minimum_size.y = 26
		line.add_theme_constant_override("separation", 16)
		var left := _marker(false)
		line.add_child(left)
		var button := Button.new()
		button.text = options[index]["label"]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", UiStyle.logo_font())
		button.add_theme_font_size_override("font_size", 16)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_color_override("font_outline_color", Color("120a06"))
		button.add_theme_constant_override("outline_size", 8)
		button.mouse_entered.connect(_point.bind(index))
		button.pressed.connect(_take.bind(index))
		line.add_child(button)
		var right := _marker(true)
		line.add_child(right)
		# NEW floats past the line's right marker: it takes no part in the
		# line's layout, so these words centre exactly as every other line's.
		if options[index]["action"] == _whats_new and GameState.settings.seen_version != version:
			right.add_child(_new_badge())
		menu.add_child(line)
		lines.append([button, left, right])
	_show_choice()


## The chosen line in gold between its markers; the rest cream. Lines are
## recoloured, not rebuilt, so a pointer resting on the menu never takes the
## choice back from the keys.
func _show_choice() -> void:
	for index in lines.size():
		var chosen := index == selected
		var button: Button = lines[index][0]
		for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(key, UiStyle.GOLD if chosen else UiStyle.CREAM)
		# self_modulate: a marker's NEW badge stays visible when it hides.
		for marker: TextureRect in [lines[index][1], lines[index][2]]:
			marker.self_modulate.a = 1.0 if chosen else 0.0


## A gold marker beside the chosen line, pointing in at it (hidden, but
## holding its place, on the others).
func _marker(right: bool) -> TextureRect:
	var art := Image.create(4, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in mini(y, 6 - y) + 1:
			var edge := x == mini(y, 6 - y)
			art.set_pixel(3 - x if right else x, y, UiStyle.BRASS_DARK if edge else UiStyle.GOLD)
	var marker := TextureRect.new()
	marker.texture = ImageTexture.create_from_image(art)
	marker.custom_minimum_size = Vector2(8, 14)
	marker.stretch_mode = TextureRect.STRETCH_SCALE
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return marker


func _point(index: int) -> void:
	# Harness runs drive keys only: the desktop's pointer must not choose.
	if world != null and world.harness:
		return
	if index != selected:
		selected = index
		_show_choice()


## NEW, in rubric red past its line: notes not yet read.
func _new_badge() -> Control:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.LAMP, UiStyle.NIGHT, 3))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(UiStyle.strong("NEW", 12, UiStyle.CREAM))
	# Beside the marker it hangs from, middles level, growing rightward.
	badge.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	badge.offset_left = 20
	badge.offset_right = 20
	badge.grow_horizontal = Control.GROW_DIRECTION_END
	badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	return badge


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		command = func() -> void:
			selected = wrapi(selected - 1, 0, options.size())
			_show_choice()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		command = func() -> void:
			selected = wrapi(selected + 1, 0, options.size())
			_show_choice()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		command = _take.bind(selected)
	return command


## Esc never closes the title: there is nowhere under it to go.
func _closes_on(_event: InputEvent) -> bool:
	return false


func _take(index: int) -> void:
	selected = index
	options[index]["action"].call()


func _continue() -> void:
	_leave()


## New Game: the opening (PIX-31), skippable, then hero creation.
func _new_game() -> void:
	var opening := Cutscene.new()
	opening.scene_id = "opening"
	opening.on_done = _create_hero
	add_child(opening)


func _create_hero() -> void:
	var creation := preload("res://scripts/create_screen.gd").new()
	creation.world = world
	add_child(creation)


## The saves over the title, like Options: Esc comes back here, and playing
## the hero in hand is Continue.
func _saves() -> void:
	var screen := preload("res://scripts/saves_screen.gd").new()
	screen.web_save = WebImport.find_in_browser()
	screen.on_play_current = _continue
	add_child(screen)
	screen.layer = layer + 1


## Every release's notes, over the title (Esc hands back).
func _whats_new() -> void:
	add_child(preload("res://scripts/changelog_screen.gd").new())
	# Read: the badge goes, until the next version.
	if GameState.settings.seen_version != version:
		GameState.settings.seen_version = version
		GameState.settings.save_file()
		_draw_menu()


## Options over the title, so sound and keys can be set before a hero
## exists; Esc hands back to the menu.
func _options() -> void:
	var screen := preload("res://scripts/options_screen.gd").new()
	screen.world = world
	add_child(screen)


func _leave() -> void:
	GameState.title_seen = true
	close()
	world._update_music()
