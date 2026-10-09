extends GutTest
## How it ends (PIX-157): at Morvax's throne the hero destroys him, or -
## knowing Maren's story of the five and holding Liane's last page - lays
## him to rest; each ending has its scene and Maren's own last words. And
## the settlers' arcs: two asks after moving in, the last growing their perk.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const RECRUITS := ["settler_iva", "settler_wren", "settler_loras", "settler_mirelle"]

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.world.map_id = "town"


func test_the_ending_is_whichever_was_played() -> void:
	assert_eq(Story.ending_of([]), "")
	assert_eq(Story.ending_of(["ending"]), "destroy", "the old single ending destroyed him")
	assert_eq(Story.ending_of(["ending_rest"]), "rest")
	for choice: String in ["destroy", "rest"]:
		assert_true(Cutscene.scenes().has(Story.ending_scene(choice)), "%s has its scene" % choice)
	assert_ne(Story.ending_scene("rest"), Story.ending_scene("destroy"))


func test_laying_him_to_rest_needs_marens_story_and_lianes_last_page() -> void:
	var all_floors := range(1, 16)
	assert_false(Story.can_lay_to_rest(all_floors, []), "not without Maren's story")
	assert_false(Story.can_lay_to_rest(range(1, 14), ["maren_confession"]), "not without the last page")
	assert_true(Story.can_lay_to_rest(all_floors, ["maren_confession"]))


func test_maren_has_last_words_for_each_ending() -> void:
	var all_floors := range(1, 16)
	var told := ["maren_graves", "maren_seal", "maren_confession"]
	assert_eq(Story.elder_story(all_floors, told), {}, "nothing new before the ending")
	assert_eq(Story.elder_story(all_floors, told + ["ending_rest"])["id"], "maren_peace")
	assert_eq(Story.elder_story(all_floors, told + ["ending"])["id"], "maren_after")
	assert_string_contains(Story.elder_story(all_floors, told + ["ending_rest"])["lines"][0], "right to run")


func test_each_recruit_has_a_two_step_arc_ending_in_their_perk() -> void:
	for recruit_id: String in RECRUITS:
		var asks := Quests.for_giver(recruit_id)
		assert_eq(asks.size(), 3, "%s: the move, then two asks" % recruit_id)
		assert_eq(asks[0].get("settles", ""), recruit_id, "%s moves in first" % recruit_id)
		assert_false(asks[1].has("upgrades"))
		assert_eq(asks[2].get("upgrades", ""), recruit_id)
		assert_ne(Town.recruit(recruit_id).get("perkUp", ""), "")


func test_a_settler_serves_then_asks_and_the_last_ask_grows_the_perk() -> void:
	state.settlement.settlers.append("settler_iva")
	state.progression.quests["iva_reeds"] = {"progress": 3, "done": true}
	state.hero.hp = 1
	var said := [""]
	state.message.connect(func(text: String) -> void: said[0] = text)
	state.questing.finish_dialogue("settler_iva")
	assert_eq(state.hero.hp, state.hero.stats["maxHp"], "she heals first")
	assert_string_contains(said[0], "Herbs for the Shrine", "then asks")
	assert_false(state.holdings.perk_grown("settler_iva"))
	state.progression.quests["iva_herbs"] = {"progress": 4, "done": true}
	state.progression.quests["iva_fever"] = {"progress": 3, "done": true}
	assert_true(state.holdings.perk_grown("settler_iva"))
	assert_has(Town.settler_perks(state.settlement.settlers, state.progression.quests), Town.recruit("settler_iva")["perkUp"])
	state.pack.items.erase("potion_hp")
	state.questing.finish_dialogue("settler_iva")
	assert_eq(int(state.pack.items.get("potion_hp", 0)), 3, "and tops up the potions")


func test_the_grown_perks_pay_more() -> void:
	for recruit_id: String in RECRUITS:
		state.settlement.settlers.append(recruit_id)
	assert_almost_eq(state.holdings.song_crit(), 0.12, 0.001)
	assert_eq(state.holdings.walk_bonus(), 0.0)
	for quest: Dictionary in Quests.all():
		if quest.has("upgrades"):
			state.progression.quests[quest["id"]] = {"progress": 0, "done": true}
	assert_almost_eq(state.holdings.song_crit(), 0.2, 0.001)
	assert_almost_eq(state.holdings.walk_bonus(), 0.1, 0.001)
	var plain := Town.savings_value({"principal": 1000, "at": 0}, 4800)
	assert_gt(Town.savings_value({"principal": 1000, "at": 0}, 4800, true), plain, "Mirelle's savings grow faster")
	# Loras's horn: a song-inspired crit is likelier (the roll that missed at 12% lands at 20%).
	var hero: HeroState = state.hero
	var crit_roll: float = HeroRules.passives(hero)["critChance"] + 0.15
	var dice := func(values: Array) -> Callable:
		var at := [0]
		return func() -> float:
			at[0] += 1
			return values[at[0] - 1]
	var plain_hit := Bestiary.hero_attack_damage(hero, state.pack, Bestiary.spawn("slime"), true, dice.call([crit_roll, 0.5]))
	var horn_hit := Bestiary.hero_attack_damage(hero, state.pack, Bestiary.spawn("slime"), true, dice.call([crit_roll, 0.5]), 0.2)
	assert_gt(horn_hit, plain_hit)
