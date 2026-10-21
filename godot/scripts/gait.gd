class_name Gait
extends RefCounted
## areas: combat town title
## How the cast walks (PIX-243): the hero, the villagers, the monsters and the
## wagon all step through their sheet's walk (PunyArt.WALKS) by the ground they
## cover, not by the clock, so their feet keep pace with the ground at any
## speed - a wolf ambling home steps slowly, the same wolf on the hunt quickly,
## a hero against a wall barely. The cycle carries on through a turn instead
## of starting over, a walker turning right round shows its side on the way,
## and a walker that stops holds its last step a breath before settling, so a
## hitch in the input or the chase never flashes the idle.
##
## Shade's Puny Characters draw eight ways, the four between the four too
## (PIX-293). A sheet that draws them walks a diagonal facing it and turns
## through them: a quarter turn shows the way between a moment, so down then
## right reads as one smooth step, not a snap. Tom found the hero sliding
## down and to the side still facing down, then turning a quarter in one
## frame as he let go of a key. The rest of the cast's sheets draw four ways
## and turn as before.
##
## The walk's frames are set here on physics ticks; the sprite's own clock
## stays paused while it walks. Its `speed_scale` still scales the walk, so 0
## holds one frame (the motion check's still frame of the walk, PIX-135).

## The walk never steps slower than this while it walks (into a wall, or a
## stick barely tilted, still reads as walking), nor quicker (a dodge's burst
## would blur).
const MIN_FPS := 4.0
const MAX_FPS := 20.0
## How long a stopped walker keeps its last step before it settles.
const SETTLE_SECONDS := 0.1
## How long a walker turning right round shows its side (or its front) first.
const TURN_SECONDS := 0.08
## How far a walker may head off the way it faces before it turns: past 53
## degrees. A diagonal (45) keeps the facing it had, so a stick held near one
## no longer flickers between two facings.
const TURN_HOLD := 0.6
const VECTORS := {"down": Vector2.DOWN, "right": Vector2.RIGHT, "up": Vector2.UP, "left": Vector2.LEFT}
const OPPOSITE := {"down": "up", "up": "down", "left": "right", "right": "left"}
## The eight ways a walker can be drawn, round from down as the rows of
## Shade's Puny Characters run (PIX-293): each way, then the one between it
## and the next.
const EIGHT := ["down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"]
## How far a walker drawn eight ways may head off the way it's drawn before
## it's drawn another: past 30 degrees, past the 22.5 halfway to the next,
## so a stick held near the line between two never flickers between them.
const EIGHT_HOLD := 0.866

var sprite: AnimatedSprite2D
## Ground per frame of the walk, in the world's pixels (the sheet's stride at
## the sprite's size).
var stride := 6.0
## Whether Reduce motion holds this walk level (PunyArt.WALKS' `level`).
var level := false
var walking := false
## Where in the cycle the walker is, in frames.
var phase := 0.0
## The way the walk is drawn: the way it heads, but for a moment on its side
## while it turns right round (or the way between, turning a quarter).
var shown := "down"
## The way the walk heads, which `shown` catches up with through a turn.
var heading := "down"
var _settle_left := 0.0
var _turn_left := 0.0


func _init(on: AnimatedSprite2D, spec: Dictionary, scale := 1.0) -> void:
	sprite = on
	var walk := PunyArt.walk_of(spec)
	stride = float(walk["stride"]) * scale
	level = walk["level"]


## A tick of walking `dir`, having covered `moved` px: the walk drawn that
## way, stepped on by the ground covered. A walk starts on its first frame -
## the rise as the weight comes off the back foot, before the first step.
func walk(dir: String, moved: float, delta: float) -> void:
	if not walking:
		walking = true
		phase = 0.0
		shown = dir
		heading = dir
		_turn_left = 0.0
	_settle_left = SETTLE_SECONDS
	_steer(dir, delta)
	var anim := PunyArt.pick(sprite.sprite_frames, "walk", shown)
	var count := sprite.sprite_frames.get_frame_count(anim)
	phase = fposmod(phase + frames_for(moved, stride, delta) * sprite.speed_scale, float(count))
	if sprite.is_playing():
		sprite.pause()
	if sprite.animation != anim:
		sprite.animation = anim
	var frame := mini(int(phase), count - 1)
	if sprite.frame != frame:
		sprite.frame = frame
	_lift(anim, frame)


## A tick standing still: the last step held SETTLE_SECONDS, then let go.
## True on the tick the walker settles, for the caller's idle (and spring).
func rest(delta: float) -> bool:
	if not walking:
		return false
	_settle_left -= delta
	if _settle_left > 0.0:
		return false
	halt()
	return true


## Out of the walk at once (a swing, a hurt, a stun): the body back on its
## feet, any turn finished.
func halt() -> void:
	walking = false
	if _turn_left > 0.0:
		shown = heading
	_turn_left = 0.0
	if level:
		sprite.offset.y = 0.0


## Turned by hand (a word with someone, an arrival, a swing): drawn that way
## from now, whatever way the walk left it.
func face(dir: String) -> void:
	shown = dir
	heading = dir
	_turn_left = 0.0


## Whether this walker's sheet draws the ways between the four (PIX-293).
func eight_ways() -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation("walk_down_right")


## The way to draw a walk heading along `motion` whose facing is `way`: one
## of the eight where the sheet draws them (PIX-293), else its facing.
func drawn_way(motion: Vector2, way: String) -> String:
	if not eight_ways():
		return way
	return steer_eight(heading if walking else shown, motion)


## Frames of the walk to step on for `moved` px this tick at `stride` px a
## frame, between MIN_FPS and MAX_FPS.
static func frames_for(moved: float, step: float, delta: float) -> float:
	return clampf(moved / maxf(step, 0.01), MIN_FPS * delta, MAX_FPS * delta)


## The way a walker faces heading along `motion`, having faced `was`: the
## same while it still heads within TURN_HOLD of it, else the motion's
## stronger axis (sideways on a tie, as before).
static func steer(was: String, motion: Vector2) -> String:
	if motion == Vector2.ZERO:
		return was
	if motion.normalized().dot(VECTORS.get(was, Vector2.ZERO)) >= TURN_HOLD:
		return was
	return dir_of(motion)


static func dir_of(motion: Vector2) -> String:
	if absf(motion.x) >= absf(motion.y):
		return "right" if motion.x >= 0 else "left"
	return "down" if motion.y >= 0 else "up"


## The side a walker shows turning right round from `from` to `to`, or ""
## for anything less: from one side to the other it faces down a moment,
## from front to back its right side.
static func through(from: String, to: String) -> String:
	if OPPOSITE.get(from, "") != to:
		return ""
	return "down" if from == "left" or from == "right" else "right"


## The way a walker heading along `motion` is drawn, eight ways, having been
## drawn `was` (PIX-293): the same while it still heads within EIGHT_HOLD
## of it, else the nearest of the eight. Two keys held are a diagonal.
static func steer_eight(was: String, motion: Vector2) -> String:
	if motion == Vector2.ZERO:
		return was
	var at := EIGHT.find(was)
	if at >= 0 and motion.normalized().dot(eight_vector(at)) >= EIGHT_HOLD:
		return was
	# Round from down (+90 degrees on the screen) in eighths of a turn.
	return EIGHT[posmod(roundi((PI / 2.0 - motion.angle()) / (PI / 4.0)), 8)]


## The way EIGHT[`index`] points, a unit vector on the screen (y down).
static func eight_vector(index: int) -> Vector2:
	return Vector2.from_angle(PI / 2.0 - index * PI / 4.0)


## The way a walker drawn eight ways shows a moment turning from `from` to
## `to` (PIX-293), or "" for a step to the next way: a quarter turn passes
## the way between, and more than that the way a quarter round from where
## it was - turning right round, the one facing the viewer (or the right
## side, from front to back, as `through`).
static func between(from: String, to: String) -> String:
	var a := EIGHT.find(from)
	var b := EIGHT.find(to)
	if a < 0 or b < 0:
		return ""
	# The shorter way round, in eighths: -4 (right round) to 3.
	var d := posmod(b - a + 4, 8) - 4
	match absi(d):
		2:
			return EIGHT[posmod(a + signi(d), 8)]
		3:
			return EIGHT[posmod(a + 2 * signi(d), 8)]
		4:
			var one := posmod(a + 2, 8)
			var other := posmod(a - 2, 8)
			var near_one := mini(one, 8 - one)
			var near_other := mini(other, 8 - other)
			if near_one == near_other:
				return "right"
			return EIGHT[one if near_one < near_other else other]
	return ""


func _steer(dir: String, delta: float) -> void:
	if _turn_left > 0.0:
		_turn_left -= delta
		heading = dir
		if _turn_left <= 0.0 or dir == shown:
			_turn_left = 0.0
			shown = dir
		return
	heading = dir
	if dir == shown:
		return
	var via := between(shown, dir) if eight_ways() else through(shown, dir)
	if via == "":
		shown = dir
		return
	shown = via
	_turn_left = TURN_SECONDS


## With Reduce motion the walk doesn't bob: a frame that rises is set down by
## its rise, whole pixels of the art, so the feet keep one line.
func _lift(anim: String, frame: int) -> void:
	if not level:
		return
	var rise := 0
	if GameState.settings.reduce_motion:
		var rises := PunyArt.rises(sprite.sprite_frames, anim)
		rise = rises[frame] if frame < rises.size() else 0
	sprite.offset.y = float(rise)
