extends CharacterBody2D
## A monster in the field: wanders near its home, notices a hero it can see
## (a "!" and a hop first), chases, bites after a tell, and gives up a chase
## that strays too far, walking home to heal (PIX-142). Its numbers are the web bestiary's (`fighter` from
## Bestiary.spawn): hits land through Bestiary's damage formulas, and its
## death pays out through GameState.defeat_monster (via the world). It wears
## the Puny sheet PunyArt assigns its species, walking the way it moves.

const WANDER_SPEED := 22.0
const CHASE_SPEED := 55.0
const HOMEWARD_SPEED := 70.0
const CONTACT_RADIUS := 13.0
## A bite that was told lands if the hero is still this close.
const BITE_REACH := 20.0
const CONTACT_COOLDOWN := 0.9
const ELITE_TINT := Color(1.0, 0.82, 0.7)
## A blow's shove (PIX-209): a push that fades to nothing over KNOCK_TIME,
## riding on top of the foe's own walk - 10 px all told (v·t/2) for a common
## foe, half for an elite or a named one, none for a boss.
const KNOCK_PUSH := 166.0
const KNOCK_TIME := 0.12
## The bite's wind-up (PIX-226): how far it leans back and tilts away.
const LEAN_BACK := 3.0
const LEAN_SKEW := 0.22
## Where a blow lands on a foe, from its feet: about its chest (the sparks).
const SPARK_LIFT := Vector2(0, -12)
## The hit stop on a blow, and the longer one on the blow that kills.
const HIT_STOP := 0.035
const KILL_STOP := 0.08

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
## "Lv N" beside the health bar (PIX-188).
var level_tag: PanelContainer
## Poison, burn and stun from the hero's afflicting passives.
var ailments := Ailments.new()
## PunyArt.monster spec, and the way it last faced.
var art: Dictionary
var facing := "down"
## True from the alert until it gives up; the alert is heard (bump).
var hunting := false
## An escort's wagon this foe was sent for (PIX-192): it goes for whichever
## is nearer, the wagon or the hero, and never gives the chase up.
var quarry: Node2D = null
var _at_quarry := false
## Where it lives: wanders around it, gives up a chase too far from it.
var home := Vector2.ZERO
## "idle" (at home), "alert" (the "!" wind-up), "chase", "homeward", and
## for a boss "cast" (standing still while its attack is told, PIX-150).
var mode := "idle"
var alert_left := 0.0
## Seconds until a told bite lands; negative while no bite is coming.
var tell_left := -1.0
var mark: PanelContainer
## An undead elite's raised guard (PIX-155): blows mostly glance off.
var guarding := false
## Busy where it stands (the Night of Ash's scavenger at its meal): it
## doesn't wander, and only notices a hero at arm's length or a blow.
var feeding := false
## A named monster's entry (Hunts, PIX-156), or {}.
var named := {}
## The health bar's full width: a named monster's is longer.
var bar_width := 16.0
## How much quicker than its kind it hunts (PIX-216: a swift depth).
var pace := 1.0
## The shove of the last blow, and how long it has left (PIX-209).
var knock := Vector2.ZERO
var knock_left := 0.0


func _ready() -> void:
	# Placed before entering the tree: start interpolating from here.
	reset_physics_interpolation()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	art = PunyArt.monster(fighter["id"])
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	# How much bigger than its kind: an elite a little, a named monster huge
	# and in its own colour (PIX-156).
	var grown := 1.2 if fighter["elite"] else 1.0
	var tint: Color = art.get("tint", Color.WHITE)
	sprite.self_modulate = tint * ELITE_TINT if fighter["elite"] else tint
	if fighter.has("named"):
		named = Hunts.named(fighter["named"])
		grown = float(named["scale"])
		var own: Array = named["tint"]
		# Its own colour may brighten past its kind's (Greymaw's silver).
		sprite.self_modulate = tint * Color(float(own[0]), float(own[1]), float(own[2]))
		bar_width = 28.0
	var size: float = art.get("scale", 1.0) * grown
	sprite.scale = Vector2.ONE * size
	sprite.position = Vector2(0, PunyArt.lift(art) * size)
	# Its own flash and dissolve (PIX-226).
	sprite.material = Juice.fighter_material()
	_play("idle")
	add_child(sprite)
	# Fafnyr and Morvax fight with their own attacks too (PIX-150); an elite
	# has its family's one trick (PIX-155), a named monster one of its own
	# besides (PIX-156).
	# A boss or an elite shakes stuns off (PIX-186).
	var guards: Dictionary = Bestiary._data()["stunGuard"]
	ailments.stun_guard = float(guards["boss"]) if Bestiary.is_boss(fighter["id"]) else (float(guards["elite"]) if fighter["elite"] or not named.is_empty() else 0.0)
	if Bestiary._data()["bossPatterns"].has(fighter["id"]):
		add_child(preload("res://scripts/boss_brain.gd").new())
	elif not named.is_empty() or (fighter["elite"] and Bestiary._data()["eliteMoves"].has(Bestiary.family_of(fighter["id"]))):
		add_child(preload("res://scripts/elite_brain.gd").new())

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
	hurt_rect.size = Vector2(16, 24) * grown
	hurt_shape.shape = hurt_rect
	hurt_shape.position = Vector2(0, -8)
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	# Health floats above the head, hidden until first scratched; elites in gold.
	health_bar_back = ColorRect.new()
	health_bar_back.color = Color(0, 0, 0, 0.6)
	health_bar_back.size = Vector2(bar_width, 2)
	health_bar_back.position = Vector2(-bar_width / 2.0, -20 * size)
	health_bar_back.visible = false
	add_child(health_bar_back)
	health_bar = ColorRect.new()
	health_bar.color = Color(1, 0.8, 0.3) if fighter["elite"] else Color(0.9, 0.25, 0.25)
	health_bar.size = Vector2(bar_width, 2)
	health_bar.position = Vector2(-bar_width / 2.0, -20 * size)
	health_bar.visible = false
	add_child(health_bar)
	# A foe's bar and name read at night too (PIX-221).
	health_bar_back.material = Lights.unshaded()
	health_bar.material = Lights.unshaded()
	if not named.is_empty():
		var plate := _name_plate(-20 * size - 1)
		Lights.unshade(plate)
		add_child(plate)
	# Its level by the health bar (PIX-188), coloured by the gap to the
	# hero's: seen once the hero is near enough to be noticed, before the charge.
	var level := Bestiary.level_of(fighter)
	# On the night's plate (the pixel font draws no outline), over every actor
	# (the y-sort would put a hero standing above the foe on top of it).
	level_tag = PanelContainer.new()
	level_tag.add_theme_stylebox_override("panel", UiStyle.plate(6))
	level_tag.add_child(UiStyle.strong(Text.t("Lv %d") % level, 16, Bestiary.gap_color(level, GameState.hero.level)))
	level_tag.scale = Vector2.ONE * 0.25
	level_tag.z_as_relative = false
	level_tag.z_index = 20
	level_tag.visible = false
	level_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_tag.resized.connect(func() -> void:
		level_tag.position = Vector2(-level_tag.size.x * 0.125, -20 * size - level_tag.size.y * 0.25 - 0.5))
	Lights.unshade(level_tag)
	add_child(level_tag)


func _physics_process(delta: float) -> void:
	if dying:
		return
	if level_tag != null:
		level_tag.visible = hunting or health_bar.visible or Packs.within_notice(global_position, world.player.global_position)
	for tick in ailments.tick(delta):
		_lose(tick["damage"], Color(0.75, 0.5, 1))
		if dying:
			return
	if ailments.is_stunned():
		_play("idle")
		return
	var player: CharacterBody2D = world.player
	var to_player := player.global_position - global_position
	match mode:
		"alert":
			velocity = Vector2.ZERO
			alert_left -= delta
			if alert_left <= 0:
				mode = "chase"
		"chase":
			var aim := _aim(to_player)
			if player.dead or (not _hunts_wagon() and Packs.gives_up(home, global_position, player.global_position)):
				_give_up()
			else:
				_chase(aim, delta)
		"cast":
			velocity = Vector2.ZERO
		"homeward":
			var back := home - global_position
			velocity = back.normalized() * HOMEWARD_SPEED
			if back.length() < 4:
				_settle()
		_:
			if not player.dead and world.can_notice(self):
				notice()
			else:
				_wander(delta)
	var walk := velocity
	var shove := _shove(delta)
	velocity += shove
	move_and_slide()
	if shove != Vector2.ZERO:
		# Shoved, it still faces (and walks) the way it meant to.
		velocity = walk
	if velocity.length() > 1:
		facing = _dir_of(velocity)
	# Let a bite or a hurt finish before walking resumes.
	if sprite.is_playing() and not sprite.sprite_frames.get_animation_loop(sprite.animation):
		return
	_play("walk" if velocity.length() > 1 else "idle")


## The hero is seen: a "!" over the head and a hop, then the chase.
func notice() -> void:
	mode = "alert"
	hunting = true
	alert_left = float(Packs.rules()["windUpSeconds"])
	world.on_enemy_noticed(self)
	_play("idle")
	if mark == null:
		mark = _alert_bubble()
		Lights.unshade(mark)
		add_child(mark)
	mark.modulate.a = 1.0
	mark.visible = true
	var fade := mark.create_tween()
	fade.tween_interval(alert_left + 0.5)
	fade.tween_property(mark, "modulate:a", 0.0, 0.25)
	var hop := sprite.create_tween()
	var rest := sprite.position
	hop.tween_property(sprite, "position:y", rest.y - 5, alert_left * 0.4).set_ease(Tween.EASE_OUT)
	hop.tween_property(sprite, "position:y", rest.y, alert_left * 0.6).set_ease(Tween.EASE_IN)


## A named monster's name over its head in the boss's red: the UI's type at
## a quarter, so at the usual zoom one font pixel is one screen pixel.
func _name_plate(lift: float) -> Label:
	var plate := UiStyle.strong(fighter["name"], 16, Color("ffb3a1"))
	plate.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.03))
	plate.add_theme_constant_override("outline_size", 4)
	plate.scale = Vector2.ONE * 0.25
	plate.z_index = 10
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.resized.connect(func() -> void: plate.position = Vector2(-plate.size.x * 0.125, lift - plate.size.y * 0.25))
	return plate


## A "!" in a white bubble over the head, built at the UI's size and drawn
## at half of it: one art pixel per font pixel.
func _alert_bubble() -> PanelContainer:
	var bubble := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("fff6dc")
	box.border_color = Color(0.12, 0.07, 0.05)
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	bubble.add_theme_stylebox_override("panel", box)
	bubble.add_child(UiStyle.strong("!", 18, Color("d8433f")))
	bubble.scale = Vector2.ONE * 0.5
	bubble.z_index = 10
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lift := -20.0 * sprite.scale.y - 16
	bubble.resized.connect(func() -> void: bubble.position = Vector2(-bubble.size.x * 0.25, lift))
	return bubble


## Straight at the hero; in reach, a flash tells the bite, which lands if the
## hero is still close when the tell is done.
func _chase(to_player: Vector2, delta: float) -> void:
	velocity = to_player.normalized() * CHASE_SPEED * pace
	if tell_left >= 0:
		velocity *= 0.3
		tell_left -= delta
		if tell_left < 0:
			_bite(to_player)
	elif to_player.length() < CONTACT_RADIUS and can_bite:
		_tell_bite(to_player)


## The bite's tell (PIX-210): it crouches to spring with a red glint and a
## blip, leaning back away from its mark (PIX-226) so it reads at a glance;
## under clear warnings a band on the ground shows where it will land.
func _tell_bite(toward: Vector2) -> void:
	tell_left = float(Packs.rules()["biteTellSeconds"])
	var rest := sprite.scale
	var at := sprite.position
	var back := -toward.normalized() * LEAN_BACK
	var tell := sprite.create_tween().set_parallel()
	tell.tween_property(sprite, "modulate", Color(1.8, 0.75, 0.6), tell_left * 0.6)
	tell.tween_property(sprite, "scale", rest * Vector2(1.12, 0.88), tell_left * 0.6)
	tell.tween_property(sprite, "position", at + back, tell_left * 0.6).set_ease(Tween.EASE_OUT)
	tell.tween_property(sprite, "skew", LEAN_SKEW * signf(back.x), tell_left * 0.6)
	tell.chain().tween_property(sprite, "modulate", Color.WHITE, tell_left * 0.4)
	tell.tween_property(sprite, "scale", rest, tell_left * 0.4)
	# The spring: forward again, fast.
	tell.tween_property(sprite, "position", at, tell_left * 0.4).set_ease(Tween.EASE_IN)
	tell.tween_property(sprite, "skew", 0.0, tell_left * 0.4)
	Sound.play_ui("tell")
	if GameState.settings.clear_warnings:
		Telegraph.mark(world, Telegraph.band(global_position, global_position + toward, BITE_REACH, 12.0), tell_left, Callable(), false)


## Where the chase goes: the hero, or the wagon when it's the nearer.
func _aim(to_player: Vector2) -> Vector2:
	_at_quarry = false
	if _hunts_wagon():
		var to_wagon := quarry.global_position - global_position
		if to_wagon.length() < to_player.length():
			_at_quarry = true
			return to_wagon
	return to_player


func _hunts_wagon() -> bool:
	return quarry != null and is_instance_valid(quarry) and not quarry.done


func _bite(to_player: Vector2) -> void:
	if to_player.length() > BITE_REACH:
		return
	can_bite = false
	_play("attack" if sprite.sprite_frames.has_animation("attack_" + facing) else "sword")
	# At the wagon the bite lands on it (the escort counts it).
	if _at_quarry:
		get_tree().create_timer(CONTACT_COOLDOWN).timeout.connect(func() -> void: can_bite = true)
		return
	world.player.take_hit(
		Bestiary.monster_attack_damage(fighter, GameState.hero, GameState.pack, GameState.roll),
		global_position, fighter.get("inflicts")
	)
	get_tree().create_timer(CONTACT_COOLDOWN).timeout.connect(func() -> void: can_bite = true)


## Too far from home or behind: back home, deaf to the hero on the way.
func _give_up() -> void:
	mode = "homeward"
	hunting = false
	tell_left = -1.0


## Home again: whole, and watching.
func _settle() -> void:
	mode = "idle"
	fighter["hp"] = fighter["maxHp"]
	health_bar.visible = false
	health_bar_back.visible = false
	health_bar.size.x = bar_width


## A step this way or that, never past the leash.
func _wander(delta: float) -> void:
	if feeding:
		velocity = Vector2.ZERO
		return
	wander_time -= delta
	if wander_time <= 0:
		wander_time = randf_range(0.8, 2.0)
		var dirs := [Vector2.ZERO, Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		wander_dir = Packs.wander_dir(home, global_position, dirs.pick_random())
	velocity = wander_dir * WANDER_SPEED


## How hard a blow shoves a foe (PIX-209): a boss stands its ground, an
## elite or a named foe gives half as much.
static func knock_push(fighter: Dictionary, is_named := false) -> float:
	if Bestiary.is_boss(fighter["id"]):
		return 0.0
	return KNOCK_PUSH * (0.5 if fighter["elite"] or is_named else 1.0)


## This tick's share of the shove, fading as it runs out.
func _shove(delta: float) -> Vector2:
	if knock_left <= 0:
		return Vector2.ZERO
	var share := knock * (knock_left / KNOCK_TIME)
	knock_left -= delta
	return share


## A landed swing: `damage` is already Bestiary.hero_attack's verdict, and
## `crit` whether it was one; `infliction` is the hero's afflicting passive,
## if any.
func take_hit(damage: int, from: Vector2, infliction: Variant = null, crit := false) -> void:
	if dying:
		return
	if guarding:
		damage = maxi(1, roundi(damage * float(Bestiary._data()["eliteMoves"]["undead"]["block"])))
		world.fx.float_text(Text.t("blocked"), global_position + Vector2(0, -26), Color(0.7, 0.85, 1.0))
	Sound.play("hit")
	# Steel on armour throws sparks where the blow lands (PIX-225).
	if Motes.sparks_off(String(fighter["id"])) and world.get("atmosphere") != null:
		world.atmosphere.sparks(global_position + (from - global_position).normalized() * 6.0 + SPARK_LIFT)
	knock = (global_position - from).normalized() * knock_push(fighter, not named.is_empty())
	knock_left = KNOCK_TIME
	_lose(damage, Color(1, 0.95, 0.85), crit)
	# A clean white flash (PIX-226), longer on the killing blow (PIX-209: a
	# longer stop, a thud).
	Juice.flash(sprite, Juice.KILL_FLASH_SECONDS if dying else Juice.FLASH_SECONDS)
	if dying:
		Sound.play_ui("kill")
	if dying and Bestiary.is_boss(fighter["id"]):
		world.boss_fell()
	else:
		world.camera_rig.hit_stop(KILL_STOP if dying else HIT_STOP)
	world.camera_rig.shake(2.5 if dying or crit else 1.5, 0.1)
	# The camera answers a crit or a killing blow with a little punch.
	if dying or crit:
		world.camera_rig.punch(global_position - from)
	# Struck from anywhere, it turns on the hero at once.
	if not dying and mode != "chase":
		mode = "chase"
		if not hunting:
			hunting = true
			world.on_enemy_noticed(self)
	if not dying and ailments.inflict(infliction, GameState.roll):
		Sound.play_ui("ail")
		world.messages.log_line(Text.t("%s is afflicted by %s!") % [fighter["name"], Ailments.label(infliction["kind"])])


func _lose(damage: int, color: Color, crit := false) -> void:
	fighter["hp"] = maxi(0, int(fighter["hp"]) - damage)
	world.fx.float_number(damage, global_position + Vector2(0, -18), color, crit)
	health_bar.size.x = bar_width * fighter["hp"] / fighter["maxHp"]
	# A boss's health is on the boss bar across the screen's top (PIX-210).
	health_bar.visible = not world.fights_like_boss(self)
	health_bar_back.visible = health_bar.visible
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
	if not sprite.sprite_frames.has_animation(death):
		death = "death"
	# It falls, then dissolves into embers or dust (PIX-226).
	if sprite.sprite_frames.has_animation(death):
		sprite.play(death)
		sprite.animation_finished.connect(_dissolve)
	else:
		_dissolve()


## The last of it: the body dissolves pixel by pixel, what it leaves drifts
## off, and it's gone.
func _dissolve() -> void:
	var color := Juice.remains_color(Bestiary.family_of(fighter["id"]))
	if world.get("atmosphere") != null:
		world.atmosphere.remains(global_position + Vector2(0, -8), color)
	Juice.dissolve(sprite, color).tween_callback(queue_free)


func _play(anim: String) -> void:
	var name := PunyArt.pick(sprite.sprite_frames, anim, facing)
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)


static func _dir_of(motion: Vector2) -> String:
	if absf(motion.x) >= absf(motion.y):
		return "right" if motion.x >= 0 else "left"
	return "down" if motion.y >= 0 else "up"
