class_name Gait
extends RefCounted
## How the cast walks (PIX-243): the hero, the villagers, the monsters and the
## wagon all step through their sheet's walk (PunyArt.WALKS) by the ground they
## cover, not by the clock, so their feet keep pace with the ground at any
## speed - a wolf ambling home steps slowly, the same wolf on the hunt quickly,
## a hero against a wall barely. The cycle carries on through a turn instead
## of starting over, a walker turning right round shows its side on the way,
## and a walker that stops holds its last step a breath before settling, so a
## hitch in the input or the chase never flashes the idle.
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
## while it turns right round.
var shown := "down"
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


## Out of the walk at once (a swing, a hurt, a stun): the body back on its feet.
func halt() -> void:
	walking = false
	_turn_left = 0.0
	if level:
		sprite.offset.y = 0.0


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


func _steer(dir: String, delta: float) -> void:
	if _turn_left > 0.0:
		_turn_left -= delta
		if _turn_left <= 0.0 or dir == shown:
			_turn_left = 0.0
			shown = dir
		return
	if dir == shown:
		return
	var via := through(shown, dir)
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
