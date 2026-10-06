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
	hero.skill_points = 1
	assert_false(state.buy_skill_node("warrior_executioner"), "its parent first")
	assert_false(state.buy_skill_node("warrior_power_strike"), "already known")
	assert_true(state.buy_skill_node("warrior_power_strike_2"))
	assert_eq(hero.skill_points, 0)
	assert_false(state.buy_skill_node("warrior_shield_slam"), "no points left")


func test_some_nodes_grow_the_pools_for_good() -> void:
	var hero: HeroState = state.hero
	hero.skill_nodes.append_array(["warrior_shield_slam", "warrior_iron_skin", "warrior_unshakeable"])
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
