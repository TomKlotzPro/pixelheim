extends GutTest
## The walk (PIX-243): its frames step with the ground covered, not the
## clock; the motion check's still frame holds; a walk carries on through a
## turn and shows its side turning right round; a diagonal holds the facing;
## a stop holds the last step a breath; and Reduce motion walks level.

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
	var sprite := _hero()
	var gait := Gait.new(sprite, PunyArt.plain("warrior", 0))
	gait.walk("right", 0.0, 0.0)
	gait.walk("right", 9.0, 0.1)
	var phase := gait.phase
	gait.walk("down", 0.0, 0.0)
	assert_eq(sprite.animation, &"walk_down", "a quarter turn is at once")
	assert_eq(gait.phase, phase, "and the stride goes on")
	assert_eq(sprite.frame, 1)


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
