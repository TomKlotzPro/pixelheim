extends GutTest
## Endgame numbers (PIX-217): a whole tree's spare points buy capped ranks
## beyond it, and potions heal a share of a grown hero. (The Deep Hunt's
## wall and its hoards' potions left with it, PIX-257: the Kings' Vault's
## numbers are test_vault's.)

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_a_whole_trees_spare_points_buy_ranks_beyond_it() -> void:
	var hero: HeroState = state.hero
	hero.skill_points = 3
	var power: Dictionary = Skills.beyond_tracks()[0]
	assert_false(Skills.can_buy_beyond(hero, power), "not before the tree is whole")
	for entry: Dictionary in Skills.tree(hero.role_id):
		if entry["id"] not in hero.skill_nodes:
			hero.skill_nodes.append(entry["id"])
	assert_true(Skills.beyond_open(hero))
	var before := float(HeroRules.passives(hero)["skillPower"])
	assert_true(state.training.buy_beyond("power"))
	assert_almost_eq(float(HeroRules.passives(hero)["skillPower"]), before + float(power["skillPower"]), 0.0001)
	var hp: int = hero.stats["maxHp"]
	var grown := HeroRules.grown_hp(hero.to_dict())
	assert_true(state.training.buy_beyond("vigor"))
	assert_eq(int(hero.stats["maxHp"]), hp + 8)
	assert_eq(HeroRules.grown_hp(hero.to_dict()), grown + 8, "a save's catch-up counts the ranks")
	assert_eq(HeroState.from_dict(hero.to_dict()).beyond, hero.beyond, "the ranks are saved")
	hero.beyond["power"] = int(power["cap"])
	assert_false(Skills.can_buy_beyond(hero, power), "capped")


func test_forgetting_gives_the_ranks_back_too() -> void:
	var hero: HeroState = state.hero
	for entry: Dictionary in Skills.tree(hero.role_id):
		if entry["id"] not in hero.skill_nodes:
			hero.skill_nodes.append(entry["id"])
	hero.skill_points = 2
	state.training.buy_beyond("vigor")
	state.training.buy_beyond("steal")
	var hp_before_ranks: int = int(hero.stats["maxHp"]) - 8
	state.world.map_id = "town"
	state.pack.gold = 9999
	var points_after: int = hero.skill_points + Skills.forgettable(hero).size() + 2
	assert_true(state.training.forget_skills())
	assert_eq(hero.skill_points, points_after)
	assert_true(hero.beyond.is_empty())
	assert_lte(int(hero.stats["maxHp"]), hp_before_ranks, "vigour's health goes with it")


func test_potions_heal_a_share_of_a_grown_hero() -> void:
	var greater := Catalog.item("greater_potion")
	state.hero.stats["maxHp"] = 100
	assert_eq(state.upkeep.hp_restore(greater), 60, "its own sixty, early on")
	state.hero.stats["maxHp"] = 500
	assert_eq(state.upkeep.hp_restore(greater), roundi(500 * float(greater["restoreHpShare"])), "a share of a deep hero's health")
	for item_id: String in ["phoenix_draught", "elixir"]:
		assert_true(Catalog.item(item_id).has("restoreHpShare"), item_id)


func test_the_rank_up_tells_the_truth() -> void:
	var hero: HeroState = state.hero
	assert_false(Skills.tree_whole(hero))
	for entry: Dictionary in Skills.tree(hero.role_id):
		hero.skill_nodes.append(entry["id"])
	assert_true(Skills.tree_whole(hero))
	assert_false(Skills.all_learned(hero))
	for track: Dictionary in Skills.beyond_tracks():
		hero.beyond[track["id"]] = int(track["cap"])
	assert_true(Skills.all_learned(hero))
