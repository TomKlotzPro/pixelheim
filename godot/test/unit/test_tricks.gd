extends GutTest
## Common foes come alive (PIX-489): six kinds each have a trick of their
## own, by combat.json's "tricks" - the slime splits, the dire wolf bites and
## runs (a pack takes turns), the goblin snatches gold and gives it back with
## half again, the skeleton rises once from its bones unless they are struck,
## the ghost struck twice fades and comes back beside the hero, the crab's
## raised claws turn blows from the front only. Modest, told, and never a
## boss's or a named monster's; an elite keeps its family's move besides.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const Enemy := preload("res://scripts/enemy.gd")
const EliteBrainScript := preload("res://scripts/elite_brain.gd")
const TrickBrainScript := preload("res://scripts/trick_brain.gd")
const KINDS := {"slime": "split", "wolf": "hitrun", "goblin": "snatch", "skeleton": "rise", "ghost": "fade", "crab": "shell"}
const HERO_AT := Vector2(128, 128)
const TICK := 1.0 / 60.0

var _lent: Node
var _kept := {}
var _world: StubWorld


class StubSkills extends RefCounted:
	func impact(_on: Node, _alpha := 0.0) -> void:
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

	func appear(_foe: Node) -> void:
		pass


class StubCamera extends RefCounted:
	func shake(_strength: float, _seconds: float) -> void:
		pass

	func hit_stop(_seconds: float, _scale := 0.0) -> void:
		pass

	func punch(_way: Vector2) -> void:
		pass


class StubMessages extends RefCounted:
	func log_now(_line: String, _holds := Callable()) -> void:
		pass


class StubHero extends CharacterBody2D:
	var dead := false
	## Whether a bite draws blood (a roll gets out of it).
	var rolls := false

	func take_hit(_damage: int, _from: Vector2, _inflicts: Variant = null, _grace := true) -> void:
		if not rolls:
			GameState.hero.hp -= 1


## The world's foes with what a fight's bookkeeping needs of the rest of
## the world left out: who fell, and what they were worth.
class StubFoes extends Foes:
	var fallen: Array[Dictionary] = []

	func on_enemy_noticed(_foe: Node) -> void:
		pass

	func on_enemy_died(foe: Node) -> void:
		fallen.append(foe.fighter.duplicate())

	func ring_spot(_foe: Node) -> Vector2:
		return Vector2.INF


class StubWorld extends Node2D:
	var fx := StubFx.new()
	var camera_rig := StubCamera.new()
	var messages := StubMessages.new()
	var foes := StubFoes.new()
	var player: StubHero
	var actors: Node
	var harness := false
	## Open grass all round.
	var map := MapData.new()

	func _init() -> void:
		# Telegraph lays its marks at this depth among the world's children.
		for i in 4:
			add_child(Node.new())
		actors = self
		foes.world = self
		player = StubHero.new()
		player.position = HERO_AT
		add_child(player)
		for x in 16:
			for y in 16:
				map.grid[Vector2i(x, y)] = "grass"

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			foes.free()


func before_each() -> void:
	_kept = {"hero": GameState.hero, "pack": GameState.pack, "progression": GameState.progression}
	_lent = GameStateScript.new()
	_lent.new_game("Robin", "warrior")
	GameState.hero = _lent.hero
	GameState.pack = _lent.pack
	GameState.progression = _lent.progression
	_world = add_child_autofree(StubWorld.new())


func after_each() -> void:
	for key: String in _kept:
		GameState.set(key, _kept[key])
	_lent.free()


## A foe of `kind` a step right of the hero, hunting, its physics and its
## trick's stopped: the test does the stepping.
func _foe(kind: String, elite := false, at := HERO_AT + Vector2(16, 0)) -> Node:
	var foe: Node = Enemy.new()
	foe.world = _world
	foe.fighter = Bestiary.spawn(kind, elite)
	foe.position = at
	foe.home = at
	foe.add_to_group("mobs")
	_world.add_child(foe)
	foe.set_physics_process(false)
	foe.enter(EnemyState.CHASE)
	foe.hunting = true
	if foe.trick != null:
		foe.trick.set_physics_process(false)
	if foe.brain != null:
		foe.brain.set_physics_process(false)
	return foe


## The trick's clock run `seconds` on.
func _run(foe: Node, seconds: float) -> void:
	for i in ceili(seconds / TICK):
		foe.trick._physics_process(TICK)


func _standing() -> Array:
	return get_tree().get_nodes_in_group("mobs").filter(func(mob: Node) -> bool: return not mob.dying)


# --- The table ---------------------------------------------------------------

func test_six_kinds_have_a_trick_and_a_line_for_the_bestiary() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/combat.json"))["tricks"]
	var kinds := table.keys().filter(func(key: String) -> bool: return key != "about")
	kinds.sort()
	var expected := KINDS.keys()
	expected.sort()
	assert_eq(kinds, expected, "the six, by monster id")
	for kind: String in KINDS:
		assert_false(Bestiary.monster(kind).is_empty(), "%s is a monster" % kind)
		assert_eq(String(Bestiary.trick(kind)["trick"]), KINDS[kind])
		assert_between(Tricks.says(kind).length(), 12, 42, "%s: one short line" % kind)
	assert_eq(Bestiary.trick("orc"), {}, "a kind without one")
	assert_eq(Tricks.says("orc"), "")


func test_a_boss_or_a_named_monster_has_none_and_an_elite_has_it_besides_its_move() -> void:
	assert_eq(Tricks.of(Hunts.fighter("greymaw")), {}, "Old Greymaw is a wolf with no hit and run")
	assert_eq(Tricks.of(Hunts.fighter("drowned_knight")), {}, "the Drowned Knight stays down")
	assert_eq(String(Tricks.of(Bestiary.spawn("crab", true))["trick"]), "shell")
	var elite := _foe("crab", true)
	assert_true(elite.trick != null and elite.trick.get_script() == TrickBrainScript, "an elite crab guards with its shell")
	assert_true(elite.brain != null and elite.brain.get_script() == EliteBrainScript, "and still lunges, as its family does")
	var orc := _foe("orc")
	assert_null(orc.trick, "an orc has no trick")
	var staged := _foe("slime")
	staged.plain()
	assert_null(staged.trick, "the story's own foes fight plain")


func test_the_foes_a_boss_calls_fight_plain() -> void:
	# Its fight was tuned on plain adds, and it counts each to its end (a
	# slime's halves would be nobody's).
	var caller := _foe("crab", true)
	caller.brain._howl({"count": 2, "max": 2, "monsterId": "slime"})
	assert_eq(caller.brain.called.size(), 2, "it called them")
	for add: Node in caller.brain.called:
		assert_null(add.trick, "a called slime doesn't split")
		add.take_hit(99999, add.global_position + Vector2.LEFT)
	assert_eq(_standing().size(), 1, "only the caller stands")


# --- The slime splits --------------------------------------------------------

func test_a_small_slime_is_a_quarter_of_its_kind_and_never_splits_again() -> void:
	var slime := Bestiary.spawn("slime")
	var half := Tricks.small(slime, Bestiary.trick("slime"))
	assert_eq(int(half["maxHp"]), maxi(1, roundi(int(slime["maxHp"]) * 0.25)), "a quarter of its health")
	assert_eq(int(half["hp"]), int(half["maxHp"]))
	assert_lt(int(half["attack"]), int(slime["attack"]), "a weaker bite")
	assert_lt(int(half["xp"]) * 2, int(slime["xp"]), "a little XP")
	assert_lt(int(half["gold"]) * 2, int(slime["gold"]) + 1, "a little gold")
	assert_eq(Tricks.of(half), {}, "it never splits again")
	assert_false(Tricks.small(Bestiary.spawn("slime", true), Bestiary.trick("slime"))["elite"], "an elite's halves are common")
	# A newcomer's first slimes stay easy: both halves together are less than
	# the slime was, and one blow of a new hero's fells one.
	assert_lt(int(half["maxHp"]) * 2, int(slime["maxHp"]))
	assert_lte(int(half["maxHp"]), Bestiary.hero_attack_damage(GameState.hero, GameState.pack, half, false, func() -> float: return 0.0))


func test_a_slain_slime_bursts_into_two_small_ones() -> void:
	var slime := _foe("slime")
	slime.take_hit(999, HERO_AT)
	assert_true(slime.dying, "the slime fell")
	var halves := _standing()
	assert_eq(halves.size(), 2, "two come of it")
	for half: Node in halves:
		assert_true(half.fighter["small"])
		assert_null(half.trick, "which never split")
		assert_true(half.faded, "the blow that burst it doesn't sweep them up")
		assert_gte(half.global_position.distance_to(HERO_AT), slime.global_position.distance_to(HERO_AT), "never nearer the hero than the slime stood (PIX-497)")
		assert_gt(half._over_head, Enemy.BAR_Y, "its tag sits just over it, not at its kind's height")
		assert_gt(half.mark_foot(), Enemy.BAR_Y, "and its \"!\" right over it")
		var low: float = half.mark_foot()
		half.lead_tag(true)
		assert_lte(half.mark_foot(), low - Enemy.TAG_HEIGHT, "over its tag when it is the one showing the pack's")
		half.lead_tag(false)
		assert_eq(half.mode, "alert", "they come after the \"!\"")
		assert_lt(half.sprite.sprite_frames.get_frame_texture("idle", 0).get_size().x, slime.sprite.sprite_frames.get_frame_texture("idle", 0).get_size().x, "drawn smaller")
	assert_eq(_world.foes.tricks_shown, {"split": 1})
	assert_has(GameState.progression.tricks, "slime", "the Bestiary knows it now")
	await wait_seconds(TrickBrainScript.BURST_SECONDS + 0.2)
	halves[0].take_hit(999, HERO_AT)
	assert_true(halves[0].dying, "then a blow fells one")
	assert_eq(_standing().size(), 1, "and nothing more comes of it")


func test_a_pack_isnt_scattered_while_a_half_still_stands() -> void:
	var slime := _foe("slime")
	slime.spawn_id = "forest_1"
	_world.foes.pack_alive["forest_1"] = 1
	slime.take_hit(999, HERO_AT)
	assert_eq(_world.foes.pack_alive["forest_1"], 3, "the halves are of its pack (the fall takes one off)")


# --- The dire wolf bites and runs ---------------------------------------------

func test_a_wolf_keeps_to_its_circle_and_bites_only_on_its_dart() -> void:
	var wolf := _foe("wolf")
	var trick: Dictionary = Bestiary.trick("wolf")
	assert_false(wolf.trick.may_bite(), "out on its circle it doesn't bite")
	var spot: Vector2 = wolf.trick.stand(Vector2.INF, HERO_AT - wolf.global_position)
	assert_almost_eq(spot.distance_to(HERO_AT), float(trick["circle"]) * 16.0, 0.01, "alone, it stands out on the circle")
	assert_gt(float(trick["circle"]) * 16.0, float(Packs.rules()["ring"]["far"]), "further out than the ring waits: out of a sweep's reach")
	assert_ne(spot.angle_to_point(HERO_AT), wolf.global_position.angle_to_point(HERO_AT), "a step round: it circles")
	var ring := HERO_AT + Vector2(0, -28)
	assert_almost_eq(wolf.trick.stand(ring, HERO_AT - wolf.global_position), HERO_AT + Vector2(0, -32), Vector2(0.01, 0.01), "in a pack, its place in the ring, out at the circle")
	# Its turn comes: the crouch is the tell, then the dart.
	_run(wolf, 0.5)
	assert_eq(wolf.trick.state, "crouch", "it crouches first")
	assert_false(wolf.trick.may_bite(), "no bite out of the crouch")
	assert_eq(wolf.trick.stand(Vector2.INF, Vector2.LEFT), wolf.global_position, "holding where it is")
	var pace: float = wolf.pace
	_run(wolf, float(trick["crouch"]) + TICK)
	assert_eq(wolf.trick.state, "in")
	assert_true(wolf.trick.may_bite(), "on its dart it bites")
	assert_eq(wolf.trick.stand(ring, Vector2.LEFT), Vector2.INF, "straight at the hero")
	assert_gt(wolf.pace, pace, "fast")
	wolf.trick.bit(true)
	assert_false(wolf.trick.may_bite(), "one bite a dart")
	assert_eq(wolf.trick.stand(ring, Vector2.LEFT), Vector2.INF, "it stays on the hero a moment: a blow's shove doesn't put it out of reach")
	_run(wolf, float(trick["linger"]) + TrickBrainScript.AWAY_SECONDS + 0.1)
	assert_eq(wolf.trick.state, "", "and out again")
	assert_almost_eq(wolf.pace, pace, 0.001, "at its own pace")
	assert_eq(_world.foes.tricks_shown, {"dart": 1})


func test_a_wolfs_circle_never_takes_it_past_its_leash() -> void:
	# PIX-493: the hero rolled twice away from a wolf's dart, the wolf's run
	# back out to its circle led past them, over its leash, and it gave the
	# fight up and walked home.
	var leash := Packs.tiles("giveUpTiles")
	var home := Vector2(100, 40)
	assert_eq(Tricks.leashed(home + Vector2(30, 0), home), home + Vector2(30, 0), "within its leash, where it would stand")
	assert_almost_eq(Tricks.leashed(home + Vector2(-200, 0), home), home + Vector2(-(leash - 16.0), 0), Vector2(0.01, 0.01), "past it, a cell inside")
	# The hero six cells west of its home, the wolf beyond them.
	var wolf := _foe("wolf", false, HERO_AT + Vector2(-16, 0))
	wolf.home = HERO_AT + Vector2(6 * 16, 0)
	for ring: Vector2 in [Vector2.INF, HERO_AT + Vector2(-28, 0)]:
		var spot: Vector2 = wolf.trick.stand(ring, HERO_AT - wolf.global_position)
		assert_lte(spot.distance_to(wolf.home), leash - 15.9, "its place out there is on its leash")
		assert_false(Enemy.gives_up(wolf.fighter, wolf.home, spot, HERO_AT), "so it fights on from it")
	wolf.at_bay = true
	assert_almost_eq(wolf.trick.stand(HERO_AT + Vector2(-28, 0), HERO_AT - wolf.global_position), HERO_AT + Vector2(-32, 0), Vector2(0.01, 0.01), "at bay it has no leash")


func test_a_crouching_wolfs_eyes_shine() -> void:
	var wolf := _foe("wolf")
	_run(wolf, 0.5)
	assert_eq(wolf.trick.state, "crouch")
	var eyes: Sprite2D = wolf.trick._eyes
	assert_true(eyes.visible, "while it crouches")
	assert_eq((eyes.material as CanvasItemMaterial).light_mode, CanvasItemMaterial.LIGHT_MODE_UNSHADED, "bright in the dark")
	# Facing the hero to its left, its frame shows an eye or two: those pixels alone.
	var lit := 0
	var image := eyes.texture.get_image()
	for y in image.get_height():
		for x in image.get_width():
			lit += int(image.get_pixel(x, y).a > 0.0)
	assert_between(lit, 1, 4, "two pixels or so of eye-shine")
	_run(wolf, float(Bestiary.trick("wolf")["crouch"]) + TICK)
	assert_eq(wolf.trick.state, "in")
	assert_false(eyes.visible, "gone as it darts")


func test_a_wolf_slain_mid_crouch_falls_with_no_eyes() -> void:
	var wolf := _foe("wolf")
	_run(wolf, 0.5)
	assert_eq(wolf.trick.state, "crouch")
	wolf.trick.died()
	assert_false(wolf.trick._eyes.visible, "no eye-shine over its fall")


func test_a_dart_the_hero_got_away_from_is_given_up() -> void:
	var wolf := _foe("wolf")
	_run(wolf, 1.0 + float(Bestiary.trick("wolf")["crouch"]))
	assert_eq(wolf.trick.state, "in")
	_run(wolf, float(Bestiary.trick("wolf")["seconds"]) + 0.1)
	assert_eq(wolf.trick.state, "", "no bite in time: back to its circle")


func test_a_pack_of_wolves_takes_turns() -> void:
	var pack: Array[Node] = [_foe("wolf"), _foe("wolf", false, HERO_AT + Vector2(-16, 0)), _foe("wolf", false, HERO_AT + Vector2(0, 16))]
	var darts := 0
	for step in 600:
		for wolf in pack:
			wolf.trick._physics_process(TICK)
			# The dart's bite, as soon as it may.
			if wolf.trick.state == "in":
				darts += 1
				wolf.trick.bit(true)
		assert_lte(pack.filter(func(wolf: Node) -> bool: return wolf.trick.state != "").size(), 1, "never two darting at once")
		assert_lte(pack.filter(func(wolf: Node) -> bool: return wolf.trick.may_bite()).size(), 1, "never two bites at once")
	assert_gt(darts, 0, "and they do dart")


func test_the_turn_is_one_wolfs_until_it_ends_and_a_breath_after() -> void:
	var a := _foe("wolf")
	var b := _foe("wolf", false, HERO_AT + Vector2(-16, 0))
	assert_true(_world.foes.take_turn(a))
	assert_false(_world.foes.take_turn(b), "one at a time")
	_world.foes.end_turn(a, 10.0)
	assert_false(_world.foes.take_turn(b), "a breath between two darts")
	assert_true(Tricks.may_dart(false, 5.0, 4.0))
	assert_false(Tricks.may_dart(true, 5.0, 4.0))
	assert_false(Tricks.may_dart(false, 3.0, 4.0))
	# A wolf that fell holding the turn holds nobody up.
	_world.foes._turn_free_at = -100.0
	assert_true(_world.foes.take_turn(a))
	a.dying = true
	assert_true(_world.foes.take_turn(b), "the turn of one that fell is free")


# --- The goblin snatches gold -------------------------------------------------

func test_a_snatch_is_a_twentieth_capped_by_the_goblins_level() -> void:
	var trick: Dictionary = Bestiary.trick("goblin")
	assert_eq(Tricks.snatched(0, 2, trick), 0, "nothing from an empty purse")
	assert_eq(Tricks.snatched(1, 2, trick), 1, "never more than is carried")
	assert_eq(Tricks.snatched(40, 2, trick), 2, "5% of 40")
	assert_eq(Tricks.snatched(5000, 2, trick), 4, "never more than twice its level")
	assert_eq(Tricks.snatched(5000, 9, trick), 18)
	assert_eq(Tricks.given_back(4, trick), 6, "back with half again")
	assert_eq(Tricks.given_back(1, trick), 2)


func test_a_goblins_bite_that_lands_takes_gold_once_and_its_fall_gives_it_back() -> void:
	GameState.pack.gold = 100
	var goblin := _foe("goblin")
	var worth := int(goblin.fighter["gold"])
	goblin._bite(HERO_AT - goblin.global_position)
	assert_eq(GameState.pack.gold, 96, "four coins gone: 5% of 100, capped at twice its level")
	assert_eq(_world.fx.words, [Text.t("-%d gold") % 4], "a small float says so")
	assert_eq(goblin.mode, "flee", "and it runs")
	assert_eq(_world.foes.tricks_shown, {"snatch": 1})
	# It turns back to fight, and bites again: nothing more is taken.
	_run(goblin, float(Bestiary.trick("goblin")["runs"]) + 0.1)
	assert_eq(goblin.mode, "chase", "then it turns back")
	goblin._bite(HERO_AT - goblin.global_position)
	assert_eq(GameState.pack.gold, 96, "once a goblin")
	goblin.take_hit(999, HERO_AT)
	assert_eq(int(_world.foes.fallen[0]["gold"]), worth + 6, "slain, it pays its own gold and the four with half again")


func test_a_bite_rolled_through_takes_nothing() -> void:
	GameState.pack.gold = 100
	_world.player.rolls = true
	var goblin := _foe("goblin")
	goblin._bite(HERO_AT - goblin.global_position)
	assert_eq(GameState.pack.gold, 100, "the roll gets out of it")
	assert_eq(goblin.mode, "chase")


func test_nothing_is_snatched_on_the_night_of_ash() -> void:
	GameState.pack.gold = 100
	GameState.progression.prologue = Prologue.SCAVENGER
	assert_eq(GameState.spoils.snatch(2, Bestiary.trick("goblin")), 0)
	assert_eq(GameState.pack.gold, 100)


# --- The skeleton pulls itself together ----------------------------------------

func test_a_slain_skeleton_falls_to_bones_and_rises_once_with_half_its_health() -> void:
	var skeleton := _foe("skeleton")
	var whole := int(skeleton.fighter["maxHp"])
	skeleton.take_hit(999, HERO_AT)
	assert_false(skeleton.dying, "not done yet")
	assert_eq(skeleton.mode, "pile", "a pile of bones")
	assert_false(skeleton.sprite.visible)
	assert_eq(_world.foes.fallen.size(), 0, "no XP for a pile")
	_run(skeleton, float(Bestiary.trick("skeleton")["seconds"]) - 0.2)
	assert_eq(skeleton.mode, "pile", "about three seconds of rattling")
	_run(skeleton, 0.3)
	assert_eq(skeleton.mode, "chase", "then it stands")
	assert_true(skeleton.sprite.visible)
	assert_eq(int(skeleton.fighter["hp"]), roundi(whole * 0.5), "with half its health")
	assert_eq(_world.foes.tricks_shown, {"pile": 1, "rose": 1})
	skeleton.take_hit(999, HERO_AT)
	assert_true(skeleton.dying, "once: the second fall is its last")
	assert_eq(_world.foes.fallen.size(), 1, "and now it pays")


func test_one_blow_on_the_pile_ends_it() -> void:
	var skeleton := _foe("skeleton")
	skeleton.take_hit(999, HERO_AT)
	_run(skeleton, 1.0)
	skeleton.take_hit(1, HERO_AT, {"kind": "poison", "chance": 2.0, "turns": 3, "power": 1})
	assert_true(skeleton.dying, "a single hit on the bones")
	assert_eq(_world.foes.fallen.size(), 1, "its XP given when it is truly done")
	assert_eq(_world.foes.tricks_shown, {"pile": 1}, "it never rose")


func test_the_bones_are_made_of_its_own_pixels() -> void:
	var skeleton := _foe("skeleton")
	var frame: Image = skeleton.sprite.sprite_frames.get_frame_texture("idle_down", 0).get_image()
	var pile: Image = TrickBrainScript.pile_image(frame)
	var used: Rect2i = frame.get_used_rect()
	assert_lt(pile.get_height(), used.size.y, "lower than it stood")
	assert_gt(pile.get_width(), used.size.x, "and spread wider")
	assert_gt(pile.get_used_rect().size.x, used.size.x, "the heap beside the skull")
	assert_eq(Tricks.risen(52, Bestiary.trick("skeleton")), 26)


# --- The ghost fades -----------------------------------------------------------

func test_two_blows_in_a_moment_fade_a_ghost_and_not_again_for_a_while() -> void:
	var trick: Dictionary = Bestiary.trick("ghost")
	assert_false(Tricks.fades([1.0], -100.0, trick), "one blow is not two")
	assert_true(Tricks.fades([1.0, 2.0], -100.0, trick))
	assert_false(Tricks.fades([1.0, 3.0], -100.0, trick), "too far apart")
	assert_false(Tricks.fades([8.0, 8.5], 5.0, trick), "not within seconds of the last")
	assert_true(Tricks.fades([10.5, 11.0], 5.0, trick))


func test_a_faded_ghost_cant_be_struck_and_comes_back_beside_the_hero() -> void:
	var ghost := _foe("ghost")
	var trick: Dictionary = Bestiary.trick("ghost")
	ghost.take_hit(1, HERO_AT)
	assert_eq(ghost.trick.state, "", "one blow: nothing")
	ghost.take_hit(1, HERO_AT)
	assert_eq(ghost.trick.state, "shimmer", "the second: it shimmers (the tell)")
	assert_false(ghost.faded, "and can still be struck as it does")
	_run(ghost, float(trick["tell"]) + TICK)
	assert_true(ghost.faded, "then no blow finds it")
	assert_almost_eq(ghost.modulate.a, TrickBrainScript.FADED, 0.001, "see-through")
	var left := int(ghost.fighter["hp"])
	ghost.take_hit(5, HERO_AT)
	assert_eq(int(ghost.fighter["hp"]), left, "a blow goes through it")
	assert_eq(ghost.mode, "cast", "and it bites nobody meanwhile")
	_run(ghost, float(trick["seconds"]) + TICK)
	assert_false(ghost.faded, "about a second later it is back")
	assert_almost_eq(ghost.modulate.a, 1.0, 0.001)
	assert_eq(ghost.mode, "chase")
	assert_almost_eq(ghost.global_position, HERO_AT + Vector2(-(ghost.edge + 3.0), 0), Vector2(0.01, 0.01), "beside the hero, on their far side")
	# Behind them: it holds its bite's tell, the hero's time to turn.
	assert_false(ghost.trick.may_bite(), "no bite told as it shows")
	var origin := GameClock.origin
	GameClock.origin -= ceili(float(trick["holds"]) * 60.0) + 1
	assert_true(ghost.trick.may_bite(), "then its bite, told as any")
	assert_almost_eq(float(trick["holds"]) + float(Packs.rules()["biteTellSeconds"]), 0.8, 0.05, "about 0.8 s from showing to the blow")
	GameClock.origin = origin
	ghost.take_hit(1, HERO_AT)
	ghost.take_hit(1, HERO_AT)
	assert_eq(ghost.trick.state, "", "not again so soon")
	assert_eq(_world.foes.tricks_shown, {"fade": 1})


func test_a_ghost_comes_back_on_open_ground() -> void:
	var spots := Tricks.beside(HERO_AT, HERO_AT + Vector2(16, 0), 14.0)
	assert_eq(spots[0], HERO_AT + Vector2(-14, 0), "behind the hero first")
	assert_eq(spots.size(), 4, "then either side, then where it came from")
	assert_almost_eq(spots[3], HERO_AT + Vector2(14, 0), Vector2(0.01, 0.01))


# --- The crab guards with its shell --------------------------------------------

func test_a_shell_turns_a_blow_from_the_front_only() -> void:
	var trick: Dictionary = Bestiary.trick("crab")
	var front := Vector2.LEFT
	assert_eq(Tricks.shelled(20, front, Vector2(-16, 0), trick), 5, "a quarter from the front")
	assert_eq(Tricks.shelled(20, front, Vector2(-16, 9), trick), 5, "within its arc")
	assert_eq(Tricks.shelled(20, front, Vector2(0, 16), trick), 20, "whole from the side")
	assert_eq(Tricks.shelled(20, front, Vector2(16, 0), trick), 20, "whole from behind")
	assert_eq(Tricks.shelled(1, front, Vector2(-16, 0), trick), 1, "never nothing")


func test_a_crabs_claws_come_up_and_go_down_and_its_back_is_open() -> void:
	var crab := _foe("crab")
	var trick: Dictionary = Bestiary.trick("crab")
	var hp := int(crab.fighter["hp"])
	crab.take_hit(4, HERO_AT)
	assert_eq(int(crab.fighter["hp"]), hp - 4, "claws down, a blow lands whole")
	_run(crab, 1.3)
	assert_eq(crab.trick.state, "raise", "claws coming up: the tell")
	assert_true(crab.trick.posed(), "shown on its sprite")
	assert_eq(crab.mode, "cast", "it stands to guard")
	await wait_seconds(float(trick["tell"]) / 2.0)
	assert_gt(crab.sprite.scale.y, crab.rest_scale.y * 1.1, "thrown up in the tell's first half")
	assert_eq(crab.get_children().filter(func(child: Node) -> bool: return child is Sprite2D and (child as Sprite2D).texture == TrickBrainScript.star_texture()).size(), 1, "a glint off them as they rise")
	_run(crab, float(trick["tell"]) + TICK)
	assert_eq(crab.trick.state, "up")
	assert_almost_eq(float(trick["tell"]), 0.3, 0.001, "the tell no longer than it was")
	assert_almost_eq(float(trick["seconds"]), 1.6, 0.001, "nor the guard")
	hp = int(crab.fighter["hp"])
	crab.take_hit(8, HERO_AT)
	assert_eq(int(crab.fighter["hp"]), hp - 2, "from the front, a quarter")
	assert_has(_world.fx.words, Text.t("blocked"))
	crab.take_hit(8, crab.global_position + Vector2(16, 0))
	assert_eq(int(crab.fighter["hp"]), hp - 10, "from behind (a Shadowstep, a walk round it), whole")
	crab.take_hit(8, crab.global_position + Vector2(0, 16))
	assert_eq(int(crab.fighter["hp"]), hp - 18, "from the side too")
	_run(crab, float(trick["seconds"]) + TICK)
	assert_eq(crab.trick.state, "", "the guard comes and goes")
	assert_eq(crab.mode, "chase")
	assert_false(crab.trick.posed())
	hp = int(crab.fighter["hp"])
	crab.take_hit(4, HERO_AT)
	assert_eq(int(crab.fighter["hp"]), hp - 4, "claws down again")
	assert_eq(_world.foes.tricks_shown, {"shell": 1})


func test_a_stun_brings_the_claws_down() -> void:
	var crab := _foe("crab")
	_run(crab, 1.3 + float(Bestiary.trick("crab")["tell"]) + TICK)
	assert_eq(crab.trick.state, "up")
	crab.take_hit(1, crab.global_position + Vector2(16, 0), {"kind": "stun", "chance": 2.0, "turns": 2, "power": 0})
	assert_eq(crab.trick.state, "", "a stun breaks the guard")
	assert_has(_world.fx.words, Text.t("Interrupted!"))


# --- The Bestiary --------------------------------------------------------------

func test_a_trick_seen_is_kept_once_and_saved() -> void:
	GameState.spoils.saw_trick("ghost")
	GameState.spoils.saw_trick("ghost")
	assert_eq(GameState.progression.tricks, ["ghost"] as Array[String])
	var state := {"quests": {}}
	GameState.progression.write_into(state)
	assert_eq(state["tricks"], ["ghost"])
	assert_eq(ProgressionState.from_dict(state).tricks, ["ghost"] as Array[String])
	var fresh := {"quests": {}}
	ProgressionState.new().write_into(fresh)
	assert_false(fresh.has("tricks"), "saved only once there is one")


func test_a_small_slime_does_not_tick_a_slime_bounty() -> void:
	_lent.progression.quests["slime_trouble"] = {"progress": 0, "done": false}
	var slime := Bestiary.spawn("slime")
	_lent.spoils.defeat_monster(Tricks.small(slime, Bestiary.trick("slime")), "", "", 1)
	assert_eq(int(_lent.progression.quests["slime_trouble"]["progress"]), 0, "its small ones are not three kills")
	_lent.spoils.defeat_monster(slime, "", "", 1)
	assert_eq(int(_lent.progression.quests["slime_trouble"]["progress"]), 1)
