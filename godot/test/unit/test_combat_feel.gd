extends GutTest
## Combat feel (PIX-155): the dodge's timings make sense together, every
## elite family has a trick, the marks on the ground catch who stands in
## them, and the dodge has a key of its own.


func test_the_dodge_protects_for_the_whole_roll_and_waits_after() -> void:
	var dodge: Dictionary = Bestiary._data()["dodge"]
	assert_gte(float(dodge["iframes"]), float(dodge["seconds"]), "untouchable for the whole roll")
	assert_gt(float(dodge["cooldown"]), float(dodge["iframes"]), "not a permanent shield")
	assert_between(float(dodge["speed"]) * float(dodge["seconds"]) / 16.0, 2.0, 4.0, "two to four tiles a roll")


func test_every_elite_family_has_a_told_trick() -> void:
	var moves: Dictionary = Bestiary._data()["eliteMoves"]
	for family: String in Bestiary._data()["familyNames"]:
		assert_true(moves.has(family), "%s elites have a move" % family)
	for family: String in moves:
		var move: Dictionary = moves[family]
		assert_true(String(move["move"]) in ["lunge", "cleave", "guard", "stamp", "firebolt"])
		if move.has("tell"):
			assert_gte(float(move["tell"]), 0.35, "%s's move gives time to react" % family)


## PIX-422: since a hero's blade reaches only the cell in front (PIX-410),
## the greenskins' and outlaws' cleave is told within a cell and a quarter,
## not from two cells off: never started further, its band striking a hero
## who stands where it began and sparing one who steps back out of it, and
## the elite comes in rather than waiting in the ring where it never could.
func test_the_cleave_is_told_up_close_and_spares_a_hero_who_steps_back() -> void:
	var EliteBrain := preload("res://scripts/elite_brain.gd")
	var at := Vector2(100, 100)
	for family: String in ["greenskins", "outlaws"]:
		var cleave: Dictionary = Bestiary.elite_moves(family)
		assert_eq(String(cleave["move"]), "cleave")
		assert_lte(float(cleave["range"][1]), 1.25, "%s: about a cell and a quarter" % family)
		assert_false(EliteBrain.in_reach(cleave, at, at + Vector2(1.3 * 16.0, 0)), "%s: not started from further" % family)
		assert_false(EliteBrain.in_reach(cleave, at, at + Vector2(2.0 * 16.0, 0)), "%s: never from two cells off" % family)
		for way: Vector2 in [Vector2.RIGHT, Vector2(-0.6, 0.8)]:
			# Just inside its reach (half a pixel: clear of float rounding).
			var hero := at + way * (float(cleave["range"][1]) * 16.0 - 0.5)
			assert_true(EliteBrain.in_reach(cleave, at, hero), "%s: started at its reach" % family)
			var band := EliteBrain.cleave_band(cleave, at, hero)
			assert_true(Geometry2D.is_point_in_polygon(hero, band), "%s: a hero who stands is struck" % family)
			assert_false(Geometry2D.is_point_in_polygon(hero + way * 4.0, band), "%s: a hero who stepped back out is not" % family)
		assert_false(Packs.waits_in_ring(cleave), "%s: it comes in, not waits in the ring" % family)
	assert_true(Packs.waits_in_ring(Bestiary.elite_moves("beasts")), "a lunge starts from the ring's far place")
	assert_true(Packs.waits_in_ring({}), "a foe with no trick waits its turn")


func test_a_band_and_a_circle_catch_what_stands_in_them() -> void:
	var band := Telegraph.band(Vector2.ZERO, Vector2(100, 0), 64, 16)
	assert_true(Geometry2D.is_point_in_polygon(Vector2(40, 0), band))
	assert_false(Geometry2D.is_point_in_polygon(Vector2(80, 0), band), "past its end")
	assert_false(Geometry2D.is_point_in_polygon(Vector2(40, 12), band), "beside it")
	var ring := Telegraph.circle(Vector2(50, 50), 30)
	assert_true(Geometry2D.is_point_in_polygon(Vector2(60, 60), ring))
	assert_false(Geometry2D.is_point_in_polygon(Vector2(90, 50), ring))


func test_the_dodge_has_a_key_and_trades_it_when_rebound() -> void:
	assert_eq(Controls.key_for("dodge", {}), KEY_SHIFT)
	var swapped := Controls.rebind({}, "dodge", KEY_J)
	assert_eq(Controls.key_for("dodge", swapped), KEY_J)
	assert_eq(Controls.key_for("attack", swapped), KEY_SHIFT, "attack takes the old key")


## PIX-209: a crit says so, from the same roll that makes it one.
func test_a_swing_knows_when_it_was_a_crit() -> void:
	var hero := HeroState.create("T", "warrior")
	var pack := InventoryState.new()
	var slime := Bestiary.spawn("slime")
	var sure := Bestiary.hero_attack(hero, pack, slime, false, func() -> float: return 0.5, 0.0, 1.0)
	assert_true(sure["crit"], "a sure crit is one")
	assert_eq(sure["damage"], Bestiary.hero_attack_damage(hero, pack, slime, false, func() -> float: return 0.5, 0.0, 1.0))
	var plain := Bestiary.hero_attack(hero, pack, slime, false, func() -> float: return 0.5, 0.0, 0.0)
	assert_false(plain["crit"])
	assert_gt(sure["damage"], plain["damage"])


## A blow shoves a common foe about 6 px, an elite half that, a boss not at
## all; never so far that a foe telling its bite (Reach.bite_tell) is out of
## its reach (Reach.bite_lands; PIX-377: at 10 px a hero swinging every
## 0.45 s was hardly ever bitten).
func test_a_blow_shoves_by_weight() -> void:
	var EnemyScript := preload("res://scripts/enemy.gd")
	var common := EnemyScript.knock_push(Bestiary.spawn("wolf"))
	assert_eq(EnemyScript.knock_push(Bestiary.spawn("wolf", true)), common / 2.0, "an elite")
	assert_eq(EnemyScript.knock_push(Bestiary.spawn("wolf"), true), common / 2.0, "a named foe")
	var boss_id: String = Bestiary._data()["bossIds"][0]
	assert_eq(EnemyScript.knock_push(Bestiary.spawn(boss_id)), 0.0, "a boss stands")
	# The shove fades over its time: what it adds up to at 60 ticks a second.
	var travelled := 0.0
	var left := float(EnemyScript.KNOCK_TIME)
	while left > 0:
		travelled += common * (left / EnemyScript.KNOCK_TIME) / 60.0
		left -= 1.0 / 60.0
	assert_between(travelled, 5.0, 8.0, "about 6 px")
	assert_lt(Reach.bite_tell() + travelled, Reach.bite_lands(), "a foe telling its bite keeps it in reach")


## PIX-451: a foe closing in stops at the hero's edge (an elite and Fafnyr
## stood on the hero, the two drawn as one): the step toward them goes, the
## step round them stays, stopped it faces them, and it never backs off a
## hero who walks up to it.
func test_a_foe_stops_at_the_heros_edge() -> void:
	var foe: CharacterBody2D = autofree(preload("res://scripts/enemy.gd").new())
	foe.edge = 14.0
	var tick := 1.0 / 60.0
	foe.velocity = Vector2(55, 0)
	foe._keep_off(Vector2(40, 0), tick)
	assert_eq(foe.velocity, Vector2(55, 0), "far off, the chase as it was")
	foe._keep_off(Vector2(14.5, 0), tick)
	assert_almost_eq(foe.velocity.x * tick, 0.5, 0.001, "a step short: as far as its edge")
	foe.facing = "up"
	foe.velocity = Vector2(55, 0)
	foe._keep_off(Vector2(14, 0), tick)
	assert_eq(foe.velocity, Vector2.ZERO, "at its edge, no nearer")
	assert_eq(foe.facing, "right", "and it faces them")
	foe.velocity = Vector2(40, 30)
	foe._keep_off(Vector2(14, 0), tick)
	assert_eq(foe.velocity, Vector2(0, 30), "round them to its place in the ring")
	foe.velocity = Vector2(-20, 0)
	foe._keep_off(Vector2(10, 0), tick)
	assert_eq(foe.velocity, Vector2(-20, 0), "walked up to, it goes on as it was")


## PIX-451: every foe, drawn as it is (the art installed), stops beside the
## hero rather than on them - a big dragon's wingtip over them at most - in
## a blade's reach, telling its bite from there; and an elite or a named
## monster with a cleave starts it there and strikes a hero who stands.
func test_every_foe_stops_beside_the_hero_in_reach_of_both() -> void:
	var EnemyScript := preload("res://scripts/enemy.gd")
	var EliteBrain := preload("res://scripts/elite_brain.gd")
	var near := float(Packs.rules()["ring"]["near"])
	var fighters: Array[Dictionary] = [Bells.fafnyr()]
	for id: String in Bestiary._data()["monsters"]:
		fighters.append(Bestiary.spawn(id))
		fighters.append(Bestiary.spawn(id, true))
	for entry: Dictionary in Hunts.all():
		fighters.append(Hunts.fighter(entry["id"]))
	for fighter in fighters:
		var who := "%s %s" % [fighter["id"], fighter.get("named", "")]
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = PunyArt.frames(PunyArt.monster(fighter["id"]))
		var size := EnemyScript.drawn_size(fighter)
		var shadow: Sprite2D = EnemyScript.ground_shadow(sprite, size, 0.0)
		var foot := shadow.texture.get_width() * size / 2.0
		shadow.free()
		sprite.free()
		var body := EnemyScript.body_of(fighter).x / 2.0
		var edge := EnemyScript.edge_of(foot, body)
		var beyond := maxf(0.0, edge - near)
		var at := Vector2(100, 100)
		var hero := at + Vector2.LEFT * edge
		assert_lte(EnemyScript.HERO_HALF + foot - edge, foot / 2.0, "%s: beside the hero, not on them" % who)
		assert_true(Reach.lands(hero, Vector2.RIGHT, at, body, Reach.swing("sword")), "%s: a blade reaches it" % who)
		assert_lt(edge, Reach.bite_tell() + beyond, "%s: it tells its bite from there" % who)
		var trick := Bestiary.elite_moves(Bestiary.family_of(fighter["id"]))
		if String(trick.get("move", "")) == "cleave":
			assert_true(EliteBrain.in_reach(trick, at, hero, beyond), "%s: it cleaves from there" % who)
			assert_true(Geometry2D.is_point_in_polygon(hero, EliteBrain.cleave_band(trick, at, hero, beyond)), "%s: and strikes a hero who stands" % who)


## PIX-377: monsters last a real fight. A wild foe's health grows by a scale
## that tapers to the forest's levels, a boss's by one that falls as its row
## grows, and the Night of Bells keeps its own numbers.
func test_monster_health_is_scaled_for_real_time() -> void:
	assert_eq(Bestiary.health_scale(1), Bestiary.LOW_HEALTH_SCALE, "a level-1 foe the least")
	assert_lt(Bestiary.health_scale(4), Bestiary.health_scale(5), "rising through the forest and the coast")
	assert_eq(Bestiary.health_scale(Bestiary.FULL_HEALTH_LEVEL), Bestiary.HEALTH_SCALE)
	assert_eq(Bestiary.health_scale(20), Bestiary.HEALTH_SCALE)
	assert_eq(int(Bestiary.spawn("orc")["maxHp"]), roundi(int(Bestiary.monster("orc")["maxHp"]) * Bestiary.health_scale(5)))
	assert_eq(int(Bestiary.spawn("orc", true)["maxHp"]), roundi(int(Bestiary.monster("orc")["maxHp"]) * Bestiary.health_scale(5) * float(Bestiary._data()["eliteHp"])), "an elite's on top")
	assert_eq(Bestiary.boss_health_scale(5), Bestiary.BOSS_HEALTH_SCALE)
	assert_eq(Bestiary.boss_health_scale(21), Bestiary.TOP_BOSS_HEALTH_SCALE)
	assert_gt(int(Hunts.fighter("hollow_king")["maxHp"]), int(Hunts.fighter("greymaw")["maxHp"]), "the last guardian still outlasts the first")
	assert_eq(int(Bells.fafnyr()["maxHp"]), int(Bells.fafnyr_spec()["maxHp"]), "Fafnyr keeps his")


func test_the_fight_has_its_own_blips() -> void:
	var SoundScript := preload("res://scripts/sound.gd")
	for name: String in ["swing", "cast", "kill"]:
		assert_true(SoundScript.UI_SOUNDS.has(name), name)
		assert_gt(SoundScript._synth(SoundScript.UI_SOUNDS[name]).data.size(), 0, name)


class FakeSkillFx extends RefCounted:
	var impacts_held := false

	func cast(_skill: Dictionary, _caster: Node, _targets: Array) -> bool:
		return false


class FakeFx extends RefCounted:
	var skills := FakeSkillFx.new()
	var words: Array[String] = []

	func dust(_at: Vector2) -> void:
		pass

	func float_text(text: String, _at: Vector2, _color: Color, _big := false) -> void:
		words.append(text)

	func float_number(_value: int, _at: Vector2, _color: Color, _crit := false, _who: Object = null) -> void:
		pass

	func skill_flash(_at: Vector2, _color: Color, _glow := true) -> void:
		pass


class FakeMessages extends RefCounted:
	func withdraw(_text: String) -> void:
		pass

	func flash(_text: String) -> void:
		pass

	func log_line(_text: String) -> void:
		pass


class FakeWorld extends Node2D:
	var fx := FakeFx.new()
	var messages := FakeMessages.new()
	var map := MapData.new()
	var foes := FakeFight.new()
	## The hero the foes keep off (PIX-458).
	var player: Node2D

	func on_player_died() -> void:
		pass


class FakeFight extends RefCounted:
	func in_fight(_linger := 0.0) -> bool:
		return true


## A foe as the hero sees one: where it stands, how near another may come,
## and how often it was struck.
class FakeFoe extends Node2D:
	var fighter := Bestiary.spawn("wolf")
	var edge := 14.0
	var dying := false
	var hits := 0

	func _ready() -> void:
		add_to_group("mobs")

	static func body_of(_fighter: Dictionary) -> Vector2:
		return Vector2(10, 8)

	func take_hit(_damage: int, _from: Vector2, _infliction: Variant = null, _crit := false, _blow := "") -> void:
		hits += 1


var _kept := {}


func after_each() -> void:
	for key: String in _kept:
		GameState.set(key, _kept[key])
	_kept.clear()


## A hero with a sword (strikes on frames 1 and 2 of 0..3), stepped by hand.
func _hero() -> CharacterBody2D:
	Controls.apply({})
	var hero: CharacterBody2D = preload("res://scripts/player.gd").new()
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(hero)
	hero.world = autofree(FakeWorld.new())
	hero.art = hero.art.merged({"attack": "sword"}, true)
	return hero


## A rogue with Shadowstep on the first key, lent to GameState for the test,
## on a field of grass at cell (5, 5), facing right.
func _rogue() -> CharacterBody2D:
	var lent: Node = autofree(preload("res://scripts/state/game_state.gd").new())
	lent.new_game("Robin", "rogue")
	lent.hero.skill_nodes.append("rogue_shadowstep")
	lent.hero.skill_dock.assign(["rogue_shadowstep"])
	lent.hero.mp = 50
	_kept = {"hero": GameState.hero, "pack": GameState.pack}
	GameState.hero = lent.hero
	GameState.pack = lent.pack
	var hero := _hero()
	for x in 12:
		for y in 12:
			hero.world.map.grid[Vector2i(x, y)] = "grass"
	hero.global_position = MapView.center(Vector2i(5, 5))
	hero.face(Vector2.RIGHT)
	return hero


func _foe(at: Vector2) -> FakeFoe:
	var foe: FakeFoe = add_child_autofree(FakeFoe.new())
	foe.global_position = at
	return foe


## PIX-455: with every spot round its foe walled off or taken by another
## foe, Shadowstep strikes from where the hero stands, as far as a blade
## reaches: refused three cells off, the foe struck from the cell beside it.
func test_a_hemmed_in_step_strikes_from_where_the_hero_stands() -> void:
	var hero := _rogue()
	for y in [4, 5, 6]:
		hero.world.map.grid[Vector2i(7, y)] = "wall"
	var foe := _foe(MapView.center(Vector2i(6, 5)))
	var others := [_foe(foe.global_position + Vector2(0, -16)), _foe(foe.global_position + Vector2(0, 16))]
	var mp: int = GameState.hero.mp
	hero.global_position = MapView.center(Vector2i(3, 5))
	hero.cast(0)
	assert_eq(hero.refused, "No foe in reach for Shadowstep.", "three cells off, out of a blade's reach")
	assert_eq(GameState.hero.mp, mp, "and it costs nothing")
	var at := MapView.center(Vector2i(5, 5))
	hero.global_position = at
	hero.cast(0)
	assert_false(hero.stepping, "no step")
	assert_eq(hero.global_position, at, "the hero stays put")
	assert_eq(foe.hits, 1, "the foe beside them is struck")
	assert_eq(others.map(func(other: FakeFoe) -> int: return other.hits), [0, 0], "and only that one")


## PIX-455: the crossing is as safe as a roll: a blow while the hero steps
## swishes past, "dodged", and costs them nothing.
func test_a_blow_while_the_hero_steps_is_dodged() -> void:
	var hero := _rogue()
	var foe := _foe(MapView.center(Vector2i(8, 5)))
	hero.cast(0)
	assert_true(hero.stepping, "the hero is crossing")
	var hp: int = GameState.hero.hp
	hero.take_hit(5, foe.global_position)
	assert_eq(GameState.hero.hp, hp, "the blow takes nothing")
	assert_eq(hero.world.fx.words, ["dodged"] as Array[String], "it swishes past")
	assert_eq(foe.hits, 0, "the step's own blow still to come")
	# The ghost the step left where the hero stood.
	for ghost: Node in get_children().filter(func(node: Node) -> bool: return node is Sprite2D):
		ghost.free()


## PIX-439: a press the hero can't honour yet waits for them.
func test_a_press_during_a_swing_fires_when_the_hero_is_free() -> void:
	var hero := _hero()
	hero.attack()
	hero._press(hero._can_attack, hero.attack)
	assert_gt(hero._kept_until, 0.0, "the press waits")
	hero._end_swing()
	hero._fire_kept()
	assert_false(hero.attacking, "the swing's cooldown still counts")
	hero.attack_ready = true
	hero._fire_kept()
	assert_true(hero.attacking, "it fires as soon as the hero can")
	assert_eq(hero._kept_until, -1.0, "once")


func test_a_kept_press_goes_stale_and_only_the_last_is_kept() -> void:
	var hero := _hero()
	var fired := []
	var open := [false]
	hero._press(func() -> bool: return open[0], func() -> void: fired.append("first"))
	hero._press(func() -> bool: return open[0], func() -> void: fired.append("last"))
	open[0] = true
	hero._kept_until = GameClock.seconds() - 0.01
	hero._fire_kept()
	assert_eq(fired.size(), 0, "too late: forgotten")
	hero._kept_until = GameClock.seconds() + 0.1
	hero._fire_kept()
	assert_eq(fired.size(), 1, "fired once")
	assert_eq(fired[0], "last", "the last press is the one kept")


## PIX-439: a roll never costs a swing its blow.
func test_a_roll_waits_for_the_end_of_the_strike() -> void:
	var hero := _hero()
	hero.attack()
	for frame in [0, 1, 2]:
		hero.sprite.frame = frame
		hero.dodge()
		assert_false(hero.dodging, "no roll on frame %d" % frame)
		assert_true(hero.attacking, "the swing stands on frame %d" % frame)
	assert_true(hero.striking, "the blade still bites on the last strike frame")


## PIX-439: and nothing of the swing outlives the roll that cut it.
func test_a_roll_past_the_strike_clears_the_swing() -> void:
	var hero := _hero()
	hero.attack()
	hero.sprite.frame = 3
	hero.casting = true
	hero.hit_this_swing.append(hero)
	hero.squash = Vector2(1.3, 0.7)
	assert_true(hero._can_dodge(), "the follow-through gives way")
	hero.dodge(Vector2.LEFT)
	assert_true(hero.dodging, "the roll starts")
	assert_false(hero.attacking, "the swing is over")
	assert_false(hero.casting, "a cast too")
	assert_false(hero.striking, "it can't bite")
	assert_eq(hero.hit_this_swing.size(), 0, "nothing held from it")
	assert_eq(hero.squash, Vector2.ONE, "not its squash either")
	assert_eq(hero.dodge_dir, Vector2.LEFT, "the way it was pressed, the key since let go")
	hero.sprite.frame = 1
	assert_false(hero.striking, "a blow never lands after the roll has started")


## Before PIX-439 a swing begun in a roll locked the hero for good: the
## roll's walk paused the sprite, so the swing's animation never finished.
func test_no_swing_or_cast_starts_during_a_roll() -> void:
	var hero := _hero()
	hero.dodging = true
	hero.attack()
	assert_false(hero.attacking, "no swing")
	assert_false(hero._can_cast(), "no cast")
	hero._press(hero._can_attack, hero.attack)
	assert_gt(hero._kept_until, 0.0, "kept for when the roll ends")
	hero.dodging = false
	hero._fire_kept()
	assert_true(hero.attacking, "and it fires then")


func test_a_stun_a_death_or_a_screen_drops_the_kept_press() -> void:
	var hero := _hero()
	var fired := [false]
	var open := [false]
	var keep := func() -> void:
		open[0] = false
		hero._press(func() -> bool: return open[0], func() -> void: fired[0] = true)
		open[0] = true
	keep.call()
	hero.ailments.inflict({"kind": "stun", "chance": 1.0, "turns": 1, "power": 0}, func() -> float: return 0.0)
	assert_true(hero._held_by_stun(), "stunned")
	hero.ailments.clear()
	hero._fire_kept()
	assert_false(fired[0], "a stun landing drops it")
	keep.call()
	hero._die()
	hero.dead = false
	hero._fire_kept()
	assert_false(fired[0], "a death drops it")
	keep.call()
	# The tree's real pause, which is how a screen holds the world.
	hero.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	get_tree().paused = false
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero._fire_kept()
	assert_false(fired[0], "a screen opening drops it")


func test_holding_the_attack_key_keeps_no_press() -> void:
	var hero := _hero()
	hero.attack()
	var press := InputMap.action_get_events("attack")[0].duplicate() as InputEventKey
	press.pressed = true
	press.echo = true
	hero._unhandled_input(press)
	assert_eq(hero._kept_until, -1.0, "a held key's repeats are no press")
	press.echo = false
	hero._unhandled_input(press)
	assert_gt(hero._kept_until, 0.0, "a real press is")


## PIX-458: the corner of the ice cave's west corridor: a wall above the
## hero, open floor to their left, and a hero the physics moves as the game
## does (the other tests' hero is held out of it), against the wall.
const CORNER := Vector2(1000, 1000)


func _cornered() -> CharacterBody2D:
	var hero := _hero()
	hero.process_mode = Node.PROCESS_MODE_INHERIT
	hero.set_physics_process(false)
	hero.world.player = hero
	var walls: StaticBody2D = add_child_autofree(StaticBody2D.new())
	for rect: Rect2 in [Rect2(CORNER + Vector2(-100, -20), Vector2(200, 20)), Rect2(CORNER + Vector2(-60, 0), Vector2(20, 80))]:
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = rect.size
		shape.position = rect.get_center()
		walls.add_child(shape)
	hero.global_position = CORNER + Vector2(0, 1.1)
	return hero


func _yeti(hero: CharacterBody2D, at: Vector2) -> CharacterBody2D:
	var foe: CharacterBody2D = preload("res://scripts/enemy.gd").new()
	foe.world = hero.world
	foe.fighter = Bestiary.spawn("yeti")
	foe.position = at
	add_child_autofree(foe)
	foe.set_physics_process(false)
	foe.add_to_group("mobs")
	return foe


## A physics tick: each foe chases as Enemy._physics_process moves it (at the
## hero, stopped at its edge, moved, held off), then the hero's own tick,
## pressing `heading`.
func _tick(hero: CharacterBody2D, foes: Array, heading: Vector2) -> void:
	var tick := 1.0 / 60.0
	for foe: CharacterBody2D in foes:
		var from := foe.global_position
		var to_hero := hero.global_position - from
		foe.velocity = to_hero.normalized() * foe.CHASE_SPEED
		foe._keep_off(to_hero, tick)
		foe.move_and_slide()
		foe._hold_off(from)
	hero.scripted_dir = heading
	hero._physics_process(tick)
	await wait_physics_frames(1)


## PIX-458: a pack pressing the hero into a corner - a yeti below them and
## one to their right, each with another behind - comes no nearer than each
## one's edge (the one behind pushed the one below onto the hero, and on
## into the wall), and the hero still steps out onto the open floor.
func test_a_crowd_in_a_corner_never_holds_the_hero() -> void:
	var hero := _cornered()
	var at := hero.global_position
	var foes := [_yeti(hero, at + Vector2(0, 14.5)), _yeti(hero, at + Vector2(0, 26)), _yeti(hero, at + Vector2(15, 1)), _yeti(hero, at + Vector2(27, 1))]
	await wait_physics_frames(2)
	for i in 90:
		await _tick(hero, foes, Vector2.UP)
	for foe: CharacterBody2D in foes:
		assert_gte(foe.global_position.distance_to(hero.global_position), foe.edge - 0.01, "beside the hero, never on them")
	at = hero.global_position
	for i in 15:
		await _tick(hero, foes, Vector2.LEFT)
	assert_lt(hero.global_position.x, at.x - 16.0, "a step out onto the open floor")


## PIX-458: a yeti pressed onto the hero against the wall (as the pack did,
## or a leap's landing) holds them no more: Godot held a body still
## overlapping after pushing itself out every way at once, so no step and
## no roll went. A step away from it goes now; a step into it doesn't.
func test_a_foe_on_the_hero_never_holds_them() -> void:
	var hero := _cornered()
	var at := CORNER + Vector2(0, 0.8)
	hero.global_position = at
	var foe := _yeti(hero, at + Vector2(0, 10.5))
	await wait_physics_frames(2)
	await _tick(hero, [], Vector2.DOWN)
	assert_lt(hero.global_position.y, foe.global_position.y - 9.0, "not into it")
	await _tick(hero, [], Vector2.LEFT)
	assert_lt(hero.global_position.x, at.x - 1.0, "but away from it")


## PIX-458: hemmed in on every side - the wall above, a yeti at each other
## side as close as bodies meet - a roll goes through them.
func test_a_roll_goes_through_the_foes_round_the_hero() -> void:
	var hero := _cornered()
	var at := hero.global_position
	for beside: Vector2 in [Vector2(-10.2, 0), Vector2(10.2, 0), Vector2(0, 11.2)]:
		_yeti(hero, at + beside)
	await wait_physics_frames(2)
	hero.dodge(Vector2.DOWN)
	for i in 10:
		await _tick(hero, [], Vector2.DOWN)
	assert_gt(hero.global_position.y, at.y + 20.0, "out through the yeti below")
	for ghost: Node in get_children().filter(func(node: Node) -> bool: return node is Sprite2D):
		ghost.free()
