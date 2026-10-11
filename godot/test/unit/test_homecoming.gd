extends GutTest
## Coming Home (PIX-253 step 10, chapter 8): once the collar is off Morvax
## waits by the fountain with one question - at his forge for a hero who
## slew Fafnyr on the old mountain - and the courier's answer is the story's
## last word. "Come home." and he sits on the bench by the fountain,
## arguing with Maren a different way each day; "Stay with them." and he is
## up at his forge but for festival days. Both endings tour Hilda's forge
## (Fafnyr on her roof, or Hilda alone for a slayer) and Maren. The City is
## the age after the Night of Bells. Old saves keep their ending and City,
## and the save has no new field.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const LATE := "res://test/fixtures/web_save_late.txt"
## Morvax's forge, where step 8 put him.
const FORGE := Vector2i(8, 4)

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _next(hero: Node = null) -> String:
	var who: Node = hero if hero != null else state
	return MainQuest.next_step(who.progression, who.settlement).get("id", "")


func _reloaded(hero: Node = null) -> Node:
	var who: Node = hero if hero != null else state
	var back: Node = autofree(GameStateScript.new())
	back.apply(SaveCodec.parse_json(SaveCodec.serialize(who.to_dict()))["state"])
	return back


## A hero home from the forge (as test_bells has them): the tin found, the
## keepsakes home with their families, Maren heard out, the fifth letter in
## Morvax's hands, a Village building its Town.
func _home_from_the_forge() -> void:
	state.mark_seen(Letters.scene_id())
	state.progression.quests[Relics.quest_id()] = {"progress": 4, "done": true}
	for relic: Dictionary in Relics.all():
		state.progression.hunted.append(relic["named"])
	state.holdings.come_home(true)
	state.mark_seen(Letters.confession_id())
	state.progression.quests[Letters.fifth_quest()["id"]] = {"progress": 1, "done": true}
	state.settlement.town_tier = 2
	state.settlement.projects.assign(Town.projects_through(2))


## The morning after the Night of Bells: Fafnyr freed, the day begun.
func _after_the_night() -> void:
	_home_from_the_forge()
	state.questing.bells_dawn()
	state.questing.bells_day()


## Who stands on `map_id` now, Morvax where the story has him.
func _folk(map_id: String, festival := false, day := 0) -> Array[Dictionary]:
	var folk := Npcs.on_map(map_id, state.settlement.town_tier, state.settlement.settlers, Town.done_projects(state.settlement), Relics.gate_open(state.progression), state.progression.deepest, Letters.tin_waits(state.progression))
	return Homecoming.placed(folk, map_id, state.progression, state.settlement, festival, day)


func _morvax_on(map_id: String, festival := false, day := 0) -> Dictionary:
	for npc in _folk(map_id, festival, day):
		if npc["id"] == Homecoming.MORVAX:
			return npc
	return {}


# ---- The question -------------------------------------------------------------

func test_after_the_collar_morvax_waits_by_the_fountain_with_his_question() -> void:
	_after_the_night()
	assert_eq(_next(), "morvax_choice")
	assert_true(Homecoming.choice_due(state.progression, state.settlement))
	assert_eq(Homecoming.chosen(state.progression), "", "not answered yet")
	var morvax := _morvax_on("town")
	assert_eq([int(morvax.get("x", -1)), int(morvax.get("y", -1))], [Homecoming.bench().x, Homecoming.bench().y], "by the fountain")
	assert_false(morvax.get("bench", true), "standing, not on a bench of his own yet")
	assert_eq(morvax["lines"], Homecoming.data()["ask"], "his question")
	assert_string_ends_with(String(morvax["lines"][-1]), "Do they want me back?")
	assert_true(_morvax_on("morvax_forge").is_empty(), "he came down for the collar: not up at his forge too")
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"], lead["who"]], ["town", Homecoming.bench(), Homecoming.MORVAX], "the arrow leads to him")
	assert_true(Bearing.tells_story(lead), "in gold")
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 8, "Coming Home's card")
	assert_eq(MainQuest.continued(state.progression, state.settlement), "", "no honest card: the story is written")
	var back := _reloaded()
	assert_true(Homecoming.choice_due(back.progression, back.settlement), "a save keeps him waiting")


## The courier's answer: the two endings, both open, under the chapter's name.
func test_the_choice_is_the_couriers_last_word() -> void:
	var screen = autofree(preload("res://scripts/throne_screen.gd").new())
	var rows: Array[Dictionary] = screen._rows()
	assert_eq(rows.map(func(row: Dictionary) -> String: return row["label"]), ["Come home.", "Stay with them."])
	assert_true(rows.all(func(row: Dictionary) -> bool: return row["enabled"]), "both always open")
	assert_eq(screen._title(), "Coming Home")
	assert_eq(Homecoming.choices().map(func(entry: Dictionary) -> String: return entry["id"]), [Homecoming.HOME, Homecoming.STAY])
	assert_eq(MainQuest.steps()[-1]["id"], "morvax_choice", "the story's last step")


# ---- Come home ----------------------------------------------------------------

func test_come_home_and_he_sits_on_his_bench_by_the_fountain() -> void:
	_after_the_night()
	var fields: Array = state.to_dict().keys()
	var fifth := Letters.fifth_quest()
	assert_eq(Homecoming.answered(fifth, state.progression), fifth["answered"], "the satchel: he stayed on his mountain, so far")
	state.mark_seen(Story.ending_scene(Homecoming.HOME))
	assert_eq(Homecoming.answered(fifth, state.progression), "Morvax read it twice, and came home.", "and now how it came out")
	var wenna := Quests.by_id("letter_wenna")
	assert_eq(Homecoming.answered(wenna, state.progression), wenna["answered"], "the other letters as they were")
	assert_eq(Homecoming.chosen(state.progression), Homecoming.HOME)
	assert_eq(_next(), "", "his choice made, the story is told")
	assert_eq(MainQuest.hint(state.progression, state.settlement), "Pixelheim is safe. The mountain is quiet, and the tavern isn't.")
	assert_false(Homecoming.choice_due(state.progression, state.settlement))
	var morvax := _morvax_on("town")
	assert_eq([int(morvax["x"]), int(morvax["y"]), morvax["bench"]], [Homecoming.bench().x, Homecoming.bench().y, true], "on his bench")
	assert_true(_morvax_on("morvax_forge").is_empty(), "his forge stands empty")
	# Their argument: a pair a day, his side and hers, in turn.
	var pairs: Array = Homecoming.data()["argument"]
	assert_gt(pairs.size(), 2)
	for day in pairs.size():
		assert_eq(_morvax_on("town", false, day)["lines"][0], pairs[day][0], "day %d: his side" % day)
		assert_eq(Homecoming.maren_word(state.progression, day), pairs[day][1], "day %d: hers" % day)
	assert_ne(_morvax_on("town", false, 0)["lines"][0], _morvax_on("town", false, 1)["lines"][0], "a new one each day")
	assert_eq(Homecoming.argument(pairs.size()), Homecoming.argument(0), "then round again")
	var back := _reloaded()
	assert_eq(Homecoming.chosen(back.progression), Homecoming.HOME, "the story ledger keeps it")
	assert_eq(back.to_dict().keys(), fields, "no new save field")


# ---- Stay with them -----------------------------------------------------------

func test_stay_with_them_and_he_comes_down_on_festival_days() -> void:
	_after_the_night()
	state.mark_seen(Story.ending_scene(Homecoming.STAY))
	assert_eq(Homecoming.chosen(state.progression), Homecoming.STAY)
	assert_eq(_next(), "")
	var up := _morvax_on("morvax_forge")
	assert_eq([int(up["x"]), int(up["y"])], [FORGE.x, FORGE.y], "back up at his forge")
	assert_eq(up["lines"], Homecoming.data()["peace"], "at peace")
	assert_true(_morvax_on("town").is_empty(), "not in town on an ordinary day")
	var down := _morvax_on("town", true)
	assert_eq([int(down["x"]), int(down["y"]), down["bench"]], [Homecoming.bench().x, Homecoming.bench().y, true], "on his bench on a festival day")
	assert_eq(down["lines"], Homecoming.data()["festival"])
	assert_true(_morvax_on("morvax_forge", true).is_empty(), "and not up there that day")
	assert_eq(Homecoming.maren_word(state.progression, 0), Homecoming.data()["marenStay"])


# ---- The endings' tour --------------------------------------------------------

func test_the_endings_stop_at_hildas_forge_and_at_maren() -> void:
	_after_the_night()
	var forge := Homecoming.forge_words(state.progression, state.settlement)
	assert_string_contains(forge["line"], "Fafnyr warms his belly on Hilda's new forge")
	assert_eq(forge["detail"], "Hilda pays him a cheese wheel a day. Bram calls it the cheese's finest hour.")
	var ruin: Array = Town.project("hildas_forge")["ruins"][0]["rect"]
	var roof := Rect2i(int(ruin[0]), int(ruin[1]), int(ruin[2]) - int(ruin[0]) + 1, int(ruin[3]) - int(ruin[1]) + 1)
	assert_true(roof.has_point(Homecoming.dragon_cell()), "Fafnyr lies on Hilda's forge")
	assert_string_contains(Homecoming.maren_line(), "You're one of ours now.")
	assert_string_contains(Homecoming.reply(Homecoming.HOME), "stew")
	assert_eq(Homecoming.reply_at(Homecoming.HOME), Homecoming.bench(), "at his bench, coming home")
	assert_eq(Homecoming.reply_at(Homecoming.STAY), Vector2i(40, 4), "at the town's gate, going back up")
	# Maren's own last words are for the old throne's endings: his choice
	# leaves her the day's argument.
	for entry: Dictionary in Story._data()["elderLines"]:
		assert_false(String(entry.get("ending", "")) in [Homecoming.HOME, Homecoming.STAY], "%s: not for his choice" % entry["id"])


# ---- The City -----------------------------------------------------------------

func _city_blocked(hero: Node = null) -> bool:
	var who: Node = hero if hero != null else state
	var line: String = Town.age(4)["requires"][0]["line"]
	return line in Town.age_blockers(4, who.progression, who.settlement)


func test_the_city_is_the_age_after_the_night_of_bells() -> void:
	assert_eq(Town.age(4)["requires"].map(func(need: Dictionary) -> String: return need["kind"]), ["freed"])
	_home_from_the_forge()
	assert_true(_city_blocked(), "not before the night")
	# The fountain the Town's last project: the scale finishes it, and the
	# City stands open on the board.
	state.settlement.projects.assign(Town.projects_through(2) + ["slate_hall", "moss_cottage"])
	state.questing.bells_dawn()
	assert_false(_city_blocked(), "the dragon freed")
	assert_eq(state.settlement.town_tier, 3)
	assert_has(state.reveals, "opens:4", "the tour ends at the board: a City now")
	assert_eq(Town.project_blocker("grand_avenue", state.progression, state.settlement, 99999, {"ember_shard": 99}), "")


func test_a_dragon_slayer_and_an_old_save_have_their_city() -> void:
	state.progression.cleared_levels.assign(range(1, 11))
	assert_false(_city_blocked(), "Fafnyr slain on the old mountain: no night to wait for")
	var old: Node = autofree(GameStateScript.new())
	old.new_game("Ada", "mage")
	old.progression.cleared_levels.assign(range(1, 16))
	assert_false(_city_blocked(old), "Morvax cast down: the old floor 15")


# ---- Old saves ----------------------------------------------------------------

## A hero who saw the old game's ending keeps it: his choice met, nobody
## asks, Morvax where step 8 left him, Maren her old last words.
func test_an_old_ending_is_kept() -> void:
	state.progression.cleared_levels.assign(range(1, 16))
	state.mark_seen("ending")
	assert_eq(_next(), "")
	assert_eq(Story.ending_of(state.progression.story_seen), "destroy")
	assert_eq(Homecoming.chosen(state.progression), "", "not one of his two")
	assert_false(Homecoming.choice_due(state.progression, state.settlement))
	assert_true(_morvax_on("town").is_empty())
	assert_eq(Homecoming.maren_word(state.progression, 0), "")
	assert_false(_city_blocked())


## The late web hero who cast Morvax down on the old mountain: the story
## told, the City theirs to build, nobody asking.
func test_the_late_web_hero_is_never_asked() -> void:
	var late := SaveCodec.decode_code(FileAccess.get_file_as_string(LATE))
	state.apply(late.duplicate(true))
	assert_eq(_next(), "", "their story is told")
	assert_false(Homecoming.choice_due(state.progression, state.settlement))
	assert_eq(Homecoming.chosen(state.progression), "")
	assert_false(_city_blocked(), "the City asks nothing more of them")
	assert_eq(state.settlement.town_tier, int(late["townTier"]), "their town as it was")
	assert_eq(state.to_dict().keys(), late.keys(), "its fields, no more")


## A hero who slew Fafnyr on the old mountain never had the night: the
## letter read to a quiet mountain, Morvax asks at his forge, and Hilda
## lights her forge alone.
func test_a_dragon_slayer_is_asked_at_morvaxs_forge() -> void:
	state.progression.cleared_levels.assign(range(1, 11))
	state.mark_seen(Letters.scene_id())
	state.questing.finish_dialogue("elder")
	state.questing.finish_dialogue("mountain_morvax")
	assert_eq(_next(), "morvax_choice")
	assert_true(Homecoming.choice_due(state.progression, state.settlement))
	assert_false(Bells.over(state.progression), "no night, no collar")
	var morvax := _morvax_on("morvax_forge")
	assert_eq([int(morvax["x"]), int(morvax["y"])], [FORGE.x, FORGE.y], "asked where he is")
	assert_eq(morvax["lines"], Homecoming.data()["ask"])
	assert_true(_morvax_on("town").is_empty())
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"]], ["morvax_forge", FORGE])
	var forge := Homecoming.forge_words(state.progression, state.settlement)
	assert_false("Fafnyr" in String(forge["line"]) + String(forge["detail"]), "no Fafnyr on Hilda's forge for them")
	assert_string_contains(forge["line"], "Hilda lights her new forge herself")
	state.mark_seen(Story.ending_scene(Homecoming.HOME))
	assert_eq(_next(), "")
	assert_false(_morvax_on("town").is_empty(), "and home he comes")


## Morvax has a face of his own beside Maren: Shade drew one old man.
func test_morvax_has_a_face_of_his_own_beside_maren() -> void:
	assert_ne(Npcs.tint_of(Homecoming.MORVAX), Npcs.tint_of("elder"))
