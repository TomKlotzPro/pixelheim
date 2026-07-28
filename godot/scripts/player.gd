extends CharacterBody2D
## Action hero using Pixel Crawler Body_A sheets: idle/run/slice/hit/death in
## three directions (side flips for left). The slice animation carries its own
## weapon, so the hitbox simply tracks facing while the swing frames play.
## Frames are 64x64 with feet anchored at y=48.

const SPEED := 95.0
const MAX_HP := 6
const ATTACK_COOLDOWN := 0.45
const INVULNERABLE_SECONDS := 0.8

## anim -> [fps, loops]
const ANIMS := {
	"idle": [5.0, true], "run": [10.0, true], "slice": [20.0, false],
	"hit": [12.0, false], "death": [10.0, false],
}

var world: Node2D
var hp := MAX_HP
var facing := Vector2.DOWN
var attack_ready := true
var attacking := false
var invulnerable := false
var dead := false
var hit_this_swing: Array[Node] = []
var scripted_dir := Vector2.ZERO  # test-harness movement override
var sprite: AnimatedSprite2D
var hitbox: Area2D

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _build_frames()
	sprite.offset = Vector2(0, -11)
	add_child(sprite)
	_play("idle")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 8)
	shape.shape = rect
	shape.position = Vector2(0, 3)
	add_child(shape)

	hitbox = Area2D.new()
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(22, 20)
	hit_shape.shape = hit_rect
	hitbox.add_child(hit_shape)
	hitbox.monitoring = false
	add_child(hitbox)

	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta: float) -> void:
	if dead:
		return
	if attacking:
		# Swings root the hero; damage lands on whatever the arc reaches.
		for body in hitbox.get_overlapping_bodies():
			if body.has_method("take_hit") and body not in hit_this_swing:
				hit_this_swing.append(body)
				body.take_hit(1, global_position)
		return
	var input := scripted_dir
	if input == Vector2.ZERO:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * SPEED
	move_and_slide()
	if input != Vector2.ZERO:
		face(input)
		_play("run")
	else:
		_play("idle")
	if Input.is_action_just_pressed("attack"):
		attack()

func face(direction: Vector2) -> void:
	if absf(direction.x) >= absf(direction.y):
		facing = Vector2.RIGHT if direction.x >= 0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if direction.y >= 0 else Vector2.UP

func attack() -> void:
	if not attack_ready or attacking or dead:
		return
	attack_ready = false
	attacking = true
	hit_this_swing = []
	velocity = Vector2.ZERO
	hitbox.position = facing * 16
	hitbox.monitoring = true
	_play("slice")
	get_tree().create_timer(ATTACK_COOLDOWN).timeout.connect(
		func() -> void: attack_ready = true
	)

func take_hit(damage: int, from: Vector2) -> void:
	if invulnerable or dead:
		return
	hp = maxi(0, hp - damage)
	world.on_player_hp_changed(hp)
	velocity = (global_position - from).normalized() * 180
	move_and_slide()
	if hp == 0:
		_die()
		return
	if not attacking:
		_play("hit")
	invulnerable = true
	var tween := create_tween().set_loops(4)
	tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	get_tree().create_timer(INVULNERABLE_SECONDS).timeout.connect(
		func() -> void: invulnerable = false
	)

func respawn(at: Vector2) -> void:
	position = at
	hp = MAX_HP
	dead = false
	sprite.modulate = Color.WHITE
	world.on_player_hp_changed(hp)
	facing = Vector2.DOWN
	_play("idle")

func _die() -> void:
	dead = true
	attacking = false
	hitbox.monitoring = false
	_play("death")
	world.on_player_died()

func _on_animation_finished() -> void:
	if attacking:
		attacking = false
		hitbox.monitoring = false
		_play("idle")
	elif not dead and sprite.animation.begins_with("hit"):
		_play("idle")

func _play(anim: String) -> void:
	var dir := "down"
	if facing == Vector2.UP:
		dir = "up"
	elif facing.x != 0:
		dir = "side"
	# Side sheets face left in the pack; mirror for rightward facing.
	sprite.flip_h = facing == Vector2.RIGHT
	sprite.play("%s_%s" % [anim, dir])

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in ANIMS:
		for dir in ["down", "side", "up"]:
			var name := "%s_%s" % [anim, dir]
			SheetFrames.add_strip(
				frames, name, "res://assets/crawler/hero_%s.png" % name,
				ANIMS[anim][0], ANIMS[anim][1], 64
			)
	return frames
