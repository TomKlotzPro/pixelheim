extends GutTest
## Deeds (PIX-219): long goals read off the save, each done for good with a
## medal for the shelf, and listed in the journal.

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
	state.progression.deepest = 10
	state._pack_changed()
	assert_has(state.progression.deeds, "deep_10")
	assert_eq(int(state.pack.items.get("medal_ten_below", 0)), 1)
	assert_eq(heard.size(), 1)
	state.progression.deepest = 9
	state._pack_changed()
	assert_has(state.progression.deeds, "deep_10", "done stays done")
	assert_eq(int(state.pack.items.get("medal_ten_below", 0)), 1, "one medal")
	var saved := {}
	state.progression.write_into(saved)
	assert_eq(ProgressionState.from_dict(saved).deeds, ["deep_10"] as Array[String])


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
