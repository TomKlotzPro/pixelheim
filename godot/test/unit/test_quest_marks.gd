extends GutTest
## The marks over people (PIX-240): "!" for a quest to give, a gold "?" for
## one to hand in, a grey "?" while one is under way, nothing when there's
## nothing between them and the hero.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const VEX := "alchemist_vex"
const QUEST := "herbs_for_vex"

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _mark(giver: String) -> String:
	return Quests.mark_for(giver, state.progression.quests, state.pack.items, state.questing.quest_open)


func test_a_quest_to_give_is_an_exclamation() -> void:
	assert_eq(_mark(VEX), "offer")


func test_a_quest_under_way_then_ready_then_done() -> void:
	state.questing.resolve_quests(VEX)
	assert_eq(_mark(VEX), "waiting", "taken, nothing brewed yet")
	state.progression.quests[QUEST]["progress"] = 1
	assert_eq(_mark(VEX), "ready", "brewed: hand it in")
	state.questing.resolve_quests(VEX)
	assert_true(state.progression.quests[QUEST]["done"])
	# Her next quest, if the story has reached it.
	var next: Dictionary = Quests.by_id("vex_glass")
	assert_eq(_mark(VEX), "offer" if state.questing.quest_open(next) else "", "her next quest, or nothing yet")


func test_nobody_with_nothing_has_a_mark() -> void:
	assert_eq(_mark("nobody_at_all"), "")


func test_a_quest_the_story_hasnt_reached_has_no_mark() -> void:
	var gated: Array = Quests.all().filter(func(quest: Dictionary) -> bool: return String(quest.get("opensAfter", "")) != "")
	assert_false(gated.is_empty(), "some quests wait for the story")
	for quest: Dictionary in gated:
		if Quests.for_giver(quest["giver"])[0]["id"] != quest["id"] or state.questing.quest_open(quest):
			continue
		assert_eq(_mark(quest["giver"]), "", "%s waits for the story" % quest["id"])
