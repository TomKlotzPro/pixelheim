extends GutTest
## Foes rest off the screen (PIX-360): one at peace well past the screen's
## edge skips its tick (each cost about 0.02 ms of the frame); one near the
## screen, hunting, hurt or a boss never rests; and one resting wakes while
## the walking hero's screen is still more than half a second from it.

const Enemy := preload("res://scripts/enemy.gd")
const Player := preload("res://scripts/player.gd")
## The screen at play zoom: 1280x720 over three.
const VIEW := Rect2(0, 0, 1280.0 / 3.0, 240)


## A slime as the world spawns it, standing still (no world to hunt in).
func _foe(at: Vector2) -> Node:
	var foe: Node = Enemy.new()
	foe.fighter = Bestiary.spawn("slime")
	add_child_autofree(foe)
	foe.set_physics_process(false)
	foe.global_position = at
	return foe


func test_only_a_foe_at_peace_well_off_the_screen_rests() -> void:
	var past := VIEW.end.x + Enemy.REST_MARGIN
	assert_true(Enemy.rests(VIEW, Vector2(past + 1, 120), true), "well off the screen")
	assert_false(Enemy.rests(VIEW, Vector2(past - 1, 120), true), "just off it: it wanders on")
	assert_false(Enemy.rests(VIEW, VIEW.get_center(), true), "on the screen")
	assert_false(Enemy.rests(VIEW, Vector2(past + 1, 120), false), "in a fight")
	assert_false(Enemy.rests(Rect2(), Vector2(past + 1, 120), true), "no camera yet: nobody rests")


func test_a_far_foe_rests_and_a_hunting_or_hurt_one_never() -> void:
	var foe := _foe(Vector2(2000, 120))
	foe.rest(VIEW)
	assert_true(foe.resting, "at home, far off")
	foe.mode = "chase"
	foe.hunting = true
	foe.rest(VIEW)
	assert_false(foe.resting, "chasing")
	foe.mode = "idle"
	foe.hunting = false
	foe.fighter["hp"] = int(foe.fighter["maxHp"]) - 1
	foe.rest(VIEW)
	assert_false(foe.resting, "struck")
	assert_false(_foe(VIEW.get_center()).resting, "a near foe")
	var boss := _foe(Vector2(2000, 120))
	boss.boss_like = true
	boss.rest(VIEW)
	assert_false(boss.resting, "a boss: where it stands is its fight's timing")


func test_a_resting_foe_wakes_before_the_screen_reaches_it() -> void:
	var foe := _foe(Vector2(VIEW.end.x + 400, 120))
	var view := VIEW
	foe.rest(view)
	assert_true(foe.resting)
	# The hero walks at it, the screen with them, a tick at a time.
	var step := Player.SPEED / 60.0
	while foe.resting and view.end.x < foe.global_position.x:
		view.position.x += step
		foe.rest(view)
	assert_false(foe.resting, "awake")
	assert_gt(foe.global_position.x - view.end.x, Player.SPEED / 2.0, "more than half a second's walk off the screen")
