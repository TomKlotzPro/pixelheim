extends GutTest
## Deeds (PIX-219): long goals read off the save, each done for good with a
## medal for the shelf, and listed in the journal; since PIX-257 Every
## Letter Delivered and A Full House, and since PIX-319 no depth feats.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _deed(id: String) -> Dictionary:
	return Deeds.all().filter(func(deed: Dictionary) -> bool: return deed["id"] == id)[0]


func test_a_deed_is_done_once_and_brings_its_medal_home() -> void:
	var heard: Array = []
	state.noted.connect(func(lines: Array) -> void: heard.append_array(lines))
	var worn: Array[String] = []
	for item_id: String in Catalog._data()["sets"]["warden"]["pieces"]:
		var piece := InventoryState.create_gear(item_id)
		state.pack.gear.append(piece)
		state.pack.equipped[Catalog.item(item_id)["slot"]] = piece["uid"]
		worn.append(Catalog.item(item_id)["slot"])
	state.pack_changed()
	assert_has(state.progression.deeds, "full_set")
	assert_eq(int(state.pack.items.get("medal_dressed", 0)), 1)
	assert_eq(heard.size(), 1)
	for slot: String in worn:
		state.pack.equipped.erase(slot)
	state.pack_changed()
	assert_has(state.progression.deeds, "full_set", "done stays done")
	assert_eq(int(state.pack.items.get("medal_dressed", 0)), 1, "one medal")
	var saved := {}
	state.progression.write_into(saved)
	assert_eq(ProgressionState.from_dict(saved).deeds, ["full_set"] as Array[String])

func test_each_deed_counts_from_the_save() -> void:
	var hero: HeroState = state.hero
	var pack: InventoryState = state.pack
	var progression: ProgressionState = state.progression
	assert_eq(Deeds.count(_deed("all_hunts"), hero, pack, progression), [0, Hunts.all().size()])
	progression.hunted.assign(Hunts.all().map(func(entry: Dictionary) -> String: return entry["id"]))
	assert_true(Deeds.met(_deed("all_hunts"), hero, pack, progression))
	hero.mastery = {}
	for family: String in Bestiary._data()["familyNames"]:
		hero.mastery[family] = 999
	assert_true(Deeds.met(_deed("all_masteries"), hero, pack, progression))
	for kind: String in Bestiary._data()["monsters"]:
		progression.met[kind] = 1
	assert_true(Deeds.met(_deed("bestiary"), hero, pack, progression))
	for item_id: String in Catalog._data()["sets"]["blackiron"]["pieces"]:
		var piece := InventoryState.create_gear(item_id)
		pack.gear.append(piece)
		pack.equipped[Catalog.item(item_id)["slot"]] = piece["uid"]
	assert_true(Deeds.met(_deed("full_set"), hero, pack, progression), "a whole set worn")


func test_every_medal_is_a_trophy_with_an_icon() -> void:
	var icons: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/puny/icons.json"))["items"]
	for deed: Dictionary in Deeds.all():
		assert_false(Catalog.item(deed["itemId"]).is_empty(), deed["itemId"])
		assert_true(Town.trophy_buffs().has(deed["itemId"]), "%s stands on the shelf" % deed["itemId"])
		assert_true(icons.has(deed["itemId"]), "%s has Shade's art" % deed["itemId"])


## Every Letter Delivered (PIX-257): Maren's five, the fifth to Morvax.
func test_every_letter_delivered() -> void:
	var deed := _deed("all_letters")
	assert_eq(Deeds.count(deed, state.hero, state.pack, state.progression, state.settlement), [0, 5])
	for quest: Dictionary in Letters.all():
		state.progression.quests[quest["id"]] = {"progress": 1, "done": true}
	assert_eq(Deeds.count(deed, state.hero, state.pack, state.progression, state.settlement), [4, 5], "the four across the Reach")
	state.progression.quests[Letters.fifth_quest()["id"]] = {"progress": 1, "done": true}
	assert_true(Deeds.met(deed, state.hero, state.pack, state.progression, state.settlement), "and Morvax's")
	state.pack_changed()
	assert_has(state.progression.deeds, "all_letters")
	assert_eq(int(state.pack.items.get("medal_letters", 0)), 1)


## A Full House (PIX-257): every settler home, the Reach's four and the
## letters' families.
func test_a_full_house() -> void:
	var deed := _deed("full_house")
	var recruits: Array = Npcs._data()["recruits"].map(func(recruit: Dictionary) -> String: return recruit["id"])
	assert_eq(Deeds.count(deed, state.hero, state.pack, state.progression, state.settlement), [0, recruits.size()])
	for id: String in recruits.slice(1):
		state.settlement.settlers.append(id)
	assert_false(Deeds.met(deed, state.hero, state.pack, state.progression, state.settlement), "one bed still empty")
	state.settlement.settlers.append(recruits[0])
	state.pack_changed()
	assert_has(state.progression.deeds, "full_house")
	assert_eq(int(state.pack.items.get("medal_full_house", 0)), 1)


## Seen Them All counts every kind there is to meet: Morvax is no foe now
## (PIX-253 step 8), and his old kind left with the old saves (PIX-319).
func test_the_bestiary_counts_what_can_be_met() -> void:
	var deed := _deed("bestiary")
	assert_false(Bestiary._data()["monsters"].has("lich"), "no Morvax the Deathless to meet")
	for kind: String in Bestiary._data()["monsters"]:
		state.progression.met[kind] = 1
	assert_true(Deeds.met(deed, state.hero, state.pack, state.progression), "every kind there is to meet")
	state.progression.met.erase("boneknight")
	assert_false(Deeds.met(deed, state.hero, state.pack, state.progression), "the Vault's bone knights still to meet")


## The Post's feats (PIX-326): Every Thread Tied counts the threads this
## hero's story has (Morvax writes from one place, his bench or his forge).
func test_every_thread_tied() -> void:
	var deed := _deed("every_thread")
	var untied := Post.threads().filter(func(thread: Dictionary) -> bool: return not thread.has("ending")).size()
	assert_eq(Deeds.count(deed, state.hero, state.pack, state.progression, state.settlement, state.post), [0, untied], "before Morvax's answer, the threads without one")
	state.mark_seen(Story.ending_scene(Homecoming.HOME))
	assert_eq(Deeds.count(deed, state.hero, state.pack, state.progression, state.settlement, state.post), [0, untied + 1], "home: his bench's letters, not his forge's")
	for thread: Dictionary in Post.threads():
		if thread["id"] != "heirlooms":
			state.post.threads[thread["id"]] = (thread["pieces"] as Array).size()
	assert_false(Deeds.met(deed, state.hero, state.pack, state.progression, state.settlement, state.post), "the hoard's heirlooms still to go home")
	state.post.threads["heirlooms"] = (Post.thread("heirlooms")["pieces"] as Array).size()
	state.pack_changed()
	assert_has(state.progression.deeds, "every_thread")
	assert_eq(int(state.pack.items.get("medal_threads", 0)), 1)


## Postmaster of the Reach (PIX-326): fifty pieces delivered, of more than
## fifty the Post has for any hero.
func test_postmaster_of_the_reach() -> void:
	var deed := _deed("postmaster")
	assert_eq(Deeds.count(deed, state.hero, state.pack, state.progression, state.settlement, state.post), [0, 50])
	for n in 49:
		state.post.delivered.append("piece_%d" % n)
	state.pack_changed()
	assert_does_not_have(state.progression.deeds, "postmaster", "one short")
	state.post.delivered.append("piece_49")
	state.pack_changed()
	assert_has(state.progression.deeds, "postmaster")
	assert_eq(int(state.pack.items.get("medal_postmaster", 0)), 1)
	var pieces := 0
	for thread: Dictionary in Post.threads():
		if Post.for_hero(thread, state.progression):
			pieces += (thread["pieces"] as Array).size()
	assert_gte(pieces, 50, "the Post has fifty pieces to carry")


## The Reach Lit (PIX-326): every post road's waystation built, its lamp lit.
func test_the_reach_lit() -> void:
	var deed := _deed("reach_lit")
	var roads := Routes.places().filter(func(place: String) -> bool: return not Routes.station(place).is_empty())
	assert_eq(Deeds.count(deed, state.hero, state.pack, state.progression, state.settlement), [0, roads.size()])
	for place: String in roads.slice(1):
		state.settlement.projects.append(Routes.station(place)["work"])
	assert_false(Deeds.met(deed, state.hero, state.pack, state.progression, state.settlement), "one road still dark")
	state.settlement.projects.append(Routes.station(roads[0])["work"])
	state.pack_changed()
	assert_has(state.progression.deeds, "reach_lit")
	assert_eq(int(state.pack.items.get("medal_reach_lit", 0)), 1)
