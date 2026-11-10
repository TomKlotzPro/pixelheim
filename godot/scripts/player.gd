extends CharacterBody2D
## areas: combat town title
## The action hero, drawn from Shade's Puny sheet for the hero's role
## (PunyArt, PIX-130): idle/walk/hurt/death in four directions, and the attack
## of the weapon in hand (sword, staff or bow, PIX-172; the role's own when
## bare-handed). The attack animation carries the weapon; while its
## striking frames play the blow lands on whoever its reach finds the way the
## hero faces (Reach, PIX-410: a blade up close, a bow's arrow and a staff's
## bolt from afar).

const SPEED := 95.0
## The body that meets walls: a cell wide, less a few pixels.
const BODY := Vector2(10, 8)
const ATTACK_COOLDOWN := 0.45
## How long a hit hero can't be hit again (PIX-377: 0.8 s let a pack take
## turns at a hero who hardly felt the second bite).
const INVULNERABLE_SECONDS := 0.5
## How long a cast takes: one of the web's battle turns (how far it reaches
## is its kind's, Reach.skill).
const SKILL_TURN := 1.0
## Out of a fight, a little energy comes back this often (PIX-187).
const REST_TICK := 2.0
## Hue of a skill's flash by the stat it draws on.
const SKILL_COLORS := {
	"strength": Color(1.0, 0.6, 0.25), "intelligence": Color(0.7, 0.5, 1.0), "dexterity": Color(0.45, 0.9, 0.5),
}
## Frames of each attack where the weapon bites; wind-up and follow-through are safe.
const STRIKE_FRAMES := {"sword": [1, 2], "staff": [1, 2], "bow": [2, 3]}
## How long a roll, swing or skill pressed while the hero can't act yet stays
## waiting for them (PIX-439); only the last press does.
const PRESS_KEPT_SECONDS := 0.15

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
## The last cast refused, said on the plate until a cast goes (PIX-444).
var refused := ""
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
## The swing's striking frames are playing: its blow lands on what it reaches.
var striking := false
## Poison, burn and stun on the hero (web turns run on a 1s clock).
var ailments := Ailments.new()
var ailment_icon: Sprite2D
## PunyArt.hero spec: sheet, attack kind, tint.
var art: Dictionary
## The sprite's shape (PIX-226): squashed or stretched for a moment, the
## feet kept on the ground. The hero is the same size at every rank: a rank
## shows only in the ascension and the title (Tom found PIX-244's aura ugly
## and the ranked hero too big; gear is what shows).
var squash := Vector2.ONE:
	set(value):
		squash = value
		_shape()
var _spring: Tween
## The walk (PIX-243): its frames step with the ground the hero covers.
var gait: Gait
## On the ground under their feet (PIX-441): stays there through the squash.
var _shadow: Sprite2D

func _ready() -> void:
	# Top-down: no floor, no walls by angle, just slide along what blocks.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = GameState.hero.hp
	# Stuns can't be chained on the hero either (PIX-377, as on bosses: PIX-186).
	ailments.stun_guard = float(Bestiary.stun_guard()["hero"])
	art = GameState.upkeep.hero_art()
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.position = Vector2(0, PunyArt.lift(art))
	sprite.self_modulate = art["tint"]
	# A clean white flash when struck (PIX-226).
	sprite.material = Juice.fighter_material()
	add_child(sprite)
	gait = Gait.new(sprite, art)
	_play("idle")
	_lay_shadow()
	GameState.inventory_changed.connect(dress)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY
	shape.shape = rect
	shape.position = Vector2(0, 3)
	add_child(shape)

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
	_lay_shadow()


## The shadow for the sheet worn now, under the sprite.
func _lay_shadow() -> void:
	if _shadow != null:
		_shadow.free()
	_shadow = preload("res://scripts/enemy.gd").ground_shadow(sprite, 1.0, PunyArt.lift(art))
	_shadow.visible = not dead
	add_child(_shadow)
	move_child(_shadow, sprite.get_index())

func _physics_process(delta: float) -> void:
	if dead:
		return
	_tick_ailments(delta)
	if dead:
		return
	_regen(delta)
	if _held_by_stun():
		return
	# Before the blow's check, so a roll that cuts a swing has already ended it.
	_fire_kept()
	if dodging:
		velocity = dodge_dir * float(Bestiary.dodge_rules()["speed"])
		var rolled_from := global_position
		move_and_slide()
		gait.walk(gait.drawn_way(dodge_dir, _dir_name()), (global_position - rolled_from).length(), delta)
		return
	if attacking:
		if not striking:
			return
		# Swings root the hero; damage lands on every foe the swing reaches
		# during its striking frames (a shot's on the one it flew to, once).
		if Reach.swing(art["attack"]).get("shot", false) and not hit_this_swing.is_empty():
			return
		for body: Node in _struck():
			if body not in hit_this_swing:
				hit_this_swing.append(body)
				# A blow after a priming dodge is a sure crit, once (PIX-190).
				var primed := GameClock.seconds() < crit_primed_until
				crit_primed_until = 0.0
				# The web's swing: scaling stat + weapon, crits, mastery, through armour (PIX-185).
				var swing := Bestiary.hero_attack(
					GameState.hero, GameState.pack, body.fighter,
					GameState.settlement.bard_song == true, GameState.roll, GameState.holdings.song_crit(), GameState.household.home_buff("crit") + (1.0 if primed else 0.0)
				)
				# A slain boss's edge (PIX-232) sharpens every blow a while.
				var dealt := roundi(swing["damage"] * GameState.spoils.damage_scale())
				body.take_hit(dealt, global_position, HeroRules.passives(GameState.hero)["attackInflict"], swing["crit"], Sound.blow_for(GameState.pack.worn_items().get("weapon", "")))
				_steal_life(dealt)
		return
	var input := scripted_dir
	if input == Vector2.ZERO:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# The pad steers the dock's menu while it's open (PIX-215), not the hero.
		if world.hud.dock != null and world.hud.dock.steering():
			input = Vector2.ZERO
	# Wren's riders taught the hero to travel light (PIX-157).
	var pace := SPEED * (1.0 + GameState.holdings.walk_bonus())
	pace *= 1.0 + float(HeroRules.passives(GameState.hero)["moveSpeed"])
	velocity = input * pace
	var from := global_position
	move_and_slide()
	# Straight into the wall with a shoulder over a door (PIX-434): across
	# to it, and the next step goes in.
	if input != Vector2.ZERO and (input.x == 0.0 or input.y == 0.0) and global_position.is_equal_approx(from):
		var door := Ways.door_by_shoulder(world.map, global_position, Vector2i(input.round()), BODY.x / 2.0)
		if door != Ways.NOWHERE:
			move_and_collide(((MapView.center(door) - global_position) * Vector2(absf(input.y), absf(input.x))).limit_length(pace * delta))
	if input != Vector2.ZERO:
		# Setting off (PIX-243): the stretch lands with the walk's first
		# frame, the rise off the back foot.
		if not gait.walking:
			_spring_from(Juice.SET_OFF)
		# A diagonal holds the way the hero faces (a swing, a word) rather
		# than flickering; the walk is drawn eight ways, a diagonal facing
		# it and a quarter turn through the way between (PIX-293).
		_face(Gait.VECTORS[Gait.steer(_dir_name(), input)])
		gait.walk(gait.drawn_way(input, _dir_name()), (global_position - from).length(), delta)
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
		_press(_can_attack, attack)
		return
	if event.is_action_pressed("dodge"):
		get_viewport().set_input_as_handled()
		_press(_can_dodge, dodge.bind(_heading()))
		return
	for index in Controls.SKILL_KEYS.size():
		if event.is_action_pressed("skill_%d" % (index + 1)):
			get_viewport().set_input_as_handled()
			press_skill(index)
			return


## A skill's key or its slot on the dock pressed.
func press_skill(index: int) -> void:
	_press(_can_cast, cast.bind(index))


## A press (PIX-439): done now if the hero can, else kept a moment in place
## of any press before it, so a roll pressed mid-swing isn't lost.
func _press(can: Callable, act: Callable) -> void:
	_kept_can = can
	_kept_act = act
	_kept_until = GameClock.seconds() + PRESS_KEPT_SECONDS
	_fire_kept()


## The kept press, the moment the hero can act on it.
func _fire_kept() -> void:
	if GameClock.seconds() <= _kept_until and _kept_can.call():
		_kept_until = -1.0
		_kept_act.call()


## A screen opening holds the world still: the press kept goes, or it would
## fire behind the screen as it closes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_kept_until = -1.0


## Neither down, stunned nor mid-roll: a blow must never land after a roll
## has started, and a swing begun in one never ended (the roll's walk holds
## the sprite, so its animation never finished).
func _can_act() -> bool:
	return not dead and not dodging and not ailments.is_stunned()


func _can_attack() -> bool:
	return _can_act() and attack_ready and not attacking


func _can_cast() -> bool:
	return _can_act() and skill_ready and not attacking


func _can_dodge() -> bool:
	return _can_act() and dodge_ready and (not attacking or _past_strike())


## The swing or cast has done what it came to do: only its follow-through is
## left (a bow's or staff's strike runs to its last frame, so it has none).
func _past_strike() -> bool:
	return sprite.frame > int(STRIKE_FRAMES.get(art["attack"], [1, 2])[1])


## The way the keys (or the harness) head right now.
func _heading() -> Vector2:
	if scripted_dir != Vector2.ZERO:
		return scripted_dir
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Turned to face `direction` (a word with someone, an arrival, a stage):
## drawn that way at once, not on a diagonal a walk left (PIX-293).
func face(direction: Vector2) -> void:
	_face(direction)
	if gait != null:
		gait.face(_dir_name())


## The way the hero faces, the nearest of the four to `direction`.
func _face(direction: Vector2) -> void:
	if absf(direction.x) >= absf(direction.y):
		facing = Vector2.RIGHT if direction.x >= 0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if direction.y >= 0 else Vector2.UP

func attack() -> void:
	if not _can_attack():
		return
	attack_ready = false
	attacking = true
	hit_this_swing = []
	velocity = Vector2.ZERO
	_spring_from(Juice.SWING)
	_play(art["attack"])
	_loosed = false
	# A staff bites on its second frame: its bolt leaves now (PIX-396).
	if STRIKE_FRAMES.get(art["attack"], [1, 2])[0] == 1:
		_loose()
	Sound.play(Sound.swing_for(GameState.pack.worn_items().get("weapon", "")))
	get_tree().create_timer(ATTACK_COOLDOWN).timeout.connect(
		func() -> void: attack_ready = true
	)

## A quick roll the way the hero is heading (or facing): a burst of speed and
## a moment nothing can touch them (PIX-155), then a cooldown. Kept a moment
## (PIX-439), it still goes the way it was pressed if the key is up by then.
func dodge(pressed_heading := Vector2.ZERO) -> void:
	if not _can_dodge():
		return
	if attacking:
		_cut_swing()
	var rules: Dictionary = Bestiary.dodge_rules()
	var heading := _heading()
	if heading == Vector2.ZERO:
		heading = pressed_heading
	dodge_dir = heading.normalized() if heading != Vector2.ZERO else facing
	_face(dodge_dir)
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
		crit_primed_until = GameClock.seconds() + PRIMED_SECONDS
	var cooldown := float(rules["cooldown"]) * (1.0 - float(passives["dodgeCooldown"]))
	get_tree().create_timer(cooldown).timeout.connect(func() -> void: dodge_ready = true)


var _dodge_iframes := false
## A dodge that primes the next blow to crit (PIX-190's dodgeCrit): until when.
var crit_primed_until := 0.0
const PRIMED_SECONDS := 2.0


## Until when a summon's bite guards the hero from the other summons' (PIX-421).
var _nipped_until := 0.0


## A blow lands; `infliction` is the attacker's ailment roll, if it carries
## one. Without `grace` (a summon's bite, PIX-421) it starts no half-second
## of invulnerability, so the boss's own bite right after still lands, only
## a half-second guard against the other summons' bites: they count once,
## like any pack's.
func take_hit(damage: int, from: Vector2, infliction: Variant = null, grace := true) -> void:
	if invulnerable or dead or (not grace and GameClock.seconds() < _nipped_until):
		return
	if _dodge_iframes:
		# The blow swishing past (PIX-383: it was silent).
		Sound.play("whiff")
		world.fx.float_text(Text.t("dodged"), global_position + Vector2(0, -22), Color(0.75, 0.9, 1.0))
		return
	# The Aegis of the Ash takes a fight's first blow whole (PIX-376).
	if GameState.upkeep.wards(GameClock.seconds()):
		# Steel taking the blow: the equip's two clinks.
		Sound.play("ward")
		world.fx.float_text(Text.t("warded"), global_position + Vector2(0, -22), Color(1.0, 0.72, 0.45))
		return
	GameState.upkeep.hurt(damage)
	hp = GameState.hero.hp
	Juice.flash(sprite)
	world.fx.skills.impact(self)
	world.fx.float_number(damage, global_position + Vector2(0, -22), Color(1, 0.35, 0.35), false, self)
	world.camera_rig.shake(3.0, 0.2)
	world.camera_rig.hit_stop(0.05)
	if hp > 0 and ailments.inflict(infliction, GameState.roll, HeroRules.passives(GameState.hero)):
		Sound.play("afflicted")
		# Its icon over the hero says it; the log doesn't again (PIX-334).
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
	if not grace:
		_nipped_until = GameClock.seconds() + INVULNERABLE_SECONDS
		return
	invulnerable = true
	# The blink lasts as long as the grace: three blinks.
	var tween := create_tween().set_loops(3)
	tween.tween_property(sprite, "modulate:a", 0.3, INVULNERABLE_SECONDS / 6.0)
	tween.tween_property(sprite, "modulate:a", 1.0, INVULNERABLE_SECONDS / 6.0)
	get_tree().create_timer(INVULNERABLE_SECONDS).timeout.connect(
		func() -> void: invulnerable = false
	)

## A soft oval of light, wider than tall: a skill's flash where it lands,
## the pool under the hero's feet at an ascension.
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
## then a heal on the hero or a strike on the nearest foe its kind reaches
## (Reach.targets, PIX-410: a blow's up close, a spell's or an arrow's from
## afar), through the web's formulas; ailments and cleansing as the skill
## says.
func cast(index: int) -> void:
	if not _can_cast():
		return
	# The skill on that key of the dock (PIX-190), not the Nth one known.
	var skills := Skills.docked(GameState.hero)
	if index >= skills.size() or skills[index].is_empty():
		_refuse("No skill on that key yet. Learn more, or set the keys, in Skills.")
		return
	var skill: Dictionary = skills[index]
	var block := Skills.cast_block(GameState.hero, skill)
	if block != "":
		_refuse(block)
		return
	var targets: Array = []
	if skill["kind"] == "damage":
		var foes := _living_foes()
		for found in Reach.targets(global_position, facing, _spots(foes), _radii(foes), skill):
			targets.append(foes[found])
		if targets.is_empty():
			_refuse(Text.t("No foe in reach for %s.") % skill["name"])
			return
		face(targets[0].global_position - global_position)
	# It went: the last refusal no longer holds.
	world.messages.withdraw(refused)
	refused = ""
	GameState.training.pay_for_skill(skill)
	skill_ready = false
	get_tree().create_timer(SKILL_TURN).timeout.connect(func() -> void: skill_ready = true)
	attacking = true
	casting = true
	velocity = Vector2.ZERO
	_play(art["attack"])
	Sound.play(Sound.cast_for(String(skill["name"])))
	var color: Color = SKILL_COLORS.get(skill["stat"], Color.WHITE)
	# Its own strips light the ground in their colour (PIX-396); the soft
	# glow without them, in the stat's.
	var light := String(ItemIcons.skill_look(String(skill["name"]))["light"])
	if skill["kind"] == "heal":
		var restored := GameState.upkeep.heal_hero(Skills.heal_power(GameState.hero, GameState.pack, skill))
		if skill.get("cleanse", false) and not ailments.kinds().is_empty():
			ailments.clear()
			_show_ailment()
			world.messages.log_line("All ailments are purged!")
		# Its own strips round the hero, the soft glow without them; the
		# ground lit either way.
		var shown: bool = world.fx.skills.cast(skill, self, [])
		world.fx.skill_flash(global_position, Color(light) if shown and light != "" else Color(0.5, 1.0, 0.6), not shown)
		world.fx.float_number(restored, global_position + Vector2(0, -22), Color(0.5, 1, 0.6), false, self)
		return
	# An area skill (PIX-190) strikes every foe in its area, not just the
	# nearest (Reach.targets). Its own strips on each, the soft glow without
	# them, the ground lit either way; they are its impact, so a blow's small
	# one stays off.
	var glow: bool = not world.fx.skills.cast(skill, self, targets)
	if not glow and light != "":
		color = Color(light)
	world.fx.skills.impacts_held = true
	var dealt := 0
	for foe: Node in targets:
		var damage := roundi(Bestiary.hero_skill_damage(GameState.hero, GameState.pack, skill, foe.fighter, GameState.roll) * GameState.spoils.damage_scale())
		world.fx.skill_flash(foe.global_position, color, glow)
		foe.take_hit(damage, global_position, skill.get("inflicts"), false, Sound.impact_for(String(skill["name"])))
		dealt += damage
	world.fx.skills.impacts_held = false
	# What it dealt (or a heal restored) is the numbers over the heads: the
	# log doesn't say it again (PIX-334).
	# A draining skill gives back a share of what it took (Drain Life).
	var drained := roundi(dealt * float(skill.get("drain", 0.0)))
	if drained > 0:
		var restored := GameState.upkeep.heal_hero(drained)
		world.fx.float_number(restored, global_position + Vector2(0, -22), Color(0.5, 1, 0.6), false, self)
	_steal_life(dealt)


## A cast refused: said on the plate, and heard.
func _refuse(text: String) -> void:
	refused = text
	world.messages.flash(text)
	Sound.play("skill_refused")


## Some passives heal the hero a share of the damage they deal (PIX-190).
func _steal_life(damage: int) -> void:
	var share := float(HeroRules.passives(GameState.hero)["lifeSteal"])
	if share <= 0 or damage <= 0:
		return
	var restored := GameState.upkeep.heal_hero(maxi(1, roundi(damage * share)))
	if restored > 0:
		world.fx.float_number(restored, global_position + Vector2(0, -22), Color(0.5, 1, 0.6), false, self)


## Every foe still standing.
func _living_foes() -> Array:
	return get_tree().get_nodes_in_group("mobs").filter(func(enemy: Node) -> bool: return not enemy.dying)


## Where they stand, and how wide either side of their feet their bodies
## are (their boxes for blows), for Reach.
static func _spots(foes: Array) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for foe: Node2D in foes:
		spots.append(foe.global_position)
	return spots


static func _radii(foes: Array) -> Array[float]:
	var radii: Array[float] = []
	for foe: Node in foes:
		radii.append(foe.body_of(foe.fighter).x / 2.0)
	return radii


## The foes this swing lands on now, the way the hero faces (Reach.struck).
func _struck() -> Array:
	var foes := _living_foes()
	var hit: Array = []
	for index in Reach.struck(global_position, facing, _spots(foes), _radii(foes), Reach.swing(art["attack"])):
		hit.append(foes[index])
	return hit


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

## Ticks poison/burn into the hero's health and shows what still ails them.
func _tick_ailments(delta: float) -> void:
	for tick in ailments.tick(delta):
		GameState.upkeep.hurt(tick["damage"])
		hp = GameState.hero.hp
		world.fx.float_number(tick["damage"], global_position + Vector2(0, -22), Color(0.75, 0.5, 1), false, self)
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
	_shadow.visible = true
	sprite.modulate = Color.WHITE
	_end_swing()
	face(Vector2.DOWN)
	_play("idle")

func _die() -> void:
	dead = true
	_shadow.visible = false
	_kept_until = -1.0
	Sound.play("defeat")
	Sound.play("hero_death")
	_end_swing()
	_play("death")
	world.on_player_died()

## A stun holds the hero still and cuts a swing or a cast short: under the
## stun's idle the swing's animation never finishes, and a swing left open
## locked out every attack, dodge, cast and step for good (PIX-333).
func _held_by_stun() -> bool:
	if not ailments.is_stunned():
		return false
	_kept_until = -1.0
	_end_swing()
	velocity = Vector2.ZERO
	_play("idle")
	return true

## A swing or a cast over: the blade stops biting and the hero is free.
func _end_swing() -> void:
	attacking = false
	casting = false
	striking = false

## A roll taking over from a swing or cast (PIX-439): nothing of it stays on
## the hero, not its squash either.
func _cut_swing() -> void:
	_end_swing()
	hit_this_swing = []
	if _spring != null:
		_spring.kill()
	squash = Vector2.ONE

func _on_animation_finished() -> void:
	if attacking:
		_end_swing()
		_play("idle")
	elif not dead and sprite.animation.begins_with("hurt"):
		_play("idle")

## The weapon only bites on the striking frames, matching what the sheet
## shows; a blade or a staff leaves its arc on the first (PIX-226).
func _on_frame_changed() -> void:
	if attacking and not casting:
		var strike: Array = STRIKE_FRAMES.get(art["attack"], [1, 2])
		striking = sprite.frame >= strike[0] and sprite.frame <= strike[1]
		if sprite.frame == strike[0] - 1 and sprite.frame > 0:
			_loose()
		if sprite.frame == strike[0] and art["attack"] != "bow" and not _loosed:
			_slash()


## This swing's arrow or bolt was drawn (PIX-396).
var _loosed := false


## The bow's arrow, the staff's bolt (PIX-396): loosed a frame before the
## weapon bites and flying that frame, so it lands as the blow does, at the
## foe the swing reaches (Reach.struck, PIX-410: the nearest a shot does) or
## as far as it reaches, a miss. The blow is still the swing's; a staff with
## no bolt drawn (motion reduced) keeps its crescent.
func _loose() -> void:
	# A blade looses nothing.
	if not ItemIcons.skill_fx().get("swings", {}).has(art["attack"]):
		return
	var frame_seconds := 1.0 / (sprite.sprite_frames.get_animation_speed(sprite.animation) * maxf(absf(sprite.get_playing_speed()), 0.01))
	var struck := _struck()
	var foe: Node2D = null if struck.is_empty() else struck[0]
	var miss := global_position + facing * Reach.px(Reach.swing(art["attack"]))
	var tint := Juice.ARCANE if art["attack"] == "staff" else Color.WHITE
	_loosed = world.fx.skills.swing(art["attack"], global_position, foe, miss if foe == null else foe.global_position, frame_seconds, tint)


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
	fade.tween_property(trail, "modulate:a", 0.0, Juice.SLASH_SECONDS)
	fade.tween_callback(trail.queue_free)


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


## The sprite at the squash, its feet where they stand at rest (PIX-243: a
## squash about the middle sank the feet below the ground). Its own size at
## every rank.
func _shape() -> void:
	if sprite == null:
		return
	sprite.scale = squash
	sprite.position.y = PunyArt.lift(art) + Juice.FEET * (1.0 - squash.y)


## The press waiting for the hero (PIX-439): whether it can happen yet, what
## it does, and until when it waits (-1: none waits).
var _kept_can := Callable()
var _kept_act := Callable()
var _kept_until := -1.0


## The way the hero faces, by name.
func _dir_name() -> String:
	return Gait.dir_of(facing)


## Shade draws all four directions, so there's no mirroring. The walk is the
## gait's (PIX-243); anything else played takes the hero out of it. The hero
## stands the way the walk left them, a diagonal too (PIX-293); a swing, a
## hurt or a fall turns them to the way they face.
func _play(anim: String) -> void:
	gait.halt()
	var way := _dir_name()
	if anim == "idle":
		way = gait.shown
	else:
		gait.face(way)
	var name := PunyArt.pick(sprite.sprite_frames, anim, way)
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)
