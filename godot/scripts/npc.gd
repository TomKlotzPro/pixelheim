extends AnimatableBody2D
## A villager: the generated two-beat idle sheet, a body the hero bumps into,
## and — for wanderers — an amble around the pacing loop. Who they are and
## where they may step comes from Npcs; the world only hosts them.

const TILE := 16
## A pace every four beats: villagers amble roughly every 1.6 s.
const BEAT_SECONDS := 0.4
const STEP_SECONDS := 0.35
## Generated villagers are 16px; drawn at 2x they stand as tall as the Pixel
## Crawler hero (an art-direction call, see PIX-123).
const DRAW_SCALE := 2.0

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

	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SheetFrames.add_strip(frames, "idle", "res://assets/sprites/%s_idle.png" % data["sprite"], 2.0, true)
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * DRAW_SCALE
	# Feet on the bottom of the tile, like every other actor.
	sprite.position = Vector2(0, TILE / 2.0 - TILE / 2.0 * DRAW_SCALE)
	sprite.play("idle")
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
	cell = next
	var tween := create_tween()
	tween.tween_property(self, "position", _center(cell), STEP_SECONDS)


func _beat() -> int:
	return int(Time.get_ticks_msec() / 1000.0 / BEAT_SECONDS)


func _center(at: Vector2i) -> Vector2:
	return Vector2(at * TILE) + Vector2(TILE, TILE) / 2.0
