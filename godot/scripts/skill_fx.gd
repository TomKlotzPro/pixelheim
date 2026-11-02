class_name SkillFx
extends Node2D
## areas: combat
## Each skill's own look and the weapons' (PIX-396), from Shade's Puny Skills
## strips as icons.json's skill_fx maps them: a skill plays its icon's
## theme's - a bolt flying from the hero to each foe it strikes and what lands
## on it, or what rises round the hero for a heal - the bow looses an arrow,
## the staff a small bolt, and every landed blow plays a small impact. Drawn
## at 1x on the world's pixel grid (a quarter turn at most, whole pixels),
## glows added as light, from a pool of sprites. Nothing is drawn without the
## paid pack or with motion reduced: callers keep their soft glow then. A
## child of WorldFx.

## The strips' pace.
const FPS := 12.0
## Sprites kept for a busy fight's bolts and blows; past them the oldest is
## taken back.
const POOL := 24
## Where on a fighter a strip is centred: its 16 px frame from the chest to
## the feet.
const ON_BODY := Vector2(0, -4)
const Z := 6
## A skill's blow lands as it's cast (Player.cast deals it at once): its bolt
## crosses in the white flash the blow gives the foe, so it reaches the foe
## while the foe still flashes.
const FLIGHT := Juice.FLASH_SECONDS
## The impact sits under the blow's flash, knockback and stop.
const IMPACT_ALPHA := 0.8

## Held while a skill deals its blows (Player.cast): its own strips are its
## impact.
var impacts_held := false
## The strips asked for on this visit, each once, in order, and how many
## sprites were drawn (none without the pack or with motion reduced): the
## harness's skillfx=.
var asked: Array[String] = []
var drawn := 0
var _pool: Array[AnimatedSprite2D] = []
## The next to take back when every sprite is busy.
var _oldest := 0


## A skill's strips as it's cast: round the hero for a heal; for a blow, its
## bolt to each foe struck then what lands on it (on the foe at once without
## a bolt). False when nothing could be drawn.
func cast(skill: Dictionary, hero: Node2D, targets: Array) -> bool:
	var look := ItemIcons.skill_look(String(skill["name"]))
	if skill["kind"] == "heal":
		_note(look["self"])
		return play(look["self"], hero) != null
	_note(look["fly"])
	_note(look["hit"])
	var shown := false
	for foe: Node2D in targets:
		if look["fly"] != "":
			shown = fly(look["fly"], hero.global_position, foe, foe.global_position, FLIGHT, look["hit"]) or shown
		else:
			shown = play(look["hit"], foe) != null or shown
	return shown


## The weapon's own (skill_fx's swings: the bow's arrow, the staff's bolt)
## from the hero to `target` (or `end`, a miss) in `seconds`, tinted; false
## when the weapon has none or it can't be drawn.
func swing(weapon: String, from: Vector2, target: Node2D, end: Vector2, seconds: float, tint := Color.WHITE) -> bool:
	var strip := String(ItemIcons.skill_fx().get("swings", {}).get(weapon, ""))
	_note(strip)
	return fly(strip, from, target, end, seconds, "", tint)


## A landed blow's small impact on whoever took it (Enemy.take_hit,
## Player.take_hit), a little faint under its flash.
func impact(who: Node2D) -> void:
	if impacts_held:
		return
	var strip := String(ItemIcons.skill_fx().get("impact", ""))
	_note(strip)
	play(strip, who, Vector2.ZERO, IMPACT_ALPHA)


## A strip played once on the fighter `on`, following it as it's knocked
## about (or where `at` stands, with none); back in the pool when it ends.
## Null when it can't be drawn.
func play(strip: String, on: Node2D, at := Vector2.ZERO, alpha := 1.0) -> AnimatedSprite2D:
	var frames := _frames(strip, false)
	if frames == null:
		return null
	var sprite := _take(strip, frames)
	if is_instance_valid(on):
		sprite.set_meta("on", on)
		at = on.global_position
	sprite.position = (at + ON_BODY).round()
	sprite.modulate.a = alpha
	sprite.play()
	return sprite


## The strips playing on a fighter keep to it, on whole pixels.
func _process(_delta: float) -> void:
	for sprite in _pool:
		if sprite.visible and sprite.has_meta("on") and is_instance_valid(sprite.get_meta("on")):
			sprite.position = ((sprite.get_meta("on") as Node2D).global_position + ON_BODY).round()


## A looping strip flying from `from` to `target` (where it is as it flies;
## `end` once it's gone, or for a miss) in `seconds`, turned by quarter turns
## the way it goes (Shade draws them pointing up), then `hit` where it lands.
func fly(strip: String, from: Vector2, target: Node2D, end: Vector2, seconds: float, hit := "", tint := Color.WHITE) -> bool:
	var frames := _frames(strip, true)
	if frames == null:
		return false
	_flight(_take(strip, frames), from, target, end, seconds, hit, tint)
	return true


## The flight itself (the test flies a sprite of its own).
func _flight(sprite: AnimatedSprite2D, from: Vector2, target: Node2D, end: Vector2, seconds: float, hit := "", tint := Color.WHITE) -> void:
	var goal := func() -> Vector2: return target.global_position if is_instance_valid(target) else end
	sprite.rotation = snappedf((goal.call() - from).angle() + PI / 2.0, PI / 2.0)
	sprite.modulate = tint
	var path := func(t: float) -> void: sprite.position = (from.lerp(goal.call(), t) + ON_BODY).round()
	path.call(0.0)
	sprite.play()
	var tween := sprite.create_tween()
	tween.tween_method(path, 0.0, 1.0, seconds)
	tween.tween_callback(func() -> void:
		sprite.hide()
		if hit != "":
			play(hit, target if is_instance_valid(target) else null, end))
	sprite.set_meta("tween", tween)


## A strip asked for, drawn or not.
func _note(strip: String) -> void:
	if strip != "" and strip not in asked:
		asked.append(strip)


## A strip's frames, or null when it can't be drawn: no paid pack, or motion
## reduced (none at all, rather than still frames).
func _frames(strip: String, loop: bool) -> SpriteFrames:
	if strip == "" or GameState.settings.reduce_motion:
		return null
	return ItemIcons.effect(strip, FPS, loop)


## A sprite from the pool, wearing `strip`: a spare, a new one while the pool
## has room, else the oldest taken back (its flight dropped).
func _take(strip: String, frames: SpriteFrames) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = null
	for spare in _pool:
		if not spare.visible:
			sprite = spare
			break
	if sprite == null and _pool.size() < POOL:
		sprite = AnimatedSprite2D.new()
		sprite.z_index = Z
		sprite.animation_finished.connect(sprite.hide)
		add_child(sprite)
		_pool.append(sprite)
	elif sprite == null:
		sprite = _pool[_oldest]
		_oldest = (_oldest + 1) % POOL
	if sprite.has_meta("tween") and (sprite.get_meta("tween") as Tween).is_valid():
		(sprite.get_meta("tween") as Tween).kill()
	if sprite.has_meta("on"):
		sprite.remove_meta("on")
	sprite.sprite_frames = frames
	sprite.animation = &"default"
	sprite.frame = 0
	# Bright at night: a glow added as light, the rest as Shade drew them.
	sprite.material = Lights.glow() if strip in ItemIcons.skill_fx().get("glow", []) else Lights.unshaded()
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.show()
	drawn += 1
	return sprite
