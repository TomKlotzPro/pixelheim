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
##
## And the desktop app's look (PIX-227, DesktopLook): the canvas in linear
## HDR and a wider glow at night, where the desktop renderer runs; the
## browser's look everywhere else.

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
## The water's reflections, the cloud shadows and the region's air (PIX-224,
## the Atmosphere node sets it), under the glow on its layer, and the map the
## reflections were laid out for; the world's clock and the wind's strength
## (1, or 0 with reduced motion).
var reflections: ColorRect
var clouds: ColorRect
var air: ColorRect
## A pass that reads the screen sees what was drawn before the first such
## pass on the layer unless the screen is copied again (a probe found): one
## copy before the air and one before the glow, shown only with them.
var _air_copy: BackBufferCopy
var _glow_copy: BackBufferCopy
var _water_of: MapData
var _mirror_version := -1
## The desktop app's wider glow (PIX-227, DesktopLook): the brights marked
## last on the layer (after a fresh copy), then spread by a pass alone on a
## canvas layer of its own right after this one (its screen copy is the one
## whose blur keeps the mark). Only where the desktop renderer runs; null in
## the browser.
var glow_mask: ColorRect
var _mask_copy: BackBufferCopy
var glow_wide: ColorRect
var _wide_layer: CanvasLayer
## The passes' own canvas layer (GLOW_LAYER).
var _layer: CanvasLayer
var time := 0.0
var wind := 1.0
## How dark a cloud's shadow is at its heart, in full day.
const CLOUD_SHADE := 0.17
## How far the hero's lantern reaches untrimmed, in pixels.
const LANTERN_REACH := 96.0
## No cloud shadows while true: the harness's motion check (PIX-275) finds
## the hero by its shirt's exact reds, which a shadow drifting over it changes.
var clear_sky := false
## The clouds' noise: one seamless sheet, CLOUD_PX square.
const CLOUD_PX := 256


func _ready() -> void:
	darkness = CanvasModulate.new()
	# A story played over the world stands its actors in this light too
	# (Cutscene's world stage, PIX-253 step 9).
	darkness.add_to_group(&"world_light")
	world.add_child(darkness)
	# Its own layer, under the HUD's: only the world blooms.
	var layer := CanvasLayer.new()
	layer.layer = GLOW_LAYER
	world.add_child(layer)
	_layer = layer
	reflections = _screen_pass(layer, preload("res://shaders/reflections.gdshader"))
	clouds = _screen_pass(layer, preload("res://shaders/clouds.gdshader"))
	var noise := cloud_noise()
	(clouds.material as ShaderMaterial).set_shader_parameter("clouds", noise)
	_air_copy = _copy(layer)
	air = _screen_pass(layer, preload("res://shaders/atmosphere.gdshader"))
	(air.material as ShaderMaterial).set_shader_parameter("noise", noise)
	air.visible = false
	_glow_copy = _copy(layer)
	bloom = _screen_pass(layer, preload("res://shaders/bloom.gdshader"))
	var app := DesktopLook.here()
	if app:
		_mask_copy = _copy(layer)
		glow_mask = _screen_pass(layer, preload("res://shaders/glow_mask.gdshader"))
		_wide_layer = CanvasLayer.new()
		_wide_layer.layer = GLOW_LAYER
		world.add_child(_wide_layer)
		glow_wide = _screen_pass(_wide_layer, preload("res://shaders/glow_wide.gdshader"))
		_show_wide(false)
	wear(DesktopLook.pick(app, HarnessFlags.given()))


## Wears a look (DesktopLook.LOOKS): the canvas in linear HDR or not, and
## the wider glow or not. Only the desktop renderer can; the browser keeps
## its own look.
func wear(look: String) -> void:
	if glow_wide == null:
		look = DesktopLook.BROWSER
	DesktopLook.look = look
	DesktopLook.linear = DesktopLook.hdr(look)
	if glow_wide != null:
		var root := get_tree().root
		root.use_hdr_2d = DesktopLook.linear
		root.use_debanding = DesktopLook.linear
	RenderingServer.global_shader_parameter_set("world_linear", 1.0 if DesktopLook.linear else 0.0)


## While the title's backdrop covers the whole view (PIX-249), the passes
## rest: they would only draw over a world no one sees. They come back as
## it goes, the wider glow with the next frame's dark.
func rest(resting: bool) -> void:
	_layer.visible = not resting
	if resting and _wide_layer != null:
		_wide_layer.visible = false


func _show_wide(on: bool) -> void:
	glow_mask.visible = on
	_mask_copy.visible = on
	_wide_layer.visible = on


## A fresh copy of the screen for the passes after it.
func _copy(layer: CanvasLayer) -> BackBufferCopy:
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(copy)
	return copy


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


## The hero carries a lantern: it only shows when it's dark. Once Aske
## lives in Pixelheim he keeps it trimmed (PIX-255: his perk, the settlers'
## `lantern` share), and it reaches that much further, from the moment he
## comes home.
func give_lantern(player: Node2D) -> void:
	lantern = Lights.make(Vector2(0, -6), lantern_reach(GameState.holdings.settler_share("lantern")), Lights.LANTERN, Lights.LANTERN_ENERGY, true)
	player.add_child(lantern)
	GameState.settlers_changed.connect(_trim_lantern)


## How far the hero's lantern reaches, in pixels, with `share` more.
static func lantern_reach(share: float) -> float:
	return LANTERN_REACH * (1.0 + share)


func _trim_lantern() -> void:
	if is_instance_valid(lantern):
		lantern.texture_scale = lantern_reach(GameState.holdings.settler_share("lantern")) * 2.0 / Lights.TEXTURE_PX


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


## The light for the map the hero is on, at this hour.
func light_for(map: MapData) -> Color:
	if map == null:
		return Lights.DAY
	if map.floor_level > 0 or map.style == "cave":
		# A region dungeon's floor may keep its own dark (PIX-255).
		return Color(map.light, 1.0) if map.light.a > 0.0 else Lights.UNDERGROUND
	if GameState.progression.prologue != Prologue.DONE and map.id == "town":
		return Lights.ASH_NIGHT
	if PunyInterior.is_room(map.id):
		return Lights.indoor(GameState.world.steps)
	return Lights.outdoor(GameState.world.steps)


func _process(delta: float) -> void:
	light = light_for(world.map)
	# Rain darkens and cools the light, and the lamps come up a little; under
	# rain, fog or snow the sky is all cloud.
	var rain := 0.0
	var overcast := 0.0
	if world.get("atmosphere") != null:
		rain = world.atmosphere.rain
		overcast = maxf(rain, maxf(world.atmosphere.weights.get("mire", 0.0), world.atmosphere.weights.get("frost", 0.0)))
	light = light.lerp(light * Weather.RAIN_LIGHT, rain)
	darkness.color = light
	dark = Lights.darkness(light)
	bloom.visible = GameState.settings.glow
	_glow_copy.visible = bloom.visible
	_air_copy.visible = air.visible
	if bloom.visible:
		(bloom.material as ShaderMaterial).set_shader_parameter("strength", lerpf(GLOW_DAY, GLOW_NIGHT, dark))
	if glow_wide != null:
		var wide := DesktopLook.wide(DesktopLook.look, dark, GameState.settings.glow)
		_show_wide(wide > 0.0)
		(glow_wide.material as ShaderMaterial).set_shader_parameter("strength", wide)
	tick(delta)
	var at := world_view()
	_mirror_water(at)
	_drift_clouds(at, overcast)
	var still: bool = GameState.settings.reduce_motion
	var t := GameClock.seconds()
	for node in get_tree().get_nodes_in_group("lights"):
		var lamp := node as PointLight2D
		if lamp.has_meta("tint"):
			lamp.color = DesktopLook.canvas_color(lamp.get_meta("tint"), DesktopLook.linear)
		var energy := float(lamp.get_meta("energy", 1.0)) * dark
		if lamp.get_meta("flicker", false) and not still:
			var phase := float(lamp.get_meta("phase", 0.0))
			energy *= 1.0 + 0.07 * sin(t * 8.3 + phase) + 0.04 * sin(t * 21.7 + phase * 1.9)
		# A way out breathes (PIX-292), held still with reduced motion.
		if lamp.get_meta("pulse", false) and not still:
			energy *= 1.0 + Lights.PULSE_DEPTH * sin(t * Lights.PULSE_SPEED)
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
func world_view() -> Array[Vector2]:
	var screen := get_viewport().get_visible_rect()
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	return [to_world * screen.position, to_world.basis_xform(screen.size)]


## The banks mirrored in the water, on maps under the sky that have some:
## on the Reach's plane (One Reach, PIX-269) the water of every map drawn
## round the hero's, laid out in the plane (Neighbours.mirror), the view in
## the plane's pixels, so nothing jumps at a line.
func _mirror_water(view: Array[Vector2]) -> void:
	var map: MapData = world.map
	var mirror := reflections.material as ShaderMaterial
	var laid: Dictionary = world.neighbours.mirror if world.get("neighbours") != null else {}
	var version: int = world.neighbours.mirror_version if world.get("neighbours") != null else 0
	if map != _water_of or version != _mirror_version:
		_water_of = map
		_mirror_version = version
		var wet := Lights.under_sky(map) and (not laid.is_empty() or map.grid.values().any(func(tile: String) -> bool: return PunyTerrain.ground_of(tile) in PunyTerrain.WATER_GROUNDS))
		reflections.visible = wet
		if wet and not laid.is_empty():
			mirror.set_shader_parameter("water_map", laid["texture"])
			mirror.set_shader_parameter("map_cells", laid["cells"])
			mirror.set_shader_parameter("mirror_origin", laid["origin"])
		elif wet:
			mirror.set_shader_parameter("water_map", PunyTerrain.water_map(map.grid, map.size))
			mirror.set_shader_parameter("map_cells", Vector2(map.size))
			mirror.set_shader_parameter("mirror_origin", world.plane_px() / MapView.TILE)
	if reflections.visible:
		mirror.set_shader_parameter("view_origin", view[0] + world.plane_px())
		mirror.set_shader_parameter("view_size", view[1])


## The cloud shadows lie on the world under the camera, by day under the
## sky; under an `overcast` sky there are none.
func _drift_clouds(view: Array[Vector2], overcast: float) -> void:
	var amount := (1.0 - dark) * (1.0 - overcast) * CLOUD_SHADE if Lights.under_sky(world.map) and not clear_sky else 0.0
	clouds.visible = amount > 0.0
	if not clouds.visible:
		return
	var sky := clouds.material as ShaderMaterial
	# The clouds drift over the plane, unbroken at a line (PIX-269).
	sky.set_shader_parameter("view_origin", view[0] + world.plane_px())
	sky.set_shader_parameter("view_size", view[1])
	sky.set_shader_parameter("depth", amount)
