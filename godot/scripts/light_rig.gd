class_name LightRig
extends Node
## areas: field night
## The world's light, frame by frame (PIX-221): the darkness for the place
## and the hour (Lights' colours) on a CanvasModulate, and every light in the
## "lights" group brought up as it gets dark - fires flickering, the lantern
## the hero carries with them (PIX-530: none without one). With reduced
## motion, nothing flickers.
##
## And the open air's motion (PIX-223): the world's clock and the wind that
## the shaders read (shaders/wind.gdshaderinc), the banks mirrored in the
## water, and cloud shadows drifting over the land by day; and the sun the
## scenery's shadows follow (PIX-449, DayNight.sun). The clock stops while the game is paused; with
## reduced motion it stops too, the wind drops and the clouds stand still.
##
## And the desktop app's look (PIX-227, DesktopLook): the canvas in linear
## HDR and a wider glow at night, where the desktop renderer runs; the
## browser's look everywhere else.

var world: World
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
## How strongly a room blooms at night, a share of the open air's (PIX-311).
const ROOM_GLOW := 0.7
## The light now and how dark it is (0 by day, 1 at night).
var light := Color.WHITE
var dark := 0.0
## How much cloud covers the sky here, 0..1 (rain, the mire's fog, snow).
var overcast := 0.0
## How far the Night of Ash's red has turned to its dawn's grey (PIX-543:
## the DawnScreen's, "Dawn came grey" stood over the night's red and its
## lit lamps); 0 again once the day begins.
var ash_dawn := 0.0
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
## How hard a thunderstorm blows over the open air here, 0..1 (PIX-491,
## the Storm node's): the sky darker, the wind harder.
var gale := 0.0
## How dark a cloud's shadow is at its heart, in full day.
const CLOUD_SHADE := 0.17
## Where the lantern the hero carries burns, from their feet: at their feet
## since it casts shadows (PIX-490; it was 6 pixels up, at the chest), as
## the hero's body keeps their feet out of every wall, and a light inside a
## wall's cell is shut in, its whole pool gone dark under a north wall.
const LANTERN_AT := Vector2.ZERO
## How far the hero's lantern reaches untrimmed, in pixels.
const LANTERN_REACH := 96.0
## The lights casting shadows now (PIX-490, NightShadows): the lamps
## nearest the hero, up to the cap, never the lantern; and how many of the
## flames burning could (the report's nightshadows=).
var casting: Array[PointLight2D] = []
var candidates := 0
## No cloud shadows, and plain daylight under the sky, while true: the
## harness's motion check (PIX-275) finds the hero by its shirt's exact reds,
## which a shadow drifting over it or the golden hours' tint change (PIX-526).
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
	# The windows' light shapes made now (PIX-311), not in the frame a map
	# with windows is first drawn beside the hero.
	Lights.spill()
	Lights.shaft()


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


## The shaders' `relief` global, set each frame (PIX-528): Lights.RELIEF
## with Light relief on, 0 off, where every shader lights as before.
static func relief_strength() -> float:
	return Lights.RELIEF if GameState.settings.relief else 0.0


## The rim on what stands, false only for the harness's `--rim off` (PIX-531).
static var rim_on := true


## The shaders' `light_rim` global (PIX-531) when it is `dark_now` dark: none by
## day nor by a room's dim day, whole from where the hand lantern lights.
## The relief's setting is not read: the rim needs none of its normals.
static func rim_strength(dark_now: float) -> float:
	return Lights.RIM * smoothstep(Lights.RIM_DUSK, Lights.LANTERN_DARK, dark_now) if rim_on else 0.0


## The moon's rim (PIX-545), as the shaders make it of `light_rim` and the
## sun's w: a clear night's under the sky, none through cloud, underground,
## indoors or through the Night of Ash's smoke.
func moon_rim(map: MapData, dark_now: float, overcast_now: float) -> float:
	return rim_strength(dark_now) * moon(map, dark_now, overcast_now)


## The shaders' `rim_flash` global (PIX-545, Storm sets it): the lightning's
## rim, as bright as its `flash` is now; none by day, nor for the `soft`
## flash of Reduce motion or the Flashes option off.
static func flash_rim(dark_now: float, flash: float, soft: bool) -> float:
	return 0.0 if soft else rim_strength(dark_now) * flash


## The hero's lantern, at their feet: it burns only while they carry one
## (PIX-530, Lights.carried: no light follows a hero without one, the night
## is its lamps', windows', fires' and torches') and only shows when it's
## dark. Once Aske lives in Pixelheim he keeps it trimmed (PIX-255: his
## perk, the settlers' `lantern` share), and it reaches that much further,
## from the moment he comes home. The light stays on the hero unlit without
## one: the shadows read where the hero stands from it.
func give_lantern(player: Player) -> void:
	lantern = Lights.make(LANTERN_AT, lantern_reach(GameState.holdings.settler_share("lantern")), Lights.LANTERN, Lights.LANTERN_ENERGY, true)
	# The hero never blocks their own lantern (PIX-490).
	lantern.shadow_item_cull_mask = NightShadows.LANTERN
	player.add_child(lantern)
	_tend_lantern()
	GameState.settlers_changed.connect(_tend_lantern)
	GameState.inventory_changed.connect(_tend_lantern)


## How far the hero's lantern reaches, in pixels, with `share` more.
static func lantern_reach(share: float) -> float:
	return LANTERN_REACH * (1.0 + share)


## The lantern trimmed as far as Aske keeps it, and lit only while the
## hero carries one: at energy 0 the frame keeps it hidden.
func _tend_lantern() -> void:
	if is_instance_valid(lantern):
		lantern.texture_scale = lantern_reach(GameState.holdings.settler_share("lantern")) * 2.0 / Lights.TEXTURE_PX
		lantern.set_meta("energy", Lights.LANTERN_ENERGY if Lights.carried(GameState.pack.items) else 0.0)


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
## Whether the map is the village on the Night of Ash, through its dawn too.
static func ash_night(map: MapData) -> bool:
	return GameState.progression.prologue != Prologue.DONE and map.id == "town"


## The moon's share (the sun's w): the night's dark under the sky, none
## through cloud, nor through the Night of Ash's smoke. The night is told by
## its state, not its colour: its dawn greys the light (ash_dawn) while the
## smoke still hangs.
func moon(map: MapData, darkness_now: float, overcast: float) -> float:
	if not Lights.under_sky(map) or ash_night(map):
		return 0.0
	return darkness_now * (1.0 - overcast)


func light_for(map: MapData) -> Color:
	if map == null:
		return Lights.DAY
	if map.style == "cave":
		# A region dungeon's floor may keep its own dark (PIX-255).
		return Color(map.light, 1.0) if map.light.a > 0.0 else Lights.UNDERGROUND
	if ash_night(map):
		return Lights.ASH_NIGHT.lerp(Lights.ASH_DAWN, ash_dawn)
	if PunyInterior.is_room(map.id):
		return Lights.indoor(GameState.world.steps)
	return Lights.outdoor(GameState.world.steps)


func _process(delta: float) -> void:
	light = light_for(world.map)
	# The motion check walks in plain daylight (PIX-526): it finds the hero by
	# the shirt's exact reds, which the golden hours' tint and grey change, as
	# a cloud's shadow does (clear_sky).
	if clear_sky and Lights.under_sky(world.map):
		light = Lights.DAY
	# Rain darkens and cools the light, and the lamps come up a little; under
	# rain, fog or snow the sky is all cloud.
	var rain := 0.0
	overcast = 0.0
	if world.atmosphere != null:
		rain = world.atmosphere.rain
		overcast = maxf(rain, maxf(world.atmosphere.weights.get("mire", 0.0), world.atmosphere.weights.get("frost", 0.0)))
	light = light.lerp(light * Weather.RAIN_LIGHT, rain)
	# A thunderstorm's clouds are darker still (PIX-491), and its wind blows
	# harder: the trees lean further, the grass ripples more.
	gale = world.storm.storm if world.storm != null and Lights.under_sky(world.map) else 0.0
	light = light.lerp(light * Weather.STORM_LIGHT, gale)
	darkness.color = light
	dark = Lights.darkness(light)
	bloom.visible = GameState.settings.glow
	_glow_copy.visible = bloom.visible
	_air_copy.visible = air.visible
	# A room blooms with the night outside, a little less (PIX-311): by its
	# own dim day its sunlit windows would glow into the dark round it.
	var glowing := dark
	if world.map != null and PunyInterior.is_room(world.map.id):
		glowing = ROOM_GLOW * Lights.darkness(Lights.outdoor(GameState.world.steps))
	if bloom.visible:
		(bloom.material as ShaderMaterial).set_shader_parameter("strength", lerpf(GLOW_DAY, GLOW_NIGHT, glowing))
	if glow_wide != null:
		var wide := DesktopLook.wide(DesktopLook.look, glowing, GameState.settings.glow)
		_show_wide(wide > 0.0)
		(glow_wide.material as ShaderMaterial).set_shader_parameter("strength", wide)
	tick(delta)
	var at := world_view()
	_mirror_water(at)
	_drift_clouds(at, overcast)
	# The scenery's shadows follow the sun (PIX-449): none indoors or
	# underground, and none under a sky all cloud. The moon (w) is the
	# night's dark under the sky (the roofs' rim, PIX-523): none through
	# cloud, nor through the Night of Ash's smoke.
	var outside := Lights.under_sky(world.map)
	var sun := DayNight.sun(GameState.world.steps) if outside else Vector3.ZERO
	RenderingServer.global_shader_parameter_set("sun", Vector4(sun.x, sun.y, sun.z * (1.0 - overcast), moon(world.map, dark, overcast)))
	# The lamps and the lantern shape the art, with Light relief on (PIX-528).
	RenderingServer.global_shader_parameter_set("relief", relief_strength())
	# And rim what stands on its side facing them, in the dark (PIX-531).
	RenderingServer.global_shader_parameter_set("light_rim", rim_strength(dark))
	var still: bool = GameState.settings.reduce_motion
	var t := GameClock.seconds()
	# The day through a room's window follows the sky, not the room's dark
	# (PIX-311), and dims under rain.
	var day := (1.0 - Lights.darkness(Lights.outdoor(GameState.world.steps))) * (1.0 - 0.5 * rain)
	var flames: Array[PointLight2D] = []
	for node in get_tree().get_nodes_in_group("lights"):
		var lamp := node as PointLight2D
		if lamp.has_meta("tint"):
			lamp.color = DesktopLook.canvas_color(lamp.get_meta("tint"), DesktopLook.linear)
		var energy := float(lamp.get_meta("energy", 1.0)) * (day if lamp.get_meta("by_day", false) else dark)
		# The hero's lantern burns only in the real dark, and goes out as the
		# fallen hero puts it away (PIX-530): the glass in their hand is lit
		# by this (lantern.visible), so the pool never burns round a cold one.
		# A lamp's or a window's pool waits for its glass (MapView._show, PIX-526).
		if lamp.get_meta("unlit", false) or (lamp == lantern and (dark < Lights.LANTERN_DARK or (lantern.get_parent() as Player).dead)):
			energy = 0.0
		if lamp.get_meta("flicker", false) and not still:
			energy *= Lights.flicker(t, float(lamp.get_meta("phase", 0.0)), lamp.get_meta("blaze", false))
		# A way out breathes (PIX-292), held still with reduced motion.
		if lamp.get_meta("pulse", false) and not still:
			energy *= 1.0 + Lights.PULSE_DEPTH * sin(t * Lights.PULSE_SPEED)
		lamp.energy = energy
		lamp.visible = energy > 0.01
		if lamp.visible and lamp.has_meta("casts"):
			flames.append(lamp)
	_cast_shadows(flames, delta)


## The nearest of `flames` (the map's lamps, torches and fires burning
## now) cast shadows (PIX-490, NightShadows), never the lantern: on the floor
## alone (Lights.FLOOR), each leaving a share of its light in its shadow,
## a lamp's fading in and out as the hero nears and leaves it. Only where
## the map has occluders (not in a room), in the dark, and with the
## Shadows setting on.
func _cast_shadows(flames: Array[PointLight2D], delta: float) -> void:
	var on: bool = GameState.settings.shadows and is_instance_valid(lantern) and world.view != null \
		and not NightShadowsLayer.laid(world.view).is_empty()
	var cap := NightShadows.LAMPS if on else 0
	candidates = flames.size()
	var wanted: Array[PointLight2D] = []
	if on:
		var hero: Vector2 = (lantern.get_parent() as Node2D).global_position
		var far := PackedFloat32Array()
		for flame in flames:
			far.append(flame.global_position.distance_to(hero))
		for i in NightShadows.nearest(far, cap):
			wanted.append(flames[i])
	# Those casting already, then those wanted: each a step on.
	var now: Array[PointLight2D] = []
	# A lamp freed with its map is still in `casting` (PIX-496): asked for by
	# its type, it stopped the whole filter with an error, and the lamps
	# fading out were dropped still casting.
	var lamps: Array[PointLight2D] = []
	for light: Variant in casting:
		if is_instance_valid(light) and light != lantern:
			lamps.append(light)
	var busy := lamps.size()
	for light: PointLight2D in wanted:
		if not light in lamps:
			lamps.append(light)
	for light: PointLight2D in lamps:
		var before := float(light.get_meta("shade", 0.0))
		# A lamp gone out (the day, a doused fire) stops at once.
		var strength := NightShadows.faded(before, light in wanted, busy < cap, delta) if on and light.visible else 0.0
		busy += int(before == 0.0 and strength > 0.0)
		light.set_meta("shade", strength)
		light.shadow_enabled = strength > 0.0
		if strength > 0.0:
			light.shadow_color = NightShadows.left_in_shadow(light.color, light.energy, strength)
			now.append(light)
	# The hero's own lantern casts none: shadows thrown out from the hero
	# read as a field of view (Tom, 2026-11-18).
	if is_instance_valid(lantern):
		lantern.shadow_enabled = false
	casting = now


## The world's clock and the wind, for the shaders: with reduced motion the
## clock stops and the wind drops.
func tick(delta: float) -> void:
	var still: bool = GameState.settings.reduce_motion
	if not still:
		time += delta
	wind = 0.0 if still else 1.0 + Weather.STORM_WIND * gale
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
	var laid: Dictionary = world.neighbours.mirror if world.neighbours != null else {}
	var version: int = world.neighbours.mirror_version if world.neighbours != null else 0
	if map != _water_of or version != _mirror_version:
		_water_of = map
		_mirror_version = version
		var wet := Lights.under_sky(map) and (not laid.is_empty() or map.grid.values().any(func(tile: String) -> bool: return PunyTerrain.ground_of(tile) in PunyTerrain.WATER_GROUNDS))
		reflections.visible = wet
		if wet and not laid.is_empty():
			mirror.set_shader_parameter("water_map", laid["texture"])
			mirror.set_shader_parameter("map_pixels", laid["cells"] * MapView.TILE)
			mirror.set_shader_parameter("mirror_origin", laid["origin"])
		elif wet:
			# The ground as drawn, so a feature's planks over drawn water
			# (MapView.drawn_as) are no bank to mirror (PIX-519).
			mirror.set_shader_parameter("water_map", PunyTerrain.water_map(world.view.look() if world.view != null else map.grid, map.size, map.id))
			mirror.set_shader_parameter("map_pixels", Vector2(map.size * MapView.TILE))
			mirror.set_shader_parameter("mirror_origin", world.plane_px() / MapView.TILE)
		# The river's banks swing in the mirror as on the hero's map's ground.
		if wet:
			mirror.set_shader_parameter("river_swing", PunyTerrain.RIVER_SWING.get(map.id, 0.0))
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
