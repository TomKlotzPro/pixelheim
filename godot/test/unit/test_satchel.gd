extends GutTest
## The courier's satchel (PIX-253 step 2, v2 §5 "Main quests stand out"):
## the journal's main story is Maren's letters by their address, to deliver
## or delivered and answered; a letter carried hangs a gold "!" ringed in
## gold over its recipient; the arrow at the view's edge is gold only while
## it leads the main story; the map keeps the main story's next place as a
## hollow gold diamond while something else leads; and each chapter opens on
## a card, shown once, kept in the story ledger - no new field in the save.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const MapScreen := preload("res://scripts/map_screen.gd")
const Npc := preload("res://scripts/npc.gd")
const ChapterScreen := preload("res://scripts/chapter_screen.gd")
const RECIPIENTS := {
	"letter_wenna": "saltmere_wenna", "letter_pell": "mines_pell", "letter_hale": "greyhold_ulla", "letter_aske": "frost_aske",
}

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _rows() -> Array[Dictionary]:
	return Journal.rows(state.progression, state.settlement, state.pack.items)


func _row(id: String) -> Dictionary:
	for row: Dictionary in _rows():
		if row["id"] == id:
			return row
	return {}


func _lead() -> Dictionary:
	return Bearing.active(state.progression, state.settlement, state.pack.items)


func _mark(npc_id: String) -> String:
	return Quests.mark_for(npc_id, state.progression.quests, state.pack.items, state.questing.quest_open)


# ---- The satchel's rows -----------------------------------------------------------

func test_before_the_tin_the_satchel_is_empty() -> void:
	assert_eq(Letters.satchel(state.progression), [])
	assert_false(_rows().any(func(row: Dictionary) -> bool: return row["letter"]), "no letter rows")


func test_the_letters_are_rows_by_their_address_to_deliver() -> void:
	state.questing.finish_dialogue("elder")
	var story := _rows().filter(func(row: Dictionary) -> bool: return row["group"] == "story")
	assert_eq(story.map(func(row: Dictionary) -> String: return row["id"]).slice(0, 5),
		[Journal.STORY, "letter_wenna", "letter_pell", "letter_hale", "letter_aske"], "the chapter, then the satchel in the story's order")
	assert_eq(story[5]["id"], Relics.quest_id(), "then what else carries the story")
	var wenna := _row("letter_wenna")
	assert_eq(wenna["title"], "Letter to Old Wenna, Saltmere")
	assert_eq([wenna["delivered"], wenna["follows"], wenna["letter"]], [false, true, true])
	assert_eq(wenna["line"], Bearing.line(Bearing.of_quest(Quests.by_id("letter_wenna"), state.progression, state.settlement, state.pack.items)), "where it goes, as the line above the dock says it")
	assert_eq(wenna["detail"], Catalog.item("letter_wenna")["description"], "the envelope, under the list")
	assert_string_contains(wenna["detail"], "A courier never reads the post")
	for quest_id: String in RECIPIENTS:
		assert_eq(_row(quest_id)["lead"]["who"], RECIPIENTS[quest_id], "%s leads to its recipient" % quest_id)
		assert_ne(String(Quests.by_id(quest_id)["addressed"]), "")


func test_a_delivered_letter_is_answered_and_shows_its_answer() -> void:
	state.questing.finish_dialogue("elder")
	state.questing.finish_dialogue("saltmere_wenna")
	var wenna := _row("letter_wenna")
	assert_true(wenna["delivered"], "still in the satchel's list, delivered")
	assert_false(wenna["follows"], "nothing left to follow")
	assert_eq(wenna["line"], "Wenna answered, with Tam's last postcard.")
	assert_string_contains(wenna["detail"], "I've brought cheese.", "the answer's heart under the list")
	assert_false(_row("letter_pell")["delivered"])
	assert_false(Journal.follow(state.progression, "letter_wenna"), "a delivered letter isn't followed")
	assert_eq(state.progression.tracked, "")
	for quest: Dictionary in Letters.all():
		assert_lte(String(quest["gist"]).length(), 200, "%s's answer fits the two lines under the list" % quest["id"])


func test_a_letter_whose_keepsake_came_home_is_answered_too() -> void:
	state.progression.hunted.append("tidecaller")
	state.questing.finish_dialogue("elder")
	assert_false(state.progression.quests.has("letter_wenna"), "never given")
	assert_true(_row("letter_wenna")["delivered"], "but answered, the ladle home")
	assert_eq(Letters.satchel(state.progression).size(), 4)


# ---- The gold mark ------------------------------------------------------------------

func test_a_recipient_wears_the_gold_mark_only_while_their_letter_is_carried() -> void:
	assert_ne(_mark("saltmere_wenna"), "letter", "no letter yet: her own errand's mark, if any")
	state.questing.finish_dialogue("elder")
	for npc_id: String in RECIPIENTS.values():
		assert_eq(_mark(npc_id), "letter", "%s: Maren's letter is in the satchel" % npc_id)
	assert_ne(_mark("elder"), "letter", "not the one who wrote them")
	state.pack.remove_item("letter_pell")
	assert_eq(_mark("mines_pell"), "", "no letter in the pack, no mark")
	state.questing.finish_dialogue("saltmere_wenna")
	assert_ne(_mark("saltmere_wenna"), "letter", "delivered: nothing more of the story with her")
	assert_eq(Npc.MARK_COLORS["letter"], UiStyle.GOLD, "gold")
	assert_eq(Npc.MARK_COLORS["offer"], Color("f2c14e"), "and a side quest's marks keep their colours")
	assert_eq(Npc.MARK_COLORS["waiting"], Color("a8a39a"))


func test_the_gold_mark_is_ringed_and_stands_clear_of_the_head() -> void:
	var plain: Node2D = autofree(Npc._outlined("!", UiStyle.GOLD))
	var ringed: Node2D = autofree(Npc._outlined("!", UiStyle.GOLD, 3))
	assert_eq(plain.get_child_count(), 5, "a side quest's: the glyph in a dark line")
	assert_eq(ringed.get_child_count(), 25, "the main story's: a gold ring and the night round it too")
	var glyph: Label = ringed.get_child(-1)
	assert_eq([glyph.position, glyph.get_theme_color("font_color")], [Vector2.ZERO, UiStyle.GOLD], "the gold glyph on top")
	var golds := ringed.get_children().filter(func(label: Label) -> bool: return label.get_theme_color("font_color") == UiStyle.GOLD)
	assert_eq(golds.size(), 9, "the glyph and its ring two pixels out")
	var frames := PunyArt.frames(PunyArt.villager("villager"))
	var low: Vector2 = Npc.mark_spot("!", frames, "idle_down", Vector2(0, -3), Vector2.ONE)
	var high: Vector2 = Npc.mark_spot("!", frames, "idle_down", Vector2(0, -3), Vector2.ONE, 3)
	assert_eq(high.x, low.x, "centred alike")
	assert_eq(low.y - high.y, 2.0, "two pixels higher: its ring clears the head as the dark line does")


# ---- The gold arrow -----------------------------------------------------------------

func test_the_arrow_is_gold_only_while_it_leads_the_main_story() -> void:
	state.questing.finish_dialogue("elder")
	state.progression.quests["cheese_run"] = {"progress": 0, "done": false}
	var arrow: Control = autofree(Hud.Arrow.new())
	arrow.main = Bearing.tells_story(_lead())
	assert_eq(arrow.ink(), UiStyle.GOLD, "the story leads")
	Journal.follow(state.progression, "cheese_run")
	arrow.main = Bearing.tells_story(_lead())
	assert_eq(arrow.ink(), UiStyle.CREAM, "a side quest followed")
	state.progression.cleared_levels.append(2)
	Journal.follow(state.progression, "greymaw")
	assert_false(Bearing.tells_story(_lead()), "and a bounty")
	Journal.follow(state.progression, "letter_pell")
	assert_false(_lead()["main"], "a letter followed on its own row")
	arrow.main = Bearing.tells_story(_lead())
	assert_eq(arrow.ink(), UiStyle.GOLD, "is the main story still: gold")
	Journal.follow(state.progression, Journal.STORY)
	arrow.main = Bearing.tells_story(_lead())
	assert_eq(arrow.ink(), UiStyle.GOLD, "the story again")
	assert_false(Bearing.tells_story({}), "nowhere to head for")


# ---- The hollow diamond -------------------------------------------------------------

class FakeHud extends Node:
	var bearing := {}
	var story := {}


class StandIn extends Node2D:
	var hud: FakeHud


func test_the_main_story_waits_behind_a_side_quest() -> void:
	state.questing.finish_dialogue("elder")
	state.progression.quests["cheese_run"] = {"progress": 0, "done": false}
	assert_eq(Bearing.behind(_lead(), state.progression, state.settlement, state.pack.items), {}, "the story leads: nothing behind it")
	Journal.follow(state.progression, "cheese_run")
	var behind := Bearing.behind(_lead(), state.progression, state.settlement, state.pack.items)
	assert_true(behind["main"], "behind the cheese, the story")
	assert_eq(behind, Bearing.main(state.progression, state.settlement, state.pack.items))
	assert_eq(behind["who"], "innkeeper", "its next step: Sela's work")
	state.progression.cleared_levels.append(2)
	Journal.follow(state.progression, "greymaw")
	assert_eq(Bearing.behind(_lead(), state.progression, state.settlement, state.pack.items)["who"], "innkeeper", "and behind a bounty")


func test_the_map_keeps_the_main_story_as_a_hollow_diamond() -> void:
	var world: StandIn = autofree(StandIn.new())
	world.hud = autofree(FakeHud.new())
	var painting = autofree(MapScreen.Painting.new())
	painting.world = world
	painting.map = MapData.load_by_id("town")
	painting.home = false
	var lead := {"who": "", "map_id": "town", "cell": Vector2i(10, 10), "main": false}
	world.hud.bearing = lead
	assert_eq(painting.goal_cell(), Vector2i(10, 10))
	assert_eq(painting.story_cell(), Bearing.NOWHERE, "the story leads itself, or nothing's behind")
	world.hud.story = {"who": "", "map_id": "town", "cell": Vector2i(30, 20), "main": true}
	assert_eq(painting.story_cell(), Vector2i(30, 20), "the main story's place, kept")
	world.hud.story = {"who": "", "map_id": "overworld", "cell": Vector2i(16, 61), "main": true}
	assert_eq(painting.story_cell(), Bearing.way_out("town", "overworld"), "on another map: the door that starts the way")
	world.hud.story = {"who": "", "map_id": "town", "cell": Vector2i(10, 10), "main": true}
	assert_eq(painting.story_cell(), Bearing.NOWHERE, "where the two meet, the goal's diamond says it")
	world.hud.story = {"who": "", "map_id": "town", "cell": Vector2i(30, 20), "main": true}
	var marks := GameState.settings.quest_marks
	GameState.settings.quest_marks = false
	assert_eq(painting.story_cell(), Bearing.NOWHERE, "the quest marks turned off")
	GameState.settings.quest_marks = marks


func test_the_hollow_diamond_is_a_gold_band_round_a_hole() -> void:
	var shown := Transform2D()
	var filled := Waypoints.diamond_bands(8.0, false, shown)
	assert_eq(filled, [[11.0, 8.0, false], [8.0, 0.0, true]], "the goal's: a dark rim, gold to the middle")
	var hollow := Waypoints.diamond_bands(8.0, true, shown)
	assert_eq(hollow.map(func(band: Array) -> bool: return band[2]), [false, true, false], "dark, gold, dark")
	assert_eq(hollow[0], filled[0], "the same rim")
	assert_gt(float(hollow[-1][1]), 0.0, "and the page shows through the middle")
	# Twice the size on the screen: whole screen pixels still.
	for band: Array in Waypoints.diamond_bands(8.0, true, Transform2D().scaled(Vector2(1.5, 1.5))):
		assert_eq(band[0] * 1.5, roundf(band[0] * 1.5))


# ---- Chapter cards ------------------------------------------------------------------

func test_each_chapter_card_is_due_once() -> void:
	state.progression.prologue = Prologue.MAREN
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 0, "not on the Night of Ash")
	state.progression.prologue = Prologue.DONE
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 1, "the day begins: chapter one")
	state.mark_seen(MainQuest.card_id(1))
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 0, "shown once")
	state.questing.finish_dialogue("elder")
	state.settlement.town_tier = 1
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 2, "the letter to Saltmere")
	assert_eq(MainQuest.title_of(2), "The Letter to Saltmere")
	state.mark_seen(MainQuest.card_id(2))
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 0)
	state.questing.finish_dialogue("saltmere_wenna")
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 0, "still chapter two: the ladle")
	state.spoils.defeat_monster(Hunts.fighter("tidecaller"), "seacave", "", 10)
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 3)
	assert_has(state.progression.story_seen, "chapter_2", "kept in the story ledger")


func test_a_hero_who_ran_ahead_sees_only_the_chapter_they_are_in() -> void:
	for named: String in ["tidecaller", "seam_warden", "hollow_captain"]:
		state.progression.hunted.append(named)
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 5, "the Frostgate's, not the three before it")
	var told := SaveCodec.decode_code(FileAccess.get_file_as_string("res://test/fixtures/web_save_late.txt"))
	state.apply(told)
	assert_eq(MainQuest.card_due(state.progression, state.settlement), 0, "a story told has no card left")


func _card(number: int, still: bool) -> Node:
	var kept: bool = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = still
	var card: Node = ChapterScreen.new()
	card.number = number
	add_child(card)
	await wait_process_frames(1)
	GameState.settings.reduce_motion = kept
	return card


func _close(card: Node) -> void:
	if is_instance_valid(card) and not card.is_queued_for_deletion():
		card.close()
	await wait_process_frames(1)
	get_tree().paused = false


func test_a_chapter_card_says_its_number_and_title_and_its_title_rises() -> void:
	var card: Node = await _card(3, false)
	assert_eq(card._number.text, "Chapter 3")
	assert_eq(card._title.text, "The Letter to Blackiron")
	assert_eq(card._title.get_theme_font("font"), UiStyle.logo_font(), "in the title's type, as the dawn's card")
	assert_gt(card.rise_left(), 0.0, "coming in, the title rises into place")
	assert_true(get_tree().paused, "the world holds still meanwhile")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.keycode = KEY_E
	press.pressed = true
	card._unhandled_input(press)
	assert_true(card.is_queued_for_deletion(), "E lets it go sooner")
	await _close(card)


func test_with_reduce_motion_a_chapter_card_only_fades() -> void:
	var card: Node = await _card(5, true)
	assert_eq(card.rise_left(), 0.0, "nothing slides")
	assert_lt(card._title.modulate.a, 1.0, "it fades in")
	await _close(card)


func test_every_chapter_title_fits_the_card() -> void:
	for number in range(1, MainQuest.chapters().size() + 1):
		var title := MainQuest.title_of(number)
		var scale: int = ChapterScreen.title_scale(title)
		assert_lte(float(title.length() * UiStyle.LOGO_PX * scale), ChapterScreen.TITLE_ROOM, title)


# ---- The save -----------------------------------------------------------------------

func test_the_satchel_and_the_cards_add_no_field_to_the_save() -> void:
	var before: Array = state.to_dict().keys()
	state.questing.finish_dialogue("elder")
	state.questing.finish_dialogue("saltmere_wenna")
	state.mark_seen(MainQuest.card_id(1))
	state.progression.quests["cheese_run"] = {"progress": 0, "done": false}
	Journal.follow(state.progression, "cheese_run")
	var after: Dictionary = state.to_dict()
	for key: String in after:
		assert_true(key in before or key in ["storySeen", "tracked"], "%s was already a field of the save" % key)
	assert_has(after["storySeen"], "chapter_1", "a card shown is a story moment seen")
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.parse_json(SaveCodec.serialize(after))["state"])
	assert_eq(MainQuest.card_due(reloaded.progression, reloaded.settlement), MainQuest.card_due(state.progression, state.settlement), "and it comes back the same")
	assert_eq(Letters.satchel(reloaded.progression).map(func(carried: Dictionary) -> bool: return carried["delivered"]), [true, false, false, false])
