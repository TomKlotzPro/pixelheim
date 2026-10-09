extends GutTest
## Ranks and the Path Graph (hero/ranks.ts, hero/paths.ts, CHOOSE_PATH,
## useRankUp): titles every five levels, the aura and presence they bring,
## which step of the graph is on offer, and the ascension's signal.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_titles_change_every_five_levels() -> void:
	assert_eq(Ranks.title("warrior", 1), "Footman")
	assert_eq(Ranks.title("warrior", 5), "Warrior")
	assert_eq(Ranks.title("warrior", 10), "Champion")
	assert_eq(Ranks.title("warrior", 15), "Warbringer")
	assert_eq(Ranks.title("warrior", 20), "Ironlord", "a fifth rank at 20 (PIX-190)")
	assert_eq(Ranks.title("warrior", 40), "Ironlord", "rank caps at 4")
	assert_eq(Ranks.title("necromancer", 15), "Lichlord")
	for role: String in Ranks._data()["rankTitles"]:
		assert_eq(Ranks._data()["rankTitles"][role].size(), 5, role)


func test_the_ascended_glow_and_stand_taller() -> void:
	assert_eq(Ranks.aura(4), null)
	assert_eq(Ranks.aura(5), Color("#9ab0d8"), "silver")
	assert_eq(Ranks.aura(10), Color("#e8c34a"), "gold")
	assert_eq(Ranks.aura(15), Color("#4ae6c8"), "radiant")
	assert_almost_eq(Ranks.presence(1), 1.0, 0.001)
	assert_almost_eq(Ranks.presence(15), 1.15, 0.001)
	assert_eq(Ranks.aura(20), Color("#c58cff"), "amethyst")
	assert_almost_eq(Ranks.presence(20), 1.2, 0.001)


func _ids(nodes: Array) -> Array:
	return nodes.map(func(node: Dictionary) -> String: return node["id"])


func test_each_rank_opens_one_step_of_the_path() -> void:
	var hero: HeroState = state.hero
	assert_eq(Ranks.pending_tier(hero), 0, "no fork before the first rank")
	hero.level = 5
	assert_eq(Ranks.pending_tier(hero), 1)
	assert_eq(_ids(Ranks.path_choices(hero)), ["juggernaut", "warlord"])
	assert_true(state.training.choose_path("warlord"))
	assert_eq(hero.path, ["warlord"])
	assert_eq(hero.spec, "warlord", "spec mirrors the first step")
	assert_eq(Ranks.pending_tier(hero), 0, "the next step waits for rank 2")
	hero.level = 10
	assert_eq(_ids(Ranks.path_choices(hero)), ["bastion", "battlelord"], "the crossover is on offer")
	assert_false(state.training.choose_path("unbroken"), "a capstone can't be skipped to")
	assert_true(state.training.choose_path("bastion"))
	hero.level = 15
	assert_eq(_ids(Ranks.path_choices(hero)), ["unbroken"], "only its own capstone follows")
	assert_true(state.training.choose_path("unbroken"))
	assert_eq(Ranks.path_choices(hero), [], "the walk is complete")
	assert_eq(HeroRules.passives(state.hero)["defense"], HeroRules.path_node("unbroken")["passive"].get("defense", 0))


func test_older_saves_walk_from_their_spec() -> void:
	var hero: HeroState = state.hero
	hero.level = 10
	hero.spec = "juggernaut"
	hero.path = null
	assert_eq(_ids(Ranks.path_choices(hero)), ["bastion", "battlelord"])


func test_crossing_a_rank_sends_the_ascension_once() -> void:
	var titles: Array[String] = []
	state.ranked_up.connect(func(title: String) -> void: titles.append(title))
	var hero: HeroState = state.hero
	hero.level = 4
	hero.xp_to_next = HeroState.xp_to_next_for(4)
	hero.xp = hero.xp_to_next
	var points: int = hero.skill_points
	state.spoils.grant_levels()
	assert_eq(titles, ["Warrior"])
	assert_eq(hero.skill_points, points + 2, "the level's point and the rank's bonus")
	hero.xp = hero.xp_to_next
	state.spoils.grant_levels()
	assert_eq(titles, ["Warrior"], "level 6 is no new rank")
