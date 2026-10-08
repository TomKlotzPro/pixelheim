extends GutTest
## Bosses that fight back (PIX-150): every boss pattern names attacks that
## exist, three phases that quicken, a roar for each new phase, and a summon
## of a real monster; and the ending's tour has a stop for each age built.


func test_every_boss_pattern_is_whole() -> void:
	var attacks: Dictionary = Bestiary._data()["bossAttacks"]
	for boss_id: String in Bestiary._data()["bossPatterns"]:
		assert_true(Bestiary.is_boss(boss_id), "%s is a boss" % boss_id)
		var pattern: Dictionary = Bestiary._data()["bossPatterns"][boss_id]
		assert_eq(pattern["phases"].size(), 3, "%s has three phases" % boss_id)
		assert_eq(pattern["every"].size(), 3)
		assert_eq(pattern["roars"].size(), 2, "a roar for each new phase")
		for i in 2:
			assert_lt(float(pattern["every"][i + 1]), float(pattern["every"][i]), "%s quickens" % boss_id)
		for phase: Array in pattern["phases"]:
			for move: String in phase:
				assert_true(attacks.has(move), "%s: %s" % [boss_id, move])
				if move == "summon":
					assert_false(Bestiary.monster(pattern["summon"]).is_empty(), "%s summons a real monster" % boss_id)


func test_every_attack_is_told_before_it_lands() -> void:
	for move: String in Bestiary._data()["bossAttacks"]:
		var attack: Dictionary = Bestiary._data()["bossAttacks"][move]
		assert_gt(float(attack["tell"]), 0.5, "%s gives time to step away" % move)


func test_the_wilds_have_more_stories() -> void:
	for quest_id: String in ["ash_orcs", "bram_imps", "mira_moss", "tomas_golems"]:
		var quest := Quests.by_id(quest_id)
		assert_false(quest.is_empty())
		var objective: Dictionary = quest["objective"]
		if objective["kind"] == "kill":
			assert_false(Bestiary.where_found(objective["monsterId"]).is_empty(), "%s's foe lives somewhere" % quest_id)
		else:
			assert_false(Economy.material_sources(objective["itemId"]).is_empty(), "%s's goods can be had" % quest_id)
