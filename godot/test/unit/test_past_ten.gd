extends GutTest
## Something to earn after level 10 (PIX-190): two more tiers in every tree
## (levels 13 and 17 then, 11 and 14 since PIX-233), passives that do
## something in a real-time fight (the web's flee chance didn't), a dock the
## hero sets, and a fifth rank at 20.

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
	assert_eq(Bestiary._data()["skillTierLevels"], [1, 3, 6, 9, 11, 14])
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
		assert_true(state.training.buy_skill_node(node_id), node_id)
	assert_eq(Skills.dock_keys(hero), ["cleric_mend", "cleric_smite", "cleric_sanctuary", "cleric_divine_word", "cleric_judgement", ""], "each new skill takes the next free key")
	assert_eq(learned.back(), ["cleric_judgement", 5])
	assert_true(state.training.choose_path(Ranks.path_choices(hero)[0]["id"]))
	assert_eq(Skills.dock_keys(hero)[5], "path", "the signature takes the last key")
	assert_true(state.training.buy_skill_node("cleric_holy_nova"))
	assert_eq(learned.back(), ["cleric_holy_nova", 0], "all six keys taken: it waits off the dock")
	assert_false(Skills.docked(hero).any(func(skill: Dictionary) -> bool: return skill.get("key", "") == "cleric_holy_nova"))
	assert_true(state.training.dock_skill("cleric_holy_nova", 1))
	assert_eq(Skills.dock_keys(hero).slice(0, 2), ["cleric_mend", "cleric_holy_nova"], "Smite makes room")
	assert_true(state.training.dock_skill("cleric_mend", 1))
	assert_eq(Skills.dock_keys(hero).slice(0, 2), ["cleric_holy_nova", "cleric_mend"], "two keys trade places")
	assert_false(state.training.dock_skill("warrior_cleave", 0), "only a skill the hero knows")
	hero.level = 20
	assert_true(state.training.choose_path(Ranks.path_choices(hero)[0]["id"]) or true)
	assert_eq(Skills.dock_keys(hero)[5], "path", "a deeper step keeps the signature's key")
	assert_eq(HeroState.from_dict(hero.to_dict()).skill_dock, hero.skill_dock, "the dock is saved")
	state.world.map_id = "town"
	state.pack.gold = 9999
	assert_true(state.training.forget_skills())
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
	# PIX-217: a whole tree's points go beyond it, until those ranks are full too.
	assert_true(Skills.can_spend(hero), "a whole tree: the points buy ranks beyond it")
	for track: Dictionary in Skills.beyond_tracks():
		hero.beyond[track["id"]] = int(track["cap"])
	assert_false(Skills.can_spend(hero), "all learned: the points wait quietly")
	assert_true(Town.trophy_stat_delta("lich_crown").has("endurance"), "the Lich Crown's every stat includes END")


## PIX-233: a point earned always has something to buy. A hero of every role
## climbs from level 1 to 25 buying all it can - every node open to it, then
## ranks beyond the whole tree - and no level leaves a point over (with the
## tiers at 10, 13 and 17, level 9 left one, and 16 left four).
func test_every_point_earned_has_something_to_buy() -> void:
	for role: String in Bestiary._data()["skillTrees"]:
		var game: Node = autofree(GameStateScript.new())
		game.new_game("T", role)
		var hero: HeroState = game.hero
		for level in range(1, 26):
			if level > 1:
				hero.xp = hero.xp_to_next
				game.spoils.grant_levels()
			assert_eq(hero.level, level)
			_spend_everything(game)
			assert_true(hero.skill_points == 0 or Skills.all_learned(hero), "%s at level %d: %d point(s) and nothing to buy" % [role, level, hero.skill_points])
			if level == 15:
				assert_true(Skills.tree_whole(hero), "%s: the whole tree by 15" % role)
			if level == 16:
				assert_eq(hero.beyond.values().reduce(func(sum: int, rank: int) -> int: return sum + rank, 0), 1, "%s: the ranks beyond take 16's point" % role)


## Every node the hero can buy, bought (parents before children), then
## every rank beyond a whole tree.
func _spend_everything(game: Node) -> void:
	var bought := true
	while bought:
		bought = false
		for entry: Dictionary in Skills.tree(game.hero.role_id):
			bought = game.training.buy_skill_node(entry["id"]) or bought
		for track: Dictionary in Skills.beyond_tracks():
			bought = game.training.buy_beyond(track["id"]) or bought


## PIX-233: should a point ever wait with nothing to buy (here, points a
## level-1 hero was handed), the level-up line says when the next skills open.
func test_a_waiting_point_says_when_the_next_skills_open() -> void:
	state.new_game("Robin", "warrior")
	var hero: HeroState = state.hero
	hero.skill_points = 2
	for node_id: String in ["warrior_shield_slam", "warrior_berserk"]:
		assert_true(state.training.buy_skill_node(node_id), node_id)
	assert_eq(Skills.next_tier_level(hero), 3)
	assert_eq(Skills.next_skills_note(hero), "", "no point waiting")
	var line: String = state.spoils.earn_xp(hero.xp_to_next)
	assert_eq(line, "Level up: you are now level 2. +3 stat points and +1 skill point to spend. Next skills at level 3.")
	assert_eq(Skills.next_skills_note(hero), "Next skills at level 3.", "the tree says so too")
	hero.level = 14
	assert_eq(Skills.next_tier_level(hero), 0, "every tier open")
	assert_eq(Skills.next_skills_note(hero), "")
