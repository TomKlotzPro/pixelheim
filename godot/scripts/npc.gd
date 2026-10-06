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

	var art := PunyArt.villager(data["sprite"])
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.position = Vector2(0, PunyArt.lift(art))
	sprite.play(PunyArt.pick(sprite.sprite_frames, "idle", "down"))
	# Offset the idle phase per villager so the square doesn't breathe in unison.
	sprite.frame = Npcs.id_hash(data["id"]) % 2
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 10)
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)


func _process(_delta: float) -> void:
	if not data["wander"]:
		return
	var next: Vector2i = home + Npcs.pace_offset(data, offsets, _beat())
	# Never step onto the hero; wait for the next pace instead.
	if next == cell or next == world.player_cell:
		return
	var step := next - cell
	cell = next
	var dir := "down" if step.y > 0 else ("up" if step.y < 0 else ("right" if step.x > 0 else "left"))
	sprite.play(PunyArt.pick(sprite.sprite_frames, "walk", dir))
	var tween := create_tween()
	tween.tween_property(self, "position", _center(cell), STEP_SECONDS)
	tween.tween_callback(func() -> void: sprite.play(PunyArt.pick(sprite.sprite_frames, "idle", "down")))


func _beat() -> int:
	return int(Time.get_ticks_msec() / 1000.0 / BEAT_SECONDS)


func _center(at: Vector2i) -> Vector2:
	return Vector2(at * TILE) + Vector2(TILE, TILE) / 2.0
