extends AnimatableBody2D
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

var world: Node2D
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
	# Their own face, though they share a sheet with others (PIX-206).
	sprite.self_modulate = Npcs.tint_of(String(data.get("id", "")))
	sprite.play(PunyArt.pick(sprite.sprite_frames, "idle", "down"))
	# Offset the idle phase per villager so the square doesn't breathe in unison.
	sprite.frame = Npcs.id_hash(data["id"]) % 2
	add_child(sprite)
	# Their mark keeps over their head as they turn (PIX-268).
	sprite.animation_changed.connect(_place_mark)
	gait = Gait.new(sprite, art, size)
	_was = position

	# The body is the villager's feet and the ground before them, so the hero,
	# whose box is only their feet, stops a step away instead of standing half
	# inside them (from the south the hero's sprite covered the villager's).
	# It ends 6 px into the cell below: the hero, standing there to talk or
	# walking past along that row, clears it by a pixel.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 17)
	shape.shape = rect
	shape.position = Vector2(0, 5.5)
	add_child(shape)
	body = shape


## Home for the night (PIX-149): out of sight and out of the way.
var away := false
var body: CollisionShape2D
## Where they're headed on the square at dusk or on a festival day
## (PIX-159), or NOWHERE.
const NOWHERE := Vector2i(-1, -1)
var gather_at := NOWHERE
var _last_beat := -1
## What hangs over their head for the hero (PIX-240): a "!" with a quest to
## give, a gold "?" with one to hand in, a grey "?" while it's under way;
## and the main story's, a letter of Maren's carried to them (PIX-253 step
## 2), a gold "!" ringed in gold. Looked at twice a second, not every frame.
const MARK_SECONDS := 0.5
## Gold for a quest to give or to hand in, grey while one is under way.
const MARK_COLORS := {"offer": Color("f2c14e"), "ready": Color("f2c14e"), "waiting": Color("a8a39a"), "letter": Color("f2c14e")}
## How far past its glyph's ink a mark draws: its dark line, a pixel; the
## main story's ring of gold and the dark round it, three.
const MARK_REACH := {"letter": 3}
var _mark: Node2D
var _mark_kind := ""
var _mark_text := ""
var _mark_left := 0.0


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


## Their quest mark as things stand: the right one, or none with the marks
## turned off in Options.
func _refresh_mark() -> void:
	var kind := ""
	if GameState.settings.quest_marks:
		kind = Quests.mark_for(String(data.get("id", "")), GameState.progression.quests, GameState.pack.items, GameState.questing.quest_open)
		# Maren with the whole story to tell and the fifth letter to give
		# (PIX-253 step 8): the main story's gold "!".
		if data.get("id", "") == "elder" and Letters.fifth_due(GameState.progression, GameState.settlement):
			kind = "letter"
	if kind == _mark_kind:
		return
	_mark_kind = kind
	if _mark != null:
		_mark.queue_free()
		_mark = null
	if kind == "":
		return
	_mark_text = "!" if kind in ["offer", "letter"] else "?"
	_mark = _outlined(_mark_text, MARK_COLORS[kind], int(MARK_REACH.get(kind, 1)))
	_mark.z_index = 10
	# Bright at night too (PIX-221).
	_mark.material = Lights.unshaded()
	_place_mark()
	add_child(_mark)


## The mark over their head the way they face now (PIX-268): they turn
## after a step (PIX-243), and a figure's head isn't always where its frame's
## middle is.
func _place_mark() -> void:
	if _mark != null:
		_mark.position = mark_spot(_mark_text, sprite.sprite_frames, sprite.animation, sprite.position, sprite.scale, int(MARK_REACH.get(_mark_kind, 1)))


## Where a mark of `text` goes over a figure drawn from `frames` playing
## `anim`, centred at `at` and drawn at `scale` (PIX-268): its glyph's ink
## centred on the head of the idle pose facing that way, in whole pixels (the
## label's box is no measure, Ink); its foot two pixels over the highest their
## head reaches standing or walking, whichever way they face, so it neither
## bobs as they breathe, step and look about nor touches their head. A mark
## drawn `reach` pixels past its ink (the main story's ring) stands as much
## higher, so the ring keeps the dark line's pixel of clearance too.
static func mark_spot(text: String, frames: SpriteFrames, anim: String, at: Vector2, scale: Vector2, reach := 1) -> Vector2:
	var ink := Ink.of_text(text, UiStyle.bold_font(), UiStyle.BODY_PX)
	var poses := []
	for way: String in PunyArt.DIRS:
		poses.append(PunyArt.pick(frames, "idle", way))
		poses.append(PunyArt.pick(frames, "walk", way))
	var head := Ink.head(frames, Ink.rest_pose(frames, anim), at, scale)
	return Vector2(Ink.centred(ink, head.get_center().x), floorf(Ink.crown(frames, poses, at, scale) - 1.0 - reach - ink.end.y))


## `text` in the UI's bold pixel face at its own size, outlined in the night
## by four dark copies a pixel off each way: the pixel face draws no outline
## of its own. With a `reach` of 3 (the main story's), a ring of gold round
## that line and the night round the ring, copies two and three pixels off
## (a diamond's way, like the map's gold diamond). The glyph itself is the
## last child. Each label sizes itself once it is in the tree, with its own
## face.
static func _outlined(text: String, color: Color, reach := 1) -> Node2D:
	var mark := Node2D.new()
	var rings: Array = []
	for far in range(reach, 0, -1):
		rings.append([_ring(far), color if far == 2 else UiStyle.NIGHT])
	rings.append([[Vector2.ZERO], color])
	for ring: Array in rings:
		for offset: Vector2 in ring[0]:
			var glyph := Label.new()
			glyph.text = text
			glyph.add_theme_font_override("font", UiStyle.bold_font())
			glyph.add_theme_font_size_override("font_size", UiStyle.BODY_PX)
			glyph.add_theme_color_override("font_color", ring[1])
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glyph.use_parent_material = true
			glyph.position = offset
			mark.add_child(glyph)
	return mark


## The offsets `far` steps off along the grid's lines (|x| + |y| = far): a
## pixel each way at 1, the four ways and the corners between at 2...
static func _ring(far: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for x in range(-far, far + 1):
		var y := far - absi(x)
		out.append(Vector2(x, y))
		if y != 0:
			out.append(Vector2(x, -y))
	return out


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
	if away:
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
