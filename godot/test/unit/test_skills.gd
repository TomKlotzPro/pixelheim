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
			["dexterity", "flee 50%", "flee 52%"],
			["defense", "blocks 8 per hit", "blocks 9 per hit"],
			["endurance", "HP 42 · EN 8 · regen 2/turn", "HP 43 · EN 10 · regen 2/turn"],
		],
		"mage": [
			["strength", "carry 69", "carry 72"],
			["intelligence", "ATK 17 · skill power 22 · MP 24", "ATK 18 · skill power 24 · MP 26"],
			["dexterity", "flee 48%", "flee 50%"],
			["defense", "blocks 5 per hit", "blocks 6 per hit"],
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
	assert_true(state.spend_stat_point("endurance"))
	assert_eq(hero.stats["maxHp"], hp + 1)
	assert_eq(hero.stats["maxMp"], en + 2, "a fighter's stamina grows with END")
	assert_true(state.spend_stat_point("strength"))
	assert_eq(hero.stat_points, 0)
	assert_false(state.spend_stat_point("strength"), "no points left")
	hero.stat_points = 1
	assert_false(state.spend_stat_point("luck"), "only the five stats")


func test_int_fills_only_a_casters_mana() -> void:
	var mage: Node = autofree(GameStateScript.new())
	mage.new_game("Ilse", "mage")
	mage.hero.stat_points = 1
	var mp: int = mage.hero.stats["maxMp"]
	mage.spend_stat_point("intelligence")
	assert_eq(mage.hero.stats["maxMp"], mp + 2)
	state.hero.stat_points = 1
	var en: int = state.hero.stats["maxMp"]
	state.spend_stat_point("intelligence")
	assert_eq(state.hero.stats["maxMp"], en, "a warrior's stamina doesn't care")


func test_nodes_are_learned_in_order_for_a_point_each() -> void:
	var hero: HeroState = state.hero
	assert_has(hero.skill_nodes, "warrior_power_strike", "the root comes free")
	hero.level = 3
	hero.skill_points = 1
	assert_false(state.buy_skill_node("warrior_executioner"), "its parent first")
	assert_false(state.buy_skill_node("warrior_power_strike"), "already known")
	assert_true(state.buy_skill_node("warrior_power_strike_2"))
	assert_eq(hero.skill_points, 0)
	assert_false(state.buy_skill_node("warrior_shield_slam"), "no points left")


func test_some_nodes_grow_the_pools_for_good() -> void:
	var hero: HeroState = state.hero
	hero.skill_nodes.append_array(["warrior_shield_slam", "warrior_iron_skin", "warrior_unshakeable"])
	hero.level = 10
	hero.skill_points = 1
	var max_hp: int = hero.stats["maxHp"]
	assert_true(state.buy_skill_node("warrior_mountainheart"))
	assert_eq(hero.stats["maxHp"], max_hp + 30)


func test_owned_skills_carry_their_upgrades_and_the_paths_signature() -> void:
	var hero: HeroState = state.hero
	var power_strike: Dictionary = Skills.hero_skills(hero)[0]
	hero.skill_nodes.append("warrior_power_strike_2")
	var upgraded: Dictionary = Skills.hero_skills(hero)[0]
	assert_ne(upgraded, power_strike, "the upgrade's patch applies")
	assert_eq(upgraded["name"], Skills.node("warrior", "warrior_power_strike_2")["patch"].get("name", power_strike["name"]))
	hero.level = 5
	state.choose_path("juggernaut")
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
	assert_true(state.pay_for_skill(berserk))
	assert_eq(hero.mp, mp - int(berserk["mpCost"]))
	assert_eq(hero.hp, hp - int(berserk["hpCost"]))
	assert_eq(state.heal_hero(999), int(berserk["hpCost"]), "a heal tops out at max HP")
	hero.mp = 0
	assert_eq(state.regen_stamina(), Skills.stamina_regen(hero), "a fighter's stamina comes back")
	var mage: Node = autofree(GameStateScript.new())
	mage.new_game("Ilse", "mage")
	mage.hero.mp = 0
	assert_eq(mage.regen_stamina(), 0, "mana does not")


## Forgetting (PIX-86): bought skills for their points back, in the village,
## for 20 gold a skill; the skill a hero starts with stays.
func test_forgetting_gives_the_points_back_and_keeps_the_born_skill() -> void:
	state.world.map_id = "town_inn"
	var born: String = Catalog.skill_roots("warrior")[0]
	state.hero.level = 3
	state.hero.skill_points = 2
	assert_true(state.buy_skill_node("warrior_power_strike_2"))
	assert_true(state.buy_skill_node("warrior_shield_slam"))
	state.pack.gold = 100
	assert_eq(Skills.forget_cost(state.hero), 40)
	assert_true(state.forget_skills())
	assert_eq(state.hero.skill_nodes, [born] as Array[String])
	assert_eq(state.hero.skill_points, 2)
	assert_eq(state.pack.gold, 60)
	assert_false(state.forget_skills(), "nothing bought is left to forget")


func test_forgetting_shrinks_what_a_skill_grew() -> void:
	state.world.map_id = "town"
	var before := int(state.hero.stats["maxHp"])
	state.hero.skill_nodes.append_array(["warrior_shield_slam", "warrior_iron_skin", "warrior_unshakeable"])
	state.hero.level = 10
	state.hero.skill_points = 1
	assert_true(state.buy_skill_node("warrior_mountainheart"))
	assert_eq(int(state.hero.stats["maxHp"]), before + 30)
	state.pack.gold = 1000
	assert_true(state.forget_skills())
	assert_eq(int(state.hero.stats["maxHp"]), before)
	assert_true(state.hero.hp <= before)


func test_forgetting_takes_the_village_and_the_gold() -> void:
	state.hero.level = 3
	state.hero.skill_points = 1
	assert_true(state.buy_skill_node("warrior_power_strike_2"))
	state.pack.gold = 100
	state.world.map_id = "overworld"
	assert_false(state.forget_skills(), "not out in the wilds")
	state.world.map_id = "town"
	state.pack.gold = 19
	assert_false(state.forget_skills(), "20g a skill")
	assert_eq(state.hero.skill_points, 0)

