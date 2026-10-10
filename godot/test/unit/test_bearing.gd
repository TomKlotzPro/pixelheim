extends GutTest
## Where the hero is headed (PIX-239, PIX-240): the main story's next step,
## or a side quest the hero follows, each with its place, a spot to point at
## and how far along it is, and the line above the dock that says it.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _lead() -> Dictionary:
	return Bearing.active(state.progression, state.settlement, state.pack.items)


func test_a_new_hero_is_sent_to_maren_then_sela() -> void:
	# Maren's tin first (PIX-253), in the ashes of her house.
	var dig := _lead()
	assert_eq(dig["step"], "Help Maren dig through what's left of her house")
	assert_eq([dig["map_id"], dig["cell"], dig["who"]], ["town", Letters.dig_spot([]), "elder"])
	state.questing.finish_dialogue("elder")
	var lead := _lead()
	assert_true(lead["main"], "the main story leads")
	assert_eq(lead["step"], "Ask Sela the innkeeper for work")
	var sela := Npcs.by_id("innkeeper", state.settlement.settlers)
	assert_eq(lead["map_id"], sela["mapId"], "to where Sela is")
	assert_eq(lead["cell"], Vector2i(int(sela["x"]), int(sela["y"])))
	assert_ne(lead["place"], "", "and the place is named")


func test_the_slimes_lead_to_their_fields_and_count() -> void:
	state.questing.resolve_quests("innkeeper")
	var lead := _lead()
	assert_eq(lead["quest_id"], "slime_trouble", "the step waits on the slimes")
	var home := Bestiary.home_of("slime")
	assert_false(home.is_empty(), "slimes live somewhere")
	assert_eq(lead["map_id"], home["mapId"])
	assert_eq(lead["progress"], "0/3")
	assert_string_contains(Bearing.line(lead), "(0/3)")


func test_a_followed_quest_leads_and_then_says_to_hand_it_in() -> void:
	state.questing.resolve_quests("alchemist_vex")
	state.progression.tracked = "herbs_for_vex"
	var lead := _lead()
	assert_false(lead["main"], "the followed quest leads, not the story")
	assert_eq(lead["title"], "A First Brew")
	assert_eq(lead["map_id"], "town_alchemist", "to Vex's cauldron")
	state.progression.quests["herbs_for_vex"]["progress"] = 1
	lead = _lead()
	assert_string_contains(lead["step"], "Hand it in to")
	var vex := Npcs.by_id("alchemist_vex", state.settlement.settlers)
	assert_eq(lead["cell"], Vector2i(int(vex["x"]), int(vex["y"])), "to Vex herself")


func test_a_followed_quest_done_hands_back_to_the_story() -> void:
	state.progression.tracked = "herbs_for_vex"
	assert_true(_lead()["main"], "not taken yet: the story leads")
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	assert_true(_lead()["main"], "done: the story leads again")


func test_a_floor_to_clear_leads_to_the_mountains_gate() -> void:
	var gate := Bearing.gate_of("mountain")
	assert_eq(gate["mapId"], "overworld")
	var floors: Array = Dungeons.dungeon("mountain")["floors"]
	var step := {"text": "Climb", "when": {"kind": "cleared", "level": int(floors[0])}}
	var lead := Bearing.of_step(step, state.progression, state.settlement, state.pack.items)
	assert_eq(lead["map_id"], "overworld")
	assert_eq(lead["cell"], gate["cell"])


func test_the_line_names_the_place_once() -> void:
	var lead := {"step": "Ask Sela the innkeeper for work", "place": "Pixelheim", "progress": ""}
	assert_eq(Bearing.line(lead), "Ask Sela the innkeeper for work - Pixelheim")
	lead["step"] = "Go back to Pixelheim"
	assert_eq(Bearing.line(lead), "Go back to Pixelheim", "a place the step names isn't said twice")


func test_the_followed_quest_is_saved_only_while_there_is_one() -> void:
	var before := {}
	state.progression.write_into(before)
	assert_false(before.has("tracked"))
	state.progression.tracked = "herbs_for_vex"
	var after := {}
	state.progression.write_into(after)
	assert_eq(ProgressionState.from_dict(after).tracked, "herbs_for_vex")


func test_the_way_out_starts_at_the_right_door() -> void:
	assert_eq(Bearing.way_out("town", "town"), Bearing.NOWHERE, "no need on the same map")
	var to_vex := Bearing.way_out("town", "town_alchemist")
	assert_ne(to_vex, Bearing.NOWHERE, "the brewery's door in town")
	assert_eq(MapData.load_by_id("town").portals[to_vex]["mapId"], "town_alchemist")
	var to_town := Bearing.way_out("town_alchemist", "town")
	assert_eq(MapData.load_by_id("town_alchemist").portals[to_town]["mapId"], "town")
	# From inside Vex's to the ice cave: out to town first.
	var far := Bearing.way_out("town_alchemist", "icecave")
	assert_ne(far, Bearing.NOWHERE, "a way exists")
	assert_eq(MapData.load_by_id("town_alchemist").portals[far]["mapId"], "town", "and starts out the door")
