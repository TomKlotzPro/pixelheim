extends CanvasLayer
## The title (TitleScreen.tsx): a night over the Ashenreach, three ridges
## deep, fog and embers, and the bestiary marching across the grass on its
## own clocks; PIXELHEIM drops in letter by letter. Continue, New Game (hero
## creation) or the saves. W/S choose, E or Enter takes it. The world waits
## paused behind.

const PARADE := [
	["slime", 46.0, -8.0], ["wolf", 34.0, -20.0], ["goblin", 40.0, -2.0],
	["skeleton", 52.0, -33.0], ["ghost", 38.0, -15.0], ["golem", 64.0, -40.0],
]
const VIEW := Vector2(1280, 720)
const GROUND_Y := 640.0

var world: Node
var options: Array[Dictionary] = []
var selected := 0
var menu: VBoxContainer
var walkers: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 7
	get_tree().paused = true
	_scene()
	_card()


func _scene() -> void:
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color("0b1026"))
	gradient.set_color(1, Color("2b2347"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	sky.texture = texture
	sky.size = VIEW
	add_child(sky)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	for i in 40:
		var star := ColorRect.new()
		var px := 2.0 if rng.randf() < 0.7 else 3.0
		star.size = Vector2(px, px)
		star.position = Vector2(rng.randf_range(0, VIEW.x), rng.randf_range(0, 300))
		star.color = Color(1, 0.96, 0.85, rng.randf_range(0.4, 0.9))
		add_child(star)
		if GameState.settings.reduce_motion:
			continue
		var twinkle := create_tween().set_loops()
		twinkle.tween_property(star, "modulate:a", 0.25, rng.randf_range(1.2, 2.6)).set_delay(rng.randf_range(0, 2))
		twinkle.tween_property(star, "modulate:a", 1.0, rng.randf_range(1.2, 2.6))
	var moon := Sprite2D.new()
	var glow := Gradient.new()
	glow.offsets = PackedFloat32Array([0.0, 0.55, 0.62, 1.0])
	glow.colors = PackedColorArray([
		Color("f4ecd0"), Color("f4ecd0"), Color(0.96, 0.92, 0.8, 0.18), Color(0.96, 0.92, 0.8, 0),
	])
	var disc := GradientTexture2D.new()
	disc.gradient = glow
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(1, 0.5)
	disc.width = 140
	disc.height = 140
	moon.texture = disc
	moon.position = Vector2(1010, 140)
	add_child(moon)
	# Three ridges, far to near, each darker and more jagged.
	for ridge: Array in [[Color("232546"), 360.0, 70.0, 11], [Color("1a1b36"), 430.0, 90.0, 23], [Color("111226"), 520.0, 70.0, 37]]:
		var shape := Polygon2D.new()
		var points := PackedVector2Array([Vector2(0, VIEW.y)])
		var step := 80.0
		var x := 0.0
		var peaks := RandomNumberGenerator.new()
		peaks.seed = ridge[3]
		while x <= VIEW.x + step:
			points.append(Vector2(x, ridge[1] - peaks.randf_range(0, ridge[2])))
			x += step * peaks.randf_range(0.6, 1.3)
		points.append(Vector2(VIEW.x, VIEW.y))
		shape.polygon = points
		shape.color = ridge[0]
		add_child(shape)
	var fog := ColorRect.new()
	fog.color = Color(0.6, 0.55, 0.75, 0.08)
	fog.position = Vector2(0, 470)
	fog.size = Vector2(VIEW.x, 90)
	add_child(fog)
	# Embers drifting up from the Ashenreach (still air with reduced motion).
	for i in 0 if GameState.settings.reduce_motion else 8:
		var ember := ColorRect.new()
		ember.size = Vector2(2, 2)
		ember.color = Color(1, 0.55, 0.2, 0.9)
		ember.position = Vector2(110 + i * 150, GROUND_Y)
		add_child(ember)
		var rise := create_tween().set_loops()
		rise.tween_property(ember, "position:y", 380.0, 7.0).set_delay(i * 0.9)
		rise.parallel().tween_property(ember, "modulate:a", 0.0, 7.0).set_delay(i * 0.9)
		rise.tween_callback(func() -> void:
			ember.position.y = GROUND_Y
			ember.modulate.a = 1.0
		)
	# Puny grass underfoot, then the parade.
	var grass := TextureRect.new()
	var tile := AtlasTexture.new()
	tile.atlas = load(PunyTerrain.SHEET)
	tile.region = PunyTerrain.region(1)
	grass.texture = tile
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grass.position = Vector2(0, GROUND_Y)
	grass.size = Vector2(VIEW.x / 4.0, (VIEW.y - GROUND_Y) / 4.0)
	grass.scale = Vector2(4, 4)
	add_child(grass)
	for entry: Array in PARADE:
		var spec := PunyArt.monster(entry[0])
		var walker := AnimatedSprite2D.new()
		walker.sprite_frames = PunyArt.frames(spec)
		walker.play(PunyArt.pick(walker.sprite_frames, "walk", "right"))
		walker.scale = Vector2.ONE * 4.0 * spec.get("scale", 1.0)
		walker.self_modulate = spec.get("tint", Color.WHITE)
		add_child(walker)
		walkers.append({"node": walker, "seconds": entry[1], "clock": -float(entry[2])})


func _process(delta: float) -> void:
	# Each walker crosses on its own clock, already mid-march at the start.
	for walker: Dictionary in walkers:
		walker["clock"] = fmod(walker["clock"] + delta, walker["seconds"])
		var node: AnimatedSprite2D = walker["node"]
		node.position = Vector2(lerpf(-80, VIEW.x + 80, walker["clock"] / walker["seconds"]), GROUND_Y - 6)


func _card() -> void:
	var title := HBoxContainer.new()
	title.position = Vector2(0, 150)
	title.custom_minimum_size = Vector2(VIEW.x, 0)
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 6)
	add_child(title)
	var word := "PIXELHEIM"
	for i in word.length():
		var letter := UiStyle.heading(word[i], 60, UiStyle.LAMP)
		letter.add_theme_color_override("font_outline_color", Color("2a1a08"))
		letter.add_theme_constant_override("outline_size", 10)
		letter.modulate.a = 0.0
		title.add_child(letter)
		var drop := create_tween()
		drop.tween_interval(0.25 + i * 0.07)
		drop.tween_property(letter, "modulate:a", 1.0, 0.25)
	var tagline := UiStyle.label("Fifteen floors. One dragon. Worse things below.", 18, UiStyle.INK, Vector2(0, 252))
	tagline.custom_minimum_size = Vector2(VIEW.x, 0)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tagline)
	menu = VBoxContainer.new()
	menu.position = Vector2(VIEW.x / 2 - 130, 310)
	menu.custom_minimum_size = Vector2(260, 0)
	menu.add_theme_constant_override("separation", 10)
	add_child(menu)
	if not GameState.standing_in:
		options.append({"label": "Continue  -  %s, Lv %d" % [GameState.hero.hero_name, GameState.hero.level], "action": _continue})
	options.append({"label": "New Game", "action": _new_game})
	options.append({"label": "Saves", "action": _saves})
	_draw_menu()
	var version: String = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/meta.json"))["version"]
	var footer := UiStyle.label("v%s - a retro RPG, now in Godot" % version, 13, UiStyle.FADED, Vector2(0, 690))
	footer.custom_minimum_size = Vector2(VIEW.x, 0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)


func _draw_menu() -> void:
	for child in menu.get_children():
		child.queue_free()
	for index in options.size():
		var chosen := index == selected
		var button := UiStyle.button(options[index]["label"], _take.bind(index))
		button.custom_minimum_size = Vector2(260, 40)
		button.add_theme_font_size_override("font_size", 18)
		if chosen:
			button.add_theme_stylebox_override("normal", UiStyle.box(Color(UiStyle.CARD, 0.9), UiStyle.LAMP))
			button.add_theme_color_override("font_color", UiStyle.LAMP)
		else:
			button.add_theme_stylebox_override("normal", UiStyle.box(Color(UiStyle.CARD, 0.6), UiStyle.RIM))
		menu.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	var command := Callable()
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		command = func() -> void:
			selected = wrapi(selected - 1, 0, options.size())
			_draw_menu()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		command = func() -> void:
			selected = wrapi(selected + 1, 0, options.size())
			_draw_menu()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		command = _take.bind(selected)
	if command.is_valid():
		get_viewport().set_input_as_handled()
		command.call()


func _take(index: int) -> void:
	selected = index
	options[index]["action"].call()


func _continue() -> void:
	_leave()


func _new_game() -> void:
	var creation := preload("res://scripts/create_screen.gd").new()
	creation.world = world
	add_child(creation)


func _saves() -> void:
	_leave()
	world._open_saves()


func _leave() -> void:
	GameState.title_seen = true
	get_tree().paused = false
	queue_free()
