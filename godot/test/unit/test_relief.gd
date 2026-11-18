extends GutTest
## Light relief (PIX-528): the option, kept and flipped; the rule that keeps
## it off exactly as before (every shader writing NORMAL_MAP lights through
## relief.gdshaderinc's light()); the plain pieces it dresses and those it
## leaves; and the lights' height.

var _kept := {}


func before_each() -> void:
	var settings := GameState.settings
	_kept = {"relief": settings.relief, "read_only": settings.read_only}
	# Never the player's own settings.cfg.
	settings.read_only = true


func after_each() -> void:
	GameState.settings.relief = _kept["relief"]
	GameState.settings.read_only = _kept["read_only"]


func test_on_by_default_and_remembered() -> void:
	var path := "user://test_relief_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var settings := GameSettings.new(path)
	settings.load_file()
	assert_true(settings.relief, "on, with no file yet (not a phone)")
	settings.relief = false
	settings.save_file()
	var again := GameSettings.new(path)
	again.load_file()
	assert_false(again.relief, "remembered off")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_options_flip_it() -> void:
	var options := OptionsScreen.new()
	var row := _row(options, "Light relief")
	assert_false(row.is_empty(), "a Light relief row")
	GameState.settings.relief = true
	assert_eq(_row(options, "Light relief")["value"], "On")
	(row["adjust"] as Callable).call(1)
	assert_false(GameState.settings.relief, "flipped off")
	assert_eq(_row(options, "Light relief")["value"], "Off")
	(_row(options, "Light relief")["adjust"] as Callable).call(-1)
	assert_true(GameState.settings.relief, "and on again")
	options.free()


func _row(options: OptionsScreen, label: String) -> Dictionary:
	for row: Dictionary in options._build():
		if row.get("label", "") == label:
			return row
	return {}


func test_every_shader_with_a_normal_lights_through_the_relief() -> void:
	var include := FileAccess.get_file_as_string("res://shaders/relief.gdshaderinc")
	assert_string_contains(include, "void light()", "the light() that keeps it off as before")
	var dir := DirAccess.open("res://shaders")
	var found := 0
	for file in dir.get_files():
		if not file.ends_with(".gdshader"):
			continue
		var code := FileAccess.get_file_as_string("res://shaders/" + file)
		if code.contains("NORMAL_MAP"):
			found += 1
			assert_string_contains(code, "#include \"res://shaders/relief.gdshaderinc\"", "%s lights through the relief's light()" % file)
			assert_true(code.contains("RELIEF_FLAT"), "%s writes a flat normal when the relief is off" % file)
	assert_gt(found, 4, "the ground, the houses, the plain pieces, see-through props, dungeons")


func test_dress_gives_the_plain_pieces_the_material() -> void:
	var root := Node2D.new()
	var bare := Sprite2D.new()
	var layer := TileMapLayer.new()
	var unshaded := Sprite2D.new()
	unshaded.material = Lights.unshaded()
	var shares := Sprite2D.new()
	shares.use_parent_material = true
	var flame := AnimatedSprite2D.new()
	var holder := Node2D.new()
	var deep := Sprite2D.new()
	holder.add_child(deep)
	for child: Node in [bare, layer, unshaded, shares, flame, holder]:
		root.add_child(child)
	Relief.dress(root)
	Relief.dress(root)
	assert_eq(bare.material, Relief.material(), "a bare sprite")
	assert_eq(layer.material, Relief.material(true), "a bare tile layer, its taps never clamped to a tile")
	assert_eq(Relief.material(true).get_shader_parameter("cut"), false)
	assert_eq(deep.material, Relief.material(), "however deep")
	assert_eq(unshaded.material, Lights.unshaded(), "never what has a material")
	assert_null(shares.material, "nor what wears its parent's")
	assert_null(flame.material, "nor an animated sprite")
	assert_eq(Relief.worn(root), 3, "dressed twice, the same three")
	root.free()


## Whatever the town draws with no material of its own wears the relief's,
## with the pack or without: none is left flat by a place that makes it.
func test_a_drawn_town_leaves_no_plain_piece_flat() -> void:
	var data := MapData.load_by_id("town")
	var root := Node2D.new()
	add_child_autofree(root)
	var standing := Node2D.new()
	root.add_child(standing)
	var view := MapView.new(data, standing)
	view.plan(data.spawn)
	view.build(root)
	var flat := []
	for top: Node in [view.under, view.stand]:
		for piece: Node in top.find_children("*", "", true, false):
			var item := piece as CanvasItem
			if (piece is Sprite2D or piece is TileMapLayer) and item.material == null and not item.use_parent_material:
				flat.append(item.get_path())
	assert_eq(flat, [], "every plain piece dressed")
	assert_gt(Relief.worn(view.under) + Relief.worn(view.stand), 0)
	KeptGround.forget()


func test_the_lights_stand_over_the_art() -> void:
	var light := Lights.make(Vector2.ZERO, 64.0, Lights.LAMP, 1.0)
	assert_eq(light.height, Lights.RELIEF_HEIGHT)
	light.free()
