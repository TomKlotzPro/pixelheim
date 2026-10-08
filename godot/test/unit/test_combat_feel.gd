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
