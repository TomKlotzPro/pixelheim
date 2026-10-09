extends GutTest
## Quests with stakes (PIX-192): some end in a choice the hero makes and the
## giver remembers, and a fall costs a tenth of the gold carried - never
## what's banked.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _ready_locket() -> void:
	state.progression.quests["fenwick_locket"] = {"progress": 0, "done": false}
	state.pack.add_item("fenwicks_locket")


func test_a_choice_waits_for_an_answer() -> void:
	_ready_locket()
	var asking := Quests.pending_choice("greyhold_fenwick", state.progression.quests, state.pack.items)
	assert_eq(asking.get("id"), "fenwick_locket")
	assert_eq(asking["choice"]["options"].size(), 2)
	var said: String = state.resolve_quests("greyhold_fenwick")
	assert_string_contains(said, "wait on your answer")
	assert_false(state.progression.quests["fenwick_locket"]["done"], "no answer, no hand-in")
	assert_eq(int(state.pack.items.get("fenwicks_locket", 0)), 1)


func test_each_answer_pays_its_own_way_and_is_remembered() -> void:
	_ready_locket()
	var gold: int = state.pack.gold
	var line: String = state.choose("fenwick_locket", "spare")
	assert_string_contains(line, "Quest complete")
	assert_string_contains(line, "north stair")
	assert_eq(state.pack.gold, gold + 50)
	assert_eq(int(state.pack.items.get("fenwicks_locket", 0)), 0, "the locket goes back to Fenwick")
	assert_eq(state.progression.quests["fenwick_locket"]["choice"], "spare")
	assert_string_contains(Quests.after_choice("greyhold_fenwick", state.progression.quests), "red cloaks got home")
	assert_eq(state.choose("fenwick_locket", "turn_in"), "", "answered once")
	assert_true(Quests.pending_choice("greyhold_fenwick", state.progression.quests, state.pack.items).is_empty())


func test_rooks_take_can_go_back_to_saltmere() -> void:
	state.progression.quests["rook_captain"] = {"progress": 1, "done": false}
	assert_eq(state.choose("rook_captain", "nobody"), "", "only an answer on offer")
	state.choose("rook_captain", "return")
	assert_eq(int(state.pack.items.get("pearl", 0)), 1, "Ola's pearl for an honest Rook")
	var split: Dictionary = Quests.by_id("rook_captain")["choice"]["options"][0]
	assert_gt(int(split["reward"]["gold"]), 200, "keeping the take pays more gold")


func test_every_choice_is_whole() -> void:
	for quest: Dictionary in Quests.all():
		if not quest.has("choice"):
			continue
		assert_gt(quest["choice"]["prompt"].size(), 0, quest["id"])
		assert_between(quest["choice"]["options"].size(), 2, 3, quest["id"])
		for option: Dictionary in quest["choice"]["options"]:
			for key in ["id", "label", "line", "reward", "after"]:
				assert_true(option.has(key), "%s %s has %s" % [quest["id"], option.get("id"), key])


func test_a_fall_costs_a_tenth_of_the_gold_carried() -> void:
	state.pack.gold = 500
	assert_true(state.bank_deposit(300))
	state.hurt(9999)
	state.wake_at_inn()
	assert_eq(state.pack.gold, 180, "a tenth of the 200 carried")
	assert_eq(int(state.investments()["savings"]["principal"]), 300, "the bank keeps what's banked")


func test_the_night_of_the_fire_costs_nothing() -> void:
	state.progression.prologue = Prologue.SCAVENGER
	state.pack.gold = 100
	state.wake_at_inn()
	assert_eq(state.pack.gold, 100)
