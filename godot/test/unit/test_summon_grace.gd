extends GutTest
## A summon's nip shields no one (PIX-421): a wolf Greymaw howled up (or a
## slime the Tidecaller called) bites without starting the hero's half-second
## of grace, so its caller's bite right after still lands; two ordinary foes
## biting in the same half-second still count once (PIX-377's grace, so a
## pack can't shred the hero in one frame), and so do two summons'.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Enemy := preload("res://scripts/enemy.gd")
const EliteBrainScript := preload("res://scripts/elite_brain.gd")

var _lent: Node
var _kept := {}
var _world: StubWorld


## What a blow on the hero asks of the world: its floats, its flash, the
## camera's shake and the screen's red edges.
class StubSkills extends RefCounted:
	func impact(_on: Node) -> void:
		pass


class StubFx extends RefCounted:
	var skills := StubSkills.new()

	func float_number(_n: int, _at: Vector2, _tone: Color, _crit: bool, _on: Node) -> void:
		pass

	func float_text(_text: String, _at: Vector2, _tone: Color) -> void:
		pass

	func appear(_enemy: Node) -> void:
		pass


class StubCamera extends RefCounted:
	func shake(_strength: float, _seconds: float) -> void:
		pass

	func hit_stop(_seconds: float) -> void:
		pass


## The red at the screen's edges (PIX-447).
class StubEdge extends RefCounted:
	func struck(_share: float) -> void:
		pass


class StubHud extends RefCounted:
	var hurt_edge := StubEdge.new()


## What a howl asks of the world besides: its line, the ground and the
## wolves it calls.
class StubMessages extends RefCounted:
	func log_line(_line: String) -> void:
		pass


class StubMap extends RefCounted:
	func is_walkable(_cell: Vector2i) -> bool:
		return true


class StubSummon extends Node:
	var called := false
	var dying := false

	func notice() -> void:
		pass


class StubFoes extends Node:
	func spawn_enemy(_species: String, _cell: Vector2i, _region := "", _spawn_id := "", _elite := false, _wild := true, _home := Vector2i(-1, -1)) -> Node:
		var summon := StubSummon.new()
		add_child(summon)
		return summon


class StubWorld extends Node2D:
	var fx := StubFx.new()
	var camera_rig := StubCamera.new()
	var hud := StubHud.new()
	var messages := StubMessages.new()
	var map := StubMap.new()
	var foes := StubFoes.new()
	var player: CharacterBody2D

	func _init() -> void:
		add_child(foes)


func before_each() -> void:
	_kept = {"hero": GameState.hero, "pack": GameState.pack}
	_lent = GameStateScript.new()
	_lent.new_game("Robin", "warrior")
	GameState.hero = _lent.hero
	GameState.pack = _lent.pack
	_world = add_child_autofree(StubWorld.new())
	var hero: CharacterBody2D = PlayerScript.new()
	hero.world = _world
	_world.add_child(hero)
	# Never stepped (its steps reach for a world the test has none of), but
	# in the physics space: a blow knocks the hero back.
	hero.set_physics_process(false)
	hero.set_process(false)
	_world.player = hero


func after_each() -> void:
	for key: String in _kept:
		GameState.set(key, _kept[key])
	_lent.free()


## A foe of `species` beside the hero, standing still; `called` when a
## named monster's howl brought it.
func _foe(species: String, called := false) -> Node:
	var foe: Node = Enemy.new()
	foe.world = _world
	foe.fighter = Bestiary.spawn(species)
	foe.called = called
	_world.add_child(foe)
	foe.set_physics_process(false)
	return foe


func test_a_summons_bite_leaves_the_callers_bite_to_land() -> void:
	var summon := _foe("wolf", true)
	var caller := _foe("wolf")
	var full := GameState.hero.hp
	summon._bite(Vector2.ZERO)
	var after_nip := GameState.hero.hp
	assert_lt(after_nip, full, "the nip lands")
	assert_false(_world.player.invulnerable, "and starts no grace")
	caller._bite(Vector2.ZERO)
	assert_lt(GameState.hero.hp, after_nip, "the caller's bite right after still lands")
	assert_true(_world.player.invulnerable, "and it starts the grace")


func test_two_ordinary_bites_in_one_half_second_count_once() -> void:
	var first := _foe("wolf")
	var second := _foe("slime")
	var full := GameState.hero.hp
	first._bite(Vector2.ZERO)
	var after_first := GameState.hero.hp
	assert_lt(after_first, full, "the first bite lands")
	second._bite(Vector2.ZERO)
	assert_eq(GameState.hero.hp, after_first, "the second, in the grace, does nothing")
	# A summon's nip in that grace is shrugged off too.
	_foe("wolf", true)._bite(Vector2.ZERO)
	assert_eq(GameState.hero.hp, after_first, "nor a summon's")


func test_two_summons_in_one_half_second_count_once() -> void:
	var full := GameState.hero.hp
	_foe("wolf", true)._bite(Vector2.ZERO)
	var after_first := GameState.hero.hp
	assert_lt(after_first, full, "the first summon's bite lands")
	_foe("wolf", true)._bite(Vector2.ZERO)
	assert_eq(GameState.hero.hp, after_first, "the second's, in the same half-second, does nothing")
	_foe("wolf")._bite(Vector2.ZERO)
	assert_lt(GameState.hero.hp, after_first, "the caller's still lands through the summons' guard")


## PIX-447: a roll leaves a faint ghost of the hero's frame beside them,
## without the white flash, gone once faded; none under reduced motion.
func test_a_roll_leaves_ghosts_that_go_but_not_with_reduced_motion() -> void:
	var kept_motion := GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false
	var hero: CharacterBody2D = _world.player
	var before := _world.get_child_count()
	hero._ghost()
	assert_eq(_world.get_child_count(), before + 1, "a ghost beside the hero")
	var ghost: Sprite2D = _world.get_child(-1)
	assert_not_null(ghost.texture, "the hero's frame")
	assert_null(ghost.material, "no white flash on it")
	assert_almost_eq(ghost.modulate.a, PlayerScript.GHOST_ALPHA, 0.0001)
	await wait_seconds(PlayerScript.GHOST_S + 0.1)
	assert_freed(ghost, "the ghost")
	GameState.settings.reduce_motion = true
	hero._ghost()
	assert_eq(_world.get_child_count(), before, "no ghost under reduced motion")
	GameState.settings.reduce_motion = kept_motion


func test_a_howl_calls_its_wolves_and_lets_them_go_when_it_falls() -> void:
	var caller := _foe("wolf")
	var brain: Node = autofree(EliteBrainScript.new())
	brain.enemy = caller
	brain.world = _world
	brain._howl({"monsterId": "wolf", "count": 2, "max": 2})
	assert_eq(brain.called.size(), 2, "the forest answers")
	for wolf: Node in brain.called:
		assert_true(wolf.called, "each one called")
	caller.dying = true
	brain._physics_process(0.0)
	for wolf: Node in brain.called:
		assert_false(wolf.called, "its caller fallen, each a wild wolf again")
