extends GutTest
## Skills and stats (hero/skillTree.ts, hero/statInfo.ts, applyStatPoint,
## SPEND_STAT_POINT, BUY_SKILL_NODE). The stat sheet's readouts were printed
## from the web's statInfo for the same heroes and gear.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


## A level-1 hero of the role in the web reference's gear: its starter
## weapon and leather armor, both worn.
func _equipped(role: String, weapon_id: String) -> Array:
	var hero := HeroState.create("T", role)
	var pack := InventoryState.new()
	var weapon := InventoryState.create_gear(weapon_id)
	var armor := InventoryState.create_gear("leather_armor")
	pack.gear.assign([weapon, armor])
	pack.equipped = {"weapon": weapon["uid"], "body": armor["uid"]}
	return [hero, pack]


func test_the_stat_sheet_reads_like_the_webs() -> void:
	var expected := {
		"warrior": [
			["strength", "ATK 13 · carry 87", "ATK 14 · carry 90"],
			["intelligence", "powers INT skills", "powers INT skills"],
			["dexterity", "powers bows, daggers and DEX skills", "powers bows, daggers and DEX skills"],
			["defense", "DEF 8 · turns aside 71% of a level-1 hit", "DEF 9 · turns aside 74% of a level-1 hit"],
			["endurance", "HP 42 · EN 8 · regen 2/turn", "HP 43 · EN 10 · regen 2/turn"],
		],
		"mage": [
			["strength", "carry 69", "carry 72"],
			["intelligence", "ATK 17 · skill power 22 · MP 24", "ATK 18 · skill power 24 · MP 26"],
			["dexterity", "powers bows, daggers and DEX skills", "powers bows, daggers and DEX skills"],
			["defense", "DEF 5 · turns aside 61% of a level-1 hit", "DEF 6 · turns aside 65% of a level-1 hit"],
			["endurance", "HP 28", "HP 29"],
		],
	}
	var weapons := {"warrior": "rusty_sword", "mage": "apprentice_staff"}
	for role: String in expected:
		var kit := _equipped(role, weapons[role])
		for row: Array in expected[role]:
			var info := Skills.info(row[0], kit[0], kit[1])
			assert_eq([info["now"], info["next"]], [row[1], row[2]], "%s %s" % [role, row[0]])
			assert_eq(info["blurb"], Skills.BLURBS[row[0]])


func test_stat_points_buy_their_stat_and_its_pools() -> void:
	var hero: HeroState = state.hero
	hero.stat_points = 2
	var hp: int = hero.stats["maxHp"]
	var en: int = hero.stats["maxMp"]
	assert_true(state.training.spend_stat_point("endurance"))
	assert_eq(hero.stats["maxHp"], hp + 1)
	assert_eq(hero.stats["maxMp"], en + 2, "a fighter's stamina grows with END")
	assert_true(state.training.spend_stat_point("strength"))
	assert_eq(hero.stat_points, 0)
	assert_false(state.training.spend_stat_point("strength"), "no points left")
	hero.stat_points = 1
	assert_false(state.training.spend_stat_point("luck"), "only the five stats")


func test_int_fills_only_a_casters_mana() -> void:
	var mage: Node = autofree(GameStateScript.new())
	mage.new_game("Ilse", "mage")
	mage.hero.stat_points = 1
	var mp: int = mage.hero.stats["maxMp"]
	mage.training.spend_stat_point("intelligence")
	assert_eq(mage.hero.stats["maxMp"], mp + 2)
	state.hero.stat_points = 1
	var en: int = state.hero.stats["maxMp"]
	state.training.spend_stat_point("intelligence")
	assert_eq(state.hero.stats["maxMp"], en, "a warrior's stamina doesn't care")


func test_nodes_are_learned_in_order_for_a_point_each() -> void:
	var hero: HeroState = state.hero
	assert_has(hero.skill_nodes, "warrior_power_strike", "the root comes free")
	hero.level = 3
	hero.skill_points = 1
	assert_false(state.training.buy_skill_node("warrior_executioner"), "its parent first")
	assert_false(state.training.buy_skill_node("warrior_power_strike"), "already known")
	assert_true(state.training.buy_skill_node("warrior_power_strike_2"))
	assert_eq(hero.skill_points, 0)
	assert_false(state.training.buy_skill_node("warrior_shield_slam"), "no points left")


func test_some_nodes_grow_the_pools_for_good() -> void:
	var hero: HeroState = state.hero
	hero.skill_nodes.append_array(["warrior_shield_slam", "warrior_iron_skin", "warrior_unshakeable"])
	hero.level = 10
	hero.skill_points = 1
	var max_hp: int = hero.stats["maxHp"]
	assert_true(state.training.buy_skill_node("warrior_mountainheart"))
	assert_eq(hero.stats["maxHp"], max_hp + 30)


func test_owned_skills_carry_their_upgrades_and_the_paths_signature() -> void:
	var hero: HeroState = state.hero
	var power_strike: Dictionary = Skills.hero_skills(hero)[0]
	hero.skill_nodes.append("warrior_power_strike_2")
	var upgraded: Dictionary = Skills.hero_skills(hero)[0]
	assert_ne(upgraded, power_strike, "the upgrade's patch applies")
	assert_eq(upgraded["name"], Skills.node("warrior", "warrior_power_strike_2")["patch"].get("name", power_strike["name"]))
	hero.level = 5
	state.training.choose_path("juggernaut")
	assert_eq(Skills.hero_skills(hero)[-1]["name"], "Immovable", "the identity teaches its signature")


## A loaded die that always rolls `value`.
func _die(value: float) -> Callable:
	return func() -> float: return value


func test_skill_strikes_land_like_the_webs() -> void:
	# Printed from heroSkillDamage with Math.random pinned to 0.1, 0.5, 0.9.
	var cases := [
		["warrior", "rusty_sword", "slime", {}, [15, 17, 19]],
		["mage", "apprentice_staff", "skeleton", {"undead": 30}, [20, 23, 26]],
		["ranger", "hunting_bow", "wolf", {}, [14, 16, 18]],
	]
	for case: Array in cases:
		var kit := _equipped(case[0], case[1])
		var hero: HeroState = kit[0]
		if not (case[3] as Dictionary).is_empty():
			hero.mastery = case[3]
		var pack: InventoryState = kit[1]
		pack.equipped.erase("body")
		var skill: Dictionary = Skills.hero_skills(hero)[0]
		var foe := Bestiary.spawn(case[2])
		var got := [0.1, 0.5, 0.9].map(func(roll: float) -> int:
			return Bestiary.hero_skill_damage(hero, pack, skill, foe, _die(roll))
		)
		assert_eq(got, case[4], "%s %s vs %s" % [case[0], skill["name"], case[2]])


func test_a_skill_needs_its_level_its_resource_and_its_price() -> void:
	var hero: HeroState = state.hero
	var strike: Dictionary = Skills.hero_skills(hero)[0]
	assert_eq(Skills.cast_block(hero, strike), "")
	hero.mp = int(strike["mpCost"]) - 1
	assert_string_contains(Skills.cast_block(hero, strike), "Not enough EN")
	var berserk: Dictionary = Skills.node("warrior", "warrior_berserk")["skill"]
	hero.mp = 99
	hero.hp = int(berserk["hpCost"])
	assert_string_contains(Skills.cast_block(hero, berserk), "Too hurt")
	var later := {"name": "Later", "mpCost": 0, "unlockLevel": 5}
	assert_string_contains(Skills.cast_block(hero, later), "needs level 5")


func test_casting_pays_heals_cap_and_stamina_returns_in_fights() -> void:
	var hero: HeroState = state.hero
	var berserk: Dictionary = Skills.node("warrior", "warrior_berserk")["skill"]
	var mp: int = hero.mp
	var hp: int = hero.hp
	assert_true(state.training.pay_for_skill(berserk))
	assert_eq(hero.mp, mp - int(berserk["mpCost"]))
	assert_eq(hero.hp, hp - int(berserk["hpCost"]))
	assert_eq(state.upkeep.heal_hero(999), int(berserk["hpCost"]), "a heal tops out at max HP")
	hero.mp = 0
	assert_eq(state.upkeep.regen_stamina(), Skills.stamina_regen(hero), "a fighter's stamina comes back")
	var mage: Node = autofree(GameStateScript.new())
	mage.new_game("Ilse", "mage")
	mage.hero.mp = 0
	assert_eq(mage.upkeep.regen_stamina(), 0, "mana does not")


## Forgetting (PIX-86; the shrine's keeper's since PIX-331): bought skills
## for their points back, the skill a hero starts with kept; the first time
## is free, then 20 gold a skill.
func test_forgetting_gives_the_points_back_and_keeps_the_born_skill() -> void:
	var born: String = Catalog.skill_roots("warrior")[0]
	state.hero.level = 3
	state.hero.skill_points = 2
	assert_true(state.training.buy_skill_node("warrior_power_strike_2"))
	assert_true(state.training.buy_skill_node("warrior_shield_slam"))
	state.pack.gold = 100
	assert_eq(Skills.forget_cost(state.hero), 0, "the first time is on the shrine")
	assert_true(state.training.forget_skills())
	assert_eq(state.hero.skill_nodes, [born] as Array[String])
	assert_eq(state.hero.skill_points, 2)
	assert_eq(state.pack.gold, 100)
	assert_eq(state.hero.forgot, [Skills.FORGOT_SKILLS] as Array[String])
	assert_false(state.training.forget_skills(), "nothing bought is left to forget")
	assert_true(state.training.buy_skill_node("warrior_power_strike_2"))
	assert_true(state.training.buy_skill_node("warrior_shield_slam"))
	assert_eq(Skills.forget_cost(state.hero), 40, "then 20g a skill")
	assert_true(state.training.forget_skills())
	assert_eq(state.hero.skill_points, 2)
	assert_eq(state.pack.gold, 60)


func test_forgetting_shrinks_what_a_skill_grew() -> void:
	var before: int = int(state.hero.stats["maxHp"])
	state.hero.skill_nodes.append_array(["warrior_shield_slam", "warrior_iron_skin", "warrior_unshakeable"])
	state.hero.level = 10
	state.hero.skill_points = 1
	assert_true(state.training.buy_skill_node("warrior_mountainheart"))
	assert_eq(int(state.hero.stats["maxHp"]), before + 30)
	assert_eq(state.hero.hp, before + 30)
	assert_true(state.training.forget_skills())
	assert_eq(int(state.hero.stats["maxHp"]), before)
	assert_eq(state.hero.hp, before, "a full hero stays full, at the lower top")


func test_forgetting_without_the_gold_changes_nothing() -> void:
	state.hero.forgot.assign([Skills.FORGOT_SKILLS])
	state.hero.level = 3
	state.hero.skill_points = 1
	assert_true(state.training.buy_skill_node("warrior_power_strike_2"))
	state.pack.gold = 19
	var before: Dictionary = state.hero.to_dict()
	assert_false(state.training.forget_skills(), "20g a skill")
	assert_eq_deep(state.hero.to_dict(), before)
	assert_eq(state.pack.gold, 19)


## Forgetting the training (PIX-331): every stat point spent comes back, and
## what the points grew (a fighter's END: max HP, and their stamina) with
## it; health and energy are kept up to the new tops. Free the first time,
## then the hero's level in gold a point.
func test_forgetting_the_training_gives_every_point_back() -> void:
	var hero: HeroState = state.hero
	var base: Dictionary = hero.stats.duplicate()
	hero.level = 4
	hero.stat_points = 9
	for stat: String in ["endurance", "endurance", "endurance", "strength", "strength"]:
		assert_true(state.training.spend_stat_point(stat))
	assert_eq(int(hero.stats["maxHp"]), int(base["maxHp"]) + 3)
	assert_eq(int(hero.stats["maxMp"]), int(base["maxMp"]) + 6, "a fighter's stamina grows with END")
	assert_eq(Skills.spent_stats(hero, []), {"strength": 2, "endurance": 3})
	state.pack.gold = 50
	assert_eq(Skills.forget_training_cost(hero, Skills.spent_stats(hero, [])), 0, "the first time is on the shrine")
	assert_true(state.training.forget_training())
	assert_eq_deep(hero.stats, base)
	assert_eq(hero.stat_points, 9)
	assert_eq(hero.hp, int(base["maxHp"]), "full health, at the lower top")
	assert_eq(hero.mp, int(base["maxMp"]))
	assert_eq(state.pack.gold, 50)
	assert_eq(hero.forgot, [Skills.FORGOT_TRAINING] as Array[String])
	assert_false(state.training.forget_training(), "nothing spent is left to forget")
	# The second time: 4 points at level 4, 4g a point.
	for stat: String in ["dexterity", "defense", "defense", "intelligence"]:
		assert_true(state.training.spend_stat_point(stat))
	assert_eq(Skills.forget_training_cost(hero, Skills.spent_stats(hero, [])), 16)
	assert_true(state.training.forget_training())
	assert_eq_deep(hero.stats, base)
	assert_eq(hero.stat_points, 9)
	assert_eq(state.pack.gold, 34)


## A caster's INT grew their mana; a hurt hero isn't healed by forgetting,
## nor hurt by it.
func test_forgetting_a_casters_training_keeps_what_they_had() -> void:
	var mage: Node = autofree(GameStateScript.new())
	mage.new_game("Ilse", "mage")
	var hero: HeroState = mage.hero
	var base: Dictionary = hero.stats.duplicate()
	hero.stat_points = 3
	for i in 3:
		assert_true(mage.training.spend_stat_point("intelligence"))
	assert_eq(int(hero.stats["maxMp"]), int(base["maxMp"]) + 6)
	hero.hp = 5
	hero.mp = 4
	assert_true(mage.training.forget_training())
	assert_eq_deep(hero.stats, base)
	assert_eq(hero.hp, 5)
	assert_eq(hero.mp, 4)


## What a trophy on the house's shelf lends a stat isn't the hero's to
## forget: it stays while the trophy does.
func test_a_trophys_stats_are_not_forgotten() -> void:
	var hero: HeroState = state.hero
	hero.stat_points = 1
	assert_true(state.training.spend_stat_point("defense"))
	state.pack.add_item("lich_crown")
	assert_true(state.household.display_trophy("lich_crown"))
	assert_eq(Skills.spent_stats(hero, state.household.trophies()), {"defense": 1})
	var defense := int(hero.stats["defense"])
	assert_true(state.training.forget_training())
	assert_eq(int(hero.stats["defense"]), defense - 1, "the crown's +2 stays on the shelf's account")
	assert_eq(hero.stat_points, 1)


func test_forgetting_the_training_without_the_gold_changes_nothing() -> void:
	var hero: HeroState = state.hero
	hero.forgot.assign([Skills.FORGOT_TRAINING])
	hero.level = 5
	hero.stat_points = 2
	assert_true(state.training.spend_stat_point("strength"))
	assert_true(state.training.spend_stat_point("endurance"))
	state.pack.gold = 9
	var before: Dictionary = hero.to_dict()
	assert_false(state.training.forget_training(), "2 points at level 5: 10g")
	assert_eq_deep(hero.to_dict(), before)
	assert_eq(state.pack.gold, 9)
	state.pack.gold = 10
	assert_true(state.training.forget_training())
	assert_eq(state.pack.gold, 0)

