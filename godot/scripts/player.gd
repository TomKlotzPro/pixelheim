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
	hitbox.collision_layer = 0
	hitbox.collision_mask = 4  # mob hurtboxes
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(26, 26)
	hit_shape.shape = hit_rect
	hitbox.add_child(hit_shape)
	hitbox.monitoring = false
	add_child(hitbox)

	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)

func _physics_process(_delta: float) -> void:
	if dead:
		return
	if attacking:
		if not hitbox.monitoring:
			return
		# Swings root the hero; damage lands on any body whose hurtbox the
		# arc reaches during the swing frames.
		for area in hitbox.get_overlapping_areas():
			var body := area.get_parent()
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

## Back to full health where the hero stands (the inn, Iva's hands).
func heal() -> void:
	if dead:
		return
	hp = MAX_HP
	world.on_player_hp_changed(hp)

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

## The blade only bites during the swing frames (3-6 of 8) — wind-up and
## follow-through are safe, matching what the animation shows.
func _on_frame_changed() -> void:
	if attacking:
		hitbox.monitoring = sprite.frame >= 3 and sprite.frame <= 6

func _play(anim: String) -> void:
	var dir := "down"
	if facing == Vector2.UP:
		dir = "up"
	elif facing.x != 0:
		dir = "side"
	# Side sheets face right in the pack (verified frame-by-frame, PIX-121);
	# mirror for leftward facing.
	sprite.flip_h = facing == Vector2.LEFT
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
