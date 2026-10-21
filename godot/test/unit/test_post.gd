extends GutTest
## The Pixelheim Post (PIX-320, PIX-321): the post box goes up once
## Maren's first letter reaches Saltmere; each morning it holds a few
## pieces worked out from the day, the seed and the threads, each between
## people where the hero has been, past no gate still shut, what it waits
## on in the story met; E at the box takes them, a word with the addressee
## hands one over (a tip, now and then a thing to keep or a recipe for the
## book, sometimes a reply to carry back) and stamps the courier's book;
## twelve threads, every place in at least two, three pieces a day from the
## first chapters; nothing expires and a day skipped costs nothing; and
## only what the hero did is kept, in the save's own `post` section.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## The places the Post has to reach (PIX-321), each in two threads at least:
## the village, the four hubs, the camps in the Mirefen and the Deepwood
## (one place between them), and the mountain after the story.
const HUBS := [["town"], ["saltmere"], ["blackiron"], ["greyhold"], ["frostgate"], ["mirefen", "deepwood"], ["morvax_forge"]]

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1


func after_each() -> void:
	if not TranslationServer.get_locale().begins_with("en"):
		Text.apply("en")


## Chapter 2 as a hero stands in it: the tin found, Maren's first letter in
## Wenna's hands, Saltmere walked, and the Reach on the way there.
func _chapter_two() -> void:
	state.mark_seen(Letters.scene_id())
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	_walk("saltmere")
	_walk("overworld")


## A map walked: the ground round its spawn seen.
func _walk(map_id: String) -> void:
	var map := MapData.load_by_id(map_id)
	Discovery.discover_around(state.world.discovered, map, map.spawn)


func _box(day := 0) -> Array[String]:
	return Post.in_box(state.post, day, state.progression, state.settlement, state.world.discovered)


func _offered() -> Array[String]:
	return Post.offered(state.post, state.progression, state.settlement, state.world.discovered)


func _carried() -> Array[String]:
	return state.post.bag


## One of the hero's days at the post: the morning's box taken, then every
## piece handed over as a word with its addressee would, replies carried
## back too. Returns how many the box held.
func _a_day(day: int) -> int:
	state.world.steps = float(day) * DayNight.DAY_CYCLE_STEPS
	var taken: int = state.posting.in_box().size()
	state.posting.take_bag()
	var handed := true
	while handed:
		handed = false
		for id: String in state.post.bag.duplicate():
			if state.posting.deliver(Post.addressee(Post.piece(id))) != "":
				handed = true
	return taken


## Where a piece's addressee lives by the data (a settler where they were
## found, Morvax at his forge): its page in the book.
func _home_of(entry: Dictionary) -> String:
	var to := Post.addressee(entry)
	if to == Homecoming.MORVAX:
		return "morvax_forge"
	return Post.place_of(String(Npcs.by_id(to, []).get("mapId", "")))


# ---- The data ---------------------------------------------------------------------

func test_twelve_threads_of_four_to_six_pieces_each_name_who_writes_and_who_reads() -> void:
	assert_eq(Post.threads().size(), 12, "twelve threads: the three of step 1 and nine more")
	var ids := {}
	for thread: Dictionary in Post.threads():
		var pieces: Array = thread["pieces"]
		assert_between(pieces.size(), 4, 6, "%s runs four to six pieces" % thread["id"])
		assert_false(pieces[0].get("reply", false), "%s starts with a piece posted, not a reply" % thread["id"])
		assert_ne(String(thread.get("title", "")), "", "%s has a title" % thread["id"])
		for entry: Dictionary in pieces:
			assert_false(ids.has(entry["id"]), "%s once" % entry["id"])
			ids[entry["id"]] = true
	for thread: Dictionary in Post.threads():
		for entry: Dictionary in thread["pieces"]:
			for who: String in [String(entry["from"]), String(entry["to"])]:
				assert_ne(Post.npc_of(who), "", "%s's %s writes or is written to" % [entry["id"], who])
			assert_ne(entry["from"], entry["to"], "%s goes from someone to someone else" % entry["id"])
			assert_false(Npcs.by_id(Post.addressee(entry), []).is_empty(), "%s goes to someone in the Reach" % entry["id"])
			assert_false(Npcs.by_id(Post.sender(entry), []).is_empty(), "%s comes from someone in the Reach" % entry["id"])
			assert_has(["letter", "note", "parcel"], String(entry["kind"]), "%s is a letter, a note or a parcel" % entry["id"])
			for key: String in ["addressed", "note"]:
				assert_ne(String(entry.get(key, "")), "", "%s has its %s" % [entry["id"], key])
			assert_false((entry["words"] as Array).is_empty(), "%s has words to read once it's delivered" % entry["id"])
			assert_false((entry["said"] as Array).is_empty(), "%s is answered as it's handed over" % entry["id"])
			assert_between(int(entry["tip"]), 1, 12, "%s's tip is small, so PIX-294's curve stands" % entry["id"])
			if entry.has("gift"):
				assert_ne(Catalog.item_name(String(entry["gift"])), String(entry["gift"]), "%s's gift is an item the game has" % entry["id"])
			if entry.has("recipe"):
				assert_false(Economy.recipe(String(entry["recipe"])).is_empty(), "%s's recipe is one the game has" % entry["id"])
			if entry.has("after"):
				assert_true(ids.has(entry["after"]), "%s comes after a piece the Post has" % entry["id"])
				assert_ne(Post.thread_of(String(entry["after"])), Post.thread_of(String(entry["id"])), "%s waits on another thread" % entry["id"])
			if entry.get("reply", false):
				var thread_pieces: Array = Post.thread(Post.thread_of(String(entry["id"])))["pieces"]
				var before: Dictionary = thread_pieces[thread_pieces.find(entry) - 1]
				assert_eq(entry["to"], before["from"], "%s goes back to whoever wrote the piece before" % entry["id"])


func test_every_place_is_in_two_threads_at_least() -> void:
	for hub: Array in HUBS:
		var threads: Array[String] = []
		for thread: Dictionary in Post.threads():
			for entry: Dictionary in thread["pieces"]:
				if _home_of(entry) in hub and String(thread["id"]) not in threads:
					threads.append(String(thread["id"]))
		assert_gte(threads.size(), 2, "%s has post from two threads at least: %s" % [hub, threads])
	for entry: Dictionary in Post.book():
		assert_eq(Post.place_of(String(entry["place"])), entry["place"], "%s has its own page" % entry["place"])
		assert_true(Postmark.EMBLEMS.has(entry["emblem"]), "%s's postmark has an emblem drawn" % entry["place"])
		assert_true(Postmark.INKS.has(entry["ink"]), "%s's postmark is in one of the page's inks" % entry["place"])


func test_some_pieces_leave_a_recipe_a_piece_of_furniture_or_a_trophy_to_keep() -> void:
	var furniture := 0
	var trophies := 0
	var recipes := 0
	for thread: Dictionary in Post.threads():
		for entry: Dictionary in thread["pieces"]:
			var kept := Post.kept(entry)
			if kept["gift"] != "" and String(Catalog.item(kept["gift"]).get("category", "")) == "furniture":
				furniture += 1
			if kept["gift"] != "" and Town.trophy_buffs().has(kept["gift"]):
				trophies += 1
			if kept["recipe"] != "":
				recipes += 1
	assert_gt(furniture, 0, "a piece of furniture for the house")
	assert_gt(trophies, 0, "a trophy for the shelf")
	assert_gt(recipes, 0, "a recipe written into the book")


func test_the_box_stands_on_open_ground_on_the_square() -> void:
	var town := MapData.load_by_id(Post.box_map())
	assert_eq(Post.box_map(), "town")
	assert_true(town.is_walkable(Post.box_cell()), "the box stands on open ground")
	assert_true(town.is_walkable(Post.box_cell() + Vector2i.DOWN), "and is faced from open ground")
	for taken: Vector2i in [Town.project_board(), Town.bounty_board(), Town.square()] + Town.lanterns():
		assert_ne(Post.box_cell(), taken, "the box keeps off the boards, the lanterns and the fountain")
	assert_does_not_have(Town.gathering_spots(town), Post.box_cell(), "nobody gathers where it stands")


func test_a_parcel_is_wrapped_and_in_french_its_tags_are_masculine() -> void:
	var parcel := Post.piece("club_ola")
	var letter := Post.piece("stew_salt")
	var note := Post.piece("canary_song")
	assert_eq(Post.tags(letter), ["SEALED", "DELIVERED"] as Array[String])
	assert_eq(Post.tags(parcel), ["WRAPPED", "HANDED OVER"] as Array[String])
	assert_eq(Post.tags(note), ["FOLDED", "HANDED OVER"] as Array[String])
	Text.apply("fr")
	assert_eq(Post.tags(Post.piece("club_ola")), ["EMBALLÉ", "REMIS"] as Array[String], "« colis » is masculine")
	assert_eq(Post.tags(Post.piece("canary_song")), ["PLIÉ", "REMIS"] as Array[String], "« mot », « rapport » too")
	assert_eq(Post.tags(Post.piece("stew_salt")), ["SCELLÉE", "REMISE"] as Array[String], "« lettre », « réponse » are feminine")
	Text.apply("en")


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

func test_the_first_bag_holds_three_pieces_between_places_the_hero_has_been() -> void:
	_chapter_two()
	for tier in [0, 1]:
		state.settlement.town_tier = tier
		var box := _box()
		assert_eq(box.size(), Post.bag_size(), "three pieces in the Ashes and in the Hamlet")
		for id: String in box:
			var entry := Post.piece(id)
			for who: String in [Post.sender(entry), Post.addressee(entry)]:
				assert_true(Post.reachable(who, state.progression, state.settlement, state.world.discovered), "%s: %s is where the hero has been" % [id, who])
				assert_has([Catalog.place_name("town"), Catalog.place_name("saltmere"), Catalog.place_name("overworld")],
					Catalog.place_name(String(Post.spot(who, state.progression, state.settlement)["mapId"])), "%s stays between Pixelheim, Saltmere and the Reach" % id)


func test_the_first_chapters_bring_three_pieces_a_day() -> void:
	# Chapter 2: Pixelheim in its Hamlet, Saltmere and the Reach's road
	# between them; the hero empties the box and delivers it all every day.
	_chapter_two()
	for day in 3:
		assert_eq(_a_day(day), 3, "chapter 2, day %d: three pieces" % (day + 1))
	# Chapter 3: the river bridge mended and Blackiron walked.
	state.settlement.projects.append("river_bridge")
	state.progression.quests["letter_pell"] = {"progress": 1, "done": true}
	_walk("blackiron")
	for day in range(3, 5):
		assert_eq(_a_day(day), 3, "chapter 3, day %d: three pieces" % (day + 1))
	# Chapter 4: Greyhold walked past Ulla's barricade, the Village built,
	# and by now the Deepwood and the Mirefen, open from the start, walked.
	state.settlement.town_tier = 2
	state.progression.hunted.append("seam_warden")
	state.progression.quests["letter_hale"] = {"progress": 1, "done": true}
	for map_id: String in ["greyhold", "deepwood", "mirefen"]:
		_walk(map_id)
	assert_eq(_a_day(5), 3, "chapter 4: three pieces")
	_a_day(6)
	# Chapter 5: the Frostgate dug out.
	state.progression.hunted.append("hollow_captain")
	_walk("frostgate")
	assert_eq(_a_day(7), 3, "chapter 5: three pieces")


## Saltmere's people are home while Pixelheim is still ash (PIX-328), so
## the Ashes' first bag reaches Ola too.
func test_a_town_still_in_its_ashes_has_three_pieces_too() -> void:
	state.settlement.town_tier = 0
	_chapter_two()
	assert_has(_offered(), "club_ola", "Bram's wheel for Ola, home in Saltmere")
	assert_eq(_a_day(0), 3, "Bram's wheel for Ola, Sela's stew for Wenna and Wren's horseshoes")


func test_nothing_goes_where_the_hero_has_not_been() -> void:
	state.mark_seen(Letters.scene_id())
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	assert_eq(_box(), [] as Array[String], "Saltmere never walked (an old save's letter delivered by its keepsake)")


func test_pip_writes_once_pip_lives_in_the_village() -> void:
	_chapter_two()
	assert_does_not_have(_offered(), "dragon_fish", "Pip isn't in the Hamlet yet")
	state.settlement.town_tier = 2
	assert_has(_offered(), "dragon_fish")


func test_nothing_goes_past_a_gate_still_shut() -> void:
	_chapter_two()
	state.post.threads["cheese_club"] = 2
	var garrick := Npcs.by_id("mines_garrick", [])
	var at := Vector2i(int(garrick["x"]), int(garrick["y"]))
	assert_eq(Gates.in_the_way("blackiron", at, state.progression, state.settlement, state.world.discovered).get("id", ""), "bridge", "the burnt bridge stands between")
	assert_false(Post.reachable("mines_garrick", state.progression, state.settlement, state.world.discovered))
	assert_does_not_have(_offered(), "club_garrick", "Garrick's wheel waits behind the burnt bridge")
	state.settlement.projects.append("river_bridge")
	assert_true(Gates.in_the_way("blackiron", at, state.progression, state.settlement, state.world.discovered).is_empty(), "the bridge mended")
	assert_does_not_have(_offered(), "club_garrick", "and still waits till the hero has been to Blackiron")
	_walk("blackiron")
	assert_has(_offered(), "club_garrick", "then it goes")


func test_nobody_writes_from_behind_a_gate_either() -> void:
	_chapter_two()
	state.post.threads["horseshoes"] = 2
	assert_does_not_have(_offered(), "shoes_snow", "Gunnar's caravan can't write from behind the avalanche")
	state.progression.hunted.append_array(["seam_warden", "hollow_captain"])
	assert_does_not_have(_offered(), "shoes_snow", "nor from a pass the hero hasn't walked")
	_walk("frostgate")
	assert_has(_offered(), "shoes_snow", "once they have, it comes down with the caravan")


func test_a_thread_waits_on_the_story_where_it_says_so() -> void:
	_chapter_two()
	state.settlement.town_tier = 2
	state.post.threads["pip_dragon"] = 2
	assert_does_not_have(_offered(), "dragon_letter", "no letter for the dragon while he's on his chain")
	state.mark_seen(Bells.collar_id())
	assert_true(MainQuest.chapter_done(7, state.progression, state.settlement))
	assert_has(_offered(), "dragon_letter", "once the collar is off, care of Hilda's chimney")
	state.post.threads["salty_stew"] = 3
	_walk("blackiron")
	state.settlement.projects.append("river_bridge")
	assert_does_not_have(_offered(), "canary_song", "the canary sings under Wenna's window only once both live in town")
	state.settlement.settlers.append_array(["saltmere_wenna", "mines_pell"])
	assert_has(_offered(), "canary_song")


func test_threads_wait_for_a_settler_home() -> void:
	_chapter_two()
	_walk("blackiron")
	_walk("greyhold")
	state.settlement.projects.append("river_bridge")
	state.progression.hunted.append("seam_warden")
	state.post.threads["smile"] = 3
	state.post.threads["everything_else"] = 4
	for id: String in ["smile_bellows", "else_salt", "charge_orders"]:
		assert_does_not_have(_offered(), id, "%s waits for its settler" % id)
	state.settlement.settlers.append_array(["mines_pell", "saltmere_wenna", "greyhold_ulla"])
	for id: String in ["smile_bellows", "else_salt", "charge_orders"]:
		assert_has(_offered(), id, "%s goes once they're home" % id)
	state.post.threads["in_charge"] = 2
	assert_does_not_have(_offered(), "charge_bell", "Teo writes about the bell once it hangs in Pixelheim's hall")
	state.settlement.settlers.append("greyhold_teo")
	assert_has(_offered(), "charge_bell")


func test_the_clubs_song_waits_for_the_garrisons_question() -> void:
	_chapter_two()
	_walk("deepwood")
	assert_does_not_have(_offered(), "song_ask", "nobody has asked for a song yet")
	state.post.delivered.append("club_mabel_reply")
	assert_has(_offered(), "song_ask", "the garrison asked: Bram writes to Loras in the Deepwood")
	assert_eq(Post.where(Post.piece("song_ask"), state.progression, state.settlement), Catalog.place_name("deepwood"))
	state.settlement.settlers.append("settler_loras")
	assert_eq(Post.where(Post.piece("song_ask"), state.progression, state.settlement), Catalog.place_name("town"), "or to him at home, once he's come to Pixelheim")


func test_maren_and_morvax_count_the_lamps_only_after_coming_home() -> void:
	_chapter_two()
	var forge := MapData.load_by_id("morvax_forge")
	Discovery.discover_around(state.world.discovered, forge, forge.spawn)
	assert_does_not_have(_offered(), "count_lamps", "not before his answer")
	assert_does_not_have(_offered(), "club_morvax")
	state.post.threads["cheese_club"] = 5
	state.mark_seen(Story.ending_scene(Homecoming.STAY))
	assert_has(_offered(), "count_lamps", "staying with the three: \"Forty-one.\" from the forge")
	assert_has(_offered(), "club_morvax", "and Bram's wheel goes up the mountain for Tam")
	assert_eq(Post.place_for(Homecoming.MORVAX, state.progression, state.settlement), "morvax_forge", "his post goes up the mountain")
	var home: Node = autofree(GameStateScript.new())
	home.new_game("Robin", "warrior")
	home.mark_seen(Story.ending_scene(Homecoming.HOME))
	assert_eq(Post.place_for(Homecoming.MORVAX, home.progression, home.settlement), "town", "come home, it goes to his bench by the fountain")
	assert_eq(Post.where(Post.piece("count_lamps_reply"), home.progression, home.settlement), Catalog.place_name("town"))


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
	var box := _box(0)
	state.posting.take_bag()
	assert_eq(_carried(), box, "into the satchel")
	assert_eq(state.post.taken, 0)
	assert_eq(_box(0), [] as Array[String], "the box is empty until the morning")
	for id: String in _box(1):
		assert_does_not_have(box, id, "the next morning, never what's already carried")
	state.post.bag.clear()
	state.post.bag.append("club_ola")
	Post.hand_over(state.post, "club_ola")
	assert_has(_carried(), "club_ola_reply")
	assert_does_not_have(_offered(), "club_garrick", "a thread waits while its reply is carried")


# ---- Handing it over ----------------------------------------------------------------

func test_handing_a_piece_over_moves_its_thread_on_and_brings_its_reply() -> void:
	_chapter_two()
	state.post.bag.assign(["club_ola", "stew_salt"])
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
	state.post.bag.assign(["club_ola"])
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
	assert_has(logged, Text.t("New postmark: %s.") % Catalog.place_name("saltmere"), "Saltmere's page stamped")
	assert_eq(state.post.delivered, ["club_ola"] as Array[String])
	var cheese := int(state.pack.items.get("cheese_wheel", 0))
	state.post.bag.erase("club_ola_reply")
	state.post.threads["cheese_club"] = 4
	state.post.bag.append("club_mabel_reply")
	state.questing.finish_dialogue("villager_bram")
	assert_eq(int(state.pack.items.get("cheese_wheel", 0)), cheese + 1, "Bram's last word gives the courier a wheel of their own")
	assert_eq(state.post.step("cheese_club"), 5, "the club's thread on to its last piece, Morvax's wheel")
	assert_eq(Post.next_of("cheese_club", state.post).get("id", ""), "club_morvax")


func test_things_kept_from_the_post_go_in_the_pack_and_the_book() -> void:
	_chapter_two()
	state.post.threads["interest"] = 5
	state.post.bag.append("interest_gunnar_reply")
	var gems := int(state.pack.items.get("gem", 0))
	state.posting.deliver("settler_mirelle")
	assert_eq(int(state.pack.items.get("gem", 0)), gems + 1, "Mirelle's interest on all that walking: a gem for the shelf")
	state.post.threads["reagents"] = 5
	state.post.bag.append("reagents_lilies_reply")
	var said: String = state.posting.deliver("alchemist_vex")
	assert_string_contains(said, Catalog.item_name("frost_mitts"), "the mittens' recipe in the courier's book")
	assert_eq(Post.kept(Post.piece("reagents_lilies_reply"))["recipe"], "craft_frost_mitts")
	assert_has(Post.delivered_at(state.post, "town"), "reagents_lilies_reply", "kept on Pixelheim's page, where Vex had it")


func test_a_reply_goes_home_to_whoever_wrote() -> void:
	_chapter_two()
	state.settlement.town_tier = 2
	state.post.bag.assign(["stew_salt", "dragon_fish"])
	state.questing.finish_dialogue("saltmere_wenna")
	assert_eq(state.post.delivered, ["stew_salt"] as Array[String], "Wenna answers Sela's question first, the first taken")
	state.questing.finish_dialogue("saltmere_wenna")
	assert_eq(state.post.delivered, ["stew_salt", "dragon_fish"] as Array[String], "then Pip's")
	assert_eq(Post.carried_for(state.post, "kid_pip").get("id", ""), "dragon_fish_reply", "her answer is Pip's to have")
	state.questing.finish_dialogue("kid_pip")
	assert_eq(state.post.step("pip_dragon"), 2)
	assert_does_not_have(_carried(), "dragon_fish_reply")


# ---- The courier's book ---------------------------------------------------------------

func test_each_place_gets_a_page_stamped_the_day_its_first_piece_arrives() -> void:
	_chapter_two()
	assert_eq(Post.pages(state.post, state.world.discovered), ["town", "saltmere", "overworld"] as Array[String],
		"a page for every place the hero has been, waiting for post")
	assert_true(state.post.stamps.is_empty())
	state.world.steps = 2.0 * DayNight.DAY_CYCLE_STEPS
	state.post.bag.assign(["club_ola", "stew_salt"])
	state.posting.deliver("saltmere_ola")
	assert_eq(state.post.stamps, {"saltmere": 2}, "Saltmere stamped on day 2")
	state.world.steps = 5.0 * DayNight.DAY_CYCLE_STEPS
	state.posting.deliver("saltmere_wenna")
	state.posting.deliver("villager_bram")
	assert_eq(state.post.stamps, {"saltmere": 2, "town": 5}, "a page keeps the day it was first stamped")
	assert_eq(Post.delivered_at(state.post, "saltmere"), ["club_ola", "stew_salt"] as Array[String])
	assert_eq(Post.delivered_at(state.post, "town"), ["club_ola_reply"] as Array[String])
	state.settlement.settlers.append("saltmere_wenna")
	assert_eq(Post.delivered_at(state.post, "saltmere"), ["club_ola", "stew_salt"] as Array[String], "Wenna's old letters stay on Saltmere's page when she moves")


func test_a_room_stamps_its_places_page() -> void:
	assert_eq(Post.place_of("town_inn"), "town", "Wenna at Sela's inn: Pixelheim's page")
	assert_eq(Post.place_of("town_smith"), "town", "Fafnyr care of Hilda: Pixelheim's")
	assert_eq(Post.place_of("saltmere"), "saltmere")
	assert_eq(Post.place_of("morvax_forge"), "morvax_forge", "the mountain's own page")
	_chapter_two()
	state.settlement.projects.append("the_inn")
	state.settlement.settlers.append("saltmere_wenna")
	assert_eq(Post.place_for("saltmere_wenna", state.progression, state.settlement), "town")


func test_the_postmarks_are_drawn_the_same_every_time() -> void:
	for entry: Dictionary in Post.book():
		var big := Postmark.image(entry, true, true)
		assert_eq(big.get_size(), Vector2i(Postmark.BIG, Postmark.BIG))
		assert_eq(big.get_data(), Postmark.image(entry, true, true).get_data(), "%s's postmark is the same each time" % entry["place"])
		var inked := 0
		for y in big.get_height():
			for x in big.get_width():
				if big.get_pixel(x, y).a > 0.0:
					inked += 1
		assert_gt(inked, 200, "%s's postmark is inked" % entry["place"])
		assert_lt(inked, Postmark.BIG * Postmark.BIG / 2, "and worn, not a blot")
		var waiting := Postmark.image(entry, false, false)
		assert_eq(waiting.get_size(), Vector2i(Postmark.SMALL, Postmark.SMALL))


# ---- The calm rules -------------------------------------------------------------------

func test_nothing_expires_and_a_day_skipped_costs_nothing() -> void:
	_chapter_two()
	var offered := _offered()
	state.world.steps = 30.0 * DayNight.DAY_CYCLE_STEPS
	assert_eq(_offered(), offered, "a month later the threads still offer what they did: nothing went off")
	assert_eq(_box(30).size(), Post.bag_size(), "and the box is as full")
	state.world.steps = 0.0
	state.posting.take_bag()
	var first := _carried().duplicate()
	state.world.steps = 300.0 * DayNight.DAY_CYCLE_STEPS
	assert_eq(_carried(), first, "what's carried stays carried, a year on")
	var entry := Post.piece(first[0])
	assert_false(state.posting.carried_for(Post.addressee(entry)).is_empty(), "still theirs to have")
	state.posting.deliver(Post.addressee(entry))
	assert_has(state.post.delivered, String(entry["id"]), "handed over as if it were the same morning")


func test_the_box_says_what_it_holds() -> void:
	assert_eq(state.posting.take_bag(), "", "shut before chapter 2: nothing to say")
	_chapter_two()
	assert_string_contains(state.posting.take_bag(), "3")
	assert_eq(state.posting.take_bag(), Text.t("The post box is empty. Fresh post comes in the morning."))


# ---- What is kept ------------------------------------------------------------------

func test_only_what_the_hero_did_is_kept_and_it_comes_back_whole() -> void:
	_chapter_two()
	state.post.bag.assign(["club_ola", "stew_salt"])
	state.post.taken = 0
	state.questing.finish_dialogue("saltmere_ola")
	var kept: Dictionary = state.post.to_dict()
	var text := JSON.stringify(kept, "", false)
	assert_eq(text, '{"bag":["stew_salt","club_ola_reply"],"threads":{"cheese_club":1},"delivered":["club_ola"],"taken":0,"stamps":{"saltmere":0},"places":{"club_ola":"saltmere"},"routes":{"saltmere":{"bram":1}},"signs":{},"lit":{},"hubs":{}}',
		"the satchel, the threads' steps, what's delivered, the day the box was emptied, the courier's book, and the roads it went along (PIX-322)")
	var back := PostState.from_dict(SaveCodec.parse_json(text))
	assert_eq(JSON.stringify(back.to_dict(), "", false), text, "read back, the same")
	assert_eq(JSON.stringify(PostState.from_dict({}).to_dict(), "", false), '{"bag":[],"threads":{},"delivered":[],"taken":-1,"stamps":{},"places":{},"routes":{},"signs":{},"lit":{},"hubs":{}}', "a hero with no post yet")


func test_the_post_is_its_own_section_of_the_save_and_comes_back_whole() -> void:
	assert_false(SaveCodec.to_file(state.to_dict()).has("post"), "a hero with no post yet writes no section")
	assert_true(SaveCodec.reread(state.to_dict()).has("hero"))
	_chapter_two()
	state.post.bag.assign(["club_ola"])
	state.post.taken = 0
	state.questing.finish_dialogue("saltmere_ola")
	var file := SaveCodec.to_file(state.to_dict())
	assert_eq(JSON.stringify(file["post"], "", false), JSON.stringify(state.post.to_dict(), "", false), "the post's own section")
	assert_eq(file["post"]["stamps"], {"saltmere": 0}, "the book's stamps in it")
	var keys: Array = file.keys()
	assert_eq(keys.find("post"), keys.find("world") + 1, "beside the world's")
	var other: Node = autofree(GameStateScript.new())
	other.apply(SaveCodec.reread(state.to_dict()))
	assert_eq(JSON.stringify(other.post.to_dict(), "", false), JSON.stringify(state.post.to_dict(), "", false), "saved and loaded, the same")
	assert_eq(Post.in_box(other.post, 0, other.progression, other.settlement, other.world.discovered), [] as Array[String], "the box still emptied today")
	assert_eq(other.posting.carried_for("villager_bram").get("id", ""), "club_ola_reply", "Ola's reply still for Bram")
	assert_eq(Post.delivered_at(other.post, "saltmere"), ["club_ola"] as Array[String], "and Saltmere's page still holds Ola's wheel")
