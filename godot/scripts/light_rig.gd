extends Node
## The world's light, frame by frame (PIX-221): the darkness for the place
## and the hour (Lights' colours) on a CanvasModulate, and every light in the
## "lights" group brought up as it gets dark - fires flickering, the hero's
## lantern with them. With reduced motion, nothing flickers.
##
## And the open air's motion (PIX-223): the world's clock and the wind that
## the shaders read (shaders/wind.gdshaderinc), the banks mirrored in the
## water, and cloud shadows drifting over the land by day. The clock stops while the game is paused; with
## reduced motion it stops too, the wind drops and the clouds stand still.

var world: Node
var darkness: CanvasModulate
var lantern: PointLight2D
## The glow (PIX-222): a screen pass between the world and the HUD.
var bloom: ColorRect
## The glow's canvas layer: over the world, under the HUD (layer 2).
const GLOW_LAYER := 1
## How strongly bright things bloom by day and at night: not in the sun
## (sunlit sand is bright too), a soft halo round every flame in the dark.
const GLOW_DAY := 0.0
const GLOW_NIGHT := 0.9
## The light now and how dark it is (0 by day, 1 at night).
var light := Color.WHITE
var dark := 0.0
## The water's reflections and the cloud shadows, under the glow on its
## layer, and the map the reflections were laid out for; the world's clock
## and the wind's strength (1, or 0 with reduced motion).
var reflections: ColorRect
var clouds: ColorRect
var _water_of: MapData
var time := 0.0
var wind := 1.0
## How dark a cloud's shadow is at its heart, in full day.
const CLOUD_SHADE := 0.17
## The clouds' noise: one seamless sheet, CLOUD_PX square.
const CLOUD_PX := 256


func _ready() -> void:
	darkness = CanvasModulate.new()
	world.add_child(darkness)
	# Its own layer, under the HUD's: only the world blooms.
	var layer := CanvasLayer.new()
	layer.layer = GLOW_LAYER
	world.add_child(layer)
	reflections = _screen_pass(layer, preload("res://shaders/reflections.gdshader"))
	clouds = _screen_pass(layer, preload("res://shaders/clouds.gdshader"))
	(clouds.material as ShaderMaterial).set_shader_parameter("clouds", cloud_noise())
	bloom = _screen_pass(layer, preload("res://shaders/bloom.gdshader"))


## A shader over the whole view, on `layer` after what's already there.
func _screen_pass(layer: CanvasLayer, shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	layer.add_child(rect)
	return rect


## The hero carries a lantern: it only shows when it's dark.
func give_lantern(player: Node2D) -> void:
	lantern = Lights.make(Vector2(0, -6), 96.0, Lights.LANTERN, Lights.LANTERN_ENERGY, true)
	player.add_child(lantern)


## Seamless soft noise for the clouds: big puffs with ragged rims.
static func cloud_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	noise.seed = 7
	var texture := NoiseTexture2D.new()
	texture.width = CLOUD_PX
	texture.height = CLOUD_PX
	texture.seamless = true
	texture.noise = noise
	return texture


## Whether the sky is over the map: not indoors, not under the ground.
static func under_sky(map: MapData) -> bool:
	return map != null and map.floor_level == 0 and map.style != "cave" and not PunyInterior.is_room(map.id)


## The light for the map the hero is on, at this hour.
func light_for(map: MapData) -> Color:
	if map == null:
		return Lights.DAY
	if map.floor_level > 0 or map.style == "cave":
		return Lights.UNDERGROUND
	if GameState.progression.prologue != Prologue.DONE and map.id == "town":
		return Lights.ASH_NIGHT
	if PunyInterior.is_room(map.id):
		return Lights.indoor(GameState.world.steps)
	return Lights.outdoor(GameState.world.steps)


func _process(delta: float) -> void:
	light = light_for(world.map)
	darkness.color = light
	dark = Lights.darkness(light)
	bloom.visible = GameState.settings.glow
	if bloom.visible:
		(bloom.material as ShaderMaterial).set_shader_parameter("strength", lerpf(GLOW_DAY, GLOW_NIGHT, dark))
	tick(delta)
	var view := _view()
	_mirror_water(view)
	_drift_clouds(view)
	var still: bool = GameState.settings.reduce_motion
	var t := Time.get_ticks_msec() / 1000.0
	for node in get_tree().get_nodes_in_group("lights"):
		var lamp := node as PointLight2D
		var energy := float(lamp.get_meta("energy", 1.0)) * dark
		if lamp.get_meta("flicker", false) and not still:
			var phase := float(lamp.get_meta("phase", 0.0))
			energy *= 1.0 + 0.07 * sin(t * 8.3 + phase) + 0.04 * sin(t * 21.7 + phase * 1.9)
		lamp.energy = energy
		lamp.visible = energy > 0.01


## The world's clock and the wind, for the shaders: with reduced motion the
## clock stops and the wind drops.
func tick(delta: float) -> void:
	var still: bool = GameState.settings.reduce_motion
	if not still:
		time += delta
	wind = 0.0 if still else 1.0
	RenderingServer.global_shader_parameter_set("world_time", time)
	RenderingServer.global_shader_parameter_set("world_wind", wind)


## The world under the screen: [its top-left corner, its size], in pixels.
func _view() -> Array[Vector2]:
	var screen := get_viewport().get_visible_rect()
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	return [to_world * screen.position, to_world.basis_xform(screen.size)]


## The banks mirrored in the water, on maps under the sky that have some.
func _mirror_water(view: Array[Vector2]) -> void:
	var map: MapData = world.map
	var mirror := reflections.material as ShaderMaterial
	if map != _water_of:
		_water_of = map
		var wet := under_sky(map) and map.grid.values().any(func(tile: String) -> bool: return PunyTerrain.ground_of(tile) in PunyTerrain.WATER_GROUNDS)
		reflections.visible = wet
		if wet:
			mirror.set_shader_parameter("water_map", PunyTerrain.water_map(map.grid, map.size))
			mirror.set_shader_parameter("map_cells", Vector2(map.size))
	if reflections.visible:
		mirror.set_shader_parameter("view_origin", view[0])
		mirror.set_shader_parameter("view_size", view[1])


## The cloud shadows lie on the world under the camera, by day under the sky.
func _drift_clouds(view: Array[Vector2]) -> void:
	var amount := (1.0 - dark) * CLOUD_SHADE if under_sky(world.map) else 0.0
	clouds.visible = amount > 0.0
	if not clouds.visible:
		return
	var sky := clouds.material as ShaderMaterial
	sky.set_shader_parameter("view_origin", view[0])
	sky.set_shader_parameter("view_size", view[1])
	sky.set_shader_parameter("depth", amount)
