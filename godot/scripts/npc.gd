extends AnimatableBody2D
## A villager: their Puny sheet (PunyArt, PIX-130), a body the hero bumps
## into, and — for wanderers — an amble around the pacing loop, walking the
## way they step. Who they are and where they may step comes from Npcs; the
## world only hosts them.

const TILE := 16
## A pace every four beats: villagers amble roughly every 1.6 s.
const BEAT_SECONDS := 0.4
const STEP_SECONDS := 0.35

var world: Node2D
var data: Dictionary
var home := Vector2i.ZERO
## The tile the villager occupies (or is stepping onto).
var cell := Vector2i.ZERO
var offsets: Array[Vector2i] = []
var sprite: AnimatedSprite2D


func _ready() -> void:
	home = Vector2i(data["x"], data["y"])
	offsets = Npcs.offsets_for(data, world.map)
	cell = home + Npcs.pace_offset(data, offsets, _beat())
	position = _center(cell)
	reset_physics_interpolation()

	var art := PunyArt.villager(data["sprite"])
	var size: float = art.get("scale", 1.0)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.scale = Vector2.ONE * size
	sprite.position = Vector2(0, PunyArt.lift(art) * size)
	# Their own face, though they share a sheet with others (PIX-206).
	sprite.self_modulate = Npcs.tint_of(String(data.get("id", "")))
	sprite.play(PunyArt.pick(sprite.sprite_frames, "idle", "down"))
	# Offset the idle phase per villager so the square doesn't breathe in unison.
	sprite.frame = Npcs.id_hash(data["id"]) % 2
	add_child(sprite)

	# The body is the villager's feet and the ground before them, so the hero,
	# whose box is only their feet, stops a step away instead of standing half
	# inside them (from the south the hero's sprite covered the villager's).
	# It ends 6 px into the cell below: the hero, standing there to talk or
	# walking past along that row, clears it by a pixel.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 17)
	shape.shape = rect
	shape.position = Vector2(0, 5.5)
	add_child(shape)
	body = shape


## Home for the night (PIX-149): out of sight and out of the way.
var away := false
var body: CollisionShape2D
## Where they're headed on the square at dusk or on a festival day
## (PIX-159), or NOWHERE.
const NOWHERE := Vector2i(-1, -1)
var gather_at := NOWHERE
var _last_beat := -1


## Gone for the night, or back: back means at home, wherever the evening
## left them.
func set_away(gone: bool) -> void:
	away = gone
	visible = not gone
	body.set_deferred("disabled", gone)
	if not gone:
		gather_at = NOWHERE
		place_at(home + Npcs.pace_offset(data, offsets, _beat()))


## Straight to `at` (only ever where nobody's watching).
func place_at(at: Vector2i) -> void:
	cell = at
	position = _center(cell)
	reset_physics_interpolation()


func _process(_delta: float) -> void:
	if away:
		return
	if gather_at != NOWHERE:
		_walk_to_square()
		return
	if not data["wander"]:
		return
	var next: Vector2i = home + Npcs.pace_offset(data, offsets, _beat())
	# Never step onto the hero; wait for the next pace instead.
	if next == cell or next == world.player_cell:
		return
	_step_to(next)


## A step a beat toward their spot on the square: the longer way first, the
## other if that's blocked; they wait where both are.
func _walk_to_square() -> void:
	var beat := _beat()
	if beat == _last_beat or cell == gather_at:
		return
	_last_beat = beat
	var to := gather_at - cell
	var tries: Array[Vector2i] = []
	if to.x != 0:
		tries.append(Vector2i(signi(to.x), 0))
	if to.y != 0:
		tries.append(Vector2i(0, signi(to.y)))
	if absi(to.y) > absi(to.x):
		tries.reverse()
	for step in tries:
		var next := cell + step
		if world.map.is_walkable(next) and not world.map.covered.has(next) and not world.map.portals.has(next) and next != world.player_cell:
			_step_to(next)
			return


func _step_to(next: Vector2i) -> void:
	var step := next - cell
	cell = next
	var dir := "down" if step.y > 0 else ("up" if step.y < 0 else ("right" if step.x > 0 else "left"))
	sprite.play(PunyArt.pick(sprite.sprite_frames, "walk", dir))
	# Stepped on physics ticks, so the step is interpolated like any walk.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", _center(cell), STEP_SECONDS)
	tween.tween_callback(func() -> void: sprite.play(PunyArt.pick(sprite.sprite_frames, "idle", "down")))


func _beat() -> int:
	return int(Time.get_ticks_msec() / 1000.0 / BEAT_SECONDS)


func _center(at: Vector2i) -> Vector2:
	return Vector2(at * TILE) + Vector2(TILE, TILE) / 2.0
