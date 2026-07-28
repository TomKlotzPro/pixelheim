extends CharacterBody2D
## Pixel Crawler mob (orc or skeleton warrior): wanders its habitat, chases the
## hero on sight, deals contact damage, dies with the pack's death animation.
## Sheets are square-frame strips — frame size equals sheet height.

const WANDER_SPEED := 22.0
const CHASE_SPEED := 55.0
const SIGHT_RADIUS := 96.0
const CONTACT_RADIUS := 13.0
const CONTACT_COOLDOWN := 0.9
const MAX_HP := 3

var world: Node2D
var kind := "orc"
var hp := MAX_HP
var dying := false
var can_bite := true
var wander_dir := Vector2.ZERO
var wander_time := 0.0
var sprite: AnimatedSprite2D
var health_bar: ColorRect
var health_bar_back: ColorRect

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _build_frames()
	# Frames are normalized to 48x48 with feet on the bottom edge; lift so the
	# feet land just below the node's center.
	sprite.offset = Vector2(0, -17)
	sprite.play("idle")
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 8)
	shape.shape = rect
	add_child(shape)

	# Health floats above the head, hidden until the mob is first scratched.
	health_bar_back = ColorRect.new()
	health_bar_back.color = Color(0, 0, 0, 0.6)
	health_bar_back.size = Vector2(14, 2)
	health_bar_back.position = Vector2(-7, -30)
	health_bar_back.visible = false
	add_child(health_bar_back)
	health_bar = ColorRect.new()
	health_bar.color = Color(0.9, 0.25, 0.25)
	health_bar.size = Vector2(14, 2)
	health_bar.position = Vector2(-7, -30)
	health_bar.visible = false
	add_child(health_bar)

func _physics_process(delta: float) -> void:
	if dying:
		return
	var player: CharacterBody2D = world.player
	var to_player := player.global_position - global_position
	if to_player.length() < SIGHT_RADIUS and not player.dead:
		velocity = to_player.normalized() * CHASE_SPEED
		if to_player.length() < CONTACT_RADIUS and can_bite:
			can_bite = false
			player.take_hit(1, global_position)
			get_tree().create_timer(CONTACT_COOLDOWN).timeout.connect(
				func() -> void: can_bite = true
			)
	else:
		wander_time -= delta
		if wander_time <= 0:
			wander_time = randf_range(0.8, 2.0)
			var dirs := [Vector2.ZERO, Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			wander_dir = dirs.pick_random()
		velocity = wander_dir * WANDER_SPEED
	move_and_slide()
	sprite.play("run" if velocity.length() > 1 else "idle")
	# Mob sheets face left in the pack; mirror when heading right.
	if absf(velocity.x) > 0.5:
		sprite.flip_h = velocity.x > 0

func take_hit(damage: int, from: Vector2) -> void:
	if dying:
		return
	hp = maxi(0, hp - damage)
	health_bar.size.x = 14.0 * hp / MAX_HP
	health_bar.visible = true
	health_bar_back.visible = true
	velocity = (global_position - from).normalized() * 220
	move_and_slide()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.4, 0.4), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if hp == 0:
		_die()

func _die() -> void:
	dying = true
	world.on_enemy_died()
	collision_layer = 0
	collision_mask = 0
	health_bar.visible = false
	health_bar_back.visible = false
	sprite.play("death")
	sprite.animation_finished.connect(func() -> void: queue_free())

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_sheet(frames, "idle", "res://assets/crawler/%s_idle.png" % kind, 4.0, true)
	_add_sheet(frames, "run", "res://assets/crawler/%s_run.png" % kind, 10.0, true)
	_add_sheet(frames, "death", "res://assets/crawler/%s_death.png" % kind, 10.0, false)
	return frames

static func _add_sheet(
	frames: SpriteFrames, anim: String, path: String, fps: float, loop: bool
) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	# Sheets use square frames of varying canvas size but all anchor the body
	# feet to the bottom edge. Normalize everything to a 48x48 bottom-anchored
	# frame so animations don't jump when they switch.
	var texture: Texture2D = load(path)
	var frame_size := texture.get_height()
	for i in int(texture.get_width() / float(frame_size)):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		match frame_size:
			32:
				frame.region = Rect2(i * 32, 0, 32, 32)
				frame.margin = Rect2(8, 16, 16, 16)
			48:
				frame.region = Rect2(i * 48, 0, 48, 48)
			_:
				frame.region = Rect2(i * frame_size + 8, frame_size - 48, 48, 48)
		frames.add_frame(anim, frame)
