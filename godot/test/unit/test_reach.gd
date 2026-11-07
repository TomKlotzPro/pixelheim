extends GutTest
## How far every blow reaches (PIX-410, Tom: « je peux toucher les ennemis de
## loin mais ça fait pas sens si je suis un guerrier »): a blade up close,
## never two cells off; a bow and a staff from afar; each skill by its kind;
## a foe's bite only at contact, a shooter's shot from afar.

const CELL := 16.0
## A common foe's body, either side of its feet (Enemy.BODY's half width).
const BODY := 8.0


func _swing(attack: String, spots: Array[Vector2], facing := Vector2.RIGHT) -> Array[int]:
	var radii: Array[float] = []
	for spot in spots:
		radii.append(BODY)
	return Reach.struck(Vector2.ZERO, facing, spots, radii, Reach.swing(attack))


func _cast(entry: Dictionary, spots: Array[Vector2]) -> Array[int]:
	var radii: Array[float] = []
	for spot in spots:
		radii.append(BODY)
	return Reach.targets(Vector2.ZERO, Vector2.RIGHT, spots, radii, entry)


func test_a_blade_lands_on_the_cell_in_front_and_never_two_cells_off() -> void:
	assert_eq(_swing("sword", [Vector2(CELL, 0)]), [0], "the foe in the cell in front")
	assert_eq(_swing("sword", [Vector2(CELL, CELL)]), [0], "the corner beside it")
	assert_eq(_swing("sword", [Vector2(11, 0)]), [0], "the ring's nearest (PIX-377)")
	assert_eq(_swing("sword", [Vector2(2 * CELL, 0)]), [], "two cells off: a miss")
	assert_eq(_swing("sword", [Vector2(2 * CELL, 0)], Vector2.DOWN), [], "whichever way it faces")
	assert_eq(_swing("sword", [Vector2(0, 2 * CELL)], Vector2.DOWN), [], "down too")
	assert_eq(_swing("sword", [Vector2(-CELL, 0)]), [], "never behind")
	assert_eq(_swing("sword", [Vector2(CELL, 0), Vector2(CELL, CELL), Vector2(CELL, -CELL)]), [0, 1, 2], "a sweep lands on all it reaches")
	# The ring's waiting foes (PIX-377) stand out of a sweep's reach.
	assert_eq(_swing("sword", [Vector2(float(Packs.rules()["ring"]["far"]), 0)]), [], "the ring's far foes wait out of reach")


func test_the_bow_and_the_staff_land_at_range_on_the_nearest() -> void:
	for attack: String in ["bow", "staff"]:
		assert_eq(_swing(attack, [Vector2(2 * CELL, 0)]), [0], "%s: two cells off" % attack)
		assert_eq(_swing(attack, [Vector2(3 * CELL, 0)]), [0], "%s: three" % attack)
		assert_eq(_swing(attack, [Vector2(5 * CELL, 0)]), [], "%s: not past its reach" % attack)
		assert_eq(_swing(attack, [Vector2(CELL, 2 * CELL)]), [], "%s: not far off its line" % attack)
		assert_eq(_swing(attack, [Vector2(11, 6)]), [0], "%s: one at its feet too" % attack)
		assert_eq(_swing(attack, [Vector2(3 * CELL, 0), Vector2(CELL, 4)]), [1], "%s: the shot flies to the nearest" % attack)
		assert_true(Reach.swing(attack).get("shot", false), "%s: a shot, seen flying" % attack)
	assert_false(Reach.swing("sword").get("shot", false), "a blade is no shot")


func test_a_big_body_is_reached_at_its_edge() -> void:
	var spots: Array[Vector2] = [Vector2(2 * CELL, 0)]
	var radii: Array[float] = [24.0]
	assert_eq(Reach.struck(Vector2.ZERO, Vector2.RIGHT, spots, radii, Reach.swing("sword")), [0], "a boss three times its kind fills the cell in front")


func test_each_kind_of_skill_has_its_reach() -> void:
	var blow := {"reach": "melee"}
	assert_eq(_cast(blow, [Vector2(CELL, 0)]), [0], "a blow lands up close")
	assert_eq(_cast(blow, [Vector2(-CELL, 0)]), [0], "the hero turns to it")
	assert_eq(_cast(blow, [Vector2(2 * CELL, 0)]), [], "not two cells off")
	var spell := {"reach": "ranged"}
	assert_eq(_cast(spell, [Vector2(5 * CELL, 0)]), [0], "a spell from afar")
	assert_eq(_cast(spell, [Vector2(7 * CELL, 0)]), [], "not past its reach")
	assert_eq(_cast(spell, [Vector2(4 * CELL, 0), Vector2(2 * CELL, 0)]), [1], "at the nearest")
	assert_eq(_cast(spell, [Vector2(0, -2 * CELL), Vector2(2.5 * CELL, 0)]), [1], "those ahead first")


func test_an_area_skill_strikes_its_area() -> void:
	var cleave := {"reach": "melee", "area": true}
	assert_eq(_cast(cleave, [Vector2(CELL, 0), Vector2(-CELL, 0), Vector2(3 * CELL, 0)]), [0, 1], "a sweep: what its blow reaches round the hero")
	var nova := {"reach": "burst", "area": true}
	assert_eq(_cast(nova, [Vector2(2 * CELL, 0), Vector2(0, -2 * CELL), Vector2(4 * CELL, 0)]), [0, 1], "a burst round the hero")
	var volley := {"reach": "ranged", "area": true}
	assert_eq(_cast(volley, [Vector2(5 * CELL, 0), Vector2(6 * CELL, CELL), Vector2(5 * CELL, 5 * CELL)]), [0, 1], "round the foe it flies to")
	assert_eq(_cast(volley, [Vector2(8 * CELL, 0)]), [], "none in reach: none at all")


func test_a_foe_bites_only_at_contact() -> void:
	assert_lt(Reach.bite_lands(), 2 * CELL, "a melee foe never bites from two cells")
	assert_gte(Reach.bite_lands(), CELL, "one beside the hero does")
	assert_gt(Reach.bite_tell(), float(Packs.rules()["ring"]["near"]), "the ring's nearest tells its bite")
	assert_lt(Reach.bite_tell(), Reach.bite_lands(), "and a told bite still reaches")


func test_the_shooters_shoot_from_afar() -> void:
	for id: String in ["pirate_gunner", "turncoat_bowman", "imp"]:
		var shot := Reach.shot(id)
		assert_false(shot.is_empty(), "%s shoots" % id)
		assert_gt(Reach.px(shot), 2 * Reach.bite_lands(), "%s: from afar" % id)
		assert_lte(Reach.px(shot), Reach.px(Reach.swing("bow")) + BODY, "%s: a bow answers it" % id)
		assert_lte(Reach.px(shot), Reach.px(Reach.swing("staff")) + BODY, "%s: a staff too" % id)
		assert_gt(float(shot["tell"]), 0.3, "%s: told first" % id)
		assert_gt(float(shot["every"]), float(shot["tell"]), "%s: one shot at a time" % id)
	assert_true(Reach.shot("goblin").is_empty(), "a goblin only bites")


func test_every_damage_skill_names_its_reach() -> void:
	var kinds: Dictionary = Reach.rules()["skills"]
	var seen := 0
	var entries: Array = []
	for role: String in Bestiary._data()["skillTrees"]:
		for node: Dictionary in Bestiary._data()["skillTrees"][role]:
			if node.has("skill"):
				entries.append(node["skill"])
	for node: Dictionary in Bestiary._data()["pathNodes"]:
		entries.append(node["signature"])
	for entry: Dictionary in entries:
		if entry["kind"] != "damage":
			assert_false(entry.has("reach"), "%s: a heal reaches no foe" % entry["name"])
			continue
		seen += 1
		assert_true(kinds.has(String(entry.get("reach", ""))), "%s names its reach" % entry["name"])
		if entry.get("reach") == "burst":
			assert_true(entry.get("area", false), "%s: a burst strikes an area" % entry["name"])
	assert_gt(seen, 60, "every one looked at")
	# The kinds the brief names: a cleave, a shield bash and a backstab up
	# close, a fireball and an arrow from afar.
	var by_name := {}
	for entry: Dictionary in entries:
		by_name[entry["name"]] = entry.get("reach", "")
	for name: String in ["Cleave", "Shield Slam", "Backstab"]:
		assert_eq(by_name[name], "melee", name)
	for name: String in ["Fireball", "Aimed Shot", "Soul Bolt", "Smite"]:
		assert_eq(by_name[name], "ranged", name)


func test_every_swing_drawn_has_a_reach() -> void:
	var swings: Dictionary = Reach.rules()["swings"]
	for attack: String in PunyArt.WEAPON_ATTACKS.values():
		assert_true(swings.has(attack), "a %s's swing" % attack)
	for role: String in PunyArt.HEROES:
		assert_true(swings.has(PunyArt.hero(role)["attack"]), "%s bare-handed" % role)
