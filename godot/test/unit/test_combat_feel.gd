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
