extends GutTest
## Light relief (PIX-528, PIX-529): the option, kept and flipped, and what
## the LightRig hands the shaders for it; the rule that keeps
## it off exactly as before (every shader writing NORMAL_MAP lights through
## relief.gdshaderinc's light()); the plain pieces it dresses, in which form,
## and those it leaves; the stone it carves and the sheets' padding its taps
## rely on; and the lights' height.

var _kept := {}


func before_each() -> void:
	var settings := GameState.settings
	_kept = {"relief": settings.relief, "read_only": settings.read_only}
	# Never the player's own settings.cfg.
	settings.read_only = true


func after_each() -> void:
	GameState.settings.relief = _kept["relief"]
	GameState.settings.read_only = _kept["read_only"]


func test_off_by_default_and_remembered() -> void:
	var path := "user://test_relief_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var settings := GameSettings.new(path)
	settings.load_file()
	assert_false(settings.relief, "off, with no file yet (until PIX-529)")
	settings.relief = true
	settings.save_file()
	var again := GameSettings.new(path)
	again.load_file()
	assert_true(again.relief, "remembered on")
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


## What the LightRig hands the shaders each frame: nothing with the option
## off, so every shader lights as before.
func test_the_rig_hands_the_shaders_the_setting() -> void:
	GameState.settings.relief = false
	assert_eq(LightRig.relief_strength(), 0.0, "off: lit as before")
	GameState.settings.relief = true
	assert_eq(LightRig.relief_strength(), Lights.RELIEF, "on: the lights shape the art")
	var rig := FileAccess.get_file_as_string("res://scripts/light_rig.gd")
	assert_string_contains(rig.substr(rig.find("func _process(")), "global_shader_parameter_set(\"relief\", relief_strength())", "set every frame")


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
	assert_gt(found, 4, "the ground, the houses (flat), the plain pieces, see-through props, dungeons")


func test_dress_rounds_what_stands_and_carves_the_tile_layers() -> void:
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
	assert_eq(bare.material, Relief.material(Relief.DOMED, false), "a bare sprite, domed")
	assert_eq(layer.material, Relief.material(Relief.CARVED, true), "a bare tile layer, carved")
	assert_eq(deep.material, Relief.material(Relief.DOMED, false), "however deep")
	assert_eq(unshaded.material, Lights.unshaded(), "never what has a material")
	assert_null(shares.material, "nor what wears its parent's")
	assert_null(flame.material, "nor an animated sprite")
	assert_eq(Relief.worn(root), 3, "dressed twice, the same three")
	root.free()
	# What lies under the actors: its tile layers carved, its sprites flat.
	var lying := Node2D.new()
	var rug := Sprite2D.new()
	var floor := TileMapLayer.new()
	lying.add_child(rug)
	lying.add_child(floor)
	Relief.dress(lying, false)
	assert_null(rug.material, "a sprite lying flat")
	assert_eq(floor.material, Relief.material(Relief.CARVED, true), "a floor, carved")
	lying.free()
	for form: int in [Relief.CARVED, Relief.DOMED]:
		for tiles: bool in [false, true]:
			var made := Relief.material(form, tiles)
			assert_eq(made.get_shader_parameter("relief_form"), form)
			assert_eq(made.get_shader_parameter("relief_tiles"), tiles)
			assert_eq(made.get_shader_parameter("relief_joints"), Relief.joints(), "its stone")


## The hero's ailment icon, a foe's or a villager's ground shadow, the
## dodge's ghost among the actors: characters stay as they were.
func test_dress_leaves_the_characters() -> void:
	var root := Node2D.new()
	var hero := CharacterBody2D.new()
	var icon := Sprite2D.new()
	hero.add_child(icon)
	var folk := AnimatableBody2D.new()
	var shadow := Sprite2D.new()
	folk.add_child(shadow)
	root.add_child(hero)
	root.add_child(folk)
	Relief.dress(root)
	Relief.dress(icon)
	assert_null(icon.material, "the hero's ailment icon")
	assert_null(shadow.material, "a villager's ground shadow")
	assert_true(Relief.on_character(icon))
	assert_false(Relief.on_character(root))
	root.free()
	var code := FileAccess.get_file_as_string("res://scripts/player.gd")
	assert_string_contains(code.substr(code.find("func _ghost()")), "ghost.use_parent_material = true", "the dodge's ghost, added among the actors")


## Whatever the town draws with no material of its own wears the relief's,
## with the pack or without: none is left flat by a place that makes it,
## but a sprite lying under the actors; and each toning material its form.
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
			if (piece is TileMapLayer or (piece is Sprite2D and top == view.stand)) and item.material == null and not item.use_parent_material and not Relief.on_character(piece):
				flat.append(item.get_path())
	assert_eq(flat, [], "every plain piece dressed")
	assert_gt(Relief.worn(view.under) + Relief.worn(view.stand), 0)
	for plain: Material in [view.ground_layer.material, view.ground_tint, view.flowers_sway]:
		assert_true((plain as ShaderMaterial).get_shader_parameter("relief_form") in [null, Relief.PLAIN], "the ground plain")
	for stands: ShaderMaterial in [view.decor_sway, view.woods_sway, view.decor_still]:
		assert_eq(stands.get_shader_parameter("relief_form"), Relief.DOMED, "the decor and trees domed")
		assert_eq(stands.get_shader_parameter("relief_tiles"), false, "as sprites")
	assert_eq(view.canopy.get_shader_parameter("relief_form"), Relief.DOMED, "the forest's crowns domed")
	assert_true(view.canopy.get_shader_parameter("relief_tiles") in [null, true], "as tiles")
	if PunyTown.available():
		assert_eq(view.paving_layer.material, Relief.material(Relief.CARVED, true), "the paving carved")
		for piece: Node in view.stand.find_children("*", "Sprite2D", true, false):
			var sprite := piece as Sprite2D
			if sprite.region_enabled and sprite.region_rect.size.y == HamletArt.AWNING:
				assert_true(sprite.use_parent_material, "a stall's awning hangs flat")
	# Cloth hangs flat wherever a place hangs it, at any age.
	var hung := FileAccess.get_file_as_string("res://scripts/map_layers/settlements_layer.gd")
	for cloth: String in ["awning", "line", "day"]:
		assert_string_contains(hung, "%s.use_parent_material = true" % cloth)
	KeptGround.forget()


## The Medieval Age's stone, from ids alone (no pack needed): the flags',
## the sandstone's and the mossy flags' fill, the keep's and Morvax's stone
## walls, the rampart; never the small stones (the cobbles, the setts, the
## edge stones), the basket weave, a room's brick floor or planks, the
## gravel, the town's plaster nor a roof (PIX-529's pictures: carved, they
## turned to grain or a mark at every brick's end).
func test_the_carved_stones() -> void:
	var stone := Relief.carved()
	var at := func(cell: Variant) -> int:
		return int(cell[1]) * PunyTown.COLUMNS + int(cell[0])
	for look: String in Streets.LOOKS:
		var paving: Dictionary = Streets.LOOKS[look]
		var carved: bool = look in ["flags", "sandstone", "mossy"]
		for fill: Array in paving["fill"]:
			assert_eq(stone.get(at.call(fill)), Relief.JOINT if carved else null, "%s's fill" % look)
		for row: int in Streets.BLOCK.size():
			for column: int in (Streets.BLOCK[row] as Array).size():
				if int(Streets.BLOCK[row][column]) >= 0:
					assert_false(stone.has(at.call(Vector2i(paving["edges"]) + Vector2i(column, row))), "%s's edge stones stay flat" % look)
	for tile: int in Rampart.WALL.values() + Rampart.TOWER:
		assert_true(stone.has(tile), "tile %d carved" % tile)
	for tile: int in PunyInterior.STONE + PunyInterior.PLANKS:
		assert_false(stone.has(tile), "a room's floor %d stays flat" % tile)
	for offset: int in PunyInterior.WALL_SETS.values():
		assert_true(stone.has(int(PunyInterior.WALLS[0]) + offset), "a stone wall")
	for tile: int in PunyInterior.WALLS.values():
		assert_false(stone.has(tile), "the town's plaster stays flat")
	assert_false(stone.has(PunyTown.GABLE_TOP[0]), "a roof stays flat")
	var map := Relief.joints().get_image()
	assert_eq(map.get_size(), Vector2i(PunyTown.COLUMNS, PunyTown.ROWS), "a texel a tile")
	assert_almost_eq(map.get_pixel(24, 32).r, Relief.JOINT, 0.01, "a sandstone flag")
	assert_eq(map.get_pixel(27, 109).r, 0.0, "a basket brick")
	var plaster: int = PunyInterior.WALLS[0]
	assert_eq(map.get_pixel(plaster % PunyTown.COLUMNS, plaster / PunyTown.COLUMNS).r, 0.0, "plaster")


## The relief's taps keep to a tile at RELIEF_PITCH 18 on a tile layer's
## sheet: a TileSet pads each 16 px tile with a copy of its edge.
func test_the_tile_sheets_are_padded_as_the_relief_reads_them() -> void:
	var sets: Array[TileSet] = [PunyTerrain.tileset(), RoadWear.tileset(), GroundDetail.tileset(), PunyDungeon.sheet().tileset, RuinArt.tileset(), DungeonArt.tileset()]
	if PunyTown.available():
		sets.append(PunyTown.tileset())
	for tileset: TileSet in sets:
		for i: int in tileset.get_source_count():
			var source := tileset.get_source(tileset.get_source_id(i)) as TileSetAtlasSource
			assert_eq(source.texture_region_size, Vector2i(16, 16))
			assert_eq(source.separation, Vector2i.ZERO)
			assert_eq(source.margins, Vector2i.ZERO)
			assert_true(source.use_texture_padding, "padded")


## Relief's forms and the shader's are the same numbers; a CC0 sheet's tile
## layer carves only in the dungeons' own shader (a ruin's and a CC0 room's
## thin bricks turned to a checker).
func test_the_forms_match_the_shader() -> void:
	var include := FileAccess.get_file_as_string("res://shaders/relief.gdshaderinc")
	for line: String in ["RELIEF_PLAIN = %d;" % Relief.PLAIN, "RELIEF_CARVED = %d;" % Relief.CARVED, "RELIEF_DOMED = %d;" % Relief.DOMED, "RELIEF_PITCH = 18.0;", "#define RELIEF_OTHER_JOINT 0.0"]:
		assert_string_contains(include, line)
	var dungeon := FileAccess.get_file_as_string("res://shaders/dungeon.gdshader")
	var asks := dungeon.find("#define RELIEF_OTHER_JOINT RELIEF_JOINT")
	assert_gt(asks, -1, "the dungeons' stone carves")
	assert_lt(asks, dungeon.find("#include \"res://shaders/relief.gdshaderinc\""), "set before the include")


## A room without the pack (PIX-318) stands its furniture domed as with it,
## and leaves the rest to dress (its floor, walls and rugs on CC0 sheets,
## flat in the shader); the forge's fire stays unshaded.
func test_a_free_room_domes_its_furniture() -> void:
	var withheld := PunyTown.withheld
	PunyTown.withheld = true
	var data := MapData.load_tiered("town_smith", [], 1)
	var root := Node2D.new()
	add_child_autofree(root)
	var standing := Node2D.new()
	root.add_child(standing)
	var view := MapView.new(data, standing)
	view.plan(data.spawn)
	view.build(root)
	PunyTown.withheld = withheld
	assert_true(view.buildings.get("free", false), "drawn from the CC0 sheets")
	var furniture: Array = (view.buildings["pieces"] as Dictionary).keys() + (view.buildings["objects"] as Dictionary).keys()
	var is_furniture := func(cell: Vector2i) -> bool: return cell in furniture
	var layers := 0
	var sprites := 0
	for piece: Node in view.ground.find_children("*", "", true, false):
		var item := piece as CanvasItem
		if piece is TileMapLayer:
			var cells := (piece as TileMapLayer).get_used_cells()
			if item.material == Relief.material(Relief.DOMED, true):
				layers += 1
				assert_true(cells.all(is_furniture), "only the furniture domed")
			else:
				assert_false(not cells.is_empty() and cells.all(is_furniture), "no furniture left undomed")
		elif piece is Sprite2D and item.material == Relief.material(Relief.DOMED, false):
			sprites += 1
			assert_true(is_furniture.call(Vector2i((piece as Sprite2D).position / 16.0)), "a piece drawn in code is furniture")
	assert_gt(layers, 0, "the CC0 furniture domed")
	assert_gt(sprites, 0, "and the pieces drawn in code")
	var unshaded := view.ground.find_children("*", "Sprite2D", true, false).filter(func(piece: Node) -> bool: return (piece as Sprite2D).material == Lights.unshaded())
	assert_gt(unshaded.size(), 0, "the forge's mouth still glows unshaded")


func test_the_lights_stand_over_the_art() -> void:
	var light := Lights.make(Vector2.ZERO, 64.0, Lights.LAMP, 1.0)
	assert_eq(light.height, Lights.RELIEF_HEIGHT)
	light.free()
