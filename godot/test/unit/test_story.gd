extends GutTest
## The Ember Seal (PIX-153): Maren tells each of her stories once, and none
## of them waits on the old mountain's floors; her confession at the shrine;
## the dreams at the inn.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


## Her stories of the old mountain's floors left play with them (PIX-257),
## and her last words after the old throne with the old saves (PIX-319):
## her confession waits for the shrine, the four keepsakes home (PIX-253
## step 8: Letters.fifth_due), never a floor.
func test_the_floors_earn_no_story_now() -> void:
	assert_eq(Story.elder_story([]), {})
	var told: Array = Story._data()["elderLines"].map(func(entry: Dictionary) -> String: return entry["id"])
	for gone: String in ["maren_graves", "maren_seal", "maren_peace", "maren_after"]:
		assert_does_not_have(told, gone, "out of play")
	assert_has(told, "maren_confession", "the confession stays, rewritten")
	for entry: Dictionary in Story._data()["elderLines"]:
		assert_false(entry.has("after") or entry.has("ending"), "%s waits on no floor and no old ending" % entry["id"])


## PIX-253 step 8: Maren tells it all - the gold, the lie to the dragon,
## the roof, the rockfall she made up - and her old line about the stair is
## gone.
func test_the_confession_tells_it_all() -> void:
	var lines := " ".join(Letters.confession_lines())
	for words: String in ["kings' gold", "freedom for the hoard", "held up the roof", "rockfall", "Two old fools and a mountain", "It has an address now"]:
		assert_string_contains(lines, words)
	assert_false(lines.contains("Go down and end it"), "nobody is sent down any more")
	assert_true(Letters.fifth_due(_at_the_shrine().progression, _at_the_shrine().settlement), "told at the shrine, the four keepsakes home")


func _at_the_shrine() -> Node:
	var hero: Node = autofree(GameStateScript.new())
	hero.new_game("Robin", "warrior")
	hero.progression.quests[Relics.quest_id()] = {"progress": 4, "done": true}
	return hero


## Dreams at the inn (PIX-154): one per night's rest, in the order earned.
## The two the old mountain's floors earned left play with them (PIX-257).
func test_dreams_come_in_order_once_each() -> void:
	assert_eq(Story.next_dream([]), "dream_courier", "the first night after the fire")
	assert_eq(Story.next_dream(["dream_courier"]), "", "nothing more until someone comes home")
	assert_eq(Story.next_dream(["dream_courier"], ["mines_pell"]), "dream_lamps")
	assert_eq(Story.next_dream(["dream_courier", "dream_lamps"], ["mines_pell", "frost_aske"]), "dream_corners")
	for dream: Dictionary in Story._data()["dreams"]:
		assert_true(Cutscene.scenes().has(dream["id"]), "%s is a scene" % dream["id"])
		assert_false(dream.has("after"), "%s waits on no floor" % dream["id"])


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


## The story's big moments (PIX-32): each names a scene that exists. The
## old floors' own (a boss's intro, a floor's first clear) left play with
## them (PIX-257), and the old throne's endings with the old saves (PIX-319).
func test_every_moment_plays_a_scene_that_exists() -> void:
	for key: String in ["ending:home", "ending:stay"]:
		var scene_id := Story._moment(key)
		assert_ne(scene_id, "", "%s has a moment" % key)
		assert_true(Cutscene.scenes().has(scene_id), "%s plays %s" % [key, scene_id])
	for key: String in ["boss:dragon", "boss:lich", "cleared:3", "cleared:7", "cleared:10", "victory", "victory:rest"]:
		assert_eq(Story._moment(key), "", "%s left play" % key)
