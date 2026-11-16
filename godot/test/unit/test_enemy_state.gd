extends GutTest
## The enemy as a state machine (PIX-501): one state at a time, which state
## may follow which a table (EnemyState), and enemy.gd's enter() the one
## place the state changes - it refuses a change the table doesn't know, and
## does the work of leaving one state and entering the next. The names are
## the ones the harness's report and tools/play.py's `foes[].mode` read.

const EnemyScript := preload("res://scripts/enemy.gd")
## Every change a foe may make: one row a state, in the enum's order (idle,
## alert, chase, cast, pile, homeward, flee), a column each state it may go
## to, in the same order.
const TABLE := [
	# to:  idle   alert  chase  cast   pile   home   flee
	[false, true, true, false, true, false, true],  # idle: seen, struck, felled, frightened
	[true, true, true, false, true, false, false],  # alert: stands down, seen again, charges, felled
	[true, false, false, true, true, true, true],  # chase: stands down, tells a move, felled, gives up, runs with gold
	[true, false, true, false, true, false, false],  # cast: stands down, the move done, felled
	[false, false, true, false, false, false, false],  # pile: it rises, nothing else
	[true, true, true, false, true, false, false],  # homeward: home, called to a fight, struck, felled
	[true, true, true, false, true, true, false],  # flee: stands down, cornered, struck or turning back, felled, calmed
]


func test_the_names_are_the_ones_the_report_reads() -> void:
	assert_eq(EnemyState.NAMES, ["idle", "alert", "chase", "cast", "pile", "homeward", "flee"] as Array[String])
	assert_eq([EnemyState.IDLE, EnemyState.ALERT, EnemyState.CHASE, EnemyState.CAST, EnemyState.PILE, EnemyState.HOMEWARD, EnemyState.FLEE], [0, 1, 2, 3, 4, 5, 6], "a name each, in the enum's order")
	for state in EnemyState.NAMES.size():
		assert_eq(EnemyState.named(EnemyState.name_of(state)), state, EnemyState.name_of(state))
	assert_eq(EnemyState.name_of(-1), "")
	assert_eq(EnemyState.name_of(EnemyState.NAMES.size()), "")
	assert_eq(EnemyState.named("asleep"), -1, "no state: a flag on an idle foe")


func test_every_change_is_in_the_table_or_refused() -> void:
	assert_eq(EnemyState.NEXT.size(), EnemyState.NAMES.size(), "a row for every state")
	for from in EnemyState.NAMES.size():
		for to in EnemyState.NAMES.size():
			assert_eq(EnemyState.allowed(from, to), TABLE[from][to], "%s -> %s" % [EnemyState.name_of(from), EnemyState.name_of(to)])
	assert_false(EnemyState.allowed(-1, EnemyState.CHASE), "from no state")
	assert_false(EnemyState.allowed(EnemyState.CHASE, 99), "to no state")


func test_only_the_alert_starts_over_and_only_a_rise_leaves_the_pile() -> void:
	for state in EnemyState.NAMES.size():
		assert_eq(EnemyState.allowed(state, state), state == EnemyState.ALERT, EnemyState.name_of(state) + " to itself")
		assert_eq(EnemyState.allowed(EnemyState.PILE, state), state == EnemyState.CHASE, "pile -> " + EnemyState.name_of(state))
		# Any state but the pile's own falls to it: a blow, or poison, anywhere.
		assert_eq(EnemyState.allowed(state, EnemyState.PILE), state != EnemyState.PILE, EnemyState.name_of(state) + " -> pile")
		# A move is told from the chase alone.
		assert_eq(EnemyState.allowed(state, EnemyState.CAST), state == EnemyState.CHASE, EnemyState.name_of(state) + " -> cast")


func test_every_state_can_be_reached_and_left() -> void:
	for state in EnemyState.NAMES.size():
		assert_true(range(EnemyState.NAMES.size()).any(func(from: int) -> bool: return from != state and EnemyState.allowed(from, state)), "into " + EnemyState.name_of(state))
		assert_true(range(EnemyState.NAMES.size()).any(func(to: int) -> bool: return to != state and EnemyState.allowed(state, to)), "out of " + EnemyState.name_of(state))


func test_fighting_is_the_chase_and_the_cast() -> void:
	for state in EnemyState.NAMES.size():
		assert_eq(EnemyState.fighting(state), state in [EnemyState.CHASE, EnemyState.CAST], EnemyState.name_of(state))


## A slime as the world spawns it, standing still (no world to hunt in).
func _foe() -> Node:
	var foe: Node = EnemyScript.new()
	foe.fighter = Bestiary.spawn("slime")
	add_child_autofree(foe)
	foe.set_physics_process(false)
	return foe


func test_the_enemy_starts_idle_and_its_mode_is_the_states_name() -> void:
	var foe := _foe()
	assert_eq(foe.state, EnemyState.IDLE)
	assert_eq(foe.mode, "idle")
	assert_true(foe.enter(EnemyState.CHASE))
	assert_eq(foe.mode, "chase")
	foe.mode = "idle"
	assert_push_error("read only")
	assert_eq(foe.state, EnemyState.CHASE, "its name can't be written")


func test_enter_refuses_a_change_the_table_doesnt_know() -> void:
	var foe := _foe()
	assert_false(foe.enter(EnemyState.CAST), "no move is told from home")
	assert_push_error("no way from idle to cast")
	assert_eq(foe.state, EnemyState.IDLE, "and it stays as it was")
	foe.begin_cast()
	assert_push_error_count(2, "its brains' asking is refused as well")
	assert_eq(foe.state, EnemyState.IDLE)


func test_a_fallen_foe_changes_no_more() -> void:
	var foe := _foe()
	foe.enter(EnemyState.CHASE)
	foe.dying = true
	assert_false(foe.enter(EnemyState.HOMEWARD))
	foe.begin_cast()
	assert_eq(foe.state, EnemyState.CHASE, "its fall ends every state")
	assert_push_error_count(0, "and that is no bug")


func test_each_state_does_its_own_entry_and_exit_work() -> void:
	var foe := _foe()
	foe.enter(EnemyState.CHASE)
	foe.hunting = true
	foe.tell_left = 0.2
	foe.aim_left = 0.3
	foe.at_bay = true
	foe.blocked_for = 1.5
	foe.velocity = Vector2(30, 0)
	foe.begin_cast()
	assert_eq(foe.state, EnemyState.CAST)
	assert_eq(foe.velocity, Vector2.ZERO, "casting, it stands")
	foe.begin_cast()
	assert_eq(foe.state, EnemyState.CAST, "asked again, it casts on")
	foe.end_cast()
	assert_eq(foe.state, EnemyState.CHASE)
	foe.end_cast()
	assert_eq(foe.state, EnemyState.CHASE, "nothing to end for one already chasing")
	foe.enter(EnemyState.HOMEWARD)
	assert_eq([foe.hunting, foe.at_bay, foe.tell_left, foe.aim_left, foe.blocked_for], [false, false, -1.0, -1.0, 0.0], "the chase given up: nothing told, nothing held")
	foe.woken = true
	foe.out_for = 12.0
	foe.enter(EnemyState.IDLE)
	assert_eq([foe.woken, foe.out_for], [false, 0.0], "home: watching again")
	foe.stuck_for = 3.0
	foe.run_off()
	assert_eq(foe.state, EnemyState.FLEE)
	assert_eq([foe.stuck_for, foe.alert_left], [0.0, 0.0], "a flight just begun")
	foe.turn_back()
	assert_eq(foe.state, EnemyState.CHASE)
	assert_true(foe.at_bay, "turned from its flight, it fights where it stands")


func test_a_pile_takes_the_body_and_the_bars_and_a_rise_gives_them_back() -> void:
	var foe := _foe()
	foe.enter(EnemyState.CHASE)
	foe.ailments.effects.append({"kind": "poison", "turnsLeft": 3, "power": 1})
	foe.tell_left = 0.2
	foe.fall_to_pile()
	assert_eq(foe.state, EnemyState.PILE)
	assert_false(foe.sprite.visible, "its body gone")
	assert_eq(foe.tell_left, -1.0, "its bite's tell dropped")
	assert_true(foe.ailments.effects.is_empty(), "nothing ails a pile of bones")
	foe.rise(3)
	assert_eq(foe.state, EnemyState.CHASE)
	assert_eq(int(foe.fighter["hp"]), 3)
	assert_true(foe.sprite.visible, "its body back")


func test_standing_down_goes_idle_then_ends_the_states() -> void:
	var foe := _foe()
	foe.world = add_child_autofree(StubWorld.new())
	foe.enter(EnemyState.CHASE)
	foe.begin_cast()
	foe.stand_down()
	assert_eq(foe.mode, "idle")
	assert_true(foe.dying and foe.stood_down)
	assert_false(foe.enter(EnemyState.CHASE), "out of the fight for good")


class StubFoes extends RefCounted:
	func stood_down(_foe: Node) -> void:
		pass


class StubWorld extends Node2D:
	var foes := StubFoes.new()
