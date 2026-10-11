extends GutTest
## The walk (PIX-243): its frames step with the ground covered, not the
## clock; the motion check's still frame holds; a walk carries on through a
## turn and shows its side turning right round; a diagonal holds the facing;
## a stop holds the last step a breath; and Reduce motion walks level. And
## where the sheet draws eight ways (PIX-293), a diagonal walks facing it, a
## quarter turn passes the way between, and a stick near a line between two
## ways doesn't flicker.

const TICK := 1.0 / 60.0

var _reduce_motion := false


func before_each() -> void:
	_reduce_motion = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false


func after_each() -> void:
	GameState.settings.reduce_motion = _reduce_motion


func _hero() -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = autofree(AnimatedSprite2D.new())
	sprite.sprite_frames = PunyArt.frames(PunyArt.plain("warrior", 0))
	return sprite


func test_frames_follow_the_ground_covered() -> void:
	# The hero's 95 px a second at a 6 px stride: about 16 frames a second.
	assert_almost_eq(Gait.frames_for(95.0 * TICK, 6.0, TICK) / TICK, 95.0 / 6.0, 0.01)
	assert_almost_eq(Gait.frames_for(0.0, 6.0, TICK) / TICK, Gait.MIN_FPS, 0.001, "against a wall it still walks, slowly")
	assert_almost_eq(Gait.frames_for(250.0 * TICK, 6.0, TICK) / TICK, Gait.MAX_FPS, 0.001, "a dodge's burst doesn't blur")


func test_a_walk_steps_by_the_ground_not_the_clock() -> void:
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	assert_eq(gait.stride, 6.0)
	gait.walk("right", 0.0, 0.0)
	assert_eq(sprite.animation, &"walk_right")
	assert_eq(sprite.frame, 0, "it sets off on its rise")
	assert_false(sprite.is_playing(), "the gait steps it, not the sprite's clock")
	gait.walk("right", 6.0, 0.1)
	assert_eq(sprite.frame, 1, "a stride's ground, a frame")
	gait.walk("right", 3.0, 0.1)
	assert_eq(sprite.frame, 1, "half a stride, half a frame")
	gait.walk("right", 3.0, 0.1)
	assert_eq(sprite.frame, 2)


func test_a_held_clock_holds_the_walk() -> void:
	# The motion check (PIX-135) freezes the hero's frame with speed_scale 0
	# so only motion moves the shirt it measures.
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	sprite.speed_scale = 0.0
	for tick in 30:
		gait.walk("right", 95.0 * TICK, TICK)
	assert_eq(sprite.frame, 0)
	assert_eq(gait.phase, 0.0)


func test_a_bigger_walker_strides_further() -> void:
	var troll := PunyArt.monster("troll")
	var sprite: AnimatedSprite2D = autofree(AnimatedSprite2D.new())
	sprite.sprite_frames = PunyArt.frames(troll)
	assert_eq(Gait.new(sprite, troll, 1.25).stride, 5.0, "a 16 px sheet's 4 px stride at 1.25")
	var wyvern := PunyArt.monster("wyvern")
	sprite.sprite_frames = PunyArt.frames(wyvern)
	assert_eq(Gait.new(sprite, wyvern).stride, 8.0, "a dragon's 32 px cells stride twice as far")


func test_the_walk_carries_on_through_a_turn() -> void:
	# A four-way sheet (a Mini World villager): a quarter turn is at once.
	var spec := PunyArt.villager("villager")
	var sprite: AnimatedSprite2D = autofree(AnimatedSprite2D.new())
	sprite.sprite_frames = PunyArt.frames(spec)
	var gait := Gait.new(sprite, spec)
	gait.walk("right", 0.0, 0.0)
	gait.walk("right", 6.0, 0.1)
	var phase := gait.phase
	gait.walk("down", 0.0, 0.0)
	assert_eq(sprite.animation, &"walk_down", "a quarter turn is at once")
	assert_eq(gait.phase, phase, "and the stride goes on")
	assert_eq(sprite.frame, 1)


## PIX-293: Tom found the hero turning a quarter in one frame, down to right
## as he let go of a key. Shade draws the ways between, so the turn passes
## through one: down, down and right a moment, right - one smooth step, the
## stride carrying on through all three.
func test_a_quarter_turn_passes_the_way_between() -> void:
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	assert_true(gait.eight_ways(), "Shade's Puny Characters draw eight ways")
	gait.walk("down", 0.0, 0.0)
	gait.walk("down", 9.0, 0.1)
	var phase := gait.phase
	gait.walk("right", 0.0, 0.0)
	assert_eq(sprite.animation, &"walk_down_right", "down to right shows the way between first")
	assert_eq(gait.phase, phase, "the stride goes on")
	assert_eq(sprite.frame, 1, "on the same foot")
	for tick in ceili(Gait.TURN_SECONDS / TICK):
		gait.walk("right", 1.5, TICK)
	assert_eq(sprite.animation, &"walk_right", "then the new way")
	assert_eq(gait.heading, "right")


func test_a_diagonal_is_walked_facing_it() -> void:
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	gait.walk("up", 0.0, 0.0)
	# Up, then left held too: an eighth of a turn, at once.
	gait.walk(gait.drawn_way(Vector2(-1, -1), "up"), 1.5, TICK)
	assert_eq(sprite.animation, &"walk_up_left")
	# Up let go: left, an eighth again, at once.
	gait.walk(gait.drawn_way(Vector2.LEFT, "left"), 1.5, TICK)
	assert_eq(sprite.animation, &"walk_left")


func test_the_eight_ways_hold_near_a_line() -> void:
	assert_eq(Gait.steer_eight("down", Vector2(1, 1)), "down_right", "two keys are a diagonal")
	assert_eq(Gait.steer_eight("down_right", Vector2.RIGHT), "right", "one let go, the other way")
	assert_eq(Gait.steer_eight("up", Vector2(-1, -1)), "up_left")
	assert_eq(Gait.steer_eight("left", Vector2(-1, 1)), "down_left")
	assert_eq(Gait.steer_eight("up", Vector2.ZERO), "up", "standing keeps the way")
	# A stick either side of the line between down and down-right (22.5
	# degrees off down) stays on the way it was drawn, either way.
	var past := Vector2.from_angle(PI / 2.0 - deg_to_rad(25.0))
	var short := Vector2.from_angle(PI / 2.0 - deg_to_rad(20.0))
	assert_eq(Gait.steer_eight("down", past), "down", "a little past the line holds")
	assert_eq(Gait.steer_eight("down_right", short), "down_right", "and back the other way")
	assert_eq(Gait.steer_eight("up", past), "down_right", "from afar, the nearest")
	assert_eq(Gait.steer_eight("down", Vector2.from_angle(PI / 2.0 - deg_to_rad(35.0))), "down_right", "past the hold it turns")
	for index in Gait.EIGHT.size():
		assert_eq(Gait.steer_eight("", Gait.eight_vector(index)), Gait.EIGHT[index], "eight_vector points %s" % Gait.EIGHT[index])


func test_what_a_turn_passes_through() -> void:
	assert_eq(Gait.between("down", "right"), "down_right", "a quarter turn, the way between")
	assert_eq(Gait.between("up", "left"), "up_left")
	assert_eq(Gait.between("left", "down"), "down_left")
	assert_eq(Gait.between("right", "up"), "up_right")
	assert_eq(Gait.between("down", "down_right"), "", "an eighth, at once")
	assert_eq(Gait.between("down_right", "right"), "")
	assert_eq(Gait.between("down", "down"), "")
	assert_eq(Gait.between("down_right", "up_right"), "right", "a diagonal's quarter turn too")
	assert_eq(Gait.between("right", "down_left"), "down", "three eighths: the quarter round, facing the viewer")
	# Right round, as `through` turns a four-way walker.
	for from: String in Gait.OPPOSITE:
		assert_eq(Gait.between(from, Gait.OPPOSITE[from]), Gait.through(from, Gait.OPPOSITE[from]), "%s right round" % from)
	assert_eq(Gait.between("down_right", "up_left"), "down_left", "a diagonal right round shows the face")


func test_a_hand_turn_and_a_stop_settle_the_way() -> void:
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	gait.walk("down", 0.0, 0.0)
	gait.walk("right", 1.5, TICK)
	assert_eq(gait.shown, "down_right", "mid-turn")
	gait.halt()
	assert_eq(gait.shown, "right", "a stop mid-turn finishes it: the hero stands the way they went")
	gait.face("up")
	assert_eq([gait.shown, gait.heading], ["up", "up"], "turned by hand, drawn that way")
	assert_eq(gait.drawn_way(Vector2(1, -1), "up"), "up_right", "and walks off from there")


func test_turning_right_round_shows_the_side_first() -> void:
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	gait.walk("right", 0.0, 0.0)
	gait.walk("left", 1.5, TICK)
	assert_eq(sprite.animation, &"walk_down", "right to left faces down on the way")
	for tick in ceili(Gait.TURN_SECONDS / TICK) + 1:
		gait.walk("left", 1.5, TICK)
	assert_eq(sprite.animation, &"walk_left")
	assert_eq(Gait.through("up", "down"), "right", "front to back by the right side")
	assert_eq(Gait.through("right", "down"), "", "nothing between a quarter turn")


func test_a_diagonal_holds_the_facing() -> void:
	assert_eq(Gait.steer("right", Vector2(1, 1)), "right")
	assert_eq(Gait.steer("down", Vector2(1, 1)), "down")
	assert_eq(Gait.steer("down", Vector2(1, 0.3)), "right", "past the hold it turns")
	assert_eq(Gait.steer("up", Vector2(-1, -1)), "up")
	assert_eq(Gait.steer("left", Vector2(1, 1)), "right", "a tie still goes sideways, as before")
	assert_eq(Gait.steer("up", Vector2.ZERO), "up")


func test_a_stop_holds_the_last_step_a_breath() -> void:
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	gait.walk("up", 0.0, 0.0)
	assert_false(gait.rest(Gait.SETTLE_SECONDS / 2.0), "a hitch in the input isn't a stop")
	assert_true(gait.walking)
	assert_eq(sprite.animation, &"walk_up")
	gait.walk("up", 1.0, TICK)
	assert_false(gait.rest(Gait.SETTLE_SECONDS / 2.0), "walking again starts the hold over")
	assert_true(gait.rest(Gait.SETTLE_SECONDS), "then it settles")
	assert_false(gait.walking)
	assert_false(gait.rest(TICK), "once")


func test_the_hero_rises_as_the_feet_pass() -> void:
	# The four-beat walk: rise, step, rise, the other step, a pixel's bob.
	var frames := PunyArt.frames(PunyArt.plain("warrior", 0))
	assert_eq(PunyArt.rises(frames, "walk_right"), PackedInt32Array([1, 0, 1, 0]))


func test_reduce_motion_walks_level() -> void:
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	gait.walk("right", 0.0, 0.0)
	assert_eq(sprite.offset.y, 0.0, "the rise shows")
	GameState.settings.reduce_motion = true
	gait.walk("right", 0.0, 0.0)
	assert_eq(sprite.frame, 0)
	assert_eq(sprite.offset.y, 1.0, "set down a whole pixel onto the steps' line")
	gait.walk("right", 6.0, 0.1)
	assert_eq(sprite.offset.y, 0.0, "a step stands where it is")
	gait.halt()
	assert_eq(sprite.offset.y, 0.0)
