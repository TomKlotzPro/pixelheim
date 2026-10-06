extends CharacterBody2D
## The action hero, drawn from Shade's Puny sheet for the hero's role
## (PunyArt, PIX-130): idle/walk/hurt/death in four directions, and the role's
## own attack (sword, staff or bow). The attack animation carries the weapon,
## so the hitbox tracks facing while the striking frames play.

const SPEED := 95.0
const ATTACK_COOLDOWN := 0.45
const INVULNERABLE_SECONDS := 0.8
## Frames of each attack where the weapon bites; wind-up and follow-through are safe.
const STRIKE_FRAMES := {"sword": [1, 2], "staff": [1, 2], "bow": [2, 3]}

var world: Node2D
## Mirrors GameState.hero.hp, the web hero's real health (PIX-126).
var hp := 0
var facing := Vector2.DOWN
var attack_ready := true
var attacking := false
var invulnerable := false
var dead := false
var hit_this_swing: Array[Node] = []
var scripted_dir := Vector2.ZERO  # test-harness movement override
var sprite: AnimatedSprite2D
var hitbox: Area2D
## Poison, burn and stun on the hero (web turns run on a 1s clock).
var ailments := Ailments.new()
var ailment_icon: Sprite2D
## PunyArt.hero spec: sheet, attack kind, tint.
var art: Dictionary

func _ready() -> void:
	hp = GameState.hero.hp
	art = PunyArt.hero(GameState.hero.role_id)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.position = Vector2(0, PunyArt.lift(art))
	sprite.self_modulate = art["tint"]
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
	ailment_icon = Sprite2D.new()
	ailment_icon.position = Vector2(0, -22)
	ailment_icon.visible = false
	add_child(ailment_icon)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_tick_ailments(delta)
	if dead:
		return
	if ailments.is_stunned():
		velocity = Vector2.ZERO
		_play("idle")
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
				# The web's swing: scaling stat + weapon, crits, mastery, minus armor.
				body.take_hit(Bestiary.hero_attack_damage(
					GameState.hero, GameState.pack, body.fighter,
					GameState.settlement.bard_song == true, GameState.roll
				), global_position, HeroRules.passives(GameState.hero)["attackInflict"])
		return
	var input := scripted_dir
	if input == Vector2.ZERO:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * SPEED
	move_and_slide()
	if input != Vector2.ZERO:
		face(input)
		_play("walk")
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
	_play(art["attack"])
	get_tree().create_timer(ATTACK_COOLDOWN).timeout.connect(
		func() -> void: attack_ready = true
	)

## A blow lands; `infliction` is the attacker's ailment roll, if it carries one.
func take_hit(damage: int, from: Vector2, infliction: Variant = null) -> void:
	if invulnerable or dead:
		return
	GameState.hurt(damage)
	hp = GameState.hero.hp
	world.float_number(damage, global_position + Vector2(0, -22), Color(1, 0.35, 0.35))
	if hp > 0 and ailments.inflict(infliction, GameState.roll, HeroRules.passives(GameState.hero)):
		world.log_line("You are afflicted by %s!" % infliction["kind"])
		_show_ailment()
	velocity = (global_position - from).normalized() * 180
	move_and_slide()
	if hp == 0:
		_die()
		return
	if not attacking:
		_play("hurt")
	invulnerable = true
	var tween := create_tween().set_loops(4)
	tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	get_tree().create_timer(INVULNERABLE_SECONDS).timeout.connect(
		func() -> void: invulnerable = false
	)

## Back in step with the hero's health after a rest, a healer or a level-up.
func heal() -> void:
	if dead:
		return
	hp = GameState.hero.hp

## Ticks poison/burn into the hero's health and shows what still ails them.
func _tick_ailments(delta: float) -> void:
	for tick in ailments.tick(delta):
		GameState.hurt(tick["damage"])
		hp = GameState.hero.hp
		world.float_number(tick["damage"], global_position + Vector2(0, -22), Color(0.75, 0.5, 1))
		if hp == 0:
			ailments.clear()
			_die()
			break
	_show_ailment()

func _show_ailment() -> void:
	var kinds := ailments.kinds()
	ailment_icon.visible = not kinds.is_empty()
	if ailment_icon.visible:
		ailment_icon.texture = load("res://assets/sprites/effect_%s.png" % kinds[0])

func respawn(at: Vector2) -> void:
	ailments.clear()
	_show_ailment()
	position = at
	hp = GameState.hero.hp
	dead = false
	sprite.modulate = Color.WHITE
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
	elif not dead and sprite.animation.begins_with("hurt"):
		_play("idle")

## The weapon only bites on the striking frames, matching what the sheet shows.
func _on_frame_changed() -> void:
	if attacking:
		var strike: Array = STRIKE_FRAMES.get(art["attack"], [1, 2])
		hitbox.monitoring = sprite.frame >= strike[0] and sprite.frame <= strike[1]

## Shade draws all four directions, so there's no mirroring.
func _play(anim: String) -> void:
	var dir := "down"
	if facing == Vector2.UP:
		dir = "up"
	elif facing == Vector2.RIGHT:
		dir = "right"
	elif facing == Vector2.LEFT:
		dir = "left"
	var name := PunyArt.pick(sprite.sprite_frames, anim, dir)
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)
