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


## A blow shoves a common foe about 10 px, an elite half that, a boss not at all.
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
	assert_between(travelled, 8.0, 12.0, "about 10 px")


func test_the_fight_has_its_own_blips() -> void:
	var SoundScript := preload("res://scripts/sound.gd")
	for name: String in ["swing", "cast", "kill"]:
		assert_true(SoundScript.UI_SOUNDS.has(name), name)
		assert_gt(SoundScript._synth(SoundScript.UI_SOUNDS[name]).data.size(), 0, name)
