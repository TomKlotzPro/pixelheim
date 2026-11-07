extends GutTest
## A summon's nip shields no one (PIX-421): a wolf Greymaw howled up (or a
## slime the Tidecaller called) bites without starting the hero's half-second
## of grace, so its caller's bite right after still lands; two ordinary foes
## biting in the same half-second still count once (PIX-377's grace, so a
## pack can't shred the hero in one frame).

const GameStateScript := preload("res://scripts/state/game_state.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Enemy := preload("res://scripts/enemy.gd")

var _lent: Node
var _kept := {}
var _world: StubWorld


## What a blow on the hero asks of the world: its floats, its flash and the
## camera's shake.
class StubSkills extends RefCounted:
	func impact(_on: Node) -> void:
		pass


class StubFx extends RefCounted:
	var skills := StubSkills.new()

	func float_number(_n: int, _at: Vector2, _tone: Color, _crit: bool, _on: Node) -> void:
		pass

	func float_text(_text: String, _at: Vector2, _tone: Color) -> void:
		pass


class StubCamera extends RefCounted:
	func shake(_strength: float, _seconds: float) -> void:
		pass

	func hit_stop(_seconds: float) -> void:
		pass


class StubWorld extends Node2D:
	var fx := StubFx.new()
	var camera_rig := StubCamera.new()
	var player: CharacterBody2D


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
