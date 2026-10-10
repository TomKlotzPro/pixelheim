extends CharacterBody2D
## The action hero, drawn from Shade's Puny sheet for the hero's role
## (PunyArt, PIX-130): idle/walk/hurt/death in four directions, and the attack
## of the weapon in hand (sword, staff or bow, PIX-172; the role's own when
## bare-handed). The attack animation carries the weapon,
## so the hitbox tracks facing while the striking frames play.

const SPEED := 95.0
const ATTACK_COOLDOWN := 0.45
const INVULNERABLE_SECONDS := 0.8
## How far a skill reaches for its target, and how long a cast takes: one
## of the web's battle turns.
const SKILL_RANGE := 88.0
const SKILL_TURN := 1.0
## Out of a fight, a little energy comes back this often (PIX-187).
const REST_TICK := 2.0
## Hue of a skill's flash by the stat it draws on.
const SKILL_COLORS := {
	"strength": Color(1.0, 0.6, 0.25), "intelligence": Color(0.7, 0.5, 1.0), "dexterity": Color(0.45, 0.9, 0.5),
}
## Frames of each attack where the weapon bites; wind-up and follow-through are safe.
const STRIKE_FRAMES := {"sword": [1, 2], "staff": [1, 2], "bow": [2, 3]}

var world: Node2D
## Mirrors GameState.hero.hp, the web hero's real health (PIX-126).
var hp := 0
var facing := Vector2.DOWN
var attack_ready := true
var rest_clock := 0.0
var attacking := false
## A skill's cast: the attack animation plays, the blade stays still.
var casting := false
var skill_ready := true
var regen_clock := 0.0
var invulnerable := false
## The dodge roll (PIX-155): rolling now, and ready to roll again.
var dodging := false
var dodge_ready := true
var dodge_dir := Vector2.ZERO
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
## The rank's glow under the hero's feet (silver, gold, radiant).
var aura: Sprite2D
## The sprite's shape (PIX-226): squashed or stretched for a moment around
## the rank's presence, the feet kept on the ground.
var squash := Vector2.ONE:
	set(value):
		squash = value
		_shape()
var _presence := 1.0
var _spring: Tween
## The walk (PIX-243): its frames step with the ground the hero covers.
var gait: Gait
## How the rank looks on the hero (PIX-244, RankLook.spec): the trim and the
## rim ride on the sprite; the swing's sparks and the trail of light are
## here, made once the rank reaches them.
var look := {}
var sparks: CPUParticles2D
var light_trail: CPUParticles2D

func _ready() -> void:
	# Top-down: no floor, no walls by angle, just slide along what blocks.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = GameState.hero.hp
	art = GameState.upkeep.hero_art()
	aura = Sprite2D.new()
	aura.texture = _glow()
	aura.position = Vector2(0, 5)
	add_child(aura)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.position = Vector2(0, PunyArt.lift(art))
	sprite.self_modulate = art["tint"]
	# A clean white flash when struck (PIX-226).
	sprite.material = Juice.fighter_material()
	add_child(sprite)
	gait = Gait.new(sprite, art)
	_play("idle")
	refresh_rank()
	GameState.inventory_changed.connect(dress)

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

## Puts on what is worn now (PIX-129): a new helmet or armour shows at once,
## mid-step.
func dress() -> void:
	var next := GameState.upkeep.hero_art()
	# The swing follows the weapon even when the look doesn't change (PIX-207:
	# a bow for a staff kept the bow's draw).
	var same_look: bool = next["sheet"] == art["sheet"]
	art = next
	if same_look:
		return
	var playing := sprite.animation
	var at := sprite.frame
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.play(playing if sprite.sprite_frames.has_animation(playing) else PunyArt.pick(sprite.sprite_frames, "idle", "down"))
	sprite.frame = at

func _physics_process(delta: float) -> void:
	if dead:
		if light_trail != null:
			light_trail.emitting = false
		return
	# The rank's trail of light (PIX-244) is shed while the hero walks or rolls.
	if light_trail != null:
		light_trail.emitting = (gait.walking or dodging) and not GameState.settings.reduce_motion
	_tick_ailments(delta)
	if dead:
		return
	_regen(delta)
	if ailments.is_stunned():
		velocity = Vector2.ZERO
		_play("idle")
		return
	if dodging:
		velocity = dodge_dir * float(Bestiary._data()["dodge"]["speed"])
		var rolled_from := global_position
		move_and_slide()
		gait.walk(_dir_name(), (global_position - rolled_from).length(), delta)
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
				# A blow after a priming dodge is a sure crit, once (PIX-190).
				var primed := Time.get_ticks_msec() / 1000.0 < crit_primed_until
				crit_primed_until = 0.0
				# The web's swing: scaling stat + weapon, crits, mastery, through armour (PIX-185).
				var swing := Bestiary.hero_attack(
					GameState.hero, GameState.pack, body.fighter,
					GameState.settlement.bard_song == true, GameState.roll, GameState.holdings.song_crit(), GameState.household.home_buff("crit") + (1.0 if primed else 0.0)
				)
				# A slain boss's edge (PIX-232) sharpens every blow a while.
				var dealt := roundi(swing["damage"] * GameState.spoils.damage_scale())
				body.take_hit(dealt, global_position, HeroRules.passives(GameState.hero)["attackInflict"], swing["crit"])
				_steal_life(dealt)
		return
	var input := scripted_dir
	if input == Vector2.ZERO:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# The pad steers the dock's menu while it's open (PIX-215), not the hero.
		if world.hud.dock != null and world.hud.dock.steering():
			input = Vector2.ZERO
	# Wren's riders taught the hero to travel light (PIX-157): above ground only.
	var pace := SPEED * (1.0 + (GameState.holdings.walk_bonus() if world.map.floor_level == 0 else 0.0))
	pace *= 1.0 + float(HeroRules.passives(GameState.hero)["moveSpeed"])
	velocity = input * pace
	var from := global_position
	move_and_slide()
	if input != Vector2.ZERO:
		# Setting off (PIX-243): the stretch lands with the walk's first
		# frame, the rise off the back foot.
		if not gait.walking:
			_spring_from(Juice.SET_OFF)
		# A diagonal holds the way the hero faces rather than flickering.
		face(Gait.VECTORS[Gait.steer(_dir_name(), input)])
		gait.walk(_dir_name(), (global_position - from).length(), delta)
	elif gait.rest(delta):
		# Settling: the weight comes down onto both feet, unless a landing's
		# spring is still playing out.
		if _spring == null or not _spring.is_running():
			_spring_from(Juice.SETTLE)
		_play("idle")
	elif not gait.walking:
		_play("idle")

## The swing and the skills answer key events, so a key that closed a
## conversation (Space) never swings the sword behind it.
func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		if not ailments.is_stunned():
			attack()
		return
	if event.is_action_pressed("dodge"):
		get_viewport().set_input_as_handled()
		dodge()
		return
	for index in Controls.SKILL_KEYS.size():
		if event.is_action_pressed("skill_%d" % (index + 1)):
			get_viewport().set_input_as_handled()
			cast(index)
			return

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
	_spring_from(Juice.SWING)
	_play(art["attack"])
	Sound.play_ui("swing")
	get_tree().create_timer(ATTACK_COOLDOWN).timeout.connect(
		func() -> void: attack_ready = true
	)

## A quick roll the way the hero is heading (or facing): a burst of speed and
## a moment nothing can touch them (PIX-155), then a cooldown.
func dodge() -> void:
	if not dodge_ready or dodging or attacking or dead or ailments.is_stunned():
		return
	var rules: Dictionary = Bestiary._data()["dodge"]
	var heading := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if scripted_dir != Vector2.ZERO:
		heading = scripted_dir
	dodge_dir = heading.normalized() if heading != Vector2.ZERO else facing
	face(dodge_dir)
	dodging = true
	dodge_ready = false
	Sound.play("dodge")
	# A blur: the hero half-seen, a puff of dust where they left from.
	var blur := sprite.create_tween()
	blur.tween_property(sprite, "modulate:a", 0.45, 0.05)
	blur.tween_interval(float(rules["seconds"]))
	blur.tween_property(sprite, "modulate:a", 1.0, 0.08)
	world.fx.dust(global_position)
	get_tree().create_timer(float(rules["seconds"])).timeout.connect(func() -> void:
		dodging = false
		_spring_from(Juice.LAND)
	)
	_dodge_iframes = true
	get_tree().create_timer(float(rules["iframes"])).timeout.connect(func() -> void: _dodge_iframes = false)
	# Passives ready the next roll sooner, and some make it the setup for a crit (PIX-190).
	var passives := HeroRules.passives(GameState.hero)
	if passives["dodgeCrit"]:
		crit_primed_until = Time.get_ticks_msec() / 1000.0 + PRIMED_SECONDS
	var cooldown := float(rules["cooldown"]) * (1.0 - float(passives["dodgeCooldown"]))
	get_tree().create_timer(cooldown).timeout.connect(func() -> void: dodge_ready = true)


var _dodge_iframes := false
## A dodge that primes the next blow to crit (PIX-190's dodgeCrit): until when.
var crit_primed_until := 0.0
const PRIMED_SECONDS := 2.0


## A blow lands; `infliction` is the attacker's ailment roll, if it carries one.
func take_hit(damage: int, from: Vector2, infliction: Variant = null) -> void:
	if invulnerable or dead:
		return
	if _dodge_iframes:
		world.fx.float_text(Text.t("dodged"), global_position + Vector2(0, -22), Color(0.75, 0.9, 1.0))
		return
	GameState.upkeep.hurt(damage)
	hp = GameState.hero.hp
	Juice.flash(sprite)
	world.fx.float_number(damage, global_position + Vector2(0, -22), Color(1, 0.35, 0.35))
	world.camera_rig.shake(3.0, 0.2)
	world.camera_rig.hit_stop(0.05)
	if hp > 0 and ailments.inflict(infliction, GameState.roll, HeroRules.passives(GameState.hero)):
		Sound.play_ui("ail")
		world.messages.log_line(Text.t("You are afflicted by %s!") % Ailments.label(infliction["kind"]))
		_show_ailment()
	velocity = (global_position - from).normalized() * 180
	move_and_slide()
	if hp == 0:
		_die()
		return
	# Struck mid-stride, the stride carries on (the walk took the sprite back
	# the next tick anyway): halting it would set the hero off afresh.
	if not attacking and not gait.walking:
		_play("hurt")
	invulnerable = true
	var tween := create_tween().set_loops(4)
	tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	get_tree().create_timer(INVULNERABLE_SECONDS).timeout.connect(
		func() -> void: invulnerable = false
	)

## Rank shows (worldActors): an aura under the ascended and a touch more
## presence, from the hero's level, and since PIX-244 the rank's own look
## (RankLook): the trim and the rim of light on the sprite, sparks off the
## swing, a trail of light behind the steps.
func refresh_rank() -> void:
	var level := GameState.hero.level
	_presence = Ranks.presence(level)
	_shape()
	var glow: Variant = Ranks.aura(level)
	aura.visible = glow != null
	if glow != null:
		aura.modulate = Color(glow, 0.4)
	look = RankLook.of_hero(GameState.hero)
	RankLook.wear(sprite, look)
	sparks = _rank_emitter(sparks, look["weapon"], func(color: Color) -> CPUParticles2D: return RankLook.sparks(color))
	light_trail = _rank_emitter(light_trail, look["trail"], func(color: Color) -> CPUParticles2D: return RankLook.trail(color))
	# Both behind the aura and the sprite: they never cross the figure.
	for emitter: CPUParticles2D in [sparks, light_trail]:
		if emitter != null:
			move_child(emitter, 0)


## The rank's emitter `node` in `color`, made with `make` the first time;
## gone (null) once the rank no longer reaches it.
func _rank_emitter(node: CPUParticles2D, color: Color, make: Callable) -> CPUParticles2D:
	if color.a == 0.0:
		if node != null:
			node.queue_free()
		return null
	if node == null:
		node = make.call(color)
		add_child(node)
	return node


## A soft oval of light, wider than tall, to sit under the feet.
static func _glow() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 35
	texture.height = 22
	return texture


## A skill by its place in the hero's list (getHeroSkills): its price paid,
## then a heal on the hero or a strike on the nearest foe in reach, through
## the web's formulas; ailments and cleansing as the skill says.
func cast(index: int) -> void:
	if dead or attacking or not skill_ready or ailments.is_stunned():
		return
	# The skill on that key of the dock (PIX-190), not the Nth one known.
	var skills := Skills.docked(GameState.hero)
	if index >= skills.size() or skills[index].is_empty():
		world.messages.flash("No skill on that key yet. Learn more, or set the keys, in Skills.")
		Sound.play_ui("deny")
		return
	var skill: Dictionary = skills[index]
	var block := Skills.cast_block(GameState.hero, skill)
	if block != "":
		world.messages.flash(block)
		Sound.play_ui("deny")
		return
	var target: Node = null
	if skill["kind"] == "damage":
		target = _nearest_foe()
		if target == null:
			world.messages.flash(Text.t("No foe in reach for %s.") % skill["name"])
			Sound.play_ui("deny")
			return
		face(target.global_position - global_position)
	GameState.training.pay_for_skill(skill)
	skill_ready = false
	get_tree().create_timer(SKILL_TURN).timeout.connect(func() -> void: skill_ready = true)
	attacking = true
	casting = true
	velocity = Vector2.ZERO
	_play(art["attack"])
	Sound.play_ui("cast")
	var color: Color = SKILL_COLORS.get(skill["stat"], Color.WHITE)
	if skill["kind"] == "heal":
		var restored := GameState.upkeep.heal_hero(Skills.heal_power(GameState.hero, GameState.pack, skill))
		if skill.get("cleanse", false) and not ailments.kinds().is_empty():
			ailments.clear()
			_show_ailment()
			world.messages.log_line("All ailments are purged!")
		world.fx.skill_flash(global_position, Color(0.5, 1.0, 0.6))
		world.fx.float_number(restored, global_position + Vector2(0, -22), Color(0.5, 1, 0.6))
		world.messages.log_line(Text.t("%s restores %d HP.") % [skill["name"], restored])
		return
	# An area skill (PIX-190) strikes every foe in reach, not just the nearest.
	var targets: Array = _foes_in_reach() if skill.get("area", false) else [target]
	var dealt := 0
	for foe: Node in targets:
		# A warded depth dulls skills (PIX-216).
		var damage := roundi(Bestiary.hero_skill_damage(GameState.hero, GameState.pack, skill, foe.fighter, GameState.roll) * world.delve.skill_ward() * GameState.spoils.damage_scale())
		world.fx.skill_flash(foe.global_position, color)
		foe.take_hit(damage, global_position, skill.get("inflicts"))
		dealt += damage
	if targets.size() > 1:
		world.messages.log_line(Text.t("%s hits %d foes for %d damage!") % [skill["name"], targets.size(), dealt])
	else:
		world.messages.log_line(Text.t("%s hits %s for %d damage!") % [skill["name"], target.fighter["name"], dealt])
	# A draining skill gives back a share of what it took (Drain Life).
	var drained := roundi(dealt * float(skill.get("drain", 0.0)))
	if drained > 0:
		var restored := GameState.upkeep.heal_hero(drained)
		world.fx.float_number(restored, global_position + Vector2(0, -22), Color(0.5, 1, 0.6))
	_steal_life(dealt)


## Some passives heal the hero a share of the damage they deal (PIX-190).
func _steal_life(damage: int) -> void:
	var share := float(HeroRules.passives(GameState.hero)["lifeSteal"])
	if share <= 0 or damage <= 0:
		return
	var restored := GameState.upkeep.heal_hero(maxi(1, roundi(damage * share)))
	if restored > 0:
		world.fx.float_number(restored, global_position + Vector2(0, -22), Color(0.5, 1, 0.6))


## Every living foe within a skill's reach.
func _foes_in_reach() -> Array:
	return get_tree().get_nodes_in_group("mobs").filter(func(enemy: Node) -> bool:
		return not enemy.dying and (enemy.global_position - global_position).length() <= SKILL_RANGE)


## The closest living foe within reach, those ahead of the hero first.
func _nearest_foe() -> Node:
	var best: Node = null
	var best_score := INF
	for enemy in get_tree().get_nodes_in_group("mobs"):
		if enemy.dying:
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() > SKILL_RANGE:
			continue
		var score := offset.length() - (12.0 if offset.normalized().dot(facing) > 0.5 else 0.0)
		if score < best_score:
			best_score = score
			best = enemy
	return best


## Stamina comes back a turn's worth each second while a fight is on; out of
## one, every hero's mana or stamina trickles back (PIX-187), so a caster
## isn't left swinging a staff at crabs.
func _regen(delta: float) -> void:
	if not world.foes.in_fight():
		regen_clock = 0.0
		rest_clock += delta
		while rest_clock >= REST_TICK:
			rest_clock -= REST_TICK
			GameState.upkeep.regen_resting()
		return
	rest_clock = 0.0
	regen_clock += delta
	while regen_clock >= SKILL_TURN:
		regen_clock -= SKILL_TURN
		GameState.upkeep.regen_stamina()


## Back in step with the hero's health after a rest, a healer or a level-up.
func heal() -> void:
	if dead:
		return
	hp = GameState.hero.hp
	refresh_rank()

## Ticks poison/burn into the hero's health and shows what still ails them.
func _tick_ailments(delta: float) -> void:
	for tick in ailments.tick(delta):
		GameState.upkeep.hurt(tick["damage"])
		hp = GameState.hero.hp
		world.fx.float_number(tick["damage"], global_position + Vector2(0, -22), Color(0.75, 0.5, 1))
		if hp == 0:
			ailments.clear()
			_die()
			break
	_show_ailment()

func _show_ailment() -> void:
	var kinds := ailments.kinds()
	ailment_icon.visible = not kinds.is_empty()
	if ailment_icon.visible:
		ailment_icon.texture = ItemIcons.ailment(kinds[0])

func respawn(at: Vector2) -> void:
	ailments.clear()
	_show_ailment()
	position = at
	reset_physics_interpolation()
	hp = GameState.hero.hp
	dead = false
	sprite.modulate = Color.WHITE
	facing = Vector2.DOWN
	_play("idle")

func _die() -> void:
	dead = true
	Sound.play("defeat")
	attacking = false
	hitbox.monitoring = false
	_play("death")
	world.on_player_died()

func _on_animation_finished() -> void:
	if attacking:
		attacking = false
		casting = false
		hitbox.monitoring = false
		_play("idle")
	elif not dead and sprite.animation.begins_with("hurt"):
		_play("idle")

## The weapon only bites on the striking frames, matching what the sheet
## shows; a blade or a staff leaves its arc on the first (PIX-226), and from
## rank IV every blow and cast flares there (PIX-244).
func _on_frame_changed() -> void:
	if not attacking:
		return
	var strike: Array = STRIKE_FRAMES.get(art["attack"], [1, 2])
	if sprite.frame == strike[0]:
		_weapon_glow()
	if casting:
		return
	hitbox.monitoring = sprite.frame >= strike[0] and sprite.frame <= strike[1]
	if sprite.frame == strike[0] and art["attack"] != "bow":
		_slash()


## The swing's arc, a breath long, in the weapon's colour.
func _slash() -> void:
	var trail := Sprite2D.new()
	trail.texture = Juice.arc()
	trail.material = Lights.glow()
	var weapon := GameState.pack.gear_by_uid(String(GameState.pack.equipped.get("weapon", "")))
	trail.modulate = Juice.slash_color(art["attack"], String(weapon.get("rarity", "")))
	trail.rotation = Juice.arc_turn(facing)
	trail.position = facing * Juice.SLASH_REACH + Vector2(0, -6)
	trail.z_index = Juice.SLASH_Z
	add_child(trail)
	var fade := trail.create_tween()
	# A glowing weapon's arc lingers (PIX-244).
	var lingers := RankLook.LINGER if look.get("weapon", RankLook.NONE).a > 0.0 else 1.0
	fade.tween_property(trail, "modulate:a", 0.0, Juice.SLASH_SECONDS * lingers)
	fade.tween_callback(trail.queue_free)


## The rank's weapon glow (PIX-244, RankLook, rank IV): the blow flares in
## the class's light at the weapon, sparks of it fly (not with reduced
## motion), and at night it lights the ground round the blow a moment.
func _weapon_glow() -> void:
	var color: Color = look.get("weapon", RankLook.NONE)
	if color.a == 0.0:
		return
	var at := facing * Juice.SLASH_REACH + Vector2(0, -6)
	var flare := Sprite2D.new()
	flare.texture = RankLook.flare()
	flare.material = Lights.glow()
	flare.modulate = color
	flare.position = at
	flare.z_index = Juice.SLASH_Z
	add_child(flare)
	var fade := flare.create_tween()
	fade.tween_property(flare, "modulate:a", 0.0, RankLook.FLARE_SECONDS).set_ease(Tween.EASE_IN)
	fade.tween_callback(flare.queue_free)
	var light := Lights.make(at, RankLook.FLARE_REACH, color, RankLook.FLARE_ENERGY)
	add_child(light)
	light.create_tween().tween_interval(RankLook.FLARE_SECONDS).finished.connect(light.queue_free)
	if sparks != null and not GameState.settings.reduce_motion:
		sparks.position = at
		sparks.restart()


## Squashes or stretches the hero to `shape` and springs back; not with
## reduced motion.
func _spring_from(shape: Vector2) -> void:
	if GameState.settings.reduce_motion:
		return
	if _spring != null:
		_spring.kill()
	squash = shape
	# On physics ticks, with the walk's frames (PIX-243) and the interpolated
	# body (PIX-135).
	_spring = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_spring.tween_property(self, "squash", Vector2.ONE, Juice.SPRING_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The sprite at the rank's presence times the squash, its feet where they
## stand at rest whatever the rank (PIX-243: the presence used to grow the
## hero from the middle, the feet sinking below the ground).
func _shape() -> void:
	if sprite == null:
		return
	sprite.scale = Vector2.ONE * _presence * squash
	sprite.position.y = PunyArt.lift(art) + Juice.FEET * (1.0 - _presence * squash.y)


## The way the hero faces, by name.
func _dir_name() -> String:
	return Gait.dir_of(facing)


## Shade draws all four directions, so there's no mirroring. The walk is the
## gait's (PIX-243); anything else played takes the hero out of it.
func _play(anim: String) -> void:
	gait.halt()
	var name := PunyArt.pick(sprite.sprite_frames, anim, _dir_name())
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)
