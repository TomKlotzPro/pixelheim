class_name RebuildRise
extends Node2D
## A building rising on the town's tour (PIX-264). Tom found the tour after
## the board "an empty screen": the camera stopped on a finished house with
## a line under it. Now a project's stop shows the town as it stood a moment
## before - the ruin's ash with its burnt fence and rubble, or a plot's
## stakes - from the moment the tour opens; at the stop the ruin gives way
## in a cloud of dust, the building goes up out of it course by course and
## its props spring up, and it lands with a squash and a burst of confetti;
## then its name and what it brings. With Reduce motion the ruin gives way
## to the building after a beat: a plain cut.
##
## The town's own drawing is never rebuilt. The town as it stood is drawn
## over it from the plan (MapView.draw_ground on the map without the
## project), a little past the project so the ground's soft tones meet, and
## dissolves in the ground's own 2px Bayer blocks, every layer of it the
## same pixels at once (a fade let its ground show through its houses); the
## new houses' cells are lifted out of the town's layers into courses of
## their own and put back as it lands; its props, signs and lights wait
## hidden. The old ground covers the new until the new is going up on it,
## so the stop never shows an empty plot or a black frame. It runs while
## the tour holds the world (PROCESS_MODE_ALWAYS), under the actors like the
## houses.

const TILE := MapView.TILE
## Where the harness and the look book find one.
const GROUP := &"rebuild_rise"
## How far around the project the old town is drawn: past the soft edge of
## the ash's tone, which PIX-247 bends up to a cell and a half off the grid.
const MARGIN := 2
## The ruin stands a moment as the camera settles on it, then gives way: a
## cloud of dust, the rubble sinking into it, the old town dissolving block
## by block into the new over GIVE_SECONDS.
const HOLD := 0.25
const GIVE_SECONDS := 0.45
## The building goes up RISE_FROM into the stop and stands RISE_SECONDS
## later: each course drops COURSE_DROP pixels into place over
## COURSE_SECONDS, the bottom one first; each prop springs up over
## POP_SECONDS.
const RISE_FROM := 0.45
const RISE_SECONDS := 0.9
const COURSE_SECONDS := 0.16
const COURSE_DROP := 6.0
const POP_SECONDS := 0.3
## As it lands: squashed on its footing, springing back.
const SQUASH := Vector2(1.04, 0.9)
const SQUASH_SECONDS := 0.22
## How long the confetti falls before this goes.
const CONFETTI_SECONDS := 1.8
## Reduce motion: the ruin stands this long, then the building does.
const STILL_BEAT := 0.6

var world: Node
var project_id := ""
## "ruin" until the stop plays it, "rising", then "built" (the harness
## reports it).
var phase := "ruin"

var _view: MapView
var _footprint: Array[Rect2i] = []
## The town as it stood, over the town as it stands, and the materials it's
## drawn with (each dissolves it).
var _past: Node2D
var _past_materials: Array[ShaderMaterial] = []
## The ruin's own props (burnt fence, rubble, a plot's stakes), to sink.
var _rubble: Array[Node2D] = []
## Each new building: {"root": its footing's middle, "courses": bottom first}.
var _buildings: Array[Dictionary] = []
## Each new flat flower in a node of its own, standing on its cell's foot.
var _blooms: Array[Node2D] = []
## The town's own props in the footprint (lamps, stalls, the fountain).
var _props: Array[Node2D] = []
## [layer, cell, source, coords, alternative] lifted out of the town's layers.
var _lifted: Array = []
## Signs, window lights, glows and chimney smoke waiting: node -> was visible.
var _hidden := {}
## The rise's own timeline and the props' springs, stopped if it's stood at
## once.
var _tweens: Array[Tween] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_view = world.view
	_footprint = Town.footprint(project_id)
	_draw_past()
	_lift_houses()
	_lift_flowers()
	_hold_back()


## From play() until it stands: when its name shows.
static func seconds() -> float:
	return STILL_BEAT if GameState.settings.reduce_motion else RISE_FROM + RISE_SECONDS


## The rows of `cells` as courses, bottom first: [[cells of the lowest row],
## ...], each row left to right.
static func courses(cells: Array) -> Array[Array]:
	var rows := {}
	for cell: Vector2i in cells:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell)
	var ys: Array = rows.keys()
	ys.sort()
	ys.reverse()
	var out: Array[Array] = []
	for y: int in ys:
		var row: Array = rows[y]
		row.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		out.append(row)
	return out


## The stop has come: the ruin gives way and the building goes up (or,
## with Reduce motion, simply stands after a beat).
func play() -> void:
	if phase != "ruin":
		return
	phase = "rising"
	var timeline := create_tween()
	_tweens.append(timeline)
	if GameState.settings.reduce_motion:
		timeline.tween_interval(STILL_BEAT)
		timeline.tween_callback(func() -> void:
			Sound.play("craft")
			finish())
		return
	for building: Dictionary in _buildings:
		_raise(building)
	_spring_up()
	timeline.tween_interval(HOLD)
	timeline.tween_callback(_give_way)
	timeline.tween_interval(seconds() - HOLD)
	timeline.tween_callback(_land)


## Stands the building at once, as the town has it (the stop's end, a key
## pressed mid-rise, the tour skipped): the lifted cells back in the town's
## layers, its props and lights back, the old town gone. The confetti falls
## on a moment; then this goes too.
func finish() -> void:
	if phase == "built":
		return
	phase = "built"
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	for item: Array in _lifted:
		if is_instance_valid(item[0]):
			(item[0] as TileMapLayer).set_cell(item[1], item[2], item[3], item[4])
	_lifted.clear()
	for node: Variant in _hidden:
		if is_instance_valid(node):
			(node as CanvasItem).visible = _hidden[node]
	_hidden.clear()
	for i in _props.size():
		var prop: Variant = _props[i]
		if is_instance_valid(prop):
			(prop as Node2D).scale = Vector2.ONE
			(prop as Node2D).physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
			(prop as Node2D).reset_physics_interpolation()
	_past.queue_free()
	for building: Dictionary in _buildings:
		(building["root"] as Node2D).queue_free()
	for bloom in _blooms:
		bloom.queue_free()
	var linger := create_tween()
	linger.tween_interval(CONFETTI_SECONDS)
	linger.tween_callback(queue_free)


## The town as it stood, around the project: its ground, houses and flat
## decor (MapView's own drawing of the map without it), and the ruin's
## props standing in it.
func _draw_past() -> void:
	var done := Town.done_projects(GameState.settlement)
	done.erase(project_id)
	var before := MapData.load_tiered("town", done, int(GameState.settlement.house.get("tier", 1)))
	var past := MapView.new(before, null)
	past.plan(before.spawn)
	var windows: Array[Rect2i] = []
	for rect in _footprint:
		windows.append(rect.grow(MARGIN))
	_past = past.draw_ground(windows)
	add_child(_past)
	for prop: Dictionary in past.outdoor_props["props"]:
		if _inside(prop["cell"]):
			var piece := _still_prop(prop)
			_past.add_child(piece)
			_rubble.append(piece)
	# What it draws untoned (houses, spans, the rubble) takes the ground's
	# shader at no strength, so all of it can dissolve as one.
	var plain := past.ground_tint.duplicate() as ShaderMaterial
	plain.set_shader_parameter("strength", 0.0)
	_past_materials.append(plain)
	for node: Node in _past.find_children("*", "", true, false):
		var item := node as CanvasItem
		if item == null:
			continue
		if item.material == null:
			item.material = plain
		elif item.material is ShaderMaterial and not _past_materials.has(item.material):
			_past_materials.append(item.material as ShaderMaterial)


## A prop of the town as it stood, still (a torch unlit), on its foot.
func _still_prop(prop: Dictionary) -> Node2D:
	var foot: Rect2 = prop["foot"]
	var sort_y := foot.end.y if foot.has_area() else float(TILE)
	var root := Node2D.new()
	root.position = Vector2(prop["cell"] * TILE) + Vector2(0, sort_y)
	for piece: Array in prop["tiles"]:
		var tile: int = PunyProps.LAMP_UNLIT if not prop["frames"].is_empty() else piece[1]
		var sprite := Sprite2D.new()
		sprite.texture = PunyDungeon.sheet().tile_texture(tile) if prop["sheet"] == "dungeon" else PunyProps.texture(tile)
		sprite.centered = false
		sprite.position = Vector2(piece[0] * TILE) - Vector2(0, sort_y)
		root.add_child(sprite)
	return root


## The new houses' cells, out of the town's layers and into courses that
## can drop into place one by one; each building stands on the middle of
## its footing, where it squashes as it lands.
func _lift_houses() -> void:
	for rect in _footprint:
		var found := {}
		for part: String in ["pieces", "decor"]:
			var layer: TileMapLayer = _view.layers.get(part)
			if layer == null:
				continue
			for cell in _cells(rect):
				if layer.get_cell_source_id(cell) >= 0:
					found[cell] = true
		if found.is_empty():
			continue
		var bottom: int = found.keys().reduce(func(low: int, cell: Vector2i) -> int: return maxi(low, cell.y), rect.position.y)
		var root := Node2D.new()
		root.position = Vector2((rect.position.x + rect.size.x / 2.0) * TILE, (bottom + 1) * TILE)
		add_child(root)
		var rising: Array[Node2D] = []
		for row: Array in courses(found.keys()):
			var course := Node2D.new()
			course.visible = false
			course.set_meta("ends", [MapView.center(row[0]) + Vector2(-6, 6), MapView.center(row[-1]) + Vector2(6, 6)])
			for part: String in ["pieces", "decor"]:
				var layer: TileMapLayer = _view.layers.get(part)
				if layer != null:
					var copy := _lift(layer, row)
					if copy != null:
						copy.position = -root.position
						course.add_child(copy)
			root.add_child(course)
			rising.append(course)
		_buildings.append({"root": root, "courses": rising})


## The flat flowers it plants, each lifted into a node standing on its
## cell's foot, to spring up.
func _lift_flowers() -> void:
	var flowers: TileMapLayer = _view.layers.get("flowers")
	if flowers == null:
		return
	for rect in _footprint:
		for cell in _cells(rect):
			if flowers.get_cell_source_id(cell) < 0:
				continue
			var bloom := Node2D.new()
			bloom.position = Vector2(cell.x * TILE, (cell.y + 1) * TILE)
			bloom.visible = false
			var copy := _lift(flowers, [cell])
			copy.position = -bloom.position
			bloom.add_child(copy)
			add_child(bloom)
			_blooms.append(bloom)


## `cells` of `layer` taken out of it, into a copy of their own (null when
## it holds none of them); finish() puts them back.
func _lift(layer: TileMapLayer, cells: Array) -> TileMapLayer:
	var copy: TileMapLayer = null
	for cell: Vector2i in cells:
		var source := layer.get_cell_source_id(cell)
		if source < 0:
			continue
		if copy == null:
			copy = TileMapLayer.new()
			copy.tile_set = layer.tile_set
			copy.material = layer.material
			copy.rendering_quadrant_size = layer.rendering_quadrant_size
		var coords := layer.get_cell_atlas_coords(cell)
		var alternative := layer.get_cell_alternative_tile(cell)
		copy.set_cell(cell, source, coords, alternative)
		_lifted.append([layer, cell, source, coords, alternative])
		layer.erase_cell(cell)
	return copy


## What else of the new building the town shows waits until it stands:
## its props, its door's sign, its window lights, glows and chimney smoke.
func _hold_back() -> void:
	for cell: Vector2i in _view.prop_nodes:
		var prop: Node2D = _view.prop_nodes[cell]
		if _inside(cell) and is_instance_valid(prop):
			# Sprung up outside the physics ticks the actors are drawn from.
			prop.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			_hide(prop)
			_props.append(prop)
	for door_sign: Dictionary in _view.door_signs:
		if _inside(door_sign["door"]):
			_hide(door_sign["node"])
	for node: Node in _view.props.get_children():
		if node is Node2D and _inside(Vector2i(((node as Node2D).position / TILE).floor())):
			_hide(node as Node2D)


func _hide(node: CanvasItem) -> void:
	if not _hidden.has(node):
		_hidden[node] = node.visible
	node.visible = false


## The ruin gives way: a cloud of dust off it, its rubble sinking, the town
## as it stood dissolving into the town as it stands.
func _give_way() -> void:
	Sound.play("craft")
	var dissolve := func(at: float) -> void:
		for material in _past_materials:
			material.set_shader_parameter("dissolve", at)
	_past.create_tween().tween_method(dissolve, 0.0, 1.0, GIVE_SECONDS)
	for piece in _rubble:
		var sink := piece.create_tween()
		sink.tween_property(piece, "scale:y", 0.05, GIVE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var fx: WorldFx = world.fx
	for rect in _footprint:
		_dust_cloud(rect)
		for x in range(rect.position.x, rect.end.x, 2):
			fx.dust(Vector2(x * TILE + TILE / 2.0, rect.end.y * TILE - 2), true)


## Each course drops into place out of the dust, the lowest first.
func _raise(building: Dictionary) -> void:
	var rising: Array = building["courses"]
	var step := (RISE_SECONDS - COURSE_SECONDS) / maxf(1.0, rising.size() - 1)
	var fx: WorldFx = world.fx
	for i in rising.size():
		var course: Node2D = rising[i]
		course.position.y = -COURSE_DROP
		course.modulate.a = 0.0
		var drop := course.create_tween()
		drop.tween_interval(RISE_FROM + i * step)
		drop.tween_callback(course.show)
		# Whole pixels on the way down, as the art is drawn.
		drop.tween_method(func(y: float) -> void: course.position.y = roundf(y), -COURSE_DROP, 0.0, COURSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drop.parallel().tween_property(course, "modulate:a", 1.0, COURSE_SECONDS * 0.6)
		drop.tween_callback(func() -> void:
			for end: Vector2 in course.get_meta("ends"):
				fx.dust(end, true))


## The props and flowers spring up out of the ground one after another.
func _spring_up() -> void:
	var popping: Array[Node2D] = []
	popping.append_array(_props)
	popping.append_array(_blooms)
	var step := (RISE_SECONDS - POP_SECONDS) / maxf(1.0, popping.size() - 1)
	var fx: WorldFx = world.fx
	for i in popping.size():
		var node := popping[i]
		# The town's own props stand among the actors, held with the world:
		# a tween of theirs would wait for the tour to end. This one runs.
		var pop := create_tween()
		_tweens.append(pop)
		pop.tween_interval(RISE_FROM + i * step)
		pop.tween_callback(func() -> void:
			node.scale = Vector2(1.0, 0.05)
			node.visible = true
			fx.dust(node.position + Vector2(TILE / 2.0, -2), true))
		pop.tween_property(node, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## It stands: squashed on its footing and springing back, confetti over it.
func _land() -> void:
	if phase == "built":
		return
	for building: Dictionary in _buildings:
		var root: Node2D = building["root"]
		root.scale = SQUASH
		root.create_tween().tween_property(root, "scale", Vector2.ONE, SQUASH_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for rect in _footprint:
		_confetti(rect)
	var settle := create_tween()
	settle.tween_interval(SQUASH_SECONDS)
	settle.tween_callback(finish)


## Dust billowing off the ruin as it gives way.
func _dust_cloud(rect: Rect2i) -> void:
	var cloud := CPUParticles2D.new()
	cloud.position = Vector2(rect.position * TILE) + Vector2(rect.size * TILE) / 2.0
	cloud.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	cloud.emission_rect_extents = Vector2(rect.size * TILE) / 2.0
	cloud.amount = clampi(rect.get_area() * 2, 8, 64)
	cloud.lifetime = 1.6
	cloud.one_shot = true
	cloud.explosiveness = 0.7
	cloud.direction = Vector2.UP
	cloud.spread = 35.0
	cloud.gravity = Vector2(0, -4)
	cloud.initial_velocity_min = 6.0
	cloud.initial_velocity_max = 16.0
	cloud.scale_amount_min = 2.0
	cloud.scale_amount_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.86, 0.8, 0.68, 0.85))
	fade.set_color(1, Color(0.7, 0.64, 0.52, 0.0))
	cloud.color_ramp = fade
	cloud.z_index = 6
	add_child(cloud)
	cloud.finished.connect(cloud.queue_free)
	cloud.emitting = true


## A burst of the festival's confetti over what was built.
func _confetti(rect: Rect2i) -> void:
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colors.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
	colors.colors = PackedColorArray(Stage.CONFETTI)
	var confetti := CPUParticles2D.new()
	confetti.position = Vector2((rect.position.x + rect.size.x / 2.0) * TILE, rect.position.y * TILE)
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(rect.size.x * TILE / 2.0, 4)
	confetti.amount = clampi(rect.size.x * 6, 12, 64)
	confetti.lifetime = CONFETTI_SECONDS
	confetti.one_shot = true
	confetti.explosiveness = 0.85
	confetti.direction = Vector2.UP
	confetti.spread = 60.0
	confetti.gravity = Vector2(0, 70)
	confetti.initial_velocity_min = 30.0
	confetti.initial_velocity_max = 60.0
	confetti.damping_min = 10.0
	confetti.damping_max = 20.0
	confetti.scale_amount_min = 1.0
	confetti.scale_amount_max = 2.0
	confetti.color_initial_ramp = colors
	confetti.z_index = 7
	add_child(confetti)
	confetti.emitting = true


func _inside(cell: Vector2i) -> bool:
	return _footprint.any(func(rect: Rect2i) -> bool: return rect.has_point(cell))


func _cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out
