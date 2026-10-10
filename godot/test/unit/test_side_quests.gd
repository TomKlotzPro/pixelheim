extends GutTest
## Side quests that follow the main (PIX-171): Pixelheim's folk send the hero
## out to the Reach once Maren has asked for the relics, a hub's side quests
## wait for its first word, every quest says where to go, and the map marks
## who is waiting.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_every_opening_names_a_real_step_or_quest() -> void:
	for quest: Dictionary in Quests.all():
		var after: String = quest.get("opensAfter", "")
		if after == "":
			continue
		assert_true(not MainQuest.step(after).is_empty() or not Quests.by_id(after).is_empty(), "%s opens after %s" % [quest["id"], after])


func test_the_town_sends_the_hero_out_once_maren_has_asked() -> void:
	state.progression.quests["hildas_buckler"] = {"progress": 1, "done": true}
	var quest := Quests.by_id("hildas_ore")
	assert_false(state.questing.quest_open(quest), "the relics aren't asked for yet")
	assert_eq(state.questing.resolve_quests("smith"), "", "Hilda has nothing to ask")
	assert_false(Quests.awaits_word("smith", state.progression.quests, state.pack.items, state.questing.quest_open), "so she opens her counter")
	state.questing.resolve_quests("elder")
	assert_true(state.questing.quest_open(quest))
	assert_true(Quests.awaits_word("smith", state.progression.quests, state.pack.items, state.questing.quest_open))
	assert_string_contains(state.questing.resolve_quests("smith"), "Black Iron for the Forge")


func test_a_hubs_side_quest_waits_for_its_first_word() -> void:
	assert_eq(state.questing.resolve_quests("saltmere_rook"), "", "Rook waits until Wenna's smugglers are dealt with")
	state.progression.quests["wenna_smugglers"] = {"progress": 3, "done": true}
	assert_string_contains(state.questing.resolve_quests("saltmere_rook"), "Quest accepted")


func test_bram_asks_for_the_shaft_cheese_before_the_imps() -> void:
	assert_eq(Quests.for_giver("villager_bram").map(func(q: Dictionary) -> String: return q["id"]), ["cheese_run", "bram_shaftcheese", "bram_imps"])


func test_what_the_town_wants_waits_in_the_regions_chests() -> void:
	for item_id: String in ["smugglers_rum", "shaft_cheese", "guard_badge"]:
		var chests: Array = Interactables._data()["chests"].filter(func(c: Dictionary) -> bool: return c.get("loot", {}).get("itemId", "") == item_id)
		assert_eq(chests.size(), 1, item_id)
		var chest: Dictionary = chests[0]
		assert_true(MapData.load_by_id(chest["mapId"]).is_walkable(Vector2i(int(chest["x"]), int(chest["y"]))), "%s's chest stands on floor" % item_id)
		assert_true(Catalog.item(item_id).get("quest", false))


func test_every_promise_says_where_to_go() -> void:
	assert_string_contains(Quests.where(Quests.by_id("garrick_seam")), "Black Seam")
	assert_string_contains(Quests.where(Quests.by_id("sela_rum")), "Sea Cave")
	assert_string_contains(Quests.where(Quests.by_id("wolf_watch")), "Found in")
	assert_string_contains(Quests.where(Quests.by_id("maren_relics")), "Saltmere")
	# PIX-184: every promise, deliveries too (Linnea's icefin comes from a hole in the ice).
	for quest: Dictionary in Quests.all():
		assert_ne(Quests.where(quest), "", "%s says where" % quest["id"])


func test_the_map_marks_who_is_waiting() -> void:
	var sela: Dictionary = Npcs.by_id("innkeeper", [])
	var bram: Dictionary = Npcs.by_id("villager_bram", [])
	var waiting: Array = state.questing.givers_waiting([sela, bram])
	assert_eq(waiting.map(func(npc: Dictionary) -> String: return npc["id"]), ["innkeeper", "villager_bram"], "both have a first ask")
	state.questing.resolve_quests("innkeeper")
	assert_eq(state.questing.givers_waiting([sela]), [] as Array[Dictionary], "a quest taken and not ready: nothing to say")


## PIX-202: a giver asks their quest themselves before it's taken.
func test_a_giver_speaks_their_ask() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	var offer: Dictionary = state.questing.quest_on_offer("innkeeper")
	assert_eq(offer.get("id"), "slime_trouble")
	assert_ne(String(offer.get("accepted", "")), "", "Sela's own words")
	var said: String = state.questing.resolve_quests("innkeeper")
	assert_string_contains(said, "journal", "the accept points at the journal")
	assert_true(state.questing.quest_on_offer("innkeeper").is_empty(), "taken: nothing more to ask")
	for quest: Dictionary in Quests.all():
		# Maren's letters (PIX-253) aren't asked in talk: the tin gives them,
		# and their words are their recipients' answers.
		if quest["objective"]["kind"] == "deliverTo":
			assert_gt(quest["answer"].size(), 0, "%s has its answer" % quest["id"])
			continue
		assert_ne(String(quest.get("accepted", "")), "", "%s has its ask" % quest["id"])
