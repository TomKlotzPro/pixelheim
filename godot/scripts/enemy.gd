extends CharacterBody2D
## A monster in the field: wanders near its home, notices a hero it can see
## (a "!" and a hop first), chases, bites after a tell, and gives up a chase
## that strays too far, walking home to heal (PIX-142). One far below the
## hero runs from it instead (PIX-251), and turns only when cornered or
## struck. One whose pack sleeps after dark lies still by its camp's fire
## until the hero comes close or strikes (PIX-252). Its numbers are the web
## bestiary's (`fighter` from Bestiary.spawn): hits land through Bestiary's
## damage formulas, and its death pays out through
## GameState.spoils.defeat_monster (via the world). It wears the Puny sheet
## PunyArt assigns its species, walking the way it moves.

const WANDER_SPEED := 22.0
const CHASE_SPEED := 55.0
const HOMEWARD_SPEED := 70.0
## Running from a hero far above it (PIX-251): quicker than its charge, but
## a hero (95) who wants the fight still catches it.
const FLEE_SPEED := 62.0
## The start before it runs, and how long it may stand stuck while running
## (a packmate or the hero's body in the way) before it tries another way.
const FLINCH_SECONDS := 0.3
const STUCK_SECONDS := 0.35
## No cell yet: a flight just begun.
const NO_CELL := Vector2i(-1, -1)
## The fright's "!" and drop shiver this many art pixels either way; the
## drop starts by the bubble's top (in the bubble's half-size units).
const SHIVER := 1.0
const DROP_FROM := 8.0
## The alert's bubble: drawn at half the UI's size, its sides this far off
## the "!"'s ink (in its own units, so three art pixels).
const BUBBLE_SCALE := 0.5
const BUBBLE_PAD := 6.0
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
## Asleep (PIX-252): its idle played this much slower, a sleeper's breath,
## how long each "Z" takes to drift up and fade, and the pause before the
## next.
const SLEEP_BREATH := 0.35
const SLEEP_DRIFT_SECONDS := 1.6
const SLEEP_PAUSE_SECONDS := 0.3

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
## "idle" (at home), "alert" (the "!" wind-up), "chase", "homeward",
## "flee" (running from a hero far above it, PIX-251), and for a boss
## "cast" (standing still while its attack is told, PIX-150).
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
## Asleep at home by its camp's fire (PIX-252: a pack that sleeps after
## dark): it lies still, a "Z" drifting up off it, and as at a meal only a
## hero at arm's length or a blow wakes it - and its pack with it.
var asleep := false
var _sleep_mark: Label
## A named monster's entry (Hunts, PIX-156), or {}.
var named := {}
## The health bar's full width: a named monster's is longer.
var bar_width := 16.0
## How much quicker than its kind it hunts (PIX-216: a swift depth).
var pace := 1.0
## The shove of the last blow, and how long it has left (PIX-209).
var knock := Vector2.ZERO
var knock_left := 0.0
## Turned on the hero from flight, cornered or struck (PIX-251): it fights
## where it stands, so the leash to its home lets go until the fight is over.
var at_bay := false
## A mimic just burst from its chest (PIX-251): it bites what woke it and
## never runs, until it is home again.
var woken := false
## How long it has run without getting anywhere (PIX-251); the step it is
## running, the cell it runs from, and the cells beside it a body has shut.
var stuck_for := 0.0
var _step := Vector2i.ZERO
var _fled_from := NO_CELL
var _taken: Array[Vector2i] = []
## The fright's cue over the head: a pale "!" and a drop of sweat.
var fright_mark: Node2D
var _fright_tween: Tween
var _drop: Sprite2D
## The start back, and the sprite's shape and place it springs back to (a
## blow cuts it short, so a bite's tell never takes a stretched shape for
## its rest).
var _flinch_tween: Tween
var _rest_scale := Vector2.ONE
var _rest_at := Vector2.ZERO
## Its walk (PIX-243): stepping with the ground it covers, wandering slowly
## or hunting fast.
var gait: Gait


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
	_rest_scale = sprite.scale
	_rest_at = sprite.position
	# Its own flash and dissolve (PIX-226).
	sprite.material = Juice.fighter_material()
	gait = Gait.new(sprite, art, size)
	_play("idle")
	add_child(sprite)
	_wear_crown()
	sprite.animation_changed.connect(_turned)
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
	level_tag.scale = Vector2.ONE * CameraRig.LABEL_SCALE
	level_tag.z_as_relative = false
	level_tag.z_index = 20
	level_tag.visible = false
	level_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_tag.resized.connect(func() -> void:
		level_tag.position = Vector2(-level_tag.size.x * CameraRig.LABEL_SCALE / 2.0, -20 * size - level_tag.size.y * CameraRig.LABEL_SCALE - 0.5))
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
			# At bay, the fight is where it stands, not a leash from home.
			var leash := global_position if at_bay else home
			if player.dead or (not _hunts_wagon() and gives_up(fighter, leash, global_position, player.global_position)):
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
		"flee":
			if alert_left > 0:
				# The flinch: a start before it runs.
				velocity = Vector2.ZERO
				alert_left -= delta
			elif player.dead or Packs.calmed(global_position, player.global_position):
				# Far enough: it calms down and walks home, as from a chase.
				_give_up()
			else:
				_flee(to_player)
		_:
			if not player.dead and world.foes.can_notice(self):
				if flees_from(fighter, GameState.hero.level, held_to_fight()):
					take_fright(to_player)
				else:
					notice()
			else:
				_wander(delta)
	var walk := velocity
	var shove := _shove(delta)
	velocity += shove
	var from := global_position
	move_and_slide()
	if shove != Vector2.ZERO:
		# Shoved, it still faces (and walks) the way it meant to.
		velocity = walk
	if mode == "flee" and alert_left <= 0:
		stuck_for = stuck_for + delta if get_real_velocity().length() < FLEE_SPEED * 0.25 else 0.0
	# Heading off at an angle, it holds its facing rather than flickering
	# between two (PIX-243).
	if velocity.length() > 1:
		facing = Gait.steer(facing, velocity)
	# Let a bite or a hurt finish before walking resumes.
	if sprite.is_playing() and not sprite.sprite_frames.get_animation_loop(sprite.animation):
		return
	if velocity.length() > 1:
		gait.walk(facing, (global_position - from).length(), delta)
	elif gait.rest(delta) or not gait.walking:
		_play("idle")


## The hero is seen: a "!" over the head and a hop, then the chase.
func notice() -> void:
	_wake()
	mode = "alert"
	hunting = true
	alert_left = float(Packs.rules()["windUpSeconds"])
	world.foes.on_enemy_noticed(self)
	_play("idle")
	if fright_mark != null:
		fright_mark.visible = false
	if mark == null:
		mark = _bubble(Color("d8433f"))
		Lights.unshade(mark)
		add_child(mark)
	_place_bubble(mark)
	mark.modulate.a = 1.0
	mark.visible = true
	var fade := mark.create_tween()
	fade.tween_interval(alert_left + 0.5)
	fade.tween_property(mark, "modulate:a", 0.0, 0.25)
	var hop := sprite.create_tween()
	var rest := sprite.position
	hop.tween_property(sprite, "position:y", rest.y - 5, alert_left * 0.4).set_ease(Tween.EASE_OUT)
	hop.tween_property(sprite, "position:y", rest.y, alert_left * 0.6).set_ease(Tween.EASE_IN)


## What a named monster may wear on its head (PIX-255), by the name the data
## gives it: the dungeon sheet's piece.
const CROWNS := {"stewpot": PunyDungeon.POT}


## A named monster wearing something of the story's (combat.json's
## "crown"): the Tidecaller with Tam's stewpot on its head, sitting on the
## top of its figure, squashing and flashing with it.
func _wear_crown() -> void:
	if not CROWNS.has(String(named.get("crown", ""))):
		return
	var crown := Sprite2D.new()
	crown.texture = PunyDungeon.sheet().tile_texture(CROWNS[named["crown"]])
	# Pot-sized on the hero's scale, whatever the monster's.
	crown.scale = Vector2.ONE * 0.75 / sprite.scale.x
	var top := Ink.crown(sprite.sprite_frames, Array(sprite.sprite_frames.get_animation_names()))
	crown.position = Vector2(0, top + 3.0 / sprite.scale.y)
	# It flashes and dissolves with the one wearing it.
	crown.use_parent_material = true
	sprite.add_child(crown)


## A named monster's name over its head in the boss's red: the UI's type at
## CameraRig.LABEL_SCALE, so at play zoom one font pixel is one screen pixel.
func _name_plate(lift: float) -> Label:
	var plate := UiStyle.strong(fighter["name"], 16, Color("ffb3a1"))
	plate.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.03))
	plate.add_theme_constant_override("outline_size", 4)
	plate.scale = Vector2.ONE * CameraRig.LABEL_SCALE
	plate.z_index = 10
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its words' ink centred over the bar, not its box (PIX-268, Ink).
	var words := Ink.of_text(plate.text, UiStyle.bold_font(), UiStyle.TEXT)
	plate.resized.connect(func() -> void: plate.position = Vector2(-words.get_center().x * CameraRig.LABEL_SCALE, lift - plate.size.y * CameraRig.LABEL_SCALE))
	return plate


## A "!" in `ink` in a white bubble over the head, built at the UI's size
## and drawn at half of it: one art pixel per font pixel. The bubble's
## sides stand BUBBLE_PAD off the glyph's ink, not its box (PIX-268: the
## face's spacing after the "!" pushed it left of the bubble's middle).
func _bubble(ink: Color) -> PanelContainer:
	var bubble := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("fff6dc")
	box.border_color = Color(0.12, 0.07, 0.05)
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	var sides := bubble_sides()
	box.content_margin_left = sides.x
	box.content_margin_right = sides.y
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	bubble.add_theme_stylebox_override("panel", box)
	bubble.add_child(UiStyle.strong("!", 18, ink))
	bubble.scale = Vector2.ONE * BUBBLE_SCALE
	bubble.z_index = 10
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.resized.connect(_place_bubble.bind(bubble))
	return bubble


## The bubble's margins left and right of its "!": BUBBLE_PAD each side of
## the glyph's ink, so the ink is the bubble's middle, and a whole number of
## art pixels wide.
static func bubble_sides() -> Vector2:
	var face := UiStyle.bold_font()
	var ink := Ink.of_text("!", face, UiStyle.TEXT)
	var box := face.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT).x
	return Vector2(BUBBLE_PAD - ink.position.x, BUBBLE_PAD - (box - ink.end.x))


## A bubble over the head the way the monster faces now (PIX-268: its head
## isn't always over its middle), in whole pixels; clear of the level tag
## (PIX-188) under it, which hid the "!"'s dot.
func _place_bubble(bubble: Control) -> void:
	var head := Ink.head(sprite.sprite_frames, Ink.rest_pose(sprite.sprite_frames, sprite.animation), _rest_at, _rest_scale)
	bubble.position = Vector2(bubble_x(bubble.size.x, head.get_center().x), -20.0 * _rest_scale.y - 20)


## The alert or the fright's cue keeps over its head as it turns to the
## chase or the flight.
func _turned() -> void:
	if mark != null and mark.visible:
		_place_bubble(mark)
	if fright_mark != null and fright_mark.visible:
		_place_bubble(fright_mark.get_child(0) as Control)


## Where a bubble `width` wide (in its own units) goes so its middle, its
## "!", is over `centre`.
static func bubble_x(width: float, centre: float) -> float:
	return Ink.centred(Rect2(0, 0, width * BUBBLE_SCALE, 0), centre)


## The hero is seen, and far too strong (PIX-251): a pale "!" and a drop of
## sweat shiver over its head, it starts back, then runs. It isn't hunting:
## no growl, no fight's clock, so the music stays the place's.
func take_fright(to_player: Vector2) -> void:
	_wake()
	mode = "flee"
	alert_left = FLINCH_SECONDS
	stuck_for = 0.0
	_step = Vector2i.ZERO
	_fled_from = NO_CELL
	world.foes.on_enemy_frightened(self)
	# It looks at what frightened it, then turns to run.
	facing = Gait.dir_of(to_player)
	_play("idle")
	if mark != null:
		mark.visible = false
	if fright_mark == null:
		fright_mark = _fright_cue()
		add_child(fright_mark)
	_place_bubble(fright_mark.get_child(0) as Control)
	var still := GameState.settings.reduce_motion
	fright_mark.visible = true
	fright_mark.modulate.a = 1.0
	fright_mark.position = Vector2.ZERO
	_drop.position.y = DROP_FROM
	if _fright_tween != null:
		_fright_tween.kill()
	_fright_tween = fright_mark.create_tween()
	if not still:
		# A shiver a whole pixel either way (the art's pixels stay square),
		# while the drop runs down beside the "!" a pixel at a time.
		for i in 6:
			_fright_tween.tween_callback(func() -> void: fright_mark.position.x = SHIVER if i % 2 == 0 else -SHIVER)
			_fright_tween.tween_interval(0.06)
		_fright_tween.tween_callback(func() -> void: fright_mark.position.x = 0.0)
		var run := _drop.create_tween()
		run.tween_method(func(y: float) -> void: _drop.position.y = 2.0 * roundf(y / 2.0), DROP_FROM, DROP_FROM + 6.0, 0.5)
		_flinch(to_player)
	_fright_tween.tween_interval(0.5 if not still else 1.0)
	_fright_tween.tween_property(fright_mark, "modulate:a", 0.0, 0.25)


## The fright's cue: the pale "!" in its bubble, and a drop of sweat at its
## side. The drop rides in the bubble, which is drawn at half size: drawn
## twice its own size there, its pixels are the art's.
func _fright_cue() -> Node2D:
	var cue := Node2D.new()
	var bubble := _bubble(Juice.FRIGHT_INK)
	cue.add_child(bubble)
	_drop = Sprite2D.new()
	_drop.texture = Juice.sweat_drop()
	_drop.scale = Vector2.ONE * 2.0
	bubble.add_child(_drop)
	bubble.resized.connect(func() -> void: _drop.position.x = bubble.size.x + 8.0)
	Lights.unshade(cue)
	return cue


## A start back from the hero: taller for a blink (Juice's set-off), leaning
## away, then back to its shape, its feet on the ground throughout; done a
## little before it runs.
func _flinch(to_player: Vector2) -> void:
	var shape := Juice.SET_OFF
	var back := -to_player.normalized() * 2.0 + Vector2(0, Juice.FEET * _rest_scale.y * (1.0 - shape.y))
	_flinch_tween = sprite.create_tween()
	_flinch_tween.tween_property(sprite, "scale", _rest_scale * shape, 0.05)
	_flinch_tween.parallel().tween_property(sprite, "position", _rest_at + back, 0.05).set_ease(Tween.EASE_OUT)
	_flinch_tween.tween_property(sprite, "scale", _rest_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flinch_tween.parallel().tween_property(sprite, "position", _rest_at, 0.2)


## A flinch cut short (a blow lands): the sprite back to its own shape.
func _end_flinch() -> void:
	if _flinch_tween != null and _flinch_tween.is_valid():
		_flinch_tween.kill()
		sprite.scale = _rest_scale
		sprite.position = _rest_at


## Away from the hero a cell at a time over open ground (Packs.flight_step);
## a body in the way (a packmate, the hero) shuts that cell and it tries
## another; with nowhere left to run, it turns and fights.
func _flee(to_player: Vector2) -> void:
	var here := Vector2i((global_position / Packs.TILE).floor())
	if here != _fled_from:
		_taken.clear()
		# Out of a step back across the hero's way (round a wall's end), not
		# straight back again: two cells would trade it to and fro.
		if _fled_from != NO_CELL and Vector2(_step).dot(to_player) > 0:
			_taken.append(_fled_from)
		_fled_from = here
	if stuck_for > STUCK_SECONDS and _step != Vector2i.ZERO:
		_taken.append(here + _step)
		stuck_for = 0.0
	_step = Packs.flight_step(world.map, region, global_position, global_position + to_player, _taken)
	if _step == Vector2i.ZERO:
		at_bay = true
		notice()
		return
	velocity = (Packs.middle(here + _step) - global_position).normalized() * FLEE_SPEED


## Whether `fighter` runs from a hero of `hero_level` instead of fighting
## (PIX-251): far enough below the hero (Packs.outmatched, an elite counting
## higher), but never a boss, a Deep Hunt warden (a boss under the deep's
## name) or a named monster, and never one `held` to its fight
## (held_to_fight).
static func flees_from(fighter: Dictionary, hero_level: int, held := false) -> bool:
	if held or Bestiary.fights_like_boss(fighter):
		return false
	return Packs.outmatched(Bestiary.level_of(fighter), bool(fighter["elite"]), hero_level)


## Bound to its fight whatever the levels (PIX-251): sent at the escort's
## wagon, one of the Night of Ash's foes (the scavenger at its meal, the
## waves in the village), a mimic just burst from its chest, or the dead a
## boss raised at its side.
func held_to_fight() -> bool:
	return _hunts_wagon() or has_meta("prologue") or has_meta("prologue_wave") or woken or is_in_group("summoned")


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


## Too far from home or behind, or far enough from a hero it ran from
## (PIX-251): back home, deaf to the hero on the way.
func _give_up() -> void:
	mode = "homeward"
	hunting = false
	at_bay = false
	tell_left = -1.0


## Whether `fighter` gives up the chase: too far from its home or the hero
## (Packs.gives_up), but never a boss or a named monster (PIX-232): walking
## off a few tiles used to send it home and make it whole again.
static func gives_up(fighter: Dictionary, home_at: Vector2, at: Vector2, hero: Vector2) -> bool:
	return not Bestiary.fights_like_boss(fighter) and Packs.gives_up(home_at, at, hero)


## Home again: whole, and watching.
func _settle() -> void:
	mode = "idle"
	woken = false
	fighter["hp"] = fighter["maxHp"]
	health_bar.visible = false
	health_bar_back.visible = false
	health_bar.size.x = bar_width


## Lies down to sleep by its camp's fire (`on`), or gets up (PIX-252): the
## world's choice by the hour (Foes.keep_hours), made where nobody sees it.
## Its breath slows and a "Z" drifts up off it; it no longer wanders.
func set_asleep(on: bool) -> void:
	asleep = on
	if sprite != null:
		sprite.speed_scale = SLEEP_BREATH if on else 1.0
	if on and _sleep_mark == null:
		_sleep_mark = _sleep_cue()
		add_child(_sleep_mark)
	elif not on and _sleep_mark != null:
		_sleep_mark.queue_free()
		_sleep_mark = null


## Up from its sleep at once, and its pack with it (a fight by the fire
## wakes everyone).
func _wake() -> void:
	if not asleep:
		return
	set_asleep(false)
	world.foes.wake_pack(spawn_id)


## A sleeper's "Z" (a capital: the small one read as a 2): the UI's type at
## CameraRig.LABEL_SCALE, as the level tag, beside its head, drifting up and
## fading a whole art pixel at a time, then again - each sleeper on its own
## breath, not in step with its pack; still with Reduce motion. Lit at night.
func _sleep_cue() -> Label:
	var cue := UiStyle.strong("Z", 16, UiStyle.CREAM)
	cue.add_theme_color_override("font_outline_color", UiStyle.NIGHT)
	cue.add_theme_constant_override("outline_size", 4)
	cue.scale = Vector2.ONE * CameraRig.LABEL_SCALE
	cue.z_index = 10
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rest := Vector2(3.0, -20.0 * _rest_scale.y - 2.0)
	cue.position = rest
	Lights.unshade(cue)
	if not GameState.settings.reduce_motion:
		var rise := func(t: float) -> void:
			cue.position = rest + Vector2(roundf(t * 3.0), -roundf(t * 6.0))
			cue.modulate.a = 1.0 - t * t
		var drift := cue.create_tween().set_loops()
		drift.tween_method(rise, 0.0, 1.0, SLEEP_DRIFT_SECONDS)
		drift.tween_interval(SLEEP_PAUSE_SECONDS)
		drift.custom_step(randf() * (SLEEP_DRIFT_SECONDS + SLEEP_PAUSE_SECONDS))
	return cue


## A step this way or that, never past the leash.
func _wander(delta: float) -> void:
	if feeding or asleep:
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
	# Struck in its sleep (PIX-252): up, and its pack with it, even if the
	# blow is its last.
	_wake()
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
	# A named monster falls as a boss does (PIX-232), not just a boss.
	if dying and Bestiary.fights_like_boss(fighter):
		world.foes.boss_fell(self)
	else:
		world.camera_rig.hit_stop(KILL_STOP if dying else HIT_STOP)
	world.camera_rig.shake(2.5 if dying or crit else 1.5, 0.1)
	# The camera answers a crit or a killing blow with a little punch.
	if dying or crit:
		world.camera_rig.punch(global_position - from)
	# Struck from anywhere, it turns on the hero at once; struck as it runs,
	# it stands and fights where it is (PIX-251).
	if not dying and mode != "chase":
		if mode == "flee":
			at_bay = true
			fright_mark.visible = false
			_end_flinch()
		mode = "chase"
		if not hunting:
			hunting = true
			world.foes.on_enemy_noticed(self)
	if not dying and ailments.inflict(infliction, GameState.roll):
		Sound.play_ui("ail")
		world.messages.log_line(Text.t("%s is afflicted by %s!") % [fighter["name"], Ailments.label(infliction["kind"])])


func _lose(damage: int, color: Color, crit := false) -> void:
	fighter["hp"] = maxi(0, int(fighter["hp"]) - damage)
	world.fx.float_number(damage, global_position + Vector2(0, -18), color, crit)
	health_bar.size.x = bar_width * fighter["hp"] / fighter["maxHp"]
	# A boss's health is on the boss bar across the screen's top (PIX-210).
	health_bar.visible = not world.foes.fights_like_boss(self)
	health_bar_back.visible = health_bar.visible
	if fighter["hp"] == 0:
		_die()


func _die() -> void:
	dying = true
	world.foes.on_enemy_died(self)
	if fright_mark != null:
		fright_mark.visible = false
	collision_layer = 0
	collision_mask = 0
	hurtbox.collision_layer = 0
	health_bar.visible = false
	health_bar_back.visible = false
	gait.halt()
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


## Anything but the walk (the gait's, PIX-243) takes it out of its stride.
func _play(anim: String) -> void:
	gait.halt()
	var name := PunyArt.pick(sprite.sprite_frames, anim, facing)
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)
