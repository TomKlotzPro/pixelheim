class_name Atmosphere
extends Node
## areas: field
## Each region's air and the weather, frame by frame (PIX-224): the air the
## hero stands in (Weather.air_at), eased in as they cross into a region and
## out as they leave it (all at once on a new map); the rain as a shower
## comes and goes; the air's pass on the LightRig's layer (shaders/
## atmosphere.gdshader: haze, fog, frost, mist, rain's veil and the colour
## mood); and what falls or drifts over the view, in the world - rain and its
## splashes, snow, the Ash's embers, the coast's salt spray - and the small
## life of the world (PIX-225, Motes): fireflies, dawn's mist (PIX-526),
## falling leaves, a room's dust, and the bursts the world asks for (dust
## and splashes underfoot, sparks off armour). With reduced motion nothing
## falls, rises or blows; the dawn's mist still lies there, still.

var world: World
## How much of each air (Weather.KINDS), 0..1, and of the rain.
var weights := {}
var rain := 0.0
var air := ""
var _map_of: MapData
## What falls or drifts, by name: "drops", "splashes", "snow", "embers", "ash",
## "spray", "fireflies", "leaves", "room_dust".
var particles := {}
## Dawn's mist (PIX-526): how thick it lies, how many misty cells round the
## view its wisps rise from (Motes.mist_points) and whether they lie still
## (Reduce motion); drawn wisp by wisp under the actors by `mist_node`, made
## the first dawn it's needed, from dice of its own (Motes.MIST_SEED). Each
## wisp where it lies, its drift (px a second), its age (seconds) and its
## look (Motes.WISPS).
var mist := 0.0
var mist_cells := 0
var mist_still := false
var mist_node: Node2D
var _mist_points := PackedVector2Array()
var _mist_at := Rect2i()
var _mist_map: MapData
var _mist_dice: RandomNumberGenerator
var _wisp_at := PackedVector2Array()
var _wisp_way := PackedVector2Array()
var _wisp_age := PackedFloat32Array()
var _wisp_look := PackedInt32Array()
## Each drawn map's ground as drawn and what its cells were found to be
## (Motes.mist_points' `seen`), by its view's instance id, while the hero's
## map stays the same.
var _mist_seen := {}
## How many cells the view may move in a frame and its wisps drift on with
## it; further (a door's cut, the harness's --at), they all rise anew.
const MIST_JUMP := 4
## The bursts, a few of each kind taken in turn, so a quick second one
## doesn't cut the first short: "dust", "splash", "sparks", "remains".
var bursts := {}
var _next := {}
## How many of each burst to take turns with.
const BURST_POOL := 3
## How fast an air or the rain comes and goes, per second.
const AIR_EASE := 0.7
const RAIN_EASE := 0.5
## How much thicker the rain's veil is under a thunderstorm (PIX-491).
const STORM_VEIL := 0.4
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
		"remains": func() -> CPUParticles2D: return Motes.make_remains(),
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
	if _fall_again > 0:
		_fall_again -= 1
		if _fall_again == 0:
			for node: CPUParticles2D in particles.values():
				if node.emitting:
					node.restart()
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


## The hero walked over a line into the map beside theirs (One Reach,
## PIX-269, step 6): not a new place come to through a door, so the air
## eases from the one to the other as it does between regions. What falls
## or drifts is in the world, which has just moved under it: it starts again
## already falling round the view - the frame after, as starting again runs
## each a lifetime ahead, and the crossing's own frame has enough to do.
func carry_on() -> void:
	_map_of = world.map
	_fall_again = 2


## Frames until what falls starts again (carry_on), 0 when it needn't.
var _fall_again := 0
## The room's floor the dust floats over (Motes.room_rect), or nothing.
var _room := Rect2()


## The air's pass: on while any air, rain or mood shows.
func _shade() -> void:
	var lights: LightRig = world.lights
	var mood := Weather.mood(weights, lights.dark)
	var air_pass: ColorRect = lights.air
	var calm := rain < 0.001 and weights.values().all(func(w: float) -> bool: return w < 0.001) and absf(float(mood[1]) - 1.0) < 0.005
	air_pass.visible = not calm
	if calm:
		return
	var shader := air_pass.material as ShaderMaterial
	var view: Array[Vector2] = lights.world_view()
	# Its fog and haze drift over the plane, unbroken at a line (PIX-269).
	shader.set_shader_parameter("view_origin", view[0] + world.plane_px())
	shader.set_shader_parameter("view_size", view[1])
	for kind: String in Weather.DRAWN:
		shader.set_shader_parameter(kind, weights[kind])
	# A storm's veil is thicker (PIX-491).
	shader.set_shader_parameter("rain", rain * (1.0 + STORM_VEIL * lights.gale))
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
		"drops": rain, "splashes": rain, "gale": world.lights.gale, "snow": weights["frost"],
		"embers": weights["ash"], "ash": weights["ash"], "spray": weights["coast"],
		"fireflies": Motes.fireflies(map, air, world.lights.dark, rain),
		"leaves": weights["woods"] * (1.0 - 0.5 * rain),
		# Fainter at night, when it shows only in the candles' light.
		"room_dust": 1.0 - 0.6 * world.lights.dark if map != null and PunyInterior.is_room(map.id) else 0.0,
		"mist": Motes.mist(map, air, GameState.world.steps, rain),
	}
	if arrived:
		_room = Motes.room_rect(map) if amounts["room_dust"] > 0.0 else Rect2()
	# The Ash's ash (PIX-308) made the first time it's breathed: a particle
	# system draws from the game's dice as it's made, and one made up front
	# shifted every seeded harness fight after it.
	# A storm's driven rain (PIX-491) the same way, with its first storm.
	for late: String in ["ash", "gale"]:
		if amounts[late] > 0.05 and not particles.has(late):
			var node := _ash() if late == "ash" else _gale()
			node.emitting = false
			node.z_index = Z
			world.add_child(node)
			particles[late] = node
			arrived = true
	for name: String in particles:
		var node: CPUParticles2D = particles[name]
		var amount: float = amounts[name]
		var on := amount > 0.05 and not still
		node.global_position = view[0] + view[1] / 2.0
		node.emission_rect_extents = view[1] / 2.0 + Vector2(MARGIN, MARGIN)
		if name == "room_dust" and _room.has_area():
			# Over the room's floor, not the dark round it (PIX-315).
			node.global_position = _room.get_center()
			node.emission_rect_extents = _room.size / 2.0
		node.modulate.a = amount
		if on and arrived:
			node.restart()
		node.emitting = on
	# The time a system runs ahead as it starts again is laid where it stood
	# the frame before (at the world's corner for a room's dust, which then
	# twinkled in the dark round the room like stars): the room's start again
	# once they stand over it (PIX-315).
	if arrived and _room.has_area():
		_fall_again = 2
	_lay_mist(amounts["mist"], view, arrived)


## Dawn's mist over the view (PIX-526), `amount` thick: its wisps rising
## from the misty cells of every map drawn round it (the view and two cells
## more each side, so none pops in at its edge), laid again as the view
## moves a cell, a wisp left behind rising again in it; on a new map, or
## the view gone far at once, every wisp rises anew, as if it had lain a
## while. Still with reduced motion, there all the same.
func _lay_mist(amount: float, view: Array[Vector2], arrived: bool) -> void:
	mist = amount
	mist_still = GameState.settings.reduce_motion
	if amount <= 0.05 or world.view == null:
		mist_cells = 0
		if mist_node != null:
			mist_node.visible = false
		return
	if mist_node == null:
		# It lies on the ground: over every map's ground and houses, under
		# everyone standing (just before world.actors), not over them as the
		# rest.
		mist_node = Node2D.new()
		mist_node.draw.connect(_draw_mist)
		world.add_child(mist_node)
		world.move_child(mist_node, world.actors.get_index())
		_mist_dice = RandomNumberGenerator.new()
		_mist_dice.seed = Motes.MIST_SEED
		_wisp_at.resize(Motes.MIST_WISPS)
		_wisp_way.resize(Motes.MIST_WISPS)
		_wisp_age.resize(Motes.MIST_WISPS)
		_wisp_look.resize(Motes.MIST_WISPS)
	var top := Vector2i((view[0] / MapView.TILE).floor())
	var cells := Rect2i(top, Vector2i((view[1] / MapView.TILE).ceil()) + Vector2i.ONE).grow(2)
	var moved := arrived or world.map != _mist_map or (cells.position - _mist_at.position).length_squared() > MIST_JUMP * MIST_JUMP
	if arrived or world.map != _mist_map:
		_mist_seen.clear()
	if moved or cells != _mist_at:
		_mist_at = cells
		_mist_map = world.map
		_mist_points = _mist_over(world.view, Vector2i.ZERO, cells)
		if world.neighbours != null:
			for id: String in world.neighbours.drawn:
				var beside: Dictionary = world.neighbours.drawn[id]
				if beside["state"] == "ready":
					var drawn: MapView = beside["view"]
					_mist_points.append_array(_mist_over(drawn, Vector2i(drawn.offset / MapView.TILE), cells))
		mist_cells = _mist_points.size()
	mist_node.visible = mist_cells > 0
	if not mist_node.visible:
		return
	if moved:
		for i in Motes.MIST_WISPS:
			_rise(i, Motes.MIST_LIFE * i / Motes.MIST_WISPS)
	else:
		var delta := get_process_delta_time()
		var room := Rect2(Vector2(cells.position * MapView.TILE), Vector2(cells.size * MapView.TILE))
		for i in Motes.MIST_WISPS:
			_wisp_age[i] += delta
			if _wisp_age[i] >= Motes.MIST_LIFE:
				_rise(i, _wisp_age[i] - Motes.MIST_LIFE)
			elif not room.has_point(_wisp_at[i]):
				_rise(i, 0.0)
			elif not mist_still:
				_wisp_at[i] += _wisp_way[i] * delta
	# A view with fewer misty cells than wisps doesn't crowd them all there.
	mist_node.modulate.a = amount * minf(1.0, float(mist_cells) / Motes.MIST_WISPS)
	mist_node.queue_redraw()


## Where wisps rise among `cells` on the map `drawn` shows, laid at `origin`
## (Motes.mist_points), its ground and what its cells were found to be kept
## from the last time.
func _mist_over(drawn: MapView, origin: Vector2i, cells: Rect2i) -> PackedVector2Array:
	var id := drawn.get_instance_id()
	if not _mist_seen.has(id):
		_mist_seen[id] = [drawn.look(), {}]
	var kept: Array = _mist_seen[id]
	return Motes.mist_points(kept[0], drawn.data.size, origin, cells, drawn.data.regions, kept[1])


## Wisp `i` rises from a misty cell, `age` seconds into its life, drifted
## that far already (unless still).
func _rise(i: int, age: float) -> void:
	var way := Vector2.from_angle(deg_to_rad(_mist_dice.randf_range(-Motes.MIST_SPREAD, Motes.MIST_SPREAD)))
	_wisp_way[i] = way * _mist_dice.randf_range(Motes.MIST_SPEED.x, Motes.MIST_SPEED.y)
	_wisp_at[i] = _mist_points[_mist_dice.randi() % _mist_points.size()] + (Vector2.ZERO if mist_still else _wisp_way[i] * age)
	_wisp_age[i] = age
	_wisp_look[i] = _mist_dice.randi() % Motes.WISPS.size()


## Each wisp at whole pixels, as faint as its life has it, in the scene's
## light (gold at dawn).
func _draw_mist() -> void:
	var strip := Motes.mist_strip()
	var size := Motes.WISP_SIZE
	for i in Motes.MIST_WISPS:
		var alpha := Motes.mist_alpha(_wisp_age[i] / Motes.MIST_LIFE)
		if alpha > 0.0:
			mist_node.draw_texture_rect_region(strip, Rect2((_wisp_at[i] - size / 2.0).floor(), size), Rect2(Vector2(_wisp_look[i] * size.x, 0), size), Color(1, 1, 1, alpha))


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


## What a fallen foe leaves at `at`, in its `color` (PIX-226).
func remains(at: Vector2, color: Color) -> void:
	_fire("remains", at, color)


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


## A thunderstorm's rain (PIX-491), over the shower's own: longer streaks
## driven hard aslant by the wind, faster and thicker.
static func _gale() -> CPUParticles2D:
	var node := Motes.over_view(320, 0.42, Vector2(0.62, 1.0), 3.0, Vector2(340, 420), Vector2(60, 240))
	node.texture = picture(["x", "x", "x", "x", "x", "x"])
	node.particle_flag_align_y = true
	node.color = Color(0.8, 0.88, 1.0, 0.55)
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


## The Ash's ash (PIX-308): grey flakes drifting down on the wind from the
## west, turning as they go, in the scene's light.
static func _ash() -> CPUParticles2D:
	var node := Motes.over_view(110, 7.0, Vector2(1.0, 0.45), 20.0, Vector2(8, 18), Vector2(2, 3))
	node.texture = picture(["xx", "x."])
	node.angle_min = 0.0
	node.angle_max = 360.0
	node.angular_velocity_min = -60.0
	node.angular_velocity_max = 60.0
	var drift := Gradient.new()
	drift.set_color(0, Color(0.82, 0.8, 0.78, 0.0))
	drift.set_color(1, Color(0.6, 0.58, 0.56, 0.0))
	drift.add_point(0.2, Color(0.82, 0.8, 0.78, 0.75))
	drift.add_point(0.8, Color(0.66, 0.64, 0.62, 0.6))
	node.color_ramp = drift
	return node


## The coast's salt spray: specks blown in off the sea, falling.
static func _spray() -> CPUParticles2D:
	var node := Motes.over_view(70, 2.2, Vector2(1.0, -0.1), 10.0, Vector2(40, 80), Vector2(0, 12))
	node.color_ramp = Motes.fading(Color(1, 1, 1, 0.6))
	return node


