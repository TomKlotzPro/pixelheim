extends CharacterBody2D
## A monster in the field: wanders near its spawn, chases the hero on sight,
## bites on contact. Its numbers are the web bestiary's (`fighter` from
## Bestiary.spawn): hits land through Bestiary's damage formulas, and its
## death pays out through GameState.defeat_monster (via the world). It wears
## the Puny sheet PunyArt assigns its species, walking the way it moves.

const WANDER_SPEED := 22.0
const CHASE_SPEED := 55.0
const SIGHT_RADIUS := 96.0
const CONTACT_RADIUS := 13.0
const CONTACT_COOLDOWN := 0.9
const ELITE_TINT := Color(1.0, 0.82, 0.7)

var world: Node2D
## Bestiary.spawn record: id, name, elite, hp, maxHp, attack, defense, xp, gold.
var fighter: Dictionary
## Encounter region (forage material, drop floor) and the spawn it guards.
var region := ""
var spawn_id := ""
var dying := false
var can_bite := true
var wander_dir := Vector2.ZERO
var wander_time := 0.0
var sprite: AnimatedSprite2D
var hurtbox: Area2D
var health_bar: ColorRect
var health_bar_back: ColorRect
## Poison, burn and stun from the hero's afflicting passives.
var ailments := Ailments.new()
## PunyArt.monster spec, and the way it last faced.
var art: Dictionary
var facing := "down"
## True while it has the hero in sight; the first sighting is heard (bump).
var hunting := false


func _ready() -> void:
	# Placed before entering the tree: start interpolating from here.
	reset_physics_interpolation()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	art = PunyArt.monster(fighter["id"])
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	var size: float = art.get("scale", 1.0) * (1.2 if fighter["elite"] else 1.0)
	var tint: Color = art.get("tint", Color.WHITE)
	sprite.self_modulate = tint * ELITE_TINT if fighter["elite"] else tint
	sprite.scale = Vector2.ONE * size
	sprite.position = Vector2(0, PunyArt.lift(art) * size)
	_play("idle")
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 8)
	shape.shape = rect
	add_child(shape)

	# Movement collides at the feet; swings land anywhere on the visible body.
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Vector2(16, 24) * (1.2 if fighter["elite"] else 1.0)
	hurt_shape.shape = hurt_rect
	hurt_shape.position = Vector2(0, -8)
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	# Health floats above the head, hidden until first scratched; elites in gold.
	health_bar_back = ColorRect.new()
	health_bar_back.color = Color(0, 0, 0, 0.6)
	health_bar_back.size = Vector2(16, 2)
	health_bar_back.position = Vector2(-8, -20 * size)
	health_bar_back.visible = false
	add_child(health_bar_back)
	health_bar = ColorRect.new()
	health_bar.color = Color(1, 0.8, 0.3) if fighter["elite"] else Color(0.9, 0.25, 0.25)
	health_bar.size = Vector2(16, 2)
	health_bar.position = Vector2(-8, -20 * size)
	health_bar.visible = false
	add_child(health_bar)


func _physics_process(delta: float) -> void:
	if dying:
		return
	for tick in ailments.tick(delta):
		_lose(tick["damage"], Color(0.75, 0.5, 1))
		if dying:
			return
	if ailments.is_stunned():
		_play("idle")
		return
	var player: CharacterBody2D = world.player
	var to_player := player.global_position - global_position
	if to_player.length() < SIGHT_RADIUS and not player.dead:
		if not hunting:
			hunting = true
			world.on_enemy_noticed(self)
		velocity = to_player.normalized() * CHASE_SPEED
		if to_player.length() < CONTACT_RADIUS and can_bite:
			can_bite = false
			_play("attack" if sprite.sprite_frames.has_animation("attack_" + facing) else "sword")
			player.take_hit(
				Bestiary.monster_attack_damage(fighter, GameState.hero, GameState.pack, GameState.roll),
				global_position, fighter.get("inflicts")
			)
			get_tree().create_timer(CONTACT_COOLDOWN).timeout.connect(
				func() -> void: can_bite = true
			)
	else:
		hunting = false
		wander_time -= delta
		if wander_time <= 0:
			wander_time = randf_range(0.8, 2.0)
			var dirs := [Vector2.ZERO, Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			wander_dir = dirs.pick_random()
		velocity = wander_dir * WANDER_SPEED
	move_and_slide()
	if velocity.length() > 1:
		facing = _dir_of(velocity)
	# Let a bite or a hurt finish before walking resumes.
	if sprite.is_playing() and not sprite.sprite_frames.get_animation_loop(sprite.animation):
		return
	_play("walk" if velocity.length() > 1 else "idle")


## A landed swing: `damage` is already Bestiary.hero_attack_damage's verdict;
## `infliction` is the hero's afflicting passive, if any.
func take_hit(damage: int, from: Vector2, infliction: Variant = null) -> void:
	if dying:
		return
	Sound.play("hit")
	velocity = (global_position - from).normalized() * 220
	move_and_slide()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.4, 0.4), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	_lose(damage, Color(1, 0.95, 0.85))
	if not dying and ailments.inflict(infliction, GameState.roll):
		world.log_line("%s is afflicted by %s!" % [fighter["name"], infliction["kind"]])


func _lose(damage: int, color: Color) -> void:
	fighter["hp"] = maxi(0, int(fighter["hp"]) - damage)
	world.float_number(damage, global_position + Vector2(0, -18), color)
	health_bar.size.x = 16.0 * fighter["hp"] / fighter["maxHp"]
	health_bar.visible = true
	health_bar_back.visible = true
	if fighter["hp"] == 0:
		_die()


func _die() -> void:
	dying = true
	world.on_enemy_died(self)
	collision_layer = 0
	collision_mask = 0
	hurtbox.collision_layer = 0
	health_bar.visible = false
	health_bar_back.visible = false
	var death := "death_" + facing
	if sprite.sprite_frames.has_animation(death):
		sprite.play(death)
		sprite.animation_finished.connect(func() -> void: queue_free())
	else:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)


func _play(anim: String) -> void:
	var name := PunyArt.pick(sprite.sprite_frames, anim, facing)
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)


static func _dir_of(motion: Vector2) -> String:
	if absf(motion.x) >= absf(motion.y):
		return "right" if motion.x >= 0 else "left"
	return "down" if motion.y >= 0 else "up"
