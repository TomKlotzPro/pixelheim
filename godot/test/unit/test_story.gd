extends GutTest
## The Ember Seal on the floors (PIX-153): the story's moments name scenes
## that exist, a page of Liane's journal waits on ten floors, and Maren tells
## each of her stories once, when the hero's floors have earned it.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_the_floors_moments_play_scenes_that_exist() -> void:
	for key: String in ["cleared:3", "cleared:7", "cleared:10"]:
		assert_true(Cutscene.scenes().has(Cutscene.moment(key)), key)
	var descent: Array = Cutscene.scenes()["descent"]
	assert_true(descent.any(func(step: Dictionary) -> bool: return String(step.get("sub", "")).contains("lied")), "Fafnyr's last words")


func test_ten_pages_one_per_floor_found_on_first_clears() -> void:
	assert_eq(Story.lore().size(), 10)
	var floors := Story.lore().map(func(page: Dictionary) -> int: return int(page["floor"]))
	assert_eq(floors, [1, 3, 4, 5, 7, 9, 11, 12, 13, 14])
	var lines: Array = state.spoils.clear_floor(1)["lines"]
	assert_true(lines.any(func(line: String) -> bool: return line.contains("Page I")))
	assert_eq(Story.found_pages(state.progression.cleared_levels).size(), 1)


func test_maren_tells_each_story_once_and_the_deepest_first() -> void:
	assert_eq(Story.elder_story([], []), {}, "nothing before the crypt")
	assert_eq(Story.elder_story([1, 2, 3], [])["id"], "maren_graves")
	assert_eq(Story.elder_story([1, 2, 3], ["maren_graves"]), {}, "told once")
	assert_eq(Story.elder_story(range(1, 11), ["maren_graves"])["id"], "maren_confession")
	assert_string_contains(Story.elder_story(range(1, 11), [])["lines"][2], "rockfall")


func test_the_main_quest_asks_for_her_stories_on_the_side() -> void:
	state.progression.unlocked_level = 3
	state.spoils.clear_floor(3)
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["id"], "graves")
	state.mark_seen("maren_graves")
	assert_ne(MainQuest.next_step(state.progression, state.settlement)["id"], "graves")


## Dreams at the inn (PIX-154): one per night's rest, in the order earned.
func test_dreams_come_in_order_once_each() -> void:
	assert_eq(Story.next_dream([], []), "dream_courier", "the first night after the fire")
	assert_eq(Story.next_dream([], ["dream_courier"]), "", "nothing more until the crypt")
	assert_eq(Story.next_dream([1, 2, 3], ["dream_courier"]), "dream_five")
	assert_eq(Story.next_dream(range(1, 8), ["dream_courier"]), "dream_five", "earliest first")
	assert_eq(Story.next_dream(range(1, 8), ["dream_courier", "dream_five"]), "dream_door")
	for dream: Dictionary in Story._data()["dreams"]:
		assert_true(Cutscene.scenes().has(dream["id"]), "%s is a scene" % dream["id"])
