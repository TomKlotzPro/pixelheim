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


## Liane's pages retired from play with Maren's letters (PIX-253 step 2): a
## first clear no longer says it turned one up, but the floors a hero has
## cleared still keep theirs, for the journal's older papers.
func test_ten_pages_one_per_floor_kept_for_the_floors_cleared() -> void:
	assert_eq(Story.lore().size(), 10)
	var floors := Story.lore().map(func(page: Dictionary) -> int: return int(page["floor"]))
	assert_eq(floors, [1, 3, 4, 5, 7, 9, 11, 12, 13, 14])
	var lines: Array = state.spoils.clear_floor(1)["lines"]
	assert_false(lines.any(func(line: String) -> bool: return line.contains("Page I") or line.contains("journal")), "a clear says nothing of a page")
	assert_eq(Story.found_pages(state.progression.cleared_levels).size(), 1)


## Her stories of the old mountain's floors left play with them (PIX-257):
## a hero who cleared them hears none of the graves or the seal now, and
## her confession waits for the shrine, the four keepsakes home (PIX-253
## step 8: Letters.fifth_due), never a floor.
func test_the_floors_earn_no_story_now() -> void:
	assert_eq(Story.elder_story([], []), {})
	assert_eq(Story.elder_story(range(1, 11), []), {}, "no graves, no seal, no confession for a floor")
	var told: Array = Story._data()["elderLines"].map(func(entry: Dictionary) -> String: return entry["id"])
	assert_false(told.has("maren_graves") or told.has("maren_seal"), "out of play: %s" % [told])
	assert_has(told, "maren_confession", "the confession stays, rewritten")
	for entry: Dictionary in Story._data()["elderLines"]:
		if entry.has("after"):
			assert_eq(int(entry["after"]), 15, "%s: only the old endings' last words wait on a floor" % entry["id"])


## PIX-253 step 8: Maren tells it all - the gold, the lie to the dragon,
## the roof, the rockfall she made up - and her old line about the stair is
## gone.
func test_the_confession_tells_it_all() -> void:
	var lines := " ".join(Letters.confession_lines())
	for words: String in ["kings' gold", "freedom for the hoard", "held up the roof", "rockfall", "Two old fools and a mountain", "It has an address now"]:
		assert_string_contains(lines, words)
	assert_false(lines.contains("Go down and end it"), "nobody is sent down any more")
	assert_eq(Letters.confession_lines(), Letters.fifth_lines(_at_the_shrine().progression, _at_the_shrine().settlement))


func _at_the_shrine() -> Node:
	var hero: Node = autofree(GameStateScript.new())
	hero.new_game("Robin", "warrior")
	hero.progression.quests[Relics.quest_id()] = {"progress": 4, "done": true}
	return hero


## Once the hero has ended it, only her last words are left to tell: the
## stories that sent the hero down would ring false (PIX-279).
func test_after_the_ending_she_speaks_only_of_it() -> void:
	var all_floors := range(1, 16)
	assert_eq(Story.elder_story(all_floors, ["ending"])["id"], "maren_after")
	assert_eq(Story.elder_story(all_floors, ["ending", "maren_after"]), {}, "the confession never follows Morvax's end")


## Dreams at the inn (PIX-154): one per night's rest, in the order earned.
## The two the old mountain's floors earned left play with them (PIX-257).
func test_dreams_come_in_order_once_each() -> void:
	assert_eq(Story.next_dream([], []), "dream_courier", "the first night after the fire")
	assert_eq(Story.next_dream([], ["dream_courier"]), "", "nothing more until someone comes home")
	assert_eq(Story.next_dream(range(1, 11), ["dream_courier"]), "", "no floor brings one now")
	assert_eq(Story.next_dream([], ["dream_courier"], ["mines_pell"]), "dream_lamps")
	assert_eq(Story.next_dream([], ["dream_courier", "dream_lamps"], ["mines_pell", "frost_aske"]), "dream_corners")
	for dream: Dictionary in Story._data()["dreams"]:
		assert_true(Cutscene.scenes().has(dream["id"]), "%s is a scene" % dream["id"])
		assert_false(dream.has("after") and int(dream["after"]) > 0, "%s waits on no floor" % dream["id"])


## The first dream is Morvax's voice (PIX-253 step 8): the old man by his
## lamp up the mountain, the same as the second dream's, and no purple eyes.
func test_the_first_dream_is_morvaxs_voice() -> void:
	var steps: Array = Cutscene.scenes()["dream_courier"]
	assert_false(steps.any(func(step: Dictionary) -> bool: return step["kind"] == "eyes"), "no purple eyes")
	var actors := steps.filter(func(step: Dictionary) -> bool: return step["kind"] == "actor")
	var lamps := (Cutscene.scenes()["dream_lamps"] as Array).filter(func(step: Dictionary) -> bool: return step["kind"] == "actor")
	assert_eq(actors.size(), 1)
	assert_eq(actors[0]["sheet"], lamps[0]["sheet"], "the old man at the forge")
	assert_true(steps.any(func(step: Dictionary) -> bool: return String(step.get("text", "")).contains("You're late, courier. Fifty years late.")))
	assert_false(JSON.stringify(steps).contains("down and down"), "no stair going down")
