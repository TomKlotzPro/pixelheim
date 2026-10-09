extends Node
## Each region's air and the weather, frame by frame (PIX-224): the air the
## hero stands in (Weather.air_at), eased in as they cross into a region and
## out as they leave it (all at once on a new map); the rain as a shower
## comes and goes; the air's pass on the LightRig's layer (shaders/
## atmosphere.gdshader: haze, fog, frost, mist, rain's veil and the colour
## mood); and what falls or drifts over the view, in the world - rain and its
## splashes, snow, the Ash's embers, the coast's salt spray - and the small
## life of the world (PIX-225, Motes): fireflies, falling leaves, a room's
## dust, and the bursts the world asks for (dust and splashes underfoot,
## sparks off armour). With reduced motion nothing falls, rises or blows.

var world: Node
## How much of each air (Weather.KINDS), 0..1, and of the rain.
var weights := {}
var rain := 0.0
var air := ""
var _map_of: MapData
## What falls or drifts, by name: "drops", "splashes", "snow", "embers",
## "spray", "fireflies", "leaves", "room_dust".
var particles := {}
## The bursts, a few of each kind taken in turn, so a quick second one
## doesn't cut the first short: "dust", "splash", "sparks".
var bursts := {}
var _next := {}
## How many of each burst to take turns with.
const BURST_POOL := 3
## How fast an air or the rain comes and goes, per second.
const AIR_EASE := 0.7
const RAIN_EASE := 0.5
## The particles cover the view and this much more each side, so nothing
## pops in at its edges; they draw over the actors, under the world's words.
const MARGIN := 24.0
const Z := 8


func _ready() -> void:
	for kind: String in Weather.KINDS:
		weights[kind] = 0.0
	particles = {
		"drops": _drops(),
		"splashes": _splashes(),
		"snow": _snow(),
		"embers": _embers(),
		"spray": _spray(),
		"fireflies": Motes.make_fireflies(),
		"leaves": Motes.make_leaves(),
		"room_dust": Motes.make_room_dust(),
	}
	for node: CPUParticles2D in particles.values():
		node.emitting = false
		node.z_index = Z
		world.add_child(node)
	var makers := {
		"dust": func() -> CPUParticles2D: return Motes.make_dust(),
		"splash": func() -> CPUParticles2D: return Motes.make_splash(),
		"sparks": func() -> CPUParticles2D: return Motes.make_sparks(),
	}
	for kind: String in makers:
		bursts[kind] = []
		_next[kind] = 0
		for i in BURST_POOL:
			var node: CPUParticles2D = (makers[kind] as Callable).call()
			node.z_index = Z
			world.add_child(node)
			bursts[kind].append(node)

func _process(delta: float) -> void:
	var map: MapData = world.map
	air = Weather.air_at(map, world.player_cell)
	var wet := Weather.rain_at(GameState.world.steps) if Weather.rains_in(map, air) else 0.0
	var arrived := map != _map_of
	_map_of = map
	for kind: String in Weather.KINDS:
		var want := 1.0 if kind == air else 0.0
		weights[kind] = want if arrived else move_toward(weights[kind], want, AIR_EASE * delta)
	rain = wet if arrived else move_toward(rain, wet, RAIN_EASE * delta)
	_shade()
	_fall(arrived)


## The air's pass: on while any air, rain or mood shows.
func _shade() -> void:
	var lights: Node = world.lights
	var mood := Weather.mood(weights, lights.dark)
	var air_pass: ColorRect = lights.air
	var calm := rain < 0.001 and weights.values().all(func(w: float) -> bool: return w < 0.001) and absf(float(mood[1]) - 1.0) < 0.005
	air_pass.visible = not calm
	if calm:
		return
	var shader := air_pass.material as ShaderMaterial
	var view: Array[Vector2] = lights.world_view()
	shader.set_shader_parameter("view_origin", view[0])
	shader.set_shader_parameter("view_size", view[1])
	for kind: String in Weather.DRAWN:
		shader.set_shader_parameter(kind, weights[kind])
	shader.set_shader_parameter("rain", rain)
	var light: Color = lights.light
	shader.set_shader_parameter("light", Vector3(light.r, light.g, light.b))
	var tint: Color = mood[0]
	shader.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	shader.set_shader_parameter("saturation", mood[1])
	shader.set_shader_parameter("contrast", mood[2])


## The particles over the view, each as strong as its air or the rain; on a
## new map they start already falling.
func _fall(arrived: bool) -> void:
	var view: Array[Vector2] = world.lights.world_view()
	var still: bool = GameState.settings.reduce_motion
	var map: MapData = world.map
	var amounts := {
		"drops": rain, "splashes": rain, "snow": weights["frost"],
		"embers": weights["ash"], "spray": weights["coast"],
		"fireflies": Motes.fireflies(map, air, world.lights.dark, rain),
		"leaves": weights["woods"] * (1.0 - 0.5 * rain),
		"room_dust": 1.0 if map != null and PunyInterior.is_room(map.id) else 0.0,
	}
	for name: String in particles:
		var node: CPUParticles2D = particles[name]
		var amount: float = amounts[name]
		var on := amount > 0.05 and not still
		node.global_position = view[0] + view[1] / 2.0
		node.emission_rect_extents = view[1] / 2.0 + Vector2(MARGIN, MARGIN)
		node.modulate.a = amount
		if on and arrived:
			node.restart()
		node.emitting = on


## A footfall on `tile` at `at`: a little dust off dry ground, a splash in
## a bog. (A roll kicks up its own ring: world.dust.)
func footfall(at: Vector2, tile: String) -> void:
	var kick := Motes.footfall(tile)
	if kick == "dust":
		_fire("dust", at, Motes.DUST[tile])
	elif kick == "splash":
		_fire("splash", at)


## Sparks off armour at `at`.
func sparks(at: Vector2) -> void:
	_fire("sparks", at)


## The next burst of `kind` at `at`, tinted `color`; none with reduced motion.
func _fire(kind: String, at: Vector2, color := Color.WHITE) -> void:
	if GameState.settings.reduce_motion or not bursts.has(kind):
		return
	var pool: Array = bursts[kind]
	var node: CPUParticles2D = pool[_next[kind]]
	_next[kind] = (_next[kind] + 1) % pool.size()
	node.global_position = at
	node.color = color
	node.restart()


## A tiny picture from rows of "x" (lit) and "." (clear), in white: the
## particles' colour tints it.
static func picture(rows: Array) -> ImageTexture:
	var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in String(rows[y]).length():
			if String(rows[y])[x] == "x":
				image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)


## Rain: slanting streaks, falling fast with the wind from the west.
static func _drops() -> CPUParticles2D:
	var node := Motes.over_view(260, 0.5, Vector2(0.22, 1.0), 2.0, Vector2(250, 300), Vector2(0, 200))
	node.texture = picture(["x", "x", "x", "x"])
	node.particle_flag_align_y = true
	node.color = Color(0.78, 0.86, 1.0, 0.5)
	return node


## Where the drops land: a little crown that opens and fades.
static func _splashes() -> CPUParticles2D:
	var node := Motes.over_view(60, 0.3, Vector2.UP, 0.0, Vector2.ZERO, Vector2.ZERO)
	node.texture = picture([".xx.", "x..x"])
	node.color_ramp = Motes.fading(Color(0.82, 0.9, 1.0, 0.7))
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.6))
	grow.add_point(Vector2(1, 1.4))
	node.scale_amount_curve = grow
	return node


## Snow: big and small flakes drifting down on the wind, each white over a
## cold blue pixel, so it shows against the snow on the ground too.
static func _snow() -> CPUParticles2D:
	var node := Motes.over_view(340, 6.0, Vector2(0.3, 1.0), 25.0, Vector2(10, 22), Vector2(3, 4))
	var flake := Image.create(1, 2, false, Image.FORMAT_RGBA8)
	flake.set_pixel(0, 0, Color.WHITE)
	flake.set_pixel(0, 1, Color(0.55, 0.65, 0.82, 0.85))
	node.texture = ImageTexture.create_from_image(flake)
	node.scale_amount_min = 1.0
	node.scale_amount_max = 2.0
	return node


## The Ash's embers: sparks rising, orange to red to nothing, bright by
## day and night alike.
static func _embers() -> CPUParticles2D:
	var node := Motes.over_view(80, 4.0, Vector2.UP, 40.0, Vector2(6, 16), Vector2(4, -6))
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.78, 0.3, 1.0))
	ramp.set_color(1, Color(0.75, 0.16, 0.06, 0.0))
	ramp.add_point(0.55, Color(1.0, 0.45, 0.12, 0.95))
	node.color_ramp = ramp
	node.scale_amount_min = 1.0
	node.scale_amount_max = 2.0
	node.material = Lights.unshaded()
	return node


## The coast's salt spray: specks blown in off the sea, falling.
static func _spray() -> CPUParticles2D:
	var node := Motes.over_view(70, 2.2, Vector2(1.0, -0.1), 10.0, Vector2(40, 80), Vector2(0, 12))
	node.color_ramp = Motes.fading(Color(1, 1, 1, 0.6))
	return node


