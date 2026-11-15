extends Node
## areas: field town rooms night
## A thunderstorm over the hero, frame by frame (PIX-491): how hard it
## blows here (Weather.storm_at, under the sky where it rains, or over a
## village house's roof), eased in and out as the rain is; the lightning,
## each strike from Weather's own list - the sky's light over the whole
## view, cold and white for a few frames, and the bolt's, from beyond the
## top of the view, which casts the shadow of everything that stands
## through the night shadows' occluders (PIX-490), on the floor alone; the
## thunder after it, later the farther the strike; and what the rain
## leaves, the ground wet and its puddles full, drying by the clock (the
## global the puddles' shader reads, PuddlesLayer). In a room the windows
## flash and the thunder is muffled. With the Flashes option off, or
## Reduce motion, a flash is one slow soft brightening with no shadows;
## and never more than Weather.FLASH_CAP flashes in any FLASH_WINDOW
## seconds, whatever asks.

var world: Node
## How hard the storm blows here, and how much of the rain's leavings show
## (1 where it rains, 0 in a room or under the Ash's heat), both eased.
var storm := 0.0
var rained := 0.0
## How wet the ground is here and how full its puddles, 0..1.
var wet := 0.0
var puddles := 0.0
## The flash now, 0..1, and whether the last one was the soft kind.
var flash := 0.0
var soft := false
## How many flashes this world has shown (the report's storm=).
var flashes := 0
## Under a roof the storm is heard and seen through the windows.
var inside := false
## The harness's `--strike held`: the flash held at its brightest.
var held := false
## The sky's light, over everything alike (a DirectionalLight2D's shadows
## fall on what stands too, whatever its light bits: it casts none), and
## the bolt's, a far point light that casts; whether the strike showing
## has a place to cast from.
var sky: DirectionalLight2D
var bolt: PointLight2D
var casts := false
## Whether the storm strikes by itself: not in a run of the harness's
## that strikes when it says (`--strike`), so its report reads the same
## however long the run took.
var wild := true
var _map_of: MapData
## The flashes showing: {"at": when it began, "soft", "bright"}; when the
## last ones began (the cap's); the thunder still to come: [when, event].
var _showing: Array[Dictionary] = []
var _shown: Array = []
var _thunder: Array = []
## The next strike of Weather's list and when it falls (-1: no storm).
var _n := 0
var _next_at := -1.0

## How fast a storm comes and goes, per second, as the rain's.
const EASE := 0.5
## Lightning only once the storm blows this hard.
const STRIKES_FROM := 0.5
## The first strike comes this share of its gap after the storm is here.
const FIRST := 0.3
## The lightning's colour, and its energy by day (the sun is behind the
## clouds, the flash whitens the view) and at night (it is the only light).
const SKY := Color(0.84, 0.91, 1.0)
const DAY_ENERGY := 0.55
const NIGHT_ENERGY := 1.25
## A strike at the horizon flashes this share as bright as one overhead.
const FAR_LIGHT := 0.55
## The bolt's light stands this far from the middle of the view, beyond
## its top; its light is flat, reaching this far (the whole view from
## there); its shadows' edges are harder than a lamp's.
const BOLT_OFF := 330.0
const BOLT_REACH := 720.0
const SHADOW_SOFT := 1.2
## The bolt's share of the flash: what a shadow takes away. The sky keeps
## the rest, so a shadow, which runs on to the edge of the view, is a
## tone, and a strike with nowhere to cast from flashes all the same.
const SHADOW_DEPTH := 0.6
## A window's light under a flash: its own energy this many times over.
const WINDOW_FLASH := 2.2


func _ready() -> void:
	sky = DirectionalLight2D.new()
	sky.energy = 0.0
	sky.visible = false
	world.add_child(sky)
	var flat := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	flat.fill(Color.WHITE)
	bolt = PointLight2D.new()
	bolt.texture = ImageTexture.create_from_image(flat)
	bolt.texture_scale = BOLT_REACH * 2.0 / 4.0
	bolt.energy = 0.0
	bolt.visible = false
	bolt.shadow_enabled = true
	bolt.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	bolt.shadow_filter_smooth = SHADOW_SOFT
	# In a shadow none of the bolt's light is left: the sky's is.
	bolt.shadow_color = Color(0, 0, 0, 0)
	# On the floor alone, from what stands and from the folk's feet, as the
	# lamps' shadows are (art.md, PIX-490); never from a hole's outline.
	bolt.shadow_item_cull_mask = NightShadows.SKY
	world.add_child(bolt)
	wild = not HarnessFlags.given().has("--strike")


func _process(delta: float) -> void:
	var map: MapData = world.map
	if map == null or world.get("atmosphere") == null:
		return
	var now := GameClock.seconds()
	var steps: float = GameState.world.steps
	var open := Weather.rains_in(map, world.atmosphere.air)
	inside = Weather.under_roof(map)
	var want := Weather.storm_at(steps) if open or inside else 0.0
	var arrived := map != _map_of
	_map_of = map
	storm = want if arrived else move_toward(storm, want, EASE * delta)
	rained = float(open) if arrived else move_toward(rained, float(open), EASE * delta)
	wet = Weather.wet_at(steps) * rained
	puddles = Weather.puddles_at(steps) * rained
	RenderingServer.global_shader_parameter_set("ground_wet", Vector3(wet, puddles, world.atmosphere.rain))
	for layer: CanvasItem in get_tree().get_nodes_in_group(PuddlesLayer.GROUP):
		layer.visible = wet > 0.004 or puddles > 0.004
	if storm < STRIKES_FROM or not wild:
		_next_at = -1.0
	elif _next_at < 0.0:
		_next_at = now + FIRST * float(Weather.strike(_n)["gap"])
	elif now >= _next_at:
		strike(Weather.strike(_n))
		_n += 1
		_next_at = now + float(Weather.strike(_n)["gap"])
	_shine(now)
	_roll(now)


## Whether a flash is the soft kind now: the Flashes option off, or Reduce
## motion.
func is_soft() -> bool:
	return not GameState.settings.flashes or GameState.settings.reduce_motion


## Lightning strikes (`spec`: Weather.strike): its flash, or its two when
## it flickers, each only if the cap lets it; then its thunder, later the
## farther it fell. A strike the cap holds back whole makes no sound.
func strike(spec: Dictionary) -> void:
	var now := GameClock.seconds()
	soft = is_soft()
	_shown = _shown.filter(func(at: float) -> bool: return now - at < Weather.FLASH_WINDOW)
	var far := float(spec["far"])
	var began := false
	# The soft kind never flickers.
	for i in (1 if soft else int(spec["flashes"])):
		var at := now + i * Weather.FLICKER_S
		if not Weather.may_flash(_shown, at):
			break
		_shown.append(at)
		_showing.append({"at": at, "soft": soft, "bright": lerpf(1.0, FAR_LIGHT, far)})
		flashes += 1
		began = true
	if not began:
		return
	var from := _bolt_at(float(spec["from"]))
	casts = from.is_finite()
	if casts:
		bolt.global_position = from
	var event := "thunder_near" if far < Weather.THUNDER_NEAR else "thunder_far"
	_thunder.append([now + Weather.thunder_delay(far), "thunder_inside" if inside else event])


## Where the bolt's light stands for a strike falling `from` (radians off
## straight down the screen): beyond the top of the view, BOLT_OFF from
## its middle, never in or against a block of tall cells, where its light
## would be shut in (NightShadows.shut_in, as a lamp's): a little further
## out then, or from the other side. Vector2.INF where the map lays no
## occluders or nowhere near is open: the strike casts nothing.
func _bolt_at(from: float) -> Vector2:
	var laid := NightShadowsLayer.laid(world.get("view"))
	if laid.is_empty():
		return Vector2.INF
	var view: Array[Vector2] = world.lights.world_view()
	var origin: Vector2 = world.view.under.global_position
	for way: float in [from, -from]:
		for further in 4:
			var at := view[0] + view[1] / 2.0 + Vector2.UP.rotated(way) * (BOLT_OFF + further * 2.0 * MapView.TILE)
			if not NightShadows.shut_in(laid["solid"], (at - origin) / MapView.TILE):
				return at
	return Vector2.INF


## The flash now: under the open sky the sky's light, and the bolt's with
## its shadows unless the flash is the soft kind, Shadows is off or the
## strike has nowhere to cast from; a room's windows under a roof.
func _shine(now: float) -> void:
	flash = 0.0
	for one: Dictionary in _showing:
		flash = maxf(flash, Weather.flash_light(now - float(one["at"]), one["soft"]) * float(one["bright"]))
	_showing = _showing.filter(func(one: Dictionary) -> bool:
		return now - float(one["at"]) < (Weather.SOFT_S if one["soft"] else Weather.FLASH_S))
	if held:
		flash = Weather.SOFT_LIGHT if soft else 1.0
	var color := DesktopLook.canvas_color(SKY, DesktopLook.linear)
	var energy: float = flash * lerpf(DAY_ENERGY, NIGHT_ENERGY, world.lights.dark)
	sky.visible = flash > 0.0 and not inside
	bolt.visible = sky.visible and casts and not soft and GameState.settings.shadows
	sky.color = color
	bolt.color = color
	sky.energy = energy * (1.0 - SHADOW_DEPTH) if bolt.visible else energy
	bolt.energy = energy * SHADOW_DEPTH
	if inside and flash > 0.0:
		# After the LightRig has set them for the hour: the day through the
		# windows (`by_day`), cold and bright for the instant.
		for node in get_tree().get_nodes_in_group("lights"):
			var pane := node as PointLight2D
			if pane.get_meta("by_day", false):
				pane.color = pane.color.lerp(color, minf(1.0, flash * 2.0))
				pane.energy += flash * WINDOW_FLASH * float(pane.get_meta("energy", 1.0))
				pane.visible = true


## The thunder whose time has come.
func _roll(now: float) -> void:
	for due: Array in _thunder.filter(func(one: Array) -> bool: return now >= float(one[0])):
		_thunder.erase(due)
		match String(due[1]):
			"thunder_near":
				Sound.play("thunder_near", false)
			"thunder_far":
				Sound.play("thunder_far", false)
			_:
				Sound.play("thunder_inside", false)
