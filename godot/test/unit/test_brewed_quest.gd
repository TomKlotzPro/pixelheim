extends GutTest
## A brewed potion finishes Vex's quest (PIX-231): a brew made before the
## quest was taken counts once it's taken, a brew made after says in the log
## that it's ready to hand in, and what the hero has made is saved only once
## there is something.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const QUEST := "herbs_for_vex"
const VEX := "alchemist_vex"

var state: Node
var noted: Array = []


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.world.map_id = "town_alchemist"
	# Never a double brew: one potion each time.
	state.roll = func() -> float: return 0.99
	noted.clear()
	state.noted.connect(func(lines: Array) -> void: noted.append_array(lines))


func _brew() -> void:
	state.pack.add_item("forest_herb")
	state.pack.add_item("marsh_reed")
	assert_true(state.trade.craft("brew_potion_hp")["made"], "brewed at Vex's cauldron")


func test_a_brew_before_the_quest_counts_once_it_is_taken() -> void:
	_brew()
	var accepted: String = state.questing.resolve_quests(VEX)
	assert_string_contains(accepted, "Quest accepted")
	assert_eq(int(state.progression.quests[QUEST]["progress"]), 1, "the potion already brewed counts")
	assert_true(Quests.is_ready(Quests.by_id(QUEST), state.progression.quests, state.pack.items))
	assert_true(noted.any(func(line: String) -> bool: return "ready to hand in" in line), "the log says so")
	var gold_before: int = state.pack.gold
	state.questing.resolve_quests(VEX)
	assert_true(state.progression.quests[QUEST]["done"], "handed in")
	assert_eq(state.pack.gold, gold_before + int(Quests.by_id(QUEST)["reward"]["gold"]))


func test_a_brew_after_the_quest_says_it_is_ready() -> void:
	state.questing.resolve_quests(VEX)
	assert_eq(int(state.progression.quests[QUEST]["progress"]), 0, "nothing brewed yet")
	noted.clear()
	_brew()
	assert_eq(int(state.progression.quests[QUEST]["progress"]), 1)
	assert_true(noted.any(func(line: String) -> bool: return "A First Brew: ready to hand in to" in line), "the brew is announced: %s" % [noted])


func test_what_was_made_is_saved_only_once_there_is_some() -> void:
	var before := {}
	state.progression.write_into(before)
	assert_false(before.has("crafted"), "a hero who never crafted saves as before")
	_brew()
	_brew()
	var after := {}
	state.progression.write_into(after)
	assert_eq(after["crafted"], {"potion_hp": 2})
	var loaded := ProgressionState.from_dict(after)
	assert_eq(loaded.crafted, {"potion_hp": 2}, "and it loads back")


func test_a_brew_away_from_the_cauldron_counts_nothing() -> void:
	state.world.map_id = "town"
	state.pack.add_item("forest_herb")
	state.pack.add_item("marsh_reed")
	assert_false(state.trade.craft("brew_potion_hp")["made"])
	assert_true(state.progression.crafted.is_empty())
