extends GutTest
## The story tells the truth in the first hours (PIX-204): Maren keeps the
## barred gate's lines until it opens, nobody says "ask Maren" to Maren, the
## town's goals offer no floor behind a barred gate, and the trades point at
## their stalls until their houses stand.

const GameStateScript := preload("res://scripts/state/game_state.gd")


func _elder(tier: int, gate_open: bool) -> Dictionary:
	for npc: Dictionary in Npcs.on_map("town", tier, [], [], gate_open):
		if npc["id"] == "elder":
			return npc
	return {}


func test_maren_keeps_the_barred_gates_lines_till_it_opens() -> void:
	var barred := _elder(2, false)
	for line: String in barred["lines"]:
		assert_false("stands open" in line or "north, past the bridge" in line, "no open gate while it's barred: %s" % line)
		assert_false("before you were born" in line, "the fire was last night, not long ago")
	assert_true(_elder(2, true)["lines"].any(func(line: String) -> bool: return "open" in line), "once open, she says so")


func test_nobody_tells_maren_to_ask_herself() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	var step := MainQuest.next_step(state.progression, state.settlement)
	if step.get("id") == "relics_taken":
		assert_false("ask her" in MainQuest.hint(state.progression, state.settlement, "elder"))
	for chapter: Dictionary in MainQuest._doc()["chapters"]:
		for each: Dictionary in chapter["steps"]:
			if "Maren" in String(each["hint"]):
				assert_false(each.get("elderHint", "").contains("Maren"), "%s: Maren in her own words" % each["id"])
			assert_false(String(each["hint"]).begins_with("Bring them to me"), "%s: the mayor never speaks as Maren" % each["id"])


func test_the_towns_goals_offer_no_floor_behind_a_barred_gate() -> void:
	for age: Dictionary in Town._data()["tiers"]:
		for need: Dictionary in age.get("requires", []):
			if need["kind"] == "relics":
				assert_false("floor" in String(need["line"]).to_lower() or "clear the" in String(need["line"]), "age %d" % age["tier"])
	assert_eq(Quests.by_id("maren_relics")["name"], "Relics of the Five", "four relics, the five's")


func test_the_trades_point_at_their_stalls_in_the_ashes() -> void:
	assert_string_contains(Economy.station_hint("alchemy", []), "stall")
	assert_string_contains(Economy.station_hint("alchemy", ["vexs_brewery"]), "door")
	assert_string_contains(Economy.station_hint("smithing", []), "stall")
