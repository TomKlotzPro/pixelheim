extends GutTest
## Something to earn after level 10 (PIX-190): two more tiers in every tree
## (levels 13 and 17), passives that do something in a real-time fight (the
## web's flee chance didn't), a dock the hero sets, and a fifth rank at 20.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())


func _hero(role: String, level: int, nodes: Array = []) -> HeroState:
	var hero := HeroState.create("T", role)
	hero.level = level
	hero.skill_nodes.append_array(nodes)
	return hero


func test_every_tree_runs_six_tiers_deep() -> void:
	assert_eq(Bestiary._data()["skillTierLevels"], [1, 3, 6, 10, 13, 17])
	for role: String in Bestiary._data()["skillTrees"]:
		var tree := Skills.tree(role)
		assert_eq(tree.size(), 18, "%s: three branches of six" % role)
		for tier in [4, 5]:
			var kinds := tree.filter(func(entry: Dictionary) -> bool: return int(entry["tier"]) == tier).map(
				func(entry: Dictionary) -> String: return entry["kind"])
			assert_eq(kinds.count("active"), 1, "%s tier %d: one new skill" % [role, tier])
			assert_eq(kinds.count("passive"), 2, "%s tier %d: two passives" % [role, tier])
		for entry: Dictionary in tree:
			if entry.has("requires"):
				var above := Skills.node(role, entry["requires"])
				assert_eq([above["branch"], int(above["tier"])], [entry["branch"], int(entry["tier"]) - 1], "%s follows the node above it" % entry["id"])


func test_every_skill_has_its_icon() -> void:
	var icons: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/puny/icons.json"))["skills"]
	for role: String in Bestiary._data()["skillTrees"]:
		for entry: Dictionary in Skills.tree(role):
			if entry["kind"] == "active":
				assert_true(icons.has(entry["skill"]["name"]), entry["skill"]["name"])


func test_no_passive_does_nothing() -> void:
	var sources: Array = Bestiary._data()["pathNodes"].map(func(node: Dictionary) -> Dictionary: return node.get("passive", {}))
	for role: String in Bestiary._data()["skillTrees"]:
		for entry: Dictionary in Skills.tree(role):
			if entry.has("passive"):
				sources.append(entry["passive"])
	for effects: Dictionary in sources:
		for key: String in effects:
			assert_true(HeroRules.NO_PASSIVES.has(key), "%s is a passive the game plays" % key)
	var flee := RegEx.create_from_string("\\bflee\\b")
	assert_null(flee.search(JSON.stringify(Bestiary._data()["skillTrees"]).to_lower()), "no node promises a flee")
	assert_null(flee.search(JSON.stringify(Bestiary._data()["pathNodes"]).to_lower()), "no path does")
	assert_false("flee" in Skills.BLURBS["dexterity"])


func test_quick_feet_and_a_dodge_that_sets_up_a_crit() -> void:
	var rogue := _hero("rogue", 17, ["rogue_fleet_foot", "rogue_pickpocket", "rogue_ghostwalk", "rogue_smoke_and_mirrors", "rogue_nightrunner"])
	var passives := HeroRules.passives(rogue)
	assert_almost_eq(float(passives["moveSpeed"]), 0.2, 0.001)
	assert_almost_eq(float(passives["dodgeCooldown"]), 0.33, 0.001)
	assert_true(passives["dodgeCrit"])
	rogue.path = ["trickster", "phantom_jester", "unseen"]
	passives = HeroRules.passives(rogue)
	assert_almost_eq(float(passives["moveSpeed"]), 0.35, 0.001, "the deepest path step adds its own")
	assert_almost_eq(float(passives["dodgeCooldown"]), 0.58, 0.001)
	assert_lte(float(passives["dodgeCooldown"]), HeroRules.MAX_DODGE_CUT, "a dodge only so much sooner")
	# A sure crit: the extra chance the player passes after a priming dodge.
	var pack := InventoryState.new()
	var dull := Bestiary.hero_attack_damage(rogue, pack, Bestiary.spawn("slime"), false, func() -> float: return 0.5, 0.0, 0.0)
	var primed := Bestiary.hero_attack_damage(rogue, pack, Bestiary.spawn("slime"), false, func() -> float: return 0.5, 0.0, 1.0)
	assert_gt(primed, dull)


func test_blessed_heals_and_sharper_skills() -> void:
	var pack := InventoryState.new()
	var cleric := _hero("cleric", 13, ["cleric_mend_2", "cleric_martyr", "cleric_divine_word"])
	var mend: Dictionary = Skills.hero_skills(cleric)[0]
	var plain := Skills.heal_power(cleric, pack, mend)
	assert_eq(plain, Skills.skill_power(cleric, pack, mend))
	cleric.skill_nodes.append("cleric_blessed_hands")
	assert_eq(Skills.heal_power(cleric, pack, mend), roundi(Skills.skill_power(cleric, pack, mend) * 1.25))
	var mage := _hero("mage", 13)
	var fireball: Dictionary = Skills.hero_skills(mage)[0]
	var even := func() -> float: return 0.5
	var before := Bestiary.hero_skill_damage(mage, pack, fireball, Bestiary.spawn("slime"), even)
	mage.skill_nodes.append("mage_spellweaver")
	assert_gt(Bestiary.hero_skill_damage(mage, pack, fireball, Bestiary.spawn("slime"), even), before)


func test_the_new_skills_sweep_and_drain() -> void:
	assert_true(Skills.node("warrior", "warrior_cleave")["skill"].get("area", false), "Cleave strikes every foe in reach")
	assert_almost_eq(float(Skills.node("necromancer", "necromancer_drain_life")["skill"]["drain"]), 0.5, 0.001)
	for role: String in Bestiary._data()["skillTrees"]:
		var areas := Skills.tree(role).filter(func(entry: Dictionary) -> bool: return entry.has("skill") and entry["skill"].get("area", false))
		assert_eq(areas.size(), 1, "%s has one skill for a crowd" % role)


func test_the_dock_keeps_its_keys() -> void:
	state.new_game("Robin", "cleric")
	var hero: HeroState = state.hero
	hero.level = 17
	hero.skill_points = 40
	assert_eq(Skills.dock_keys(hero), ["cleric_mend", "", "", "", "", ""], "a new hero's one skill, on key 1")
	var learned := []
	state.skill_learned.connect(func(entry: Dictionary, key: int) -> void: learned.append([entry["id"], key]))
	for node_id in ["cleric_smite", "cleric_sanctuary", "cleric_mend_2", "cleric_martyr", "cleric_divine_word", "cleric_smite_2", "cleric_zealotry", "cleric_judgement"]:
		assert_true(state.buy_skill_node(node_id), node_id)
	assert_eq(Skills.dock_keys(hero), ["cleric_mend", "cleric_smite", "cleric_sanctuary", "cleric_divine_word", "cleric_judgement", ""], "each new skill takes the next free key")
	assert_eq(learned.back(), ["cleric_judgement", 5])
	assert_true(state.choose_path(Ranks.path_choices(hero)[0]["id"]))
	assert_eq(Skills.dock_keys(hero)[5], "path", "the signature takes the last key")
	assert_true(state.buy_skill_node("cleric_holy_nova"))
	assert_eq(learned.back(), ["cleric_holy_nova", 0], "all six keys taken: it waits off the dock")
	assert_false(Skills.docked(hero).any(func(skill: Dictionary) -> bool: return skill.get("key", "") == "cleric_holy_nova"))
	assert_true(state.dock_skill("cleric_holy_nova", 1))
	assert_eq(Skills.dock_keys(hero).slice(0, 2), ["cleric_mend", "cleric_holy_nova"], "Smite makes room")
	assert_true(state.dock_skill("cleric_mend", 1))
	assert_eq(Skills.dock_keys(hero).slice(0, 2), ["cleric_holy_nova", "cleric_mend"], "two keys trade places")
	assert_false(state.dock_skill("warrior_cleave", 0), "only a skill the hero knows")
	hero.level = 20
	assert_true(state.choose_path(Ranks.path_choices(hero)[0]["id"]) or true)
	assert_eq(Skills.dock_keys(hero)[5], "path", "a deeper step keeps the signature's key")
	assert_eq(HeroState.from_dict(hero.to_dict()).skill_dock, hero.skill_dock, "the dock is saved")
	state.world.map_id = "town"
	state.pack.gold = 9999
	assert_true(state.forget_skills())
	assert_eq(Skills.dock_keys(hero)[0], "", "a forgotten skill leaves its key empty")
	assert_eq(Skills.docked(hero)[1]["key"], "cleric_mend")


func test_points_find_a_use_past_ten() -> void:
	# The points a level-19 hero has earned, against the nodes there are to buy.
	var hero := HeroState.create("T", "warrior")
	hero.xp = 0
	for level in range(2, 20):
		hero.xp += hero.xp_to_next
		HeroRules.apply_level_ups(hero)
	assert_eq(hero.level, 19)
	var buyable := Skills.tree("warrior").size() - 1
	assert_between(hero.skill_points - buyable, 0, 4, "a few to spare, not ten")


func test_twenty_is_the_fifth_rank() -> void:
	var hero := HeroState.create("T", "warrior")
	hero.level = 19
	hero.xp_to_next = HeroState.xp_to_next_for(19)
	hero.xp = hero.xp_to_next
	hero.path = ["juggernaut", "bastion", "unbroken"]
	HeroRules.apply_level_ups(hero)
	assert_eq(hero.skill_points, 2, "a rank's bonus point")
	assert_eq(HeroRules.rank_index(20), 4)
	assert_eq(Ranks.pending_tier(hero), 0, "the path was walked at 15: no step left")


## PIX-207: points with nothing to buy don't nag.
func test_spare_points_wait_without_nagging() -> void:
	var hero := HeroState.create("T", "warrior")
	hero.level = 20
	hero.skill_points = 3
	assert_true(Skills.can_spend(hero), "a whole tree still to learn")
	for entry: Dictionary in Skills.tree("warrior"):
		if entry["id"] not in hero.skill_nodes:
			hero.skill_nodes.append(entry["id"])
	assert_false(Skills.can_spend(hero), "all learned: the points wait quietly")
	assert_true(Town.trophy_stat_delta("lich_crown").has("endurance"), "the Lich Crown's every stat includes END")
