extends Node
## areas: combat field
## A common foe's own trick as it plays (PIX-489), riding on the enemy (its
## parent) as an elite's brain does: the slime bursts into two small ones,
## the dire wolf circles out of reach and darts in to bite (a pack takes
## turns), the goblin snatches gold with a bite and runs, the skeleton falls
## to a pile of bones that rattles and rises once, the ghost struck twice
## fades and comes back beside the hero, the crab lifts its claws and turns
## blows from the front. Tricks holds the rules and combat.json's "tricks"
## the numbers; the enemy asks where it stands (stand), whether it may bite
## (may_bite), what a blow does (takes, hurt) and what its fall is (falls,
## died). Every trick that hurts or costs is told: the wolf crouches before
## its dart and its bite has the bite's own tell, as the goblin's has.

const TILE := 16.0
## A faded ghost, see-through.
const FADED := 0.3
## A crab's claws up: its shell's cold shine, how far it rears and how
## tall it stands as it does (the claws thrown up, then held), and where
## the glint catches them, over its sprite's top (PIX-493's playtest: the
## weakest of the six tells, a slow 2 px lift and a tint).
const SHELL_TINT := Color(0.75, 0.9, 1.4)
const SHELL_LIFT := 3.0
const SHELL_THROWN := Vector2(1.0, 1.3)
const SHELL_HELD := Vector2(1.0, 1.15)
const GLINT_SIZE := 5
## A crouching wolf's eyes, as its sheet draws them, and how bright they
## shine in the dark (PIX-493's playtest: black on dark, the crouch could
## not be read at night).
const EYE := Color8(243, 214, 0)
const EYE_SHINE := Color(1.0, 0.95, 0.55)
## Where a goblin holds the coin it took, from its feet.
const COIN_AT := Vector2(7, -9)
## A slime's halves can't be struck for this long as they burst out.
const BURST_SECONDS := 0.35
## A wolf's dart is over once it is this near its circle again, or after
## this long.
const BACK_OUT := 4.0
const AWAY_SECONDS := 1.0

var enemy: CharacterBody2D
var world: Node2D
## Its kind's entry in combat.json's "tricks", and which trick that is.
var trick: Dictionary
var kind := ""
## What it is doing, "" for nothing: a wolf's "crouch", "in", "back" and
## "away"; a goblin's "run"; a skeleton's "pile"; a ghost's "shimmer" and
## "gone"; a crab's "raise" and "up". How long that has left, and how long
## until the trick is ready again.
var state := ""
var left := 0.0
var ready_in := 0.0
## A wolf alone circles this way round (1 or -1), and is dashing.
var _turn := 1.0
var _dashing := false
## The coins a goblin took (once a goblin), and the coin in its grip.
var carried := 0
var _coin: Sprite2D
## A skeleton's bones where they lie, and whether it has risen (once).
var risen := false
var _pile: Sprite2D
var _pile_at := Vector2.ZERO
var _rattled := false
## When the last blows landed on a ghost, when it last came back, and where
## it stood as it faded.
var _struck: Array[float] = []
var _faded_at := -100.0
var _from := Vector2.ZERO
## The way a crab's claws are raised, and the pose's tween.
var _front := Vector2.ZERO
var _pose: Tween
## A crouching wolf's eyes, shining over its sprite.
var _eyes: Sprite2D
static var _eye_masks := {}
static var _star: ImageTexture


func _ready() -> void:
	enemy = get_parent()
	world = enemy.world
	trick = Tricks.of(enemy.fighter)
	kind = String(trick["trick"])
	# The first one a little into the fight, never as it opens.
	ready_in = 0.4 if kind == "hitrun" else 1.2


func _physics_process(delta: float) -> void:
	if enemy.dying:
		return
	match kind:
		"hitrun":
			_hit_and_run(delta)
		"snatch":
			_run_with_gold(delta)
		"rise":
			_rattle(delta)
		"fade":
			_fade(delta)
		"shell":
			_shell(delta)


## Where the foe stands rather than at `spot`, its place in the ring round
## the hero `to_player` away (Vector2.INF: straight at them). A wolf keeps
## out on its circle, holds while it crouches or has just bitten, and goes
## straight in on its dart.
func stand(spot: Vector2, to_player: Vector2) -> Vector2:
	if kind != "hitrun":
		return spot
	match state:
		# Its bite done it stays on the hero a moment: a blow's shove doesn't
		# put it out of the blade's reach, where no fight could be had with it.
		"in", "back":
			return Vector2.INF
		"crouch":
			return enemy.global_position
	var hero := enemy.global_position + to_player
	var out := _on_leash(Tricks.circle_spot(hero, enemy.global_position, spot, _turn, trick))
	if Packs.walks_straight(world.map, hero, out):
		return out
	# A wall where its circle runs: its place in the ring as it is, or alone
	# round the other way, or where it stands.
	if spot != Vector2.INF:
		return _on_leash(spot)
	_turn = -_turn
	out = _on_leash(Tricks.circle_spot(hero, enemy.global_position, spot, _turn, trick))
	return out if Packs.walks_straight(world.map, hero, out) else enemy.global_position


## A wolf's place out on its circle never takes it past its leash
## (PIX-493: its run back out past a hero who had rolled away carried it
## too far from home, and it gave the fight up); at bay it has none.
func _on_leash(spot: Vector2) -> Vector2:
	return spot if enemy.at_bay else Tricks.leashed(spot, enemy.home)


## Whether it may tell a bite now: a wolf only on its dart; a ghost come
## back beside the hero (most often behind them) only `holds` seconds after,
## so with the bite's own tell the hero has time to turn (it bit 0.45 s
## after it showed).
func may_bite() -> bool:
	if kind == "fade":
		return GameClock.seconds() - _faded_at >= float(trick["holds"])
	return kind != "hitrun" or state == "in"


## Whether the enemy's sprite is held in a pose of the trick's.
func posed() -> bool:
	return kind == "shell" and state != ""


## Its bite came (`landed`: it drew blood): a wolf stays a moment, then runs
## back out; a goblin that drew blood snatches gold, once, and runs with it.
func bit(landed: bool) -> void:
	if kind == "hitrun" and state == "in":
		state = "back"
		left = float(trick["linger"])
	elif kind == "snatch" and landed and carried == 0 and _coin == null:
		var taken: int = GameState.spoils.snatch(Bestiary.level_of(enemy.fighter), trick)
		if taken <= 0:
			return
		carried = taken
		world.foes.showed(enemy, "snatch")
		Sound.play("coin_gain")
		world.fx.float_text(Text.t("-%d gold") % taken, enemy.global_position + WorldFx.OVER_FOE, UiStyle.GOLD)
		# The coin shows in its grip while it has it.
		_coin = Sprite2D.new()
		_coin.texture = UiStyle.coin()
		# The purse's coin at the size a win's floats draw it.
		_coin.scale = Vector2.ONE * WorldFx.GAIN_ICON
		_coin.position = COIN_AT
		_coin.z_index = 10
		Lights.unshade(_coin)
		enemy.add_child(_coin)
		enemy.run_off()
		state = "run"
		left = float(trick["runs"])


## What a blow of `damage` from `from` does to it: a crab's raised shell
## turns most of one from the front.
func takes(damage: int, from: Vector2) -> int:
	if kind == "shell" and state == "up":
		return Tricks.shelled(damage, _front, from - enemy.global_position, trick)
	return damage


## A blow landed and it still stands: a ghost struck twice in a moment
## shimmers, the tell that it is about to fade.
func hurt() -> void:
	if kind != "fade" or state != "":
		return
	_struck.append(GameClock.seconds())
	if _struck.size() > int(trick["hits"]):
		_struck.pop_front()
	if not Tricks.fades(_struck, _faded_at, trick):
		return
	state = "shimmer"
	left = float(trick["tell"])
	enemy.drop_tell()
	enemy.begin_cast()
	_from = enemy.global_position
	world.foes.showed(enemy, "fade")
	Sound.play("dodge")
	_pose = enemy.sprite.create_tween().set_loops(2)
	_pose.tween_property(enemy.sprite, "modulate", Color(1.5, 1.7, 2.0, 1.0), left / 4.0)
	_pose.tween_property(enemy.sprite, "modulate", Color(1.0, 1.0, 1.0, 0.5), left / 4.0)


## Whether its fall is no death yet: a skeleton falls to a pile of bones,
## once, its XP and gold kept for when it is truly done.
func falls() -> bool:
	if kind != "rise" or risen or state == "pile":
		return false
	state = "pile"
	left = float(trick["seconds"])
	enemy.fall_to_pile()
	_lay_pile()
	world.foes.showed(enemy, "pile")
	Sound.play(Sound.of_family("kill", String(enemy.fighter["id"])))
	Sound.play(Sound.voice_for(String(enemy.fighter["id"]), "death"))
	world.fx.dust(enemy.global_position)
	return true


## It is truly done, before the world pays out: a slime bursts into its
## small ones, a goblin gives back what it took and half again (in its
## gold, so it floats up "+N gold" as any kill's), a struck pile scatters.
func died() -> void:
	match kind:
		"split":
			world.foes.showed(enemy, "split")
			var count := int(trick["count"])
			# Side by side across the way to the hero, never toward them: of two
			# left and right of a slime beside the hero, one came out inside
			# them (PIX-497).
			var hero: Vector2 = world.player.global_position
			var across := (enemy.global_position - hero).orthogonal().normalized() if enemy.global_position != hero else Vector2.RIGHT
			for i in count:
				var at := enemy.global_position + across * (i - (count - 1) / 2.0) * 14.0
				if not world.map.is_walkable(Packs.cell_of(at)):
					at = enemy.global_position
				var half: Node = world.foes.spawn_of(enemy, Tricks.small(enemy.fighter, trick), at)
				# The blow that burst it doesn't sweep them up as they come out.
				half.burst_out(BURST_SECONDS)
				# They come at the hero after the "!" and the hop, as any foe
				# (one far below them runs on its own).
				if not enemy.flees_from(half.fighter, GameState.hero.level, half.held_to_fight()):
					half.notice()
		"snatch":
			if carried > 0:
				enemy.add_gold(Tricks.given_back(carried, trick))
				_coin.visible = false
		"rise":
			if state == "pile":
				world.fx.dust(enemy.global_position)
				_pile.create_tween().tween_property(_pile, "modulate:a", 0.0, 0.3)
		# Slain mid-crouch or mid-guard: no eyes over its fall, no stretch.
		"hitrun":
			_end_dart()
		"shell":
			if _pose != null:
				_pose.kill()
			enemy.sprite.scale = enemy.rest_scale


## A stun breaks what it was telling: a wolf's crouch, a crab's claws. True
## if there was anything to break.
func interrupt() -> bool:
	if kind == "hitrun" and state != "":
		var told := state == "crouch"
		_end_dart()
		return told
	if kind == "shell" and state != "":
		_lower()
		return true
	return false


## The wolf: out on its circle until its turn, then a crouch (the tell), the
## dart in, the bite (told as any bite), a moment there and out again fast.
func _hit_and_run(delta: float) -> void:
	if enemy.mode != "chase" or enemy.ailments.is_stunned():
		_end_dart()
		return
	var hero: Vector2 = world.player.global_position
	var apart := enemy.global_position.distance_to(hero)
	var circle := float(trick["circle"]) * TILE
	left -= delta
	match state:
		"":
			ready_in -= delta
			if ready_in <= 0.0 and apart <= circle + 1.5 * TILE and world.foes.take_turn(enemy):
				state = "crouch"
				left = float(trick["crouch"])
				world.foes.showed(enemy, "dart")
				Sound.play(Sound.of_family("foe_noticed", String(enemy.fighter["id"])))
				_pose = enemy.sprite.create_tween()
				_pose.tween_property(enemy.sprite, "scale", enemy.rest_scale * Vector2(1.15, 0.85), left * 0.7)
				_pose.tween_property(enemy.sprite, "scale", enemy.rest_scale, left * 0.3)
				_shine()
		"crouch":
			_shine()
			if left <= 0.0:
				_eyes.visible = false
				state = "in"
				left = float(trick["seconds"])
				_dash(true)
		"in":
			# A dart that never got its bite (the hero rolled away) is given up.
			if left <= 0.0 and enemy.tell_left < 0.0:
				_end_dart()
		"back":
			if left <= 0.0:
				state = "away"
				left = AWAY_SECONDS
				_dash(true)
		"away":
			if left <= 0.0 or apart >= circle - BACK_OUT:
				_end_dart()


## Dashing, a wolf runs `dash` times as fast (its pace, as a swift depth's).
func _dash(on: bool) -> void:
	if on == _dashing:
		return
	_dashing = on
	enemy.quicken(float(trick["dash"]) if on else 1.0 / float(trick["dash"]))


## A crouching wolf's eyes shine (the tell, by night as by day): the eyes
## of the frame it shows, drawn again over it and never darkened.
func _shine() -> void:
	var sprite: AnimatedSprite2D = enemy.sprite
	if _eyes == null:
		_eyes = Sprite2D.new()
		_eyes.material = Lights.unshaded()
		_eyes.modulate = EYE_SHINE
		sprite.add_child(_eyes)
	_eyes.texture = eyes_of(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
	_eyes.flip_h = sprite.flip_h
	_eyes.visible = true


## The eyes alone of a wolf's frame `drawn` (its sheet's EYE pixels, in
## white), kept by frame; a frame showing none (its back) gives an empty one.
static func eyes_of(drawn: Texture2D) -> ImageTexture:
	if not _eye_masks.has(drawn):
		var frame := drawn.get_image()
		frame.decompress()
		frame.convert(Image.FORMAT_RGBA8)
		var eyes := Image.create(frame.get_width(), frame.get_height(), false, Image.FORMAT_RGBA8)
		for y in frame.get_height():
			for x in frame.get_width():
				if frame.get_pixel(x, y).is_equal_approx(EYE):
					eyes.set_pixel(x, y, Color.WHITE)
		_eye_masks[drawn] = ImageTexture.create_from_image(eyes)
	return _eye_masks[drawn]


func _end_dart() -> void:
	if state == "":
		return
	if _eyes != null:
		_eyes.visible = false
	_dash(false)
	if _pose != null and _pose.is_running():
		_pose.kill()
		enemy.sprite.scale = enemy.rest_scale
	state = ""
	ready_in = float(trick["every"])
	world.foes.end_turn(enemy, float(trick["gap"]))


## The goblin runs with the gold a while, then turns back to fight for it
## (struck, cornered or calmed first, it is the enemy's to say).
func _run_with_gold(delta: float) -> void:
	if state != "run":
		return
	left -= delta
	if enemy.mode != "flee":
		state = ""
	elif left <= 0.0:
		state = ""
		enemy.turn_back()


## The pile rattles, harder as it is about to stand (the tell: strike it
## now), then rises with a share of its health.
func _rattle(delta: float) -> void:
	if state != "pile":
		return
	left -= delta
	var near := 1.0 - clampf(left / float(trick["seconds"]), 0.0, 1.0)
	if near > 0.4:
		if not _rattled:
			_rattled = true
			Sound.play(Sound.voice_for(String(enemy.fighter["id"]), "hurt"))
		var beat := int(left * lerpf(8.0, 20.0, near)) % 2
		_pile.modulate = Color.WHITE.lerp(Color(1.5, 1.6, 1.2), near * beat)
		if not GameState.settings.reduce_motion:
			_pile.position.x = _pile_at.x + (1.0 if beat == 0 else -1.0)
	if left > 0.0:
		return
	state = ""
	risen = true
	_pile.queue_free()
	enemy.rise(Tricks.risen(int(enemy.fighter["maxHp"]), trick))
	world.foes.showed(enemy, "rose")
	Sound.play(Sound.of_family("foe_noticed", String(enemy.fighter["id"])))
	world.fx.dust(enemy.global_position)
	var rest: Vector2 = enemy.rest_at
	var hop: Tween = enemy.sprite.create_tween()
	hop.tween_property(enemy.sprite, "position:y", rest.y - 5, 0.15).set_ease(Tween.EASE_OUT)
	hop.tween_property(enemy.sprite, "position:y", rest.y, 0.2).set_ease(Tween.EASE_IN)


## The bones where it fell, made of its own pixels (pile_image), on the
## ground its feet stood on.
func _lay_pile() -> void:
	var frames: SpriteFrames = enemy.sprite.sprite_frames
	var frame := frames.get_frame_texture(PunyArt.pick(frames, "idle", "down"), 0)
	var drawn := frame.get_image()
	var image := pile_image(drawn)
	var size: Vector2 = enemy.rest_scale
	_pile = Sprite2D.new()
	_pile.texture = ImageTexture.create_from_image(image)
	_pile.centered = false
	_pile.scale = size
	var ground: float = enemy.rest_at.y + (drawn.get_used_rect().end.y - drawn.get_height() / 2.0) * size.y
	_pile_at = Vector2(-roundf(image.get_width() * size.x / 2.0), ground - image.get_height() * size.y)
	_pile.position = _pile_at
	enemy.add_child(_pile)


## A fallen figure's bones, from its standing frame `drawn`: its head and
## shoulders set on the ground at the left, the rest of it, every other row,
## heaped behind at the right - its own pixels, whatever sheet it wears.
static func pile_image(drawn: Image) -> Image:
	var frame := drawn.duplicate() as Image
	frame.decompress()
	frame.convert(Image.FORMAT_RGBA8)
	var used := frame.get_used_rect()
	var head := used.size.y / 2 + 1
	var out := Image.create(used.size.x + 6, head, false, Image.FORMAT_RGBA8)
	var row := head - 1
	for y in range(used.end.y - 1, used.position.y + head - 1, -2):
		out.blit_rect(frame, Rect2i(used.position.x, y, used.size.x, 1), Vector2i(6, row))
		row -= 1
	out.blend_rect(frame, Rect2i(used.position.x, used.position.y, used.size.x, head), Vector2i.ZERO)
	return out


## The ghost shimmers, goes see-through - no blow finds it, nothing meets
## it - and comes back beside the hero, where its bite is told as any.
func _fade(delta: float) -> void:
	if state == "":
		return
	left -= delta
	if state == "shimmer":
		if left > 0.0:
			return
		state = "gone"
		left = float(trick["seconds"])
		enemy.vanish()
		enemy.sprite.modulate = Color.WHITE
	# Whatever else moved it on (a stun wearing off), it bides until it is back.
	enemy.begin_cast()
	enemy.modulate.a = FADED
	if left > 0.0:
		return
	var hero: Vector2 = world.player.global_position
	for spot in Tricks.beside(hero, _from, enemy.edge + 3.0):
		if world.map.is_walkable(Packs.cell_of(spot)) and Packs.walks_straight(world.map, hero, spot):
			enemy.global_position = spot
			enemy.reset_physics_interpolation()
			break
	state = ""
	enemy.appear()
	enemy.modulate.a = 1.0
	enemy.end_cast()
	_faded_at = GameClock.seconds()
	_struck.clear()
	Sound.play("whiff")
	world.fx.appear(enemy)


## The crab lifts its claws (the tell, on its sprite: reared up, its shell
## shining cold), holds them a while facing where the hero stood, and lowers
## them: the guard comes and goes, and its side and back are open all along.
func _shell(delta: float) -> void:
	if state == "":
		if enemy.mode != "chase" or enemy.ailments.is_stunned():
			return
		ready_in -= delta
		var to_hero: Vector2 = world.player.global_position - enemy.global_position
		if ready_in > 0.0 or enemy.tell_left >= 0.0 or to_hero.length() > float(trick["range"]) * TILE:
			return
		state = "raise"
		left = float(trick["tell"])
		_front = to_hero.normalized()
		enemy.begin_cast()
		enemy.face(to_hero)
		world.foes.showed(enemy, "shell")
		Sound.play("guard_raise")
		# Its claws at their highest: the walk's second frame, held.
		var sprite: AnimatedSprite2D = enemy.sprite
		enemy.gait.halt()
		sprite.play(PunyArt.pick(sprite.sprite_frames, "walk", enemy.facing))
		sprite.pause()
		sprite.frame = mini(1, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
		# Thrown up in the tell's first half and held: as long a tell, read
		# from its first frames.
		_pose = sprite.create_tween().set_parallel()
		_pose.tween_property(sprite, "position", enemy.rest_at + Vector2(0, -SHELL_LIFT), left * 0.5).set_ease(Tween.EASE_OUT)
		_pose.tween_property(sprite, "modulate", SHELL_TINT, left * 0.5)
		_pose.tween_property(sprite, "scale", enemy.rest_scale * SHELL_THROWN, left * 0.5).set_ease(Tween.EASE_OUT)
		_pose.chain().tween_property(sprite, "scale", enemy.rest_scale * SHELL_HELD, left * 0.5)
		_glint()
		return
	left -= delta
	if left > 0.0:
		return
	if state == "raise":
		state = "up"
		left = float(trick["seconds"])
	else:
		_lower()


## A glint off the claws as they rise: a small star over the crab's top
## opening and going out within the tell, bright at night too.
func _glint() -> void:
	var star := Sprite2D.new()
	star.texture = star_texture()
	star.material = Lights.unshaded()
	star.position = Vector2(0, enemy.crown_of(enemy.sprite.sprite_frames, enemy.rest_at, enemy.rest_scale.x) - SHELL_LIFT)
	star.z_index = 10
	star.scale = Vector2.ONE * 0.4
	enemy.add_child(star)
	var flash := star.create_tween()
	flash.tween_property(star, "scale", Vector2.ONE * 1.4, left * 0.5).set_ease(Tween.EASE_OUT)
	flash.tween_property(star, "modulate:a", 0.0, left * 0.5)
	flash.tween_callback(star.queue_free)


## The glint's star: a cross GLINT_SIZE pixels across, white.
static func star_texture() -> ImageTexture:
	if _star == null:
		var image := Image.create(GLINT_SIZE, GLINT_SIZE, false, Image.FORMAT_RGBA8)
		for i in GLINT_SIZE:
			image.set_pixel(i, GLINT_SIZE / 2, Color.WHITE)
			image.set_pixel(GLINT_SIZE / 2, i, Color.WHITE)
		_star = ImageTexture.create_from_image(image)
	return _star


func _lower() -> void:
	state = ""
	ready_in = float(trick["every"])
	if _pose != null:
		_pose.kill()
	_pose = enemy.sprite.create_tween().set_parallel()
	_pose.tween_property(enemy.sprite, "position", enemy.rest_at, 0.12)
	_pose.tween_property(enemy.sprite, "scale", enemy.rest_scale, 0.12)
	_pose.tween_property(enemy.sprite, "modulate", Color.WHITE, 0.12)
	enemy.end_cast()
	enemy.play("idle")
