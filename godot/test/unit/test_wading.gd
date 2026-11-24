extends GutTest
## Wading (PIX-548): in a map's shallows a figure's feet sink under a
## waterline and rings spread from under it as it moves, in whole pixels,
## none with Reduce motion; out of them it stands as it did.

var _motion: bool


func before_each() -> void:
	_motion = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false


func after_each() -> void:
	GameState.settings.reduce_motion = _motion


## A figure as the hero is built: its sprite in the fighters' material,
## under a parent the rings are laid in.
func _figure() -> Node2D:
	var ground := Node2D.new()
	add_child_autofree(ground)
	var figure := Node2D.new()
	ground.add_child(figure)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(GameState.upkeep.hero_art())
	sprite.material = Juice.fighter_material()
	sprite.position = Vector2(0, -4)
	figure.add_child(sprite)
	return figure


func _rings(figure: Node2D) -> int:
	return figure.get_parent().get_child_count() - 1


func test_feet_sink_in_the_shallows_and_stand_out_of_them() -> void:
	var figure := _figure()
	var sprite: AnimatedSprite2D = figure.get_child(0)
	assert_eq(Wading.sunk(sprite), 0, "dry before")
	Wading.tread(figure, sprite, true)
	assert_eq(Wading.sunk(sprite), Wading.SINK, "sunk in the shallows")
	var material := sprite.material as ShaderMaterial
	assert_eq(float(material.get_shader_parameter("wade_foot")), Wading.foot(sprite), "the waterline where its soles stood")
	# The hero's soles: the last inked row of the frame they stand in.
	assert_eq(Wading.foot(sprite), 7.0, "the hero's soles, from the sprite's middle")
	assert_lt(Wading.SINK, 3, "a row of the hero's three of leg still shows")
	Wading.tread(figure, sprite, false)
	assert_eq(Wading.sunk(sprite), 0, "and out of them again")
	assert_eq(sprite.position, Vector2(0, -4), "the sprite itself never moved: the shader draws it lower")


func test_a_ring_spreads_as_it_moves() -> void:
	var figure := _figure()
	var sprite: AnimatedSprite2D = figure.get_child(0)
	Wading.tread(figure, sprite, true)
	assert_eq(_rings(figure), 0, "none standing still")
	figure.position.x += Wading.STRIDE - 1.0
	Wading.tread(figure, sprite, true)
	assert_eq(_rings(figure), 0, "none short of a stride")
	figure.position.x += 1.0
	Wading.tread(figure, sprite, true)
	assert_eq(_rings(figure), 1, "one a stride on")
	var ring: Sprite2D = figure.get_parent().get_child(1)
	assert_eq(ring.position, figure.position + Vector2(0, -4 + Wading.foot(sprite)), "under its feet, at the waterline")
	assert_false(ring.z_as_relative, "under every figure, as the shadows")
	Wading.tread(figure, sprite, true)
	assert_eq(_rings(figure), 1, "and no other until the next stride")
	figure.position.x += Wading.STRIDE
	Wading.tread(figure, sprite, false)
	assert_eq(_rings(figure), 1, "none out of the water")


func test_no_ring_with_reduce_motion() -> void:
	GameState.settings.reduce_motion = true
	var figure := _figure()
	var sprite: AnimatedSprite2D = figure.get_child(0)
	Wading.tread(figure, sprite, true)
	figure.position.x += Wading.STRIDE * 3
	Wading.tread(figure, sprite, true)
	assert_eq(_rings(figure), 0, "no ripple")
	assert_eq(Wading.sunk(sprite), Wading.SINK, "but the feet still sink")


## Whole pixels of the art, never half-transparent: each of a ring's is the
## lip's colour whole or nothing, and a ring thins as it spreads.
func test_the_rings_are_whole_pixels() -> void:
	var image := Wading.draw_rings()
	assert_eq(image.get_size(), Vector2i(Wading.RING_SIZE.x * Wading.RINGS.size(), Wading.RING_SIZE.y))
	var drawn := []
	for n in Wading.RINGS.size():
		var count := 0
		for y in Wading.RING_SIZE.y:
			for x in Wading.RING_SIZE.x:
				var pixel := image.get_pixel(n * Wading.RING_SIZE.x + x, y)
				if pixel.a > 0.0:
					count += 1
					assert_eq(pixel.a, 1.0, "ring %d's pixel at %d,%d whole" % [n, x, y])
					assert_almost_eq(pixel.g, Wading.LIP.g, 0.01, "and the lip's colour")
		drawn.append(count)
	assert_gt(drawn[0], 6, "the first ring drawn")
	assert_lt(drawn[-1], drawn[-2], "the last thinner than the one before")
	assert_gt(drawn[-1], 0, "but still there")


## The fighters' shader draws the wader lower and cuts it at the line, with
## no pixel half there.
func test_the_shader_cuts_at_the_waterline() -> void:
	var code := (load("res://shaders/fighter.gdshader") as Shader).code
	assert_string_contains(code, "VERTEX.y += wade;")
	assert_string_contains(code, "c.a = 0.0;")
	assert_string_contains(code, "c.rgb = wade_lip;")


## The mask's code for the shallows is the shader's.
func test_the_shallows_tone_is_the_shader_s() -> void:
	var code := (load("res://shaders/water_bank.gdshaderinc") as ShaderInclude).code
	assert_string_contains(code, "const int TONE_SHALLOWS = %d;" % PunyTerrain.WATER_SHALLOWS)
	assert_eq(PunyTerrain.TONE_NAMES[PunyTerrain.WATER_SHALLOWS], "shallows")
	# A pool three cells across in the fen, its west column waded.
	var grid := {}
	for y in 5:
		for x in 5:
			grid[Vector2i(x, y)] = "water" if x in [1, 2, 3] and y in [1, 2, 3] else "marsh"
	var shallows := {Vector2i(1, 1): true, Vector2i(1, 2): true, Vector2i(1, 3): true, Vector2i(0, 0): true}
	var mask := PunyTerrain.water_map(grid, Vector2i(5, 5), "mirefen", shallows).get_image()
	assert_eq(roundi(mask.get_pixel(1, 2).a * 255.0), PunyTerrain.WATER_SHALLOWS * PunyTerrain.TONE_BIT, "the waded cell: shallows, still")
	assert_eq(roundi(mask.get_pixel(2, 2).a * 255.0), PunyTerrain.WATER_MIRE * PunyTerrain.TONE_BIT, "the pool beside it: the mire's")
	assert_eq(mask.get_pixel(0, 0).r, 0.0, "no water made of dry ground")
	assert_eq(PunyTerrain.water_near(mask, Vector2i(0, 2), 2), "shallows still")
