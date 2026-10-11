extends GutTest
## Maren's letters (PIX-253 step 1, the main story's new beginning): the
## opening and the dawn say what v2 says; under her hearthstone the courier
## finds a tin of five letters, four go out across the Reach in the story's
## order and are answered as they're handed over, the fifth stays with her;
## the main quest is eight chapters with the relics required and in turn;
## and a hero from before is never sent back for a letter.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const RECIPIENTS := {
	"letter_wenna": "saltmere_wenna", "letter_pell": "mines_pell", "letter_hale": "greyhold_ulla", "letter_aske": "frost_aske",
}

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _next() -> String:
	return MainQuest.next_step(state.progression, state.settlement).get("id", "")


func _step(step_id: String) -> Dictionary:
	return MainQuest.step(step_id)


func _met(step_id: String) -> bool:
	return MainQuest.is_met(_step(step_id), state.progression, state.settlement)


func _win(named_id: String) -> void:
	state.spoils.defeat_monster(Hunts.fighter(named_id), Hunts.named(named_id)["mapId"], "", 10)


func _letters_carried() -> Array:
	return Letters.all().filter(func(quest: Dictionary) -> bool: return int(state.pack.items.get(quest["objective"]["itemId"], 0)) > 0) \
		.map(func(quest: Dictionary) -> String: return quest["id"])


# ---- The opening and the dawn ---------------------------------------------------

func test_the_opening_says_v2s_captions_in_order_and_holds_each_to_be_read() -> void:
	var captions: Array = Cutscene.scenes()["opening"].filter(func(step: Dictionary) -> bool: return step["kind"] == "caption")
	assert_eq(captions.map(func(step: Dictionary) -> String: return step["text"]), [
		"Pixelheim. A village under a mountain, and glad of it.",
		"On top of the mountain a dragon sleeps on a chain. Everyone agrees this is the best place for him.",
		"Fifty years ago five of the village climbed up to keep it that way. Only one came home, and she never talked about it.",
		"Tonight, the dragon woke up.",
	])
	for step: Dictionary in captions:
		assert_gte(float(step["hold"]), UiStyle.reading_seconds(String(step["text"])), "long enough to read: %s" % step["text"])


func test_the_opening_no_longer_burns_the_village_nor_whispers_from_below() -> void:
	var opening: Array = Cutscene.scenes()["opening"]
	assert_false(opening.any(func(step: Dictionary) -> bool: return step["kind"] == "eyes"), "no purple eyes")
	for step: Dictionary in opening:
		var text := String(step.get("text", ""))
		assert_false("burned" in text or "below" in text, "the fire is played, not told: %s" % text)
	var climbing := opening.filter(func(step: Dictionary) -> bool: return step["kind"] == "actor" and step.get("anim") == "walk" and String(step["sheet"]).begins_with("characters/"))
	assert_eq(climbing.size(), 5, "five climb")
	var fallen := opening.filter(func(step: Dictionary) -> bool: return step["kind"] == "actor" and step.get("anim") == "death")
	assert_eq(fallen.size(), 3, "three fall")


func test_maren_asked_the_crown_for_soldiers_fifty_years_ago_too() -> void:
	var lines: Array = Npcs.by_id("elder", [])["prologue"]["lines"]
	assert_true(lines.any(func(line: String) -> bool: return "Then no one is coming. Again. Fifty years ago I asked the Crown for soldiers too." in line))


func test_the_dawn_ends_on_the_tagline_before_the_card() -> void:
	var last: Dictionary = Prologue.dawn()[-1]
	assert_true(last.get("tagline", false))
	assert_eq(String(last["line"]), "The Chancellor's courier should have ridden south by noon. You stayed.")
	assert_eq(String(last["who"]), "", "told, not said by anyone on the square")


# ---- The tin ---------------------------------------------------------------------

func test_the_tin_waits_once_the_night_is_over() -> void:
	assert_true(Letters.tin_waits(state.progression))
	state.progression.prologue = Prologue.MAREN
	assert_false(Letters.tin_waits(state.progression), "not on the Night of Ash")
	state.progression.prologue = Prologue.DONE
	assert_eq(_next(), "tin", "a new hero's first step")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Help Maren dig through what's left of her house")


func test_maren_digs_in_front_of_her_house_while_it_is_ash() -> void:
	var house := Town.ruins([]).filter(func(ruin: Dictionary) -> bool: return ruin["home"] == "elder")
	assert_eq(house.size(), 1, "her house is one of the inn's ruins")
	var dig := Letters.dig_spot([])
	assert_true(MapData.load_tiered("town", [], 1).is_walkable(dig), "she stands on open ground")
	var rect: Rect2i = house[0]["rect"]
	assert_true(rect.grow(1).has_point(dig), "right in front of it")
	var elder := func(tin: bool, done: Array) -> Dictionary:
		return Npcs.on_map("town", 0, [], done, false, 0, tin).filter(func(npc: Dictionary) -> bool: return npc["id"] == "elder")[0]
	assert_eq(Vector2i(elder.call(true, [])["x"], elder.call(true, [])["y"]), dig)
	assert_eq(Vector2i(elder.call(false, [])["x"], elder.call(false, [])["y"]), Vector2i(12, 6), "at the shrine once it's found")
	assert_eq(Letters.dig_spot(["the_inn"]), Vector2i(-1, -1), "rebuilt with the inn")
	assert_eq(Vector2i(elder.call(true, ["the_inn"])["x"], elder.call(true, ["the_inn"])["y"]), Vector2i(12, 6))
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["map_id"], lead["cell"], lead["who"]], ["town", dig, "elder"], "the story points at her")


func test_the_tin_gives_four_letters_and_the_step_is_met() -> void:
	assert_eq(Letters.tin_lines([]), Quests._data()["letters"]["tin"], "the dig, while her house is ash")
	var said: Array[String] = []
	state.message.connect(func(text: String) -> void: said.append(text))
	state.questing.finish_dialogue("elder")
	assert_eq(_letters_carried(), ["letter_wenna", "letter_pell", "letter_hale", "letter_aske"])
	assert_false(state.pack.items.has("letter_morvax"), "the fifth stays with Maren")
	assert_true(_met("tin"))
	assert_false(Letters.tin_waits(state.progression))
	assert_eq(said.size(), 1)
	assert_string_contains(said[0], "Four letters in your satchel")
	assert_string_contains(said[0], "cliff road", "Bram's crew clears the road to Saltmere")
	for quest: Dictionary in Letters.all():
		assert_eq(state.progression.quests[quest["id"]], {"progress": 0, "done": false}, "%s taken" % quest["id"])
	assert_true(state.progression.quests.has(Relics.quest_id()), "her ask comes with them: the relics home")
	assert_true(_met("relics_taken"), "and the five's errands open")
	assert_eq(_next(), "ask_sela")
	# It's found once: the next word with her is a word.
	state.questing.finish_dialogue("elder")
	assert_eq(_letters_carried().size(), 4)
	assert_false("letters in your satchel" in said[-1], "nothing more from the tin")


func test_the_letters_are_the_journals_main_story() -> void:
	state.questing.finish_dialogue("elder")
	var rows: Array[Dictionary] = Journal.rows(state.progression, state.settlement, state.pack.items)
	var story := rows.filter(func(row: Dictionary) -> bool: return row["group"] == "story").map(func(row: Dictionary) -> String: return row["id"])
	for quest_id: String in RECIPIENTS:
		assert_has(story, quest_id)
	var wenna: Dictionary = rows.filter(func(row: Dictionary) -> bool: return row["id"] == "letter_wenna")[0]
	assert_eq(wenna["lead"]["who"], "saltmere_wenna", "it leads to her")
	assert_eq(wenna["lead"]["map_id"], "saltmere")
	assert_string_contains(wenna["detail"], "Old Wenna")


# ---- Delivering ------------------------------------------------------------------

func test_a_deliver_to_quest_goes_to_its_recipient_not_its_giver() -> void:
	for quest: Dictionary in Letters.all():
		var objective: Dictionary = quest["objective"]
		assert_eq(objective["kind"], "deliverTo")
		assert_eq(objective["to"], RECIPIENTS[quest["id"]])
		assert_ne(objective["to"], quest["giver"], "carried to someone else")
		assert_false(Npcs.by_id(objective["to"], []).is_empty(), "%s is someone" % objective["to"])
		assert_true(Catalog.item(objective["itemId"]).get("quest", false), "a letter isn't for sale")
		assert_eq(Catalog.item(objective["itemId"])["sprite"], "letter")
		assert_between(quest["answer"].size(), 2, 3, "two or three lines of answer")
		assert_false(Relics.all().filter(func(relic: Dictionary) -> bool: return relic["itemId"] == quest["keepsake"]).is_empty(), "its keepsake is a relic")
		assert_eq(Quests.for_recipient(objective["to"]), [quest])
	var maren := Quests.for_giver("elder").map(func(quest: Dictionary) -> String: return quest["id"])
	assert_eq(maren, ["maren_relics", "troll_toll"], "never offered in talk, never handed back to her")
	# And the fifth, to Morvax (PIX-253 step 8).
	assert_true(MainQuest.steps().filter(func(step: Dictionary) -> bool: return step["when"]["kind"] == "delivered").size() == 5)


func test_a_letter_waits_for_its_recipient_and_the_pack() -> void:
	state.questing.finish_dialogue("elder")
	assert_true(state.questing.letter_for("elder").is_empty(), "not Maren's to receive")
	assert_true(state.questing.letter_for("saltmere_brin").is_empty(), "nor anyone else's")
	assert_eq(state.questing.letter_for("saltmere_wenna")["id"], "letter_wenna")
	state.pack.remove_item("letter_wenna")
	assert_true(state.questing.letter_for("saltmere_wenna").is_empty(), "no letter, nothing to hand over")
	assert_eq(state.questing.deliver("saltmere_wenna"), "")
	assert_false(_met("letter_wenna"))


func test_each_delivery_meets_its_step_and_takes_the_letter() -> void:
	state.questing.finish_dialogue("elder")
	var gold: int = state.pack.gold
	var xp: int = state.hero.xp
	var postage := 0
	var said: Array[String] = []
	state.message.connect(func(text: String) -> void: said.append(text))
	for quest_id: String in RECIPIENTS:
		assert_false(_met(quest_id))
		state.questing.finish_dialogue(RECIPIENTS[quest_id])
		assert_true(_met(quest_id), "%s delivered" % quest_id)
		assert_eq(int(state.pack.items.get(quest_id, 0)), 0, "%s handed over" % quest_id)
		assert_true(state.progression.quests[quest_id]["done"])
		postage += int(Quests.by_id(quest_id)["reward"]["gold"])
		assert_eq(said[-1], "Delivered: %s. +%d gold." % [Quests.by_id(quest_id)["name"], Quests.by_id(quest_id)["reward"]["gold"]])
		# Once is all: the next word with them is a word.
		assert_eq(state.questing.deliver(RECIPIENTS[quest_id]), "")
	assert_eq(state.pack.gold, gold + postage, "each pays its postage, as the post was paid then")
	assert_gt(postage, 0)
	assert_eq(state.hero.xp, xp, "and no XP: the curve is retuned with the story's last step")
	assert_eq(_letters_carried(), [])


func test_a_letter_leads_to_its_recipient() -> void:
	state.questing.finish_dialogue("elder")
	state.settlement.town_tier = 1
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	assert_eq(_next(), "letter_wenna")
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq(lead["title"], "The Letter to Saltmere")
	assert_eq(Bearing.line(lead), "Deliver Maren's letter to Old Wenna in Saltmere")
	assert_eq([lead["map_id"], lead["who"]], ["saltmere", "saltmere_wenna"])
	assert_eq(Journal.chapter_title(MainQuest.next_step(state.progression, state.settlement)), "Chapter 2: The Letter to Saltmere")
	assert_string_contains(MainQuest.hint(state.progression, state.settlement, "mayor"), "Take the cliff road to Saltmere with Maren's first letter")


# ---- The quest's shape -------------------------------------------------------------

func test_the_main_quest_is_v2s_eight_chapters() -> void:
	assert_eq(MainQuest.chapters().map(func(chapter: Dictionary) -> String: return chapter["title"]), [
		"Out of the Ashes", "The Letter to Saltmere", "The Letter to Blackiron", "The Letter to Greyhold",
		"The Letter to the Frostgate", "The Fifth Letter", "The Night of Bells", "Coming Home",
	])
	for index in range(1, 5):
		assert_eq(MainQuest.chapters()[index]["steps"][0]["when"]["kind"], "delivered", "a chapter of the Reach opens on its letter")
	# The fifth letter's chapter (PIX-253 step 8): Maren heard out, then the
	# letter up the mountain road.
	assert_eq(MainQuest.chapters()[5]["steps"].map(func(step: Dictionary) -> String: return step["text"]), [
		"Hear Maren out at the shrine", "Climb the mountain road and deliver the fifth letter",
	])
	# The Night of Bells (step 9): home, then the night's three beats (§5's Next).
	assert_eq(MainQuest.chapters()[6]["steps"].map(func(step: Dictionary) -> String: return step["text"]), [
		"Run home: the dragon is awake", "Light the five lanterns on the square",
		"Drive off the embers and douse the fires", "Hold the square until dawn",
	])
	# Home, still to write (step 10), marked.
	assert_string_contains(String(MainQuest.chapters()[7].get("about", "")), "builds it", "a chapter still to write, marked")
	var first: Array = MainQuest.chapters()[0]["steps"].filter(func(step: Dictionary) -> bool: return not step.get("optional", false) or step["id"] == "rebuild")
	assert_eq(first.map(func(step: Dictionary) -> String: return step["text"]), [
		"Help Maren dig through what's left of her house", "Ask Sela the innkeeper for work",
		"Flatten three slimes in the fields east of town, then see Sela", "Put a roof back on Sela's inn",
	])


func test_the_relic_steps_are_required_and_in_the_storys_order() -> void:
	var order: Array[String] = []
	for step: Dictionary in MainQuest.steps():
		var when: Dictionary = step["when"]
		if when["kind"] == "hunted":
			assert_false(step.get("optional", false), "%s is required" % step["id"])
			order.append(String(when["named"]))
	assert_eq(order, ["tidecaller", "seam_warden", "hollow_captain", "rimefang"], "Saltmere, Blackiron, Greyhold, the Frostgate")
	var ids: Array = MainQuest.steps().map(func(step: Dictionary) -> String: return step["id"])
	for pair: Array in [["letter_wenna", "ladle"], ["ladle", "letter_pell"], ["letter_pell", "ingot"], ["ingot", "letter_hale"],
			["letter_hale", "shield"], ["shield", "letter_aske"], ["letter_aske", "lantern"], ["lantern", "gate"]]:
		assert_lt(ids.find(pair[0]), ids.find(pair[1]), "%s before %s" % pair)


func test_the_story_runs_letter_by_letter() -> void:
	state.questing.finish_dialogue("elder")
	state.settlement.town_tier = 1
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	assert_eq(_next(), "letter_wenna")
	state.questing.finish_dialogue("saltmere_wenna")
	assert_eq(_next(), "ladle")
	_win("tidecaller")
	assert_eq(_next(), "letter_pell")
	state.questing.finish_dialogue("mines_pell")
	assert_eq(_next(), "ingot")
	_win("seam_warden")
	state.settlement.settlers.append("settler_iva")
	state.settlement.projects.append("street_lamps")
	assert_eq(_next(), "letter_hale")
	state.questing.finish_dialogue("greyhold_ulla")
	assert_eq(_next(), "order_book", "Ulla sends the courier to the captain's order book (PIX-255)")
	state.mark_seen("hale_order_book")
	assert_eq(_next(), "shield")
	_win("hollow_captain")
	assert_eq(_next(), "letter_aske")
	state.questing.finish_dialogue("frost_aske")
	assert_eq(_next(), "sums", "Aske opens Liane's door to her sums (PIX-255)")
	state.mark_seen("liane_sums")
	assert_eq(_next(), "lantern")
	_win("rimefang")
	assert_eq(_next(), "gate")
	state.questing.resolve_quests("elder")
	assert_eq(_next(), "confession", "then Maren tells it all (PIX-253 step 8)")
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["chapter"], "The Fifth Letter")
	state.questing.finish_dialogue("elder")
	assert_eq(_next(), "letter_morvax", "the fifth letter, up the mountain road")
	state.questing.finish_dialogue("mountain_morvax")
	assert_eq(_next(), "run_home", "then run home")
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["chapter"], "The Night of Bells")


# ---- Old saves ---------------------------------------------------------------------

func test_an_old_save_with_relics_won_counts_their_letters_delivered() -> void:
	_win("tidecaller")
	_win("hollow_captain")
	assert_true(_met("letter_wenna"), "the ladle is home: Wenna's letter as good as delivered")
	assert_true(_met("letter_hale"))
	assert_false(_met("letter_pell"))
	state.questing.finish_dialogue("elder")
	assert_eq(_letters_carried(), ["letter_pell", "letter_aske"], "only the ones still to deliver")
	assert_false(state.progression.quests.has("letter_wenna"), "the answered stay answered")
	state.progression.quests[Relics.quest_id()] = {"progress": 4, "done": true}
	for quest: Dictionary in Letters.all():
		assert_true(Letters.delivered(quest, state.progression), "every relic home: %s" % quest["id"])


func test_an_old_save_past_the_prologue_gets_the_letters_from_maren() -> void:
	# A hero from before the letters: their town rebuilt, Sela's work done,
	# Maren's relics asked for, nothing found yet.
	state.settlement.town_tier = 1
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	state.questing.resolve_quests("elder")
	assert_eq(Letters.dig_spot(Town.done_projects(state.settlement)), Vector2i(-1, -1), "her house stands again")
	assert_eq(Letters.tin_lines(Town.done_projects(state.settlement)), Quests._data()["letters"]["late"], "a short word, no dig")
	assert_true(Quests._data()["letters"]["late"].size() <= 2)
	assert_eq(_next(), "letter_wenna", "the tin is behind them: the story asks for the first letter")
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq([lead["who"], lead["map_id"]], ["elder", "town"], "which Maren has")
	state.questing.finish_dialogue("elder")
	assert_eq(_letters_carried().size(), 4, "the first word with Maren gives them")
	assert_eq(Bearing.active(state.progression, state.settlement, state.pack.items)["who"], "saltmere_wenna")


## The web hero who beat Morvax before the relics or the letters existed:
## their story stays told, and Maren's letters are news from the Reach to
## carry if they like, never a way back. Their save keeps its shape.
func test_the_late_web_save_keeps_its_story_and_its_shape() -> void:
	var saved := SaveCodec.decode_code(FileAccess.get_file_as_string("res://test/fixtures/web_save_late.txt"))
	state.apply(saved)
	assert_eq(_next(), "", "their story is told")
	var before: Array = state.to_dict().keys()
	state.questing.finish_dialogue("elder")
	assert_eq(_letters_carried().size(), 4, "no keepsake of theirs came home: four letters")
	assert_eq(_next(), "", "and it stays told")
	for key: String in state.to_dict():
		assert_true(key in before or key == "storySeen", "%s was already a field of the save" % key)
	assert_has(state.to_dict()["storySeen"], Letters.scene_id(), "the tin in the story ledger")


func test_a_new_heros_save_holds_no_new_field() -> void:
	var before: Array = state.to_dict().keys()
	state.questing.finish_dialogue("elder")
	state.questing.finish_dialogue("saltmere_wenna")
	var after: Dictionary = state.to_dict()
	for key: String in after:
		assert_true(key in before or key == "storySeen", "%s was already a field of the save" % key)
	assert_eq(after["quests"]["letter_wenna"], {"progress": 1, "done": true}, "progress lives with the quests")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(after))["state"])
	assert_true(MainQuest.is_met(_step("letter_wenna"), reloaded.progression, reloaded.settlement))
	assert_false(Letters.tin_waits(reloaded.progression))


# ---- Around the tin ----------------------------------------------------------------

func test_sela_has_a_word_the_first_night_and_bram_of_the_road() -> void:
	assert_string_contains(state.upkeep.rest_at_inn(), "Heroes pay double. ...Fine. Half.")
	state.mark_seen("dream_courier")
	state.pack.gold = 50
	assert_false("Heroes pay double" in state.upkeep.rest_at_inn(), "once")
	assert_eq(Letters.news_for("villager_bram", state.progression), "", "the road's news waits for the letters")
	state.questing.finish_dialogue("elder")
	assert_string_contains(Letters.news_for("villager_bram", state.progression), "I lifted one rock. Supervised the rest.")
	assert_eq(Letters.news_for("villager_ana", state.progression), "")
	state.questing.finish_dialogue("saltmere_wenna")
	assert_eq(Letters.news_for("villager_bram", state.progression), "", "old news once Wenna has hers")
