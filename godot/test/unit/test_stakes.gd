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


## PIX-192: Pell's canary against the clock.
func test_the_canary_runs_against_the_clock() -> void:
	state.progression.quests["pell_canary"] = {"progress": 0, "done": false}
	assert_eq(state.tick_runs(1.0)["message"], "", "no canary, no clock")
	var chest_id: String = Interactables._data()["chests"].filter(func(chest: Dictionary) -> bool: return chest.get("loot", {}).get("itemId", "") == "canary")[0]["id"]
	state.pack.add_item("canary")
	state.world.opened_chests.append(chest_id)
	var started: Dictionary = state.tick_runs(0.5)
	assert_string_contains(started["message"], "60 seconds")
	state.tick_runs(10.0)
	assert_almost_eq(float(state.timed_run()["left"]), 50.0, 0.01)
	var lapsed: Dictionary = state.tick_runs(51.0)
	assert_string_contains(lapsed["message"], "west gallery")
	assert_eq(int(state.pack.items.get("canary", 0)), 0, "she flies back")
	assert_false(chest_id in state.world.opened_chests, "her chest can be opened again")
	assert_true(state.timed_run().is_empty())


func test_the_canary_home_in_time_stops_the_clock() -> void:
	state.progression.quests["pell_canary"] = {"progress": 0, "done": false}
	state.pack.add_item("canary")
	state.tick_runs(0.1)
	state.resolve_quests("mines_pell")
	assert_true(state.progression.quests["pell_canary"]["done"])
	assert_true(state.timed_run().is_empty())
	assert_eq(state.tick_runs(500.0)["message"], "")


func test_an_answer_survives_a_save() -> void:
	_ready_locket()
	state.choose("fenwick_locket", "turn_in")
	var saved := {}
	state.progression.write_into(saved)
	assert_eq(ProgressionState.from_dict(saved).quests["fenwick_locket"]["choice"], "turn_in")


## PIX-192: Gunnar's last wagon down the pass.
func test_the_wagon_waits_while_its_quest_runs() -> void:
	assert_true(state.escort_due().is_empty(), "not before Gunnar asks")
	state.progression.quests["gunnar_strongbox"] = {"progress": 1, "done": true}
	state.progression.quests["gunnar_wagon"] = {"progress": 0, "done": false}
	var due: Dictionary = state.escort_due()
	assert_eq(due["quest"]["id"], "gunnar_wagon")
	assert_eq(due["def"]["mapId"], "frostgate")
	assert_false(Quests.is_ready(Quests.by_id("gunnar_wagon"), state.progression.quests, state.pack.items))
	state.escort_arrived("gunnar_wagon")
	assert_true(state.escort_due().is_empty(), "down: no more wagon")
	assert_true(Quests.is_ready(Quests.by_id("gunnar_wagon"), state.progression.quests, state.pack.items), "Gunnar waits with the pay")
	assert_string_contains(state.resolve_quests("frost_gunnar"), "Quest complete: The Last Wagon Down")


func test_the_wagons_road_and_its_ambushes_stand_on_open_ground() -> void:
	for escort_id: String in Bestiary._data()["escorts"]:
		var def: Dictionary = Bestiary._data()["escorts"][escort_id]
		var map := MapData.load_by_id(def["mapId"])
		for cell: Array in def["route"]:
			assert_true(map.is_walkable(Vector2i(int(cell[0]), int(cell[1]))), "%s road %s" % [escort_id, cell])
		for ambush: Dictionary in def["ambushes"]:
			assert_between(int(ambush["at"]), 1, def["route"].size() - 1, "%s ambush on the road" % escort_id)
			assert_eq(ambush["foes"].size(), ambush["from"].size())
			for cell: Array in ambush["from"]:
				assert_true(map.is_walkable(Vector2i(int(cell[0]), int(cell[1]))), "%s ambush from %s" % [escort_id, cell])
			for foe: String in ambush["foes"]:
				assert_false(Bestiary.monster(foe).is_empty(), foe)
