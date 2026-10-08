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


## PIX-186: sized for real time. A hero matched to the boss (their level,
## the stage's weapon forged up two, their points in what they hit with),
## swinging every 0.45 s for half the fight (the rest is spent stepping out
## of marks and closing in), takes 20-45 s to bring Fafnyr or Morvax down:
## long enough for all three phases.
const WEAPONS := {"warrior": "warden_longsword", "mage": "rime_staff", "ranger": "deeproot_bow"}
const MAIN := {"warrior": ["strength", 2], "mage": ["intelligence", 3], "ranger": ["dexterity", 3]}
const UPTIME := 0.5


func test_the_great_bosses_last_through_their_three_phases() -> void:
	for floor_level: int in [10, 15]:
		var boss := Bestiary.spawn(Dungeons.boss_of(floor_level)["monsterId"], false, Dungeons.lift(floor_level))
		for role: String in WEAPONS:
			var hero := HeroState.create("Match", role)
			hero.level = int(boss["level"])
			hero.stats[MAIN[role][0]] = int(hero.stats[MAIN[role][0]]) + int(MAIN[role][1]) * (hero.level - 1)
			var pack := InventoryState.new()
			var weapon := InventoryState.create_gear(WEAPONS[role])
			weapon["bonus"] = 2
			pack.gear.append(weapon)
			pack.equipped["weapon"] = weapon["uid"]
			var swing := Bestiary.hero_attack_damage(hero, pack, boss, false, func() -> float: return 0.5)
			var seconds := float(boss["maxHp"]) / (swing * UPTIME / 0.45)
			gut.p("%s (L%d, %d HP): a %s hits %d, %.0f s" % [boss["name"], boss["level"], boss["maxHp"], role, swing, seconds])
			assert_between(seconds, 20.0, 45.0, "%s against a matched %s" % [boss["name"], role])


func test_a_guardian_outlasts_its_kind() -> void:
	var plain := Bestiary.spawn("wyvern", false, Dungeons.lift(9))
	var guardian := Bestiary.spawn("wyvern", true, Dungeons.lift(9))
	assert_eq(guardian["maxHp"], roundi(plain["maxHp"] * 2.25))
	assert_gt(Bestiary.spawn("dragon", false, Dungeons.lift(10))["maxHp"], guardian["maxHp"] * 3, "Fafnyr far outlasts the wyvern before him")


func test_the_dead_rise_at_their_masters_level() -> void:
	var morvax := Bestiary.spawn("lich", false, Dungeons.lift(15))
	var summon: String = Bestiary._data()["bossPatterns"]["lich"]["summon"]
	var risen := Bestiary.spawn(summon, false, Bestiary.lift_to(summon, int(morvax["level"])))
	assert_eq(int(risen["level"]), int(morvax["level"]))
	assert_eq(Bestiary.lift_to("lich", 3), 0, "never lifted below its own level")


func test_a_lifted_monster_poisons_like_its_level() -> void:
	var goblin := Bestiary.spawn("goblin", false, 10)
	assert_eq(int(goblin["level"]), 12)
	var base: int = Bestiary.monster("goblin")["inflicts"]["power"]
	assert_gt(int(goblin["inflicts"]["power"]), base * 3, "a level-12 goblin's poison bites like level 12")
	assert_eq(Bestiary.monster("goblin")["inflicts"]["power"], base, "the kind itself is untouched")
	var shade := Bestiary.spawn("shade", false, 5)
	assert_eq(int(shade["inflicts"]["power"]), 0, "a stun stays a stun")
