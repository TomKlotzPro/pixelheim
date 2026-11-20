class_name Npc
extends AnimatableBody2D
## areas: town story
## A villager: their Puny sheet (PunyArt, PIX-130), a body the hero bumps
## into, and — for wanderers — an amble around the pacing loop, walking the
## way they step. Who they are and where they may step comes from Npcs; the
## world only hosts them.

const TILE := 16
## A pace every four beats: villagers amble roughly every 1.6 s.
const BEAT_SECONDS := 0.4
const STEP_SECONDS := 0.35
## After a step they look the way they walked this long before turning back
## to face the street (PIX-243: they used to snap round the moment they
## stopped).
const LOOK_SECONDS := 0.5
## Morvax's bench by the fountain (PIX-253 step 10): Shade's long bench in
## the Medieval Age atlas, its two ends, a little below his middle so he
## sits on the left of it with the right kept free (for Maren, if she ever
## sits down).
const BENCH: Array[int] = [1659, 1661]
const BENCH_AT := Vector2(0, 3)

## The body the hero bumps into (_ready says why this shape).
const BODY := Vector2(20, 17)

var world: World
var data: Dictionary
var home := Vector2i.ZERO
## The tile the villager occupies (or is stepping onto).
var cell := Vector2i.ZERO
var offsets: Array[Vector2i] = []
var sprite: AnimatedSprite2D
## Their walk (PIX-243): frames by the ground the step covers, two steps a
## cell, and the way the last step went.
var gait: Gait
var _step_dir := "down"
## Where they stood last tick, the way their idle faces, and how long until
## they turn it back toward the street.
var _was := Vector2.ZERO
var _facing := "down"
var _look_left := 0.0


func _ready() -> void:
	home = Vector2i(data["x"], data["y"])
	offsets = Npcs.offsets_for(data, world.map)
	cell = home + Npcs.pace_offset(data, offsets, _beat())
	position = _center(cell)
	reset_physics_interpolation()

	var art := PunyArt.villager(data["sprite"])
	var size: float = art.get("scale", 1.0)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.scale = Vector2.ONE * size
	sprite.position = Vector2(0, PunyArt.lift(art) * size)
	sprite.play(PunyArt.pick(sprite.sprite_frames, "idle", "down"))
	# Offset the idle phase per villager so the square doesn't breathe in unison.
	sprite.frame = Npcs.id_hash(data["id"]) % 2
	add_child(preload("res://scripts/enemy.gd").ground_shadow(sprite, size, sprite.position.y))
	# Their feet block the street lamps' light (PIX-490).
	add_child(NightShadowsLayer.occluder_of(NightShadows.FEET, NightShadows.FOLK))
	# Morvax's bench by the fountain (PIX-253 step 10): Shade's Medieval Age
	# bench behind him and on to the next cell east, when the pack is here.
	if data.get("bench", false) and PunyTown.available():
		for i in BENCH.size():
			var seat := Sprite2D.new()
			seat.texture = PunyProps.texture(BENCH[i])
			seat.position = BENCH_AT + Vector2(TILE * i, 0)
			add_child(seat)
	add_child(sprite)
	# Their mark keeps over their head as they turn (PIX-268).
	sprite.animation_changed.connect(_place_mark)
	gait = Gait.new(sprite, art, size)
	_was = position
	if Prologue.pinned(data, GameState.progression.prologue):
		_pin()

	# The body is the villager's feet and the ground before them, so the hero,
	# whose box is only their feet, stops a step away instead of standing half
	# inside them (from the south the hero's sprite covered the villager's).
	# It ends 6 px into the cell below: the hero, standing there to talk or
	# walking past along that row, clears it by a pixel. From there the
	# hero's head still hid a villager's feet (a Mini World one's whole
	# lower half): they're drawn over the hero instead (stands_over).
	# Either side it runs 10 px (PIX-484): the hero's feet stop 15 px off,
	# a pixel clear of a figure 14 px wide, and still walk the next column.
	# At 6 px (as wide as a Mini World villager, before everyone who talks
	# got a Puny figure of the hero's size, PIX-405) the hero stopped 11 px
	# off, half over Bram, Vex and Odo.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY
	shape.shape = rect
	shape.position = Vector2(0, 5.5)
	add_child(shape)
	body = shape
	# The bench's free end blocks its cell as he does his, with the art or
	# without it.
	if data.get("bench", false):
		var end := CollisionShape2D.new()
		end.shape = rect
		end.position = shape.position + Vector2(TILE, 0)
		add_child(end)


## Lying pinned under a burning beam on the Night of Ash (PIX-515: Bram
## stood in the street with no beam while his line said he lay under one).
## He lies on his back, head to the west: his standing figure turned on its
## side (the Medieval Age's folk are drawn only standing, and a Puny
## figure's fall is cut where no dye reaches: he fell in another man's
## clothes). The beam is AshArt's charred log lying east to west along his
## legs and lower body, as the Ash's fallen logs lie, his head and chest
## clear of its west end (turned north to south beside him it read as a
## burning fence post standing by a lump); FireArt's flames stand on its
## middle, clear of him and of its east end, with a blaze's light of its own.
## Where the figure's frame stands on the cell, turned.
const TURNED_AT := Vector2(-3, 4)
## Where the beam lies from his middle, where each flame stands on it (from
## its middle), and how far its light reaches.
const BEAM_AT := Vector2(9, 3)
const BEAM_FLAMES: Array[Vector2] = [Vector2(-3, 0), Vector2(3, 0)]
const BEAM_LIGHT := 44.0
## Where his mark's tail points, from the cell's middle: the top of his
## chest, as low as it goes without hiding him (a head higher, as over a
## villager standing, it was on the face of a hero come down the road).
const PINNED_MARK := Vector2(-3, 0)
## The beam's going (unpin): it shifts, then rolls away east, so far, fading.
const SHIFT := 2.0
const SHIFT_SECONDS := 0.25
const ROLL := 22.0
const ROLL_SECONDS := 0.6
## The beam while they lie under it, else null.
var beam: Node2D
var _stood := Vector2.ZERO


func _pin() -> void:
	_stood = sprite.position
	sprite.stop()
	sprite.rotation = -PI / 2.0
	sprite.position = TURNED_AT
	beam = Node2D.new()
	beam.position = BEAM_AT
	var timber := Sprite2D.new()
	timber.texture = AshArt.texture("beam")
	beam.add_child(timber)
	var size: Vector2i = FireArt.KINDS["lick"]
	for i in BEAM_FLAMES.size():
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = FireArt.frames("lick", i % FireArt.VARIANTS)
		flame.centered = false
		flame.offset = Vector2(-(size.x / 2), -size.y)
		flame.position = BEAM_FLAMES[i]
		flame.frame = i * 4
		flame.speed_scale = FireArt.pace({"cell": home, "frame": i}, GameState.settings.reduce_motion)
		flame.material = Lights.unshaded()
		beam.add_child(flame)
		flame.play()
	beam.add_child(Lights.blaze(Vector2.ZERO, BEAM_LIGHT))
	add_child(beam)


## The beam off them (the hero's shoulder to it: Interaction.talk): it
## shifts, rolls away and is gone, and they get up. With Reduce motion it
## only fades. It goes while the talk holds the world still.
func unpin() -> void:
	if beam == null or beam.process_mode == Node.PROCESS_MODE_ALWAYS:
		return
	beam.process_mode = Node.PROCESS_MODE_ALWAYS
	var tween := beam.create_tween()
	if not GameState.settings.reduce_motion:
		tween.tween_property(beam, "position:x", beam.position.x + SHIFT, SHIFT_SECONDS)
		tween.tween_property(beam, "position:x", beam.position.x + ROLL, ROLL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel()
	tween.tween_property(beam, "modulate:a", 0.0, ROLL_SECONDS).set_ease(Tween.EASE_IN)
	tween.tween_callback(_stand)


func _stand() -> void:
	beam.queue_free()
	beam = null
	sprite.rotation = 0.0
	sprite.position = _stood
	_idle("down")
	_place_mark()


## Home for the night (PIX-149): out of sight and out of the way.
var away := false
var body: CollisionShape2D
## Where they're headed on the square at dusk or on a festival day
## (PIX-159), or NOWHERE.
const NOWHERE := Vector2i(-1, -1)
var gather_at := NOWHERE
var _last_beat := -1
## What hangs over their head for the hero (PIX-240): the talk mark
## (Marks, PIX-289), a "!" with a quest to give, a "?" with one to hand in, a
## faded "?" while it's under way; gold when it's the main story's (a letter
## of Maren's carried to them, PIX-253 step 2, or her relics and a relic's
## hunt: Quests.mark_tells_story), parchment for a side quest. Looked at
## twice a second, not every frame.
const MARK_SECONDS := 0.5
## Each kind's glyph.
const MARK_GLYPHS := {"offer": "!", "letter": "!", "ready": "?", "waiting": "?"}
## Air between the mark's tail and the highest their head reaches.
const MARK_CLEAR := 1.0
var _mark: Sprite2D
## The mark showing, as "<kind> <tone>", or "".
var _mark_shown := ""
var _mark_left := 0.0


## Whether a villager at `at` is drawn over the hero at `hero` (PIX-348):
## the hero right below them, where the hero's head hid Maren, Hessa and
## Bram as they spoke.
static func stands_over(at: Vector2, hero: Vector2) -> bool:
	var below := hero - at
	return absf(below.x) < TILE and below.y > 0.0 and below.y <= TILE * 1.5


## Gone for the night, or back: back means at home, wherever the evening
## left them.
func set_away(gone: bool) -> void:
	away = gone
	visible = not gone
	body.set_deferred("disabled", gone)
	if not gone:
		gather_at = NOWHERE
		place_at(home + Npcs.pace_offset(data, offsets, _beat()))


## Straight to `at` (only ever where nobody's watching): not a walk.
func place_at(at: Vector2i) -> void:
	cell = at
	position = _center(cell)
	_was = position
	reset_physics_interpolation()


func _process(delta: float) -> void:
	if away:
		return
	if world.player != null:
		z_index = 1 if stands_over(position, world.player.position) else 0
	_mark_left -= delta
	if _mark_left <= 0.0:
		_mark_left = MARK_SECONDS
		_refresh_mark()
	if gather_at != NOWHERE:
		_walk_to_square()
		return
	if not data["wander"]:
		return
	var next: Vector2i = home + Npcs.pace_offset(data, offsets, _beat())
	# Never step onto the hero; wait for the next pace instead.
	if next == cell or next == world.player_cell:
		return
	_step_to(next)


## No mark over them while a scene has them (PIX-509: Maren kept her "!"
## through the dawn she speaks in).
var unmarked := false:
	set(value):
		unmarked = value
		_refresh_mark()


## Their quest mark as things stand: the right one, or none with the marks
## turned off in Options.
func _refresh_mark() -> void:
	var kind := ""
	var story := false
	# Nobody asks or hands in anything on the Night of Bells (PIX-253 step 9).
	if GameState.settings.quest_marks and GameState.progression.bells == Bells.NONE and not unmarked:
		var id := String(data.get("id", ""))
		kind = Quests.mark_for(id, GameState.progression.quests, GameState.pack.items, GameState.questing.quest_open)
		story = Quests.mark_tells_story(id, GameState.progression.quests, GameState.pack.items, GameState.questing.quest_open)
		# Maren with the whole story to tell and the fifth letter to give
		# (PIX-253 step 8): the main story's gold "!".
		if id == "elder" and Letters.fifth_due(GameState.progression, GameState.settlement):
			kind = "letter"
		# Morvax with his question (PIX-253 step 10): the same.
		if id == Homecoming.MORVAX and Homecoming.choice_due(GameState.progression, GameState.settlement):
			kind = "letter"
		# On the Night of Ash, the survivor its step waits on (PIX-426): where
		# the arrow and the map's goal point.
		if GameState.progression.prologue != Prologue.DONE and id == Prologue.goal(GameState.progression.prologue)["who"]:
			kind = "letter"
	var shown := "" if kind == "" else "%s %s" % [kind, mark_tone(kind, story)]
	if shown == _mark_shown:
		return
	_mark_shown = shown
	if _mark != null:
		_mark.queue_free()
		_mark = null
	if kind == "":
		return
	_mark = mark_sprite(kind, story)
	_place_mark()
	add_child(_mark)


## The talk mark for a mark of `kind` (Quests.mark_for), the main story's
## when `story`: drawn at the world's scale, over the people round it, and
## bright at night too (PIX-221).
static func mark_sprite(kind: String, story: bool) -> Sprite2D:
	var mark := Sprite2D.new()
	mark.texture = Marks.talk(MARK_GLYPHS[kind], mark_tone(kind, story))
	mark.centered = false
	mark.z_index = 10
	mark.material = Lights.unshaded()
	return mark


## A mark's tone (Marks.TALK_TONES): faded while a quest is under way, gold
## for the main story (a letter carried is always its), else parchment.
static func mark_tone(kind: String, story: bool) -> String:
	if kind == "waiting":
		return "waiting"
	return "gold" if story or kind == "letter" else "plain"


## The mark over their head the way they face now (PIX-268): they turn
## after a step (PIX-243), and a figure's head isn't always where its frame's
## middle is.
func _place_mark() -> void:
	if _mark != null and beam != null:
		_mark.position = Vector2(Marks.centred(_mark.texture.get_width(), PINNED_MARK.x), PINNED_MARK.y - _mark.texture.get_height())
	elif _mark != null:
		_mark.position = mark_spot(_mark.texture.get_size(), sprite.sprite_frames, sprite.animation, sprite.position, sprite.scale)


## Where a mark `size` pixels big goes over a figure drawn from `frames`
## playing `anim`, centred at `at` and drawn at `scale` (PIX-268): its middle
## (the glyph's two middle columns) on the head of the idle pose facing that
## way, in whole pixels; its tail's tip MARK_CLEAR over the highest their
## head reaches standing or walking, whichever way they face, so it neither
## bobs as they breathe, step and look about nor touches their head.
static func mark_spot(size: Vector2, frames: SpriteFrames, anim: String, at: Vector2, scale: Vector2) -> Vector2:
	var poses := []
	for way: String in PunyArt.DIRS:
		poses.append(PunyArt.pick(frames, "idle", way))
		poses.append(PunyArt.pick(frames, "walk", way))
	var head := Ink.head(frames, Ink.rest_pose(frames, anim), at, scale)
	return Vector2(Marks.centred(size.x, head.get_center().x), floorf(Ink.crown(frames, poses, at, scale) - MARK_CLEAR - size.y))


## A step a beat toward their spot on the square: the longer way first, the
## other if that's blocked; they wait where both are.
func _walk_to_square() -> void:
	var beat := _beat()
	if beat == _last_beat or cell == gather_at:
		return
	_last_beat = beat
	var to := gather_at - cell
	var tries: Array[Vector2i] = []
	if to.x != 0:
		tries.append(Vector2i(signi(to.x), 0))
	if to.y != 0:
		tries.append(Vector2i(0, signi(to.y)))
	if absi(to.y) > absi(to.x):
		tries.reverse()
	for step in tries:
		var next := cell + step
		if world.map.is_walkable(next) and not world.map.covered.has(next) and not world.map.portals.has(next) and next != world.player_cell:
			_step_to(next)
			return


func _step_to(next: Vector2i) -> void:
	var step := next - cell
	cell = next
	_step_dir = "down" if step.y > 0 else ("up" if step.y < 0 else ("right" if step.x > 0 else "left"))
	# Stepped on physics ticks, so the step is interpolated like any walk;
	# the gait draws it (_physics_process).
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", _center(cell), STEP_SECONDS)


## The walk on physics ticks, beside the step's tween (PIX-243): frames by
## the ground covered, the last step held a breath before they settle facing
## the way they went, then a look that way before they turn back to face the
## street - by their side, from their back.
func _physics_process(delta: float) -> void:
	if away or beam != null:
		return
	var moved := (position - _was).length()
	_was = position
	if moved > 0.0:
		gait.walk(_step_dir, moved, delta)
		return
	if gait.rest(delta):
		_idle(_step_dir)
		_look_left = LOOK_SECONDS
	elif not gait.walking and _facing != "down":
		_look_left -= delta
		if _look_left <= 0.0:
			var via := Gait.through(_facing, "down")
			_idle(via if via != "" else "down")
			_look_left = Gait.TURN_SECONDS


func _idle(dir: String) -> void:
	_facing = dir
	sprite.play(PunyArt.pick(sprite.sprite_frames, "idle", dir))


func _beat() -> int:
	return int(GameClock.seconds() / BEAT_SECONDS)


func _center(at: Vector2i) -> Vector2:
	return Vector2(at * TILE) + Vector2(TILE, TILE) / 2.0
