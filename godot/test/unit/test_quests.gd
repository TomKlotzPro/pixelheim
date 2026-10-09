extends GutTest
## Quests (src/game/quests.ts + resolveQuests in reducers/world.ts + the
## bounty tick in battleEngine's onMonsterDefeated): accept on a giver's
## first word, count kills, take deliveries from the pack, pay on turn-in.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	# No drops, no foraging: only the quests move.
	state.roll = func() -> float: return 0.99


func _slay(monster_id: String) -> Array[String]:
	return state.defeat_monster(Bestiary.spawn(monster_id), "", "", 1)


func test_a_givers_first_word_accepts_their_quest() -> void:
	assert_eq(
		state.resolve_quests("innkeeper"),
		"Quest accepted: Slime Trouble. Slimes have crept into what's left of Sela's stores. Thin the forest's supply of them. It's in your journal (Q).",
		"PIX-194: the task, not the words just said"
	)
	assert_eq(state.progression.quests["slime_trouble"], {"progress": 0, "done": false})
	assert_eq(state.resolve_quests("innkeeper"), "Slime Trouble: 0/3 slimes flattened.")
	assert_eq(state.resolve_quests("shopkeeper"), "", "no quest to give")


func test_bounties_count_matching_kills_up_to_the_goal() -> void:
	assert_false(_slay("slime").has("Slime Trouble: 1/3."), "not yet accepted")
	state.resolve_quests("innkeeper")
	assert_has(_slay("slime"), "Slime Trouble: 1/3.")
	assert_false(_slay("goblin").has("Slime Trouble: 2/3."), "only slimes count")
	_slay("slime")
	assert_has(_slay("slime"), "Slime Trouble: 3/3.")
	assert_eq(state.progression.quests["slime_trouble"]["progress"], 3)
	_slay("slime")
	assert_eq(state.progression.quests["slime_trouble"]["progress"], 3, "never past the goal")


func test_turning_in_pays_and_closes_the_quest() -> void:
	state.resolve_quests("innkeeper")
	for i in 3:
		_slay("slime")
	var gold: int = state.pack.gold
	var xp: int = state.hero.xp
	assert_eq(
		state.resolve_quests("innkeeper"),
		"Quest complete: Slime Trouble. +60 gold, +30 XP. \u201cThe stores thank you. So does my nose. Here - you've earned it.\u201d"
		+ "\nLevel up: you are now level 2. +3 stat points and +1 skill point to spend.",
		"the three slimes and the reward make a level"
	)
	assert_eq(state.pack.gold, gold + 60)
	assert_true(state.hero.xp == xp + 30 or state.hero.level > 1, "xp paid (a level-up may spend it)")
	assert_true(state.progression.quests["slime_trouble"]["done"])
	assert_eq(state.resolve_quests("innkeeper"), "", "a kept promise stays kept")
	assert_false(_slay("slime").has("Slime Trouble: 4/3."))


func test_deliveries_count_the_pack_and_leave_it_on_turn_in() -> void:
	state.pack.items.erase("cheese_wheel")  # the starting kit packs one
	state.resolve_quests("villager_bram")
	assert_eq(state.resolve_quests("villager_bram"), "The Cheese Run: 0/1 cheese wheels delivered.")
	state.pack.add_item("cheese_wheel", 2)
	assert_true(Quests.is_ready(Quests.by_id("cheese_run"), state.progression.quests, state.pack.items))
	assert_string_starts_with(state.resolve_quests("villager_bram"), "Quest complete: The Cheese Run. +25 gold, +15 XP.")
	assert_eq(state.pack.items.get("cheese_wheel", 0), 1, "one wheel handed over")


func test_some_quests_pay_an_item_too() -> void:
	state.resolve_quests("alchemist_vex")
	state.progression.quests["herbs_for_vex"]["progress"] = 1
	var potions: int = state.pack.items.get("greater_potion", 0)
	state.resolve_quests("alchemist_vex")
	assert_eq(state.pack.items.get("greater_potion", 0), potions + 1)


func test_closing_a_conversation_resolves_quests() -> void:
	var said: Array[String] = []
	state.message.connect(func(text: String) -> void: said.append(text))
	state.finish_dialogue("elder")
	# Since the gate was barred (PIX-170) Maren's first ask is the relics.
	assert_eq(said.size(), 1)
	assert_string_contains(said[0], "Quest accepted: Relics of the Five. Only what the five climbers left behind")


func test_vex_talks_before_his_counter_only_while_his_quest_waits() -> void:
	var waits := func() -> bool:
		return Quests.awaits_word("alchemist_vex", state.progression.quests, state.pack.items, state.quest_open)
	assert_true(waits.call(), "untaken: he offers it")
	state.finish_dialogue("alchemist_vex")
	assert_eq(state.progression.quests["herbs_for_vex"], {"progress": 0, "done": false})
	assert_false(waits.call(), "under way: the counter")
	# A first brew at the cauldron (PIX-143) makes it ready.
	state.world.map_id = "town_alchemist"
	state.pack.items.merge({"forest_herb": 1, "marsh_reed": 1})
	state.roll = func() -> float: return 0.99
	state.craft("brew_potion_hp")
	assert_true(waits.call(), "potion brewed: he takes word of it")
	state.finish_dialogue("alchemist_vex")
	assert_true(state.progression.quests["herbs_for_vex"]["done"])
	assert_eq(state.pack.items.get("greater_potion", 0), 1)
	assert_false(waits.call(), "done: the counter")
	assert_false(Quests.awaits_word("shopkeeper", state.progression.quests, state.pack.items), "Odo gives no quest")
