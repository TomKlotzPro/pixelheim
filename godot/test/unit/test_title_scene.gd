extends GutTest
## The title's living backdrop (PIX-249): a slow camera drifting from the
## frame the title was composed for, near layers travelling further; real
## lights that reach the village alone and add their own colour to its
## moonlight; the lake, the wind and the glow; reduced motion holding it all
## still; and the world under it resting from drawing while it's covered.

const LightRig := preload("res://scripts/light_rig.gd")
const TitleScreen := preload("res://scripts/title_screen.gd")
## A world as the title sees it: a canvas to hide, its LightRig, its sounds.
const WORLD := """
extends Node2D
var map: MapData
var harness := true
var lights: Node
var soundscape: Node
"""

var _reduce_motion: bool
var _glow: bool


func before_each() -> void:
	_reduce_motion = GameState.settings.reduce_motion
	_glow = GameState.settings.glow


func after_each() -> void:
	GameState.settings.reduce_motion = _reduce_motion
	GameState.settings.glow = _glow
	get_tree().paused = false
	# The title starts its music: it mustn't play on past the tests.
	Sound.stop_all()


func _scene(still: bool) -> TitleScene:
	GameState.settings.reduce_motion = still
	var scene := TitleScene.new()
	add_child_autofree(scene)
	return scene


func test_the_camera_drifts_slowly_from_the_composed_frame() -> void:
	assert_eq(TitleScene.drift(0.0), Vector2.ZERO, "it opens on the frame the boot splash shows")
	var widest := Vector2.ZERO
	for i in 600:
		var t := i * 0.5
		var at := TitleScene.drift(t)
		widest = widest.max(at.abs())
		assert_lt(at.distance_to(TitleScene.drift(t + 1.0 / 60.0)), 0.1, "a slow drift: under a tenth of an art pixel a frame")
	assert_almost_eq(widest.x, TitleScene.DRIFT.x, 0.5, "along the street as far as DRIFT")
	assert_almost_eq(widest.y, TitleScene.DRIFT.y, 0.5, "up and down a little")


func test_near_layers_travel_further_on_whole_screen_pixels() -> void:
	var order := ["stars", "moon", "clouds", "far", "ashen", "mist", "hills", "village"]
	for i in order.size() - 1:
		assert_lt(float(TitleScene.DEPTH[order[i]]), float(TitleScene.DEPTH[order[i + 1]]), "%s lies behind %s" % [order[i], order[i + 1]])
	assert_eq(float(TitleScene.DEPTH["village"]), 1.0, "the village moves with the camera")
	var at := Vector2(10.3, -2.2)
	var moved := TitleScene.parallax(Vector2(5, 7), 1.0, at)
	assert_eq(moved * TitleScene.PIXEL, (moved * TitleScene.PIXEL).round(), "on whole screen pixels")
	assert_lt(TitleScene.parallax(Vector2.ZERO, 0.2, at).length(), TitleScene.parallax(Vector2.ZERO, 0.66, at).length())


func test_the_lake_and_the_street_outrun_the_camera() -> void:
	assert_lt(float(TitleScene.LAKE_COLUMNS.x * 16), -TitleScene.DRIFT.x, "no end to the lake on the left")
	assert_gt(float((TitleScene.LAKE_COLUMNS.y + 1) * 16), TitleScene.ART.x + TitleScene.DRIFT.x, "nor on the right")


func test_a_light_adds_its_own_colour_to_the_moonlight() -> void:
	for is_linear: bool in [false, true]:
		var light := TitleScene.lit(Lights.FIRE, is_linear)
		var moon := DesktopLook.canvas_color(TitleScene.MOONLIT, is_linear)
		var fire := DesktopLook.canvas_color(Lights.FIRE, is_linear)
		assert_almost_eq(light.r * moon.r, fire.r, 0.0001, "red, linear=%s" % is_linear)
		assert_almost_eq(light.g * moon.g, fire.g, 0.0001, "green, linear=%s" % is_linear)
		assert_almost_eq(light.b * moon.b, fire.b, 0.0001, "blue, linear=%s" % is_linear)


func test_the_lights_reach_the_village_alone() -> void:
	var scene := _scene(false)
	if not PunyTown.available():
		pending("no torches or windows without Shade's paid pack")
		return
	var lamps := scene.lights.find_children("*", "PointLight2D", true, false)
	assert_gte(lamps.size(), 5, "two torches, the lit windows and the lantern")
	for lamp: PointLight2D in lamps:
		assert_eq(lamp.range_item_cull_mask, TitleScene.LIT_MASK, "only what answers to the village's bit")
		for layer: int in [7, 9]:
			assert_between(layer, lamp.range_layer_min, lamp.range_layer_max, "on the title's layer and a story's")
	var lit := 0
	for item in scene.village.find_children("*", "CanvasItem", true, false):
		var lake := item.has_meta(TitleScene.UNLIT)
		assert_eq((item as CanvasItem).light_mask & TitleScene.LIT_MASK != 0, not lake, "%s answers the lights unless it's the lake" % item.name)
		if not lake:
			lit += 1
	assert_gt(lit, 10)
	var sky: CanvasItem = scene.get_child(0)
	assert_eq(sky.light_mask & TitleScene.LIT_MASK, 0, "the sky never does")


func test_the_lake_the_wind_and_the_glow() -> void:
	var scene := _scene(false)
	var lakes := scene.village.find_children("*", "TileMapLayer", true, false).filter(func(layer: Node) -> bool: return layer.has_meta(TitleScene.UNLIT))
	assert_eq(lakes.size(), 1, "one lake")
	var lake: TileMapLayer = lakes[0]
	assert_gt(lake.get_used_cells().size(), 50, "across the village")
	assert_true((lake.material as ShaderMaterial).get_shader_parameter("water"), "its water lives")
	var swaying := 0
	for sprite in scene.find_children("*", "Sprite2D", true, false):
		var material := (sprite as Sprite2D).material as ShaderMaterial
		if material != null and float(material.get_shader_parameter("sway")) > 0.0:
			swaying += 1
	assert_gt(swaying, 20, "the hill pines and the village's trees lean in the wind")
	GameState.settings.glow = true
	scene._process(0.0)
	assert_true(scene.bloom.visible, "what's bright blooms")
	GameState.settings.glow = false
	scene._process(0.0)
	assert_false(scene.bloom.visible, "unless Glow is off in the options")


func test_the_camera_moves_the_near_layers_most() -> void:
	var scene := _scene(false)
	scene._process(20.0)
	assert_ne(scene.camera, Vector2.ZERO, "the camera has drifted")
	var shift := {}
	for layer: Array in scene.layers:
		var node: Node2D = layer[0]
		shift[float(layer[2])] = (node.position - (layer[1] as Vector2)).length()
	assert_gt(float(shift[TitleScene.DEPTH["village"]]), float(shift[TitleScene.DEPTH["hills"]]))
	assert_gt(float(shift[TitleScene.DEPTH["hills"]]), float(shift[TitleScene.DEPTH["far"]]))


func test_reduced_motion_holds_the_scene_still() -> void:
	var scene := _scene(true)
	var before: Array[Vector2] = []
	for layer: Array in scene.layers:
		before.append((layer[0] as Node2D).position)
	for i in 5:
		scene._process(1.0)
	assert_eq(scene.clock, 0.0, "the clock the water, the wind and the mist keep stops")
	for i in scene.layers.size():
		assert_eq((scene.layers[i][0] as Node2D).position, before[i], "no layer drifts")
	for flame in scene.find_children("*", "AnimatedSprite2D", true, false):
		assert_false((flame as AnimatedSprite2D).is_playing(), "%s holds its frame" % flame.name)


func test_the_world_rests_under_the_title() -> void:
	var stub := GDScript.new()
	stub.source_code = WORLD
	stub.reload()
	var world := Node2D.new()
	world.set_script(stub)
	add_child_autofree(world)
	# As the world sets its LightRig up: in the tree, then the rig.
	var rig: Node = LightRig.new()
	rig.world = world
	world.lights = rig
	world.add_child(rig)
	var title: CanvasLayer = TitleScreen.new()
	title.world = world
	world.add_child(title)
	var glow_layer: CanvasLayer = rig.bloom.get_parent()
	if Touch.view_size(title) != Touch.DESIGN:
		assert_true(world.visible, "a view wider than the title shows the world round it")
	else:
		assert_false(world.visible, "covered, the world draws nothing")
		assert_false(glow_layer.visible, "nor do its passes")
	title.close()
	await wait_physics_frames(2)
	assert_true(world.visible, "the world draws again as the title goes")
	assert_true(glow_layer.visible, "and its passes with it")
