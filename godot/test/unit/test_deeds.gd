extends GutTest
## Deeds (PIX-219): long goals read off the save, each done for good with a
## medal for the shelf, and listed in the journal; since PIX-257 Every
## Letter Delivered and A Full House, and the depth feats retired.

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


## Ten Below and Thirty Below retired with the Deep Hunt (PIX-257): never
## earned now, but a hero who earned one keeps it in the journal, medal and
## all.
func test_the_depth_feats_retire_but_stay_with_who_earned_them() -> void:
	var shown := func() -> Array: return Deeds.shown(state.progression).map(func(deed: Dictionary) -> String: return deed["id"])
	assert_does_not_have(shown.call(), "deep_10", "not to a new hero")
	assert_does_not_have(Deeds.in_play().map(func(deed: Dictionary) -> String: return deed["id"]), "deep_30")
	# An old save deep in the Hunt: no new medal comes of it.
	state.progression.deepest = 40
	state.pack_changed()
	assert_does_not_have(state.progression.deeds, "deep_10", "the depths earn nothing now")
	assert_eq(int(state.pack.items.get("medal_ten_below", 0)), 0)
	# One who earned it before keeps it.
	state.progression.deeds.append("deep_10")
	assert_has(shown.call(), "deep_10")
	assert_does_not_have(shown.call(), "deep_30", "only what they earned")
	assert_eq(Deeds.count(_deed("deep_10"), state.hero, state.pack, state.progression), [1, 1], "and it reads done")
	assert_true(Town.trophy_buffs().has("medal_ten_below"), "its medal still stands on the shelf")


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


## The late web hero beat Morvax before the letters were written: their
## story is told, and their satchel counts as delivered.
func test_an_old_hero_who_went_all_the_way_has_delivered_them_all() -> void:
	for relic: Dictionary in Relics.all():
		state.progression.hunted.append(relic["named"])
	state.progression.cleared_levels.append(15)
	assert_true(Deeds.met(_deed("all_letters"), state.hero, state.pack, state.progression, state.settlement))


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


## Seen Them All counts what can still be met: Morvax is no foe now (PIX-253
## step 8), so his kind counts only for a hero who fought him.
func test_the_bestiary_counts_what_can_be_met() -> void:
	var deed := _deed("bestiary")
	for kind: String in Bestiary._data()["monsters"]:
		if kind != "lich":
			state.progression.met[kind] = 1
	assert_true(Deeds.met(deed, state.hero, state.pack, state.progression), "every kind there is to meet")
	state.progression.met.erase("boneknight")
	assert_false(Deeds.met(deed, state.hero, state.pack, state.progression), "the Vault's bone knights still to meet")
	state.progression.met["boneknight"] = 1
	state.progression.met["lich"] = 15
	var counted := Deeds.count(deed, state.hero, state.pack, state.progression)
	assert_eq(counted[0], counted[1], "one who met Morvax counts him too")
