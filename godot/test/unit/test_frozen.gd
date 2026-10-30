extends GutTest
## Ice drawn frozen wherever it lies (PIX-255, PIX-398). The ice cave's
## floors had cracks, polish and glints (shaders/frozen.gdshader); the
## Frostgate's lake in the open air was one flat pale fill, Shade's sand
## frosted, stepped cell by cell. Both share one look now
## (shaders/frozen.gdshaderinc), the lake drawn by the ground's own shader
## over the snow it lies on, its shore rounded and bent off the grid, a
## little cold light over it at night, and the hero still walks on it.

const SHARED := "#include \"res://shaders/frozen.gdshaderinc\""


func before_all() -> void:
	KeptGround.forget()


func after_all() -> void:
	KeptGround.forget()


## `map` drawn as a door draws it.
func _view(map: MapData) -> MapView:
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	return view


## The cells a frozen material's mask holds as ice.
static func _frozen_cells(material: ShaderMaterial) -> int:
	var mask := (material.get_shader_parameter("ice_map") as Texture2D).get_image()
	var cells := 0
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x, y).r > 0.5:
				cells += 1
	return cells


static func _ice(map: MapData) -> Array:
	return map.grid.keys().filter(func(cell: Vector2i) -> bool: return map.grid[cell] == "ice")


func test_the_ice_has_one_look_shared_not_copied() -> void:
	for path: String in ["res://shaders/frozen.gdshader", "res://shaders/region_tint.gdshader"]:
		var source := FileAccess.get_file_as_string(path)
		assert_string_contains(source, SHARED, "%s draws the ice with the shared look" % path)
		assert_false(source.contains("vec4 ice_over(") or source.contains("plate_edge(vec2"), "%s keeps no copy of it" % path)


func test_the_frostgates_lake_is_frozen_in_the_open_air() -> void:
	var map := MapData.load_by_id("frostgate")
	var ice := _ice(map)
	assert_eq(ice.size(), 145, "the Frostgate's lake")
	for cell: Vector2i in ice:
		assert_true(map.is_walkable(cell), "%s: frozen hard enough to walk on" % cell)
	var view := _view(map)
	assert_not_null(view.frozen, "drawn frozen")
	assert_eq(view.frozen, view.ground_layer.material, "by the ground's own shader")
	assert_true(view.frozen.get_shader_parameter("ice_life"))
	assert_eq(_frozen_cells(view.frozen), ice.size(), "every cell of it")
	assert_between(view.ice_lights.size(), 3, 8, "a little cold light over it at night")
	# Over the snow it lies on, toned as the snow beside it: no beach of
	# Shade's sand stepping round it cell by cell.
	assert_eq(PunyTerrain.ground_of("ice"), "grass")
	assert_eq(map.grid[Vector2i(30, 22)], "snow")
	for cell: Vector2i in ice:
		assert_eq(view.kept.tint_image.get_pixelv(cell), view.kept.tint_image.get_pixelv(Vector2i(30, 22)), "%s: toned as the snow" % cell)


func test_the_ice_caves_floors_keep_their_frozen_floor() -> void:
	for map_id: String in ["icecave_lake", "icecave_glass"]:
		var map := MapData.load_by_id(map_id)
		var view := _view(map)
		assert_not_null(view.frozen, "%s: drawn frozen" % map_id)
		assert_eq(view.frozen.shader.resource_path, "res://shaders/frozen.gdshader", "%s: over its stone" % map_id)
		assert_eq(_frozen_cells(view.frozen), _ice(map).size(), "%s: every cell of its ice" % map_id)
		assert_gt(view.ice_lights.size(), 0, "%s: its cold light" % map_id)
	assert_null(_view(MapData.load_by_id("deepwood")).frozen, "no ice, nothing frozen")
