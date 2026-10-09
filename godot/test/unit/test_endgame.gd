extends GutTest
## Endgame numbers (PIX-217): the Deep Hunt climbs faster than a hero
## levels, so a kit that held at the bottom of the mountain gives way deep
## down; a whole tree's spare points buy capped ranks beyond it; potions heal
## a share of a grown hero; and the deep hoard's potion grows with the depth.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## The mountain's best plate, forged up two and again for each deep tier.
const PLATE := ["wyrm_visor", "city_plate", "blackiron_gauntlets", "scaled_greaves", "cinderscale_shield"]

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


## How many matched hits a warrior who levelled a level a depth, in the
## mountain's plate forged as deep as `depth`, takes from that depth's foes.
func _hits_at(depth: int) -> float:
	var rules: Dictionary = Bestiary._data()["deepHunt"]
	var hero := HeroState.create("Model", "warrior")
	var level := int(rules["startLevel"]) + depth - 1
	while hero.level < level:
		hero.xp = hero.xp_to_next
		HeroRules.apply_level_ups(hero)
	for i in level - 1:
		Skills.apply_stat_point(hero, "defense")
	var pack := InventoryState.new()
	for item_id: String in PLATE:
		var piece := InventoryState.create_gear(item_id)
		piece["bonus"] = 2 + int(Economy._data()["deepTiers"]["bonus"]) * Dungeons.deep_tier(Dungeons.floor_count() + depth)
		pack.gear.append(piece)
		pack.equipped[Catalog.item(item_id)["slot"]] = piece["uid"]
	var guardian := Dungeons.boss_of(Dungeons.floor_count() + depth)
	var foe_level := int(Bestiary.monster(guardian["monsterId"])["level"]) + int(guardian["lift"])
	var foe := Bestiary.matched_attack(foe_level)
	var hit := foe * (1.0 - Bestiary.turned_aside(foe, HeroRules.total_defense(hero, pack)))
	return float(hero.stats["maxHp"]) / hit


func test_the_deep_hunt_becomes_a_wall() -> void:
	var first := _hits_at(1)
	var thirtieth := _hits_at(29)
	gut.p("hits to die: depth 1 %.1f, depth 29 %.1f, depth 59 %.1f" % [first, thirtieth, _hits_at(59)])
	assert_gt(first, 6.0, "the first depth is fair to a mountain kit")
	assert_lt(thirtieth, 6.0, "by depth thirty, the kit alone doesn't hold")


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
	assert_eq(state.hp_restore(greater), 60, "its own sixty, early on")
	state.hero.stats["maxHp"] = 500
	assert_eq(state.hp_restore(greater), roundi(500 * float(greater["restoreHpShare"])), "a share of a deep hero's health")
	for item_id: String in ["phoenix_draught", "elixir"]:
		assert_true(Catalog.item(item_id).has("restoreHpShare"), item_id)


func test_the_deep_hoards_potion_grows_with_the_depth() -> void:
	assert_has(Dungeons.deep_def(1)["rewardItemIds"], "greater_potion")
	assert_has(Dungeons.deep_def(12)["rewardItemIds"], "phoenix_draught")
	assert_has(Dungeons.deep_def(40)["rewardItemIds"], "dragon_tonic")


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
