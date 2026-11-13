extends GutTest
## A chasing foe goes round what stands between it and the hero (PIX-475).
## In the village a goblin whose place in the ring lay past the well walked
## straight at it and stood pressed against the well, chasing, for 20 s; a
## second, walking home, stood against a villager until it settled there,
## saw the hero and chased again. Every foe now walks by a way round a prop
## (as a boss did since PIX-288), round whoever stands in its way, and with
## no way at all gives the chase up and takes up none.

const Enemy := preload("res://scripts/enemy.gd")
const TICK := 1.0 / 60.0
## The well, two cells wide as the village's, on the row the hero and the
## foe stand on.
const WELL := Rect2i(7, 8, 2, 1)
const HERO := Vector2i(4, 8)
const FOE := Vector2i(11, 8)

var _world: StubWorld
var _origin := 0


class StubHero extends CharacterBody2D:
	var dead := false


class StubFoes extends RefCounted:
	## The foe's place in the ring round the hero, when it has one.
	var spot := Vector2.INF

	func ring_spot(_foe: Node) -> Vector2:
		return spot

	func can_notice(_foe: Node) -> bool:
		return false


class StubWorld extends Node2D:
	var foes := StubFoes.new()
	var player := StubHero.new()
	var map := MapData.new()

	func _init() -> void:
		add_child(player)
		map.size = Vector2i(16, 16)
		for x in 16:
			for y in 16:
				map.grid[Vector2i(x, y)] = "grass"


func before_each() -> void:
	_world = add_child_autofree(StubWorld.new())
	_world.player.global_position = MapView.center(HERO)
	_origin = GameClock.origin


func after_each() -> void:
	GameClock.origin = _origin


## Something solid over `cells`: a prop the map knows (covered), or with
## `known` false a body it doesn't (a villager).
func _stand(cells: Rect2i, known := true) -> void:
	var body: PhysicsBody2D = StaticBody2D.new() if known else AnimatableBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(cells.size) * MapView.TILE
	shape.position = Vector2(cells.position) * MapView.TILE + shape.shape.size / 2.0
	body.add_child(shape)
	_world.add_child(body)
	if known:
		for x in range(cells.position.x, cells.end.x):
			for y in range(cells.position.y, cells.end.y):
				_world.map.covered[Vector2i(x, y)] = true


## A goblin on the hunt, its bite held back and its physics stopped: the
## test does the stepping.
func _goblin(mode := "chase") -> CharacterBody2D:
	var foe: CharacterBody2D = Enemy.new()
	foe.world = _world
	foe.fighter = Bestiary.spawn("goblin")
	foe.position = MapView.center(FOE)
	_world.add_child(foe)
	foe.set_physics_process(false)
	foe.home = foe.position
	foe.mode = mode
	foe.hunting = mode == "chase"
	foe.can_bite = false
	return foe


## `seconds` of the foe's own ticks, the game's clock stepped with them (not
## the machine's sixty a second); the longest it stood still while not yet
## `near` px from `goal`.
func _run(foe: CharacterBody2D, seconds: float, goal: Vector2, near: float) -> float:
	await wait_physics_frames(2)
	var stood := 0.0
	var longest := 0.0
	for i in roundi(seconds / TICK):
		var from := foe.global_position
		foe._physics_process(TICK)
		GameClock.origin -= 1
		if foe.global_position.distance_to(goal) <= near:
			break
		stood = stood + TICK if foe.global_position.distance_to(from) < 0.2 else 0.0
		longest = maxf(longest, stood)
	return longest


func test_a_chasing_foe_walks_round_the_well_to_the_hero() -> void:
	_stand(WELL)
	var foe := _goblin()
	var hero: Vector2 = _world.player.global_position
	var stood := await _run(foe, 5.0, hero, foe.edge + 2.0)
	assert_eq(foe.mode, "chase", "still on the hunt")
	assert_lte(foe.global_position.distance_to(hero), foe.edge + 2.0, "at the hero within a few seconds")
	assert_lt(stood, 0.2, "never standing against the well")


func test_a_foe_walks_round_the_well_to_its_place_in_the_ring() -> void:
	_stand(WELL)
	var foe := _goblin()
	# Its place round past the hero, the well on the straight line to it.
	_world.foes.spot = _world.player.global_position + Vector2(-14, -24)
	var stood := await _run(foe, 6.0, _world.foes.spot, 2.0)
	assert_lte(foe.global_position.distance_to(_world.foes.spot), 2.0, "at its place")
	assert_lt(stood, 0.2, "never standing against the well")


func test_a_foe_walks_home_round_a_villager_in_its_way() -> void:
	var foe := _goblin("homeward")
	foe.global_position = MapView.center(Vector2i(5, 8))
	# Across its row and the two beside it: no slide past.
	_stand(Rect2i(8, 7, 1, 3), false)
	await _run(foe, 6.0, foe.home, 4.0)
	assert_lte(foe.global_position.distance_to(foe.home), 4.0, "home, not settled against them")


func test_with_no_way_to_the_hero_a_foe_gives_up_and_takes_up_no_chase() -> void:
	# The hero on an island: every cell round theirs shut.
	for cell in Packs.AROUND:
		_world.map.covered[HERO + cell] = true
	var foe := _goblin()
	var hero: Vector2 = _world.player.global_position
	assert_false(foe._can_reach(hero - foe.global_position), "it watches, taking up no chase")
	await _run(foe, Enemy.BLOCKED_SECONDS + 1.0, hero, 0.0)
	assert_false(foe.hunting, "no way a while: it gives the chase up")


## A ranger across a river: the foe they hurt walks home, but no walk home
## makes it whole (as a boss's never did, PIX-232).
func test_a_hurt_foe_with_no_way_goes_home_still_hurt() -> void:
	for cell in Packs.AROUND:
		_world.map.covered[HERO + cell] = true
	var foe := _goblin()
	foe.global_position = MapView.center(FOE + Vector2i(-2, 0))
	foe.fighter["hp"] = 1
	await _run(foe, Enemy.BLOCKED_SECONDS + 6.0, foe.home, 0.0)
	assert_eq(foe.mode, "idle", "home and watching")
	assert_eq(int(foe.fighter["hp"]), 1, "as hurt as it left the fight")


func test_a_hurt_foe_led_too_far_goes_home_and_heals() -> void:
	var foe := _goblin("homeward")
	foe.global_position = MapView.center(FOE + Vector2i(-2, 0))
	foe.fighter["hp"] = 1
	await _run(foe, 6.0, foe.home, 0.0)
	assert_eq(foe.mode, "idle", "home and watching")
	assert_eq(int(foe.fighter["hp"]), int(foe.fighter["maxHp"]), "whole again")
