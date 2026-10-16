extends GutTest
## The Pixelheim Post's first step (PIX-320): the post box goes up once
## Maren's first letter reaches Saltmere; each morning it holds a few
## pieces worked out from the day, the seed and the threads, each for
## someone where the hero has been, past no gate still shut, its sender at
## home and what it waits on in the story met; E at the box takes them, a
## word with the addressee hands one over (a tip, now and then a thing to
## keep, sometimes a reply to carry back); nothing expires and a day skipped
## costs nothing; and only what the hero did is kept, in the save's own
## `post` section.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1


## Chapter 2 as a hero stands in it: the tin found, Maren's first letter in
## Wenna's hands, Saltmere walked.
func _chapter_two() -> void:
	state.mark_seen(Letters.scene_id())
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	_walk("saltmere")


## A map walked: the ground round its first villager seen.
func _walk(map_id: String) -> void:
	var map := MapData.load_by_id(map_id)
	Discovery.discover_around(state.world.discovered, map, map.spawn)


func _box(day := 0) -> Array[String]:
	return Post.in_box(state.post, day, state.progression, state.settlement, state.world.discovered)


func _carried() -> Array[String]:
	return state.post.bag


# ---- The data ---------------------------------------------------------------------

func test_three_threads_of_four_to_six_pieces_each_name_who_writes_and_who_reads() -> void:
	assert_eq(Post.threads().map(func(thread: Dictionary) -> String: return thread["id"]), ["cheese_club", "salty_stew", "pip_dragon"])
	var ids := {}
	for thread: Dictionary in Post.threads():
		var pieces: Array = thread["pieces"]
		assert_between(pieces.size(), 4, 6, "%s runs four to six pieces" % thread["id"])
		assert_false(pieces[0].get("reply", false), "%s starts with a piece posted, not a reply" % thread["id"])
		for entry: Dictionary in pieces:
			assert_false(ids.has(entry["id"]), "%s once" % entry["id"])
			ids[entry["id"]] = true
			for who: String in [String(entry["from"]), String(entry["to"])]:
				assert_ne(Post.npc_of(who), "", "%s's %s writes or is written to" % [entry["id"], who])
			assert_false(Npcs.by_id(Post.addressee(entry), []).is_empty(), "%s goes to someone in the Reach" % entry["id"])
			assert_false(Npcs.by_id(Post.sender(entry), []).is_empty(), "%s comes from someone in the Reach" % entry["id"])
			for key: String in ["addressed", "note"]:
				assert_ne(String(entry.get(key, "")), "", "%s has its %s" % [entry["id"], key])
			assert_false((entry["words"] as Array).is_empty(), "%s has words to read once it's delivered" % entry["id"])
			assert_false((entry["said"] as Array).is_empty(), "%s is answered as it's handed over" % entry["id"])
			assert_between(int(entry["tip"]), 1, 12, "%s's tip is small, so PIX-294's curve stands" % entry["id"])
			if entry.has("gift"):
				assert_ne(Catalog.item_name(String(entry["gift"])), String(entry["gift"]), "%s's gift is an item" % entry["id"])


func test_the_box_stands_on_open_ground_on_the_square() -> void:
	var town := MapData.load_by_id(Post.box_map())
	assert_eq(Post.box_map(), "town")
	assert_true(town.is_walkable(Post.box_cell()), "the box stands on open ground")
	assert_true(town.is_walkable(Post.box_cell() + Vector2i.DOWN), "and is faced from open ground")
	for taken: Vector2i in [Town.project_board(), Town.bounty_board(), Town.square()] + Town.lanterns():
		assert_ne(Post.box_cell(), taken, "the box keeps off the boards, the lanterns and the fountain")
	assert_does_not_have(Town.gathering_spots(town), Post.box_cell(), "nobody gathers where it stands")


# ---- When it opens ------------------------------------------------------------------

func test_the_post_opens_in_chapter_two_once_the_first_letter_reaches_saltmere() -> void:
	assert_false(Post.open(state.progression, state.settlement), "not in chapter 1")
	state.mark_seen(Letters.scene_id())
	assert_false(Post.open(state.progression, state.settlement), "not with the letters only found")
	assert_eq(_box(), [] as Array[String], "and its box holds nothing")
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	assert_true(Post.open(state.progression, state.settlement), "open once Wenna has her letter")


func test_delivering_the_first_letter_says_the_box_is_going_up() -> void:
	var said: Array = []
	state.noted.connect(func(lines: Array) -> void: said.append_array(lines))
	state.questing.open_tin()
	assert_true(state.pack.items.has("letter_wenna"))
	state.questing.deliver("saltmere_wenna")
	assert_has(said, Post.opened_line(), "the log says the post box goes up")
	said.clear()
	state.progression.quests["letter_pell"] = {"progress": 0, "done": false}
	state.pack.add_item("letter_pell")
	state.questing.deliver("mines_pell")
	assert_does_not_have(said, Post.opened_line(), "once")


# ---- The bag: chapters, gates, places, the day and the seed --------------------------

func test_the_first_bag_in_chapter_two_goes_to_saltmere() -> void:
	_chapter_two()
	assert_eq(_box(), ["club_ola", "stew_salt"] as Array[String], "Bram's first wheel and Sela's question; Pip isn't in the Hamlet yet")
	for id: String in _box():
		assert_eq(Post.where(Post.piece(id), state.settlement), Catalog.place_name("saltmere"))


func test_nothing_goes_where_the_hero_has_not_been() -> void:
	state.mark_seen(Letters.scene_id())
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	assert_eq(_box(), [] as Array[String], "Saltmere never walked (an old save's letter delivered by its keepsake)")


func test_pip_writes_once_pip_lives_in_the_village() -> void:
	_chapter_two()
	state.settlement.town_tier = 2
	assert_eq(_box(), ["club_ola", "stew_salt", "dragon_fish"] as Array[String])


func test_nothing_goes_past_a_gate_still_shut() -> void:
	_chapter_two()
	state.post.threads["cheese_club"] = 2
	var garrick := Npcs.by_id("mines_garrick", [])
	var at := Vector2i(int(garrick["x"]), int(garrick["y"]))
	assert_eq(Gates.in_the_way("blackiron", at, state.progression, state.settlement, state.world.discovered).get("id", ""), "bridge", "the burnt bridge stands between")
	assert_false(Post.reachable("mines_garrick", state.progression, state.settlement, state.world.discovered))
	assert_does_not_have(_box(), "club_garrick", "Garrick's wheel waits behind the burnt bridge")
	state.settlement.projects.append("river_bridge")
	assert_true(Gates.in_the_way("blackiron", at, state.progression, state.settlement, state.world.discovered).is_empty(), "the bridge mended")
	assert_does_not_have(_box(), "club_garrick", "and still waits till the hero has been to Blackiron")
	_walk("blackiron")
	assert_has(_box(), "club_garrick", "then it goes")


func test_a_thread_waits_on_the_story_where_it_says_so() -> void:
	_chapter_two()
	state.settlement.town_tier = 2
	state.post.threads["pip_dragon"] = 2
	assert_does_not_have(_box(), "dragon_letter", "no letter for the dragon while he's on his chain")
	state.mark_seen(Bells.collar_id())
	assert_true(MainQuest.chapter_done(7, state.progression, state.settlement))
	assert_has(_box(), "dragon_letter", "once the collar is off, care of Hilda's chimney")
	state.post.threads["salty_stew"] = 3
	_walk("blackiron")
	state.settlement.projects.append("river_bridge")
	assert_does_not_have(_box(), "canary_song", "the canary sings under Wenna's window only once both live in town")
	state.settlement.settlers.append_array(["saltmere_wenna", "mines_pell"])
	assert_has(_box(), "canary_song")


func test_the_day_and_the_seed_pick_the_same_bag_every_time() -> void:
	var ids: Array[String] = ["a", "b", "c", "d", "e", "f"]
	var seen := {}
	for day in 12:
		var bag := Post.pick(ids, day, 3)
		assert_eq(bag, Post.pick(ids, day, 3), "day %d draws the same bag every time" % day)
		assert_eq(bag.size(), 3, "three pieces at most")
		for id: String in bag:
			assert_has(ids, id)
		seen[",".join(bag)] = true
	assert_gt(seen.size(), 1, "different days draw different bags")
	assert_eq(Post.pick(["a", "b"] as Array[String], 4, 3), ["a", "b"] as Array[String], "fewer than three: all of them, in the threads' order")
	_chapter_two()
	assert_eq(_box(5), _box(5), "the box on the same morning holds the same")


func test_the_box_empties_for_the_day_and_never_offers_a_piece_twice() -> void:
	_chapter_two()
	state.posting.take_bag()
	assert_eq(_carried(), ["club_ola", "stew_salt"] as Array[String], "into the satchel")
	assert_eq(state.post.taken, 0)
	assert_eq(_box(0), [] as Array[String], "the box is empty until the morning")
	assert_eq(_box(1), [] as Array[String], "the next morning too: what it offered is already carried")
	Post.hand_over(state.post, "club_ola")
	assert_eq(_box(0), [] as Array[String], "a thread on a step fills the box only the next morning")
	state.post.bag.erase("club_ola_reply")
	state.post.threads["cheese_club"] = 2
	_walk("blackiron")
	state.settlement.projects.append("river_bridge")
	assert_eq(_box(1), ["club_garrick"] as Array[String], "the thread's next, the next morning")


# ---- Handing it over ----------------------------------------------------------------

func test_handing_a_piece_over_moves_its_thread_on_and_brings_its_reply() -> void:
	_chapter_two()
	Post.take(state.post, _box(), 0)
	assert_eq(Post.carried_for(state.post, "saltmere_ola").get("id", ""), "club_ola")
	assert_true(Post.carried_for(state.post, "villager_bram").is_empty(), "nothing yet for Bram")
	var reply := Post.hand_over(state.post, "club_ola")
	assert_eq(reply.get("id", ""), "club_ola_reply")
	assert_eq(state.post.step("cheese_club"), 1)
	assert_eq(state.post.delivered, ["club_ola"] as Array[String])
	assert_eq(_carried(), ["stew_salt", "club_ola_reply"] as Array[String], "the reply in the satchel, to carry back")
	assert_eq(Post.carried_for(state.post, "villager_bram").get("id", ""), "club_ola_reply")
	assert_true(Post.hand_over(state.post, "stew_salt").is_empty(), "Sela's question wants no reply")
	assert_eq(Post.hand_over(state.post, "club_garrick"), {}, "a piece not carried is never handed over")
	assert_eq(state.post.step("cheese_club"), 1)
	state.post.bag.append("club_mabel")
	assert_true(Post.carried_for(state.post, "greyhold_mabel").is_empty(), "nor one out of its turn")
	Post.hand_over(state.post, "club_mabel")
	assert_eq(state.post.step("cheese_club"), 1)
	assert_has(_carried(), "club_mabel")


func test_a_word_with_the_addressee_hands_it_over_for_a_tip() -> void:
	_chapter_two()
	state.posting.take_bag()
	var gold: int = state.pack.gold
	var said: Array = []
	state.message.connect(func(text: String) -> void: said.append(text))
	var logged: Array = []
	state.noted.connect(func(lines: Array) -> void: logged.append_array(lines))
	state.questing.finish_dialogue("saltmere_ola")
	assert_eq(state.pack.gold, gold + int(Post.piece("club_ola")["tip"]), "Ola tips the courier")
	assert_eq(said.size(), 1)
	assert_string_contains(String(said[0]), String(Post.piece("club_ola")["addressed"]))
	assert_has(logged, Text.t("A reply to carry back: %s.") % Post.piece("club_ola_reply")["addressed"])
	assert_eq(state.post.delivered, ["club_ola"] as Array[String])
	var cheese := int(state.pack.items.get("cheese_wheel", 0))
	state.post.bag.erase("club_ola_reply")
	state.post.threads["cheese_club"] = 4
	state.post.bag.append("club_mabel_reply")
	state.questing.finish_dialogue("villager_bram")
	assert_eq(int(state.pack.items.get("cheese_wheel", 0)), cheese + 1, "Bram's last word gives the courier a wheel of their own")
	assert_eq(state.post.step("cheese_club"), 5, "the club's thread told")
	assert_eq(Post.next_of("cheese_club", state.post), {})


func test_a_reply_goes_home_to_whoever_wrote() -> void:
	_chapter_two()
	state.settlement.town_tier = 2
	state.posting.take_bag()
	assert_has(_carried(), "dragon_fish")
	state.questing.finish_dialogue("saltmere_wenna")
	assert_eq(state.post.delivered, ["stew_salt"] as Array[String], "Wenna answers Sela's question first, the first taken")
	state.questing.finish_dialogue("saltmere_wenna")
	assert_eq(state.post.delivered, ["stew_salt", "dragon_fish"] as Array[String], "then Pip's")
	assert_eq(Post.carried_for(state.post, "kid_pip").get("id", ""), "dragon_fish_reply", "her answer is Pip's to have")
	state.questing.finish_dialogue("kid_pip")
	assert_eq(state.post.step("pip_dragon"), 2)
	assert_does_not_have(_carried(), "dragon_fish_reply")


# ---- The calm rules -------------------------------------------------------------------

func test_nothing_expires_and_a_day_skipped_costs_nothing() -> void:
	_chapter_two()
	var first := _box(0)
	assert_eq(_box(30), first, "a month later the box still holds what it held: nothing went off")
	state.world.steps = 0.0
	state.posting.take_bag()
	state.world.steps = 300.0 * DayNight.DAY_CYCLE_STEPS
	assert_eq(_carried(), first, "and what's carried stays carried, a year on")
	assert_false(state.posting.carried_for("saltmere_ola").is_empty(), "still Ola's to have")
	state.questing.finish_dialogue("saltmere_ola")
	assert_eq(state.post.step("cheese_club"), 1, "handed over as if it were the same morning")


func test_the_box_says_what_it_holds() -> void:
	assert_eq(state.posting.take_bag(), "", "shut before chapter 2: nothing to say")
	_chapter_two()
	assert_string_contains(state.posting.take_bag(), "2")
	assert_eq(state.posting.take_bag(), Text.t("The post box is empty. Fresh post comes in the morning."))


# ---- What is kept ------------------------------------------------------------------

func test_only_what_the_hero_did_is_kept_and_it_comes_back_whole() -> void:
	_chapter_two()
	state.posting.take_bag()
	state.questing.finish_dialogue("saltmere_ola")
	var kept: Dictionary = state.post.to_dict()
	var text := JSON.stringify(kept, "", false)
	assert_eq(text, '{"bag":["stew_salt","club_ola_reply"],"threads":{"cheese_club":1},"delivered":["club_ola"],"taken":0}',
		"the satchel, the threads' steps, what's delivered and the day the box was emptied")
	var back := PostState.from_dict(SaveCodec.parse_json(text))
	assert_eq(JSON.stringify(back.to_dict(), "", false), text, "read back, the same")
	assert_eq(JSON.stringify(PostState.from_dict({}).to_dict(), "", false), '{"bag":[],"threads":{},"delivered":[],"taken":-1}', "a hero with no post yet")


func test_the_post_is_its_own_section_of_the_save_and_comes_back_whole() -> void:
	assert_false(SaveCodec.to_file(state.to_dict()).has("post"), "a hero with no post yet writes no section")
	assert_true(SaveCodec.reread(state.to_dict()).has("hero"))
	_chapter_two()
	state.posting.take_bag()
	state.questing.finish_dialogue("saltmere_ola")
	var file := SaveCodec.to_file(state.to_dict())
	assert_eq(JSON.stringify(file["post"], "", false), JSON.stringify(state.post.to_dict(), "", false), "the post's own section")
	var keys: Array = file.keys()
	assert_eq(keys.find("post"), keys.find("world") + 1, "beside the world's")
	var other: Node = autofree(GameStateScript.new())
	other.apply(SaveCodec.reread(state.to_dict()))
	assert_eq(JSON.stringify(other.post.to_dict(), "", false), JSON.stringify(state.post.to_dict(), "", false), "saved and loaded, the same")
	assert_eq(Post.in_box(other.post, 0, other.progression, other.settlement, other.world.discovered), [] as Array[String], "the box still emptied today")
	assert_eq(other.posting.carried_for("villager_bram").get("id", ""), "club_ola_reply", "Ola's reply still for Bram")
