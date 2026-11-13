extends GutTest
## A stun breaks the attack a foe is telling (PIX-440), so every told attack
## can be stopped as well as dodged: the mark goes and never strikes, the
## boss's count of marks to come is left at none, the foe goes back to
## chasing, "Interrupted!" rises over it; and what ails a foe shows as icons
## over it, one each, gone when the ailment or the foe is. And a mark left to
## strike: a leap lands beside the hero, not on them (PIX-468).

const GameStateScript := preload("res://scripts/state/game_state.gd")
const Enemy := preload("res://scripts/enemy.gd")
const BossBrainScript := preload("res://scripts/boss_brain.gd")
const EliteBrainScript := preload("res://scripts/elite_brain.gd")
const STUN := {"kind": "stun", "chance": 2.0, "turns": 2, "power": 0}
const POISON := {"kind": "poison", "chance": 2.0, "turns": 3, "power": 1}
const BURN := {"kind": "burn", "chance": 2.0, "turns": 3, "power": 1}
## A tell short enough to wait out here.
const TELL := 0.05
const STRUCK_BY := 0.3

var _lent: Node
var _kept := {}
var _world: StubWorld


class StubSkills extends RefCounted:
	func impact(_on: Node) -> void:
		pass


class StubFx extends RefCounted:
	var skills := StubSkills.new()
	var words: Array[String] = []

	func float_number(_n: int, _at: Vector2, _tone: Color, _crit: bool, _on: Node) -> void:
		pass

	func float_text(text: String, _at: Vector2, _tone: Color, _big := false) -> void:
		words.append(text)

	func dust(_at: Vector2) -> void:
		pass


class StubCamera extends RefCounted:
	func shake(_strength: float, _seconds: float) -> void:
		pass

	func hit_stop(_seconds: float) -> void:
		pass


class StubMessages extends RefCounted:
	func log_line(_line: String) -> void:
		pass


class StubHero extends CharacterBody2D:
	var dead := false
	var hits := 0

	func take_hit(_damage: int, _from: Vector2, _inflicts: Variant = null, _grace := true) -> void:
		hits += 1


class StubFoes extends RefCounted:
	func fights_like_boss(_foe: Node) -> bool:
		return false

	func on_enemy_noticed(_foe: Node) -> void:
		pass


class StubWorld extends Node2D:
	var fx := StubFx.new()
	var camera_rig := StubCamera.new()
	var messages := StubMessages.new()
	var foes := StubFoes.new()
	var player: StubHero
	## Open grass, for a leap to land on.
	var map := MapData.new()

	func _init() -> void:
		# Telegraph lays its marks at this depth among the world's children.
		for i in 4:
			add_child(Node.new())
		player = StubHero.new()
		add_child(player)
		for x in 16:
			for y in 16:
				map.grid[Vector2i(x, y)] = "grass"


func before_each() -> void:
	_kept = {"hero": GameState.hero, "pack": GameState.pack}
	_lent = GameStateScript.new()
	_lent.new_game("Robin", "warrior")
	GameState.hero = _lent.hero
	GameState.pack = _lent.pack
	_world = add_child_autofree(StubWorld.new())


func after_each() -> void:
	for key: String in _kept:
		GameState.set(key, _kept[key])
	_lent.free()


## A wolf, its physics stopped: the test does the stepping.
func _foe() -> Node:
	var foe: Node = Enemy.new()
	foe.world = _world
	foe.fighter = Bestiary.spawn("wolf")
	_world.add_child(foe)
	foe.set_physics_process(false)
	return foe


func _boss_brain(foe: Node) -> Node:
	var brain: Node = BossBrainScript.new()
	brain.enemy = foe
	brain.world = _world
	foe.brain = brain
	foe.add_child(brain)
	brain.set_physics_process(false)
	return brain


func _elite_brain(foe: Node) -> Node:
	var brain: Node = EliteBrainScript.new()
	brain.enemy = foe
	brain.world = _world
	foe.brain = brain
	foe.add_child(brain)
	brain.set_physics_process(false)
	return brain


func _stun(foe: Node) -> void:
	foe.take_hit(1, Vector2.ZERO, STUN)


## A band round the hero that strikes them if it isn't taken back.
func _over_hero() -> PackedVector2Array:
	return Telegraph.circle(Vector2.ZERO, 16.0)


func _marks_left() -> int:
	return _world.get_children().filter(func(node: Node) -> bool: return node is Polygon2D).size()


func _boss_attack() -> Dictionary:
	return {"tell": TELL, "power": 1.0}


func test_a_stun_takes_a_bosss_marks_back_and_leaves_it_waiting_for_none() -> void:
	var foe := _foe()
	var brain := _boss_brain(foe)
	foe.mode = "cast"
	# Two marks of one cast, as his embers.
	brain._tell(_over_hero(), _boss_attack())
	brain._tell(_over_hero(), _boss_attack())
	assert_eq(brain.pending, 2, "two marks to come")
	_stun(foe)
	assert_eq(brain.pending, 0, "none left to wait for")
	assert_eq(foe.mode, "chase", "not stuck in its cast")
	assert_eq(_world.fx.words, [Text.t("Interrupted!")], "the word rises")
	await wait_seconds(STRUCK_BY)
	assert_eq(_world.player.hits, 0, "neither mark struck")
	assert_eq(_marks_left(), 0, "and they are gone")


func test_a_mark_already_struck_is_no_tell_to_break() -> void:
	var foe := _foe()
	var brain := _boss_brain(foe)
	foe.mode = "cast"
	brain._tell(_over_hero(), _boss_attack())
	await wait_seconds(TELL + 0.05)
	assert_eq(_world.player.hits, 1, "it struck")
	assert_eq(brain.pending, 0)
	_stun(foe)
	assert_eq(_world.fx.words.size(), 0, "nothing was interrupted")


func test_a_stun_breaks_an_elites_mark_and_its_blow_never_lands() -> void:
	var foe := _foe()
	var brain := _elite_brain(foe)
	foe.mode = "cast"
	brain._tell({"move": "cleave", "tell": TELL, "power": 1.0}, _over_hero(), "")
	_stun(foe)
	assert_eq(foe.mode, "chase")
	assert_eq(_world.fx.words.size(), 1, "the word rises")
	await wait_seconds(STRUCK_BY)
	assert_eq(_world.player.hits, 0, "the cleave never came")


## PIX-457, PIX-463: a leap ends where the beast would have stopped walking
## up (Enemy.stop), on the side it came from: it landed on a hero who stood.
## One already that near stays where it is.
func test_a_leap_lands_beside_the_hero() -> void:
	var hero := Vector2(8.5, 8.5) * 16.0
	_world.player.global_position = hero
	var leap := {"move": "leap", "tell": TELL, "power": 1.0}
	for from: Vector2 in [Vector2(-64, 0), Vector2(48, -48), Vector2(0, 56)]:
		var foe := _foe()
		foe.global_position = hero + from
		var beside: float = foe.stop(-from)
		assert_gt(beside, Enemy.HERO_HALF, "beside is clear of the hero's body")
		_elite_brain(foe)._tell(leap, Telegraph.circle(hero, 24.0), "leap")
		await wait_seconds(STRUCK_BY + 0.25)
		var landed: Vector2 = foe.global_position - hero
		assert_almost_eq(landed.length(), beside, 0.5, "%s: as near as it stops, no nearer" % from)
		assert_almost_eq(landed.angle_to(from), 0.0, 0.01, "%s: on the side it came from" % from)
		foe.free()
	var near := _foe()
	near.global_position = hero + Vector2(4, 0)
	_elite_brain(near)._tell(leap, Telegraph.circle(hero, 24.0), "leap")
	await wait_seconds(STRUCK_BY + 0.25)
	assert_eq(near.global_position, hero + Vector2(4, 0), "nearer already: it stays")
	assert_eq(_world.player.hits, 4, "and each struck the hero in its ring")


func test_a_blow_that_turned_it_to_the_chase_first_still_breaks_the_tell() -> void:
	# Its mark still standing though it chases (take_hit set a telling foe
	# chasing before PIX-451): the stun still takes it back.
	var foe := _foe()
	var brain := _elite_brain(foe)
	foe.mode = "cast"
	brain._tell({"move": "stamp", "tell": TELL, "power": 1.0}, _over_hero(), "")
	foe.mode = "chase"
	_stun(foe)
	await wait_seconds(STRUCK_BY)
	assert_eq(_world.player.hits, 0, "the stamp never came")
	assert_eq(_world.fx.words.size(), 1)


## PIX-451: a blow that doesn't stun leaves the move told to land - before,
## it set the foe chasing, and the elite walked and bit through its cleave,
## whose blow the bite's grace took: a hero swinging nonstop never met it.
func test_a_blow_without_a_stun_leaves_the_tell_to_land() -> void:
	var elite := _foe()
	var cleave := _elite_brain(elite)
	elite.mode = "cast"
	cleave._tell({"move": "cleave", "tell": TELL, "power": 1.0}, _over_hero(), "")
	var boss := _foe()
	var breath := _boss_brain(boss)
	boss.mode = "cast"
	breath._tell(_over_hero(), _boss_attack())
	elite.take_hit(1, Vector2.ZERO)
	boss.take_hit(1, Vector2.ZERO)
	assert_eq(elite.mode, "cast", "the elite holds its cleave")
	assert_eq(boss.mode, "cast", "the boss its breath")
	await wait_seconds(STRUCK_BY)
	assert_eq(_world.player.hits, 2, "both land")
	assert_eq([elite.mode, boss.mode], ["chase", "chase"], "then they chase again")


func test_a_stun_breaks_a_told_bolt_its_glow_and_its_marks() -> void:
	var foe := _foe()
	var brain := _elite_brain(foe)
	var flown := [false]
	foe.mode = "cast"
	brain._keep(Telegraph.mark(_world, _over_hero(), TELL, Callable(), false))
	brain._flash({"tell": TELL}, func() -> void: flown[0] = true)
	_stun(foe)
	assert_eq(foe.sprite.modulate, Color.WHITE, "the glow let go")
	await wait_seconds(STRUCK_BY)
	assert_false(flown[0], "the bolt never flew")
	assert_eq(_marks_left(), 0, "its way off the ground")
	assert_eq(foe.mode, "chase")


func test_a_stun_drops_a_raised_guard() -> void:
	var foe := _foe()
	var brain := _elite_brain(foe)
	brain._guard({"seconds": 5.0})
	assert_true(foe.guarding)
	_stun(foe)
	assert_false(foe.guarding, "the guard is down")
	assert_has(_world.fx.words, Text.t("Interrupted!"), "the word rises, after this blow's \"blocked\"")


func test_a_stun_breaks_a_common_foes_bite_and_the_foe_stands_as_it_was() -> void:
	var foe := _foe()
	var at: Vector2 = foe.sprite.position
	foe.mode = "chase"
	foe._tell_bite(Vector2.RIGHT)
	await wait_seconds(0.05)
	_stun(foe)
	assert_lt(foe.tell_left, 0.0, "no bite is coming")
	assert_eq(foe.sprite.position, at, "out of its crouch")
	assert_eq(foe.sprite.modulate, Color.WHITE)
	assert_eq(_world.fx.words.size(), 1, "the word rises")


func test_a_mark_long_gone_is_no_tell_either() -> void:
	# A band left over from a bite told and struck (clear warnings), freed.
	var foe := _foe()
	foe._tell_mark = Telegraph.mark(_world, _over_hero(), TELL, Callable(), false)
	await wait_seconds(TELL + 0.4)
	assert_eq(_marks_left(), 0, "faded out")
	_stun(foe)
	assert_eq(_world.fx.words.size(), 0)


func test_a_foe_telling_nothing_shows_no_word() -> void:
	var foe := _foe()
	foe.mode = "chase"
	_stun(foe)
	assert_true(foe.ailments.is_stunned())
	assert_eq(_world.fx.words.size(), 0)


func test_a_stun_the_guard_shrugs_off_breaks_nothing() -> void:
	var foe := _foe()
	var brain := _boss_brain(foe)
	foe.ailments.stun_guard = 12.0
	var one_turn := {"kind": "stun", "chance": 2.0, "turns": 1, "power": 0}
	foe.ailments.inflict(one_turn, GameState.roll)
	foe.ailments.effects.clear()
	foe.mode = "cast"
	brain._tell(_over_hero(), _boss_attack())
	# A second within the guard's window: halved to nothing.
	foe.take_hit(1, Vector2.ZERO, one_turn)
	assert_false(foe.ailments.is_stunned(), "shrugged off")
	assert_eq(brain.pending, 1, "the mark stands")
	assert_eq(_world.fx.words.size(), 0)


func test_each_ailment_shows_its_own_icon_side_by_side_then_goes() -> void:
	var foe := _foe()
	foe.ailments.inflict(POISON, GameState.roll)
	foe.ailments.inflict(BURN, GameState.roll)
	foe._show_ailments()
	assert_eq(foe._ailment_row.get_child_count(), 2, "one each")
	var first: Sprite2D = foe._ailment_row.get_child(0)
	var second: Sprite2D = foe._ailment_row.get_child(1)
	assert_gt(second.position.x, first.position.x, "side by side")
	foe.ailments.cure("poison")
	foe._show_ailments()
	assert_eq(foe._ailment_row.get_child_count(), 1, "cured, one left")
	foe.ailments.clear()
	foe._show_ailments()
	assert_eq(foe._ailment_row.get_child_count(), 0, "none left")


func test_a_foe_nothing_ails_has_no_row_at_all() -> void:
	var foe := _foe()
	foe._show_ailments()
	assert_null(foe._ailment_row, "no nodes for it in a big pack")


func test_the_icons_go_with_the_foe() -> void:
	var foe := _foe()
	foe.ailments.inflict(POISON, GameState.roll)
	foe._show_ailments()
	foe.dying = true
	foe._show_ailments()
	assert_eq(foe._ailment_row.get_child_count(), 0, "gone as it falls")
