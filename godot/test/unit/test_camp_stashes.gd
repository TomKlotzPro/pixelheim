extends GutTest
## The camps' stashes (PIX-453): every day camp hides one and nothing else
## does; each find is small, each note a line or two of the message's plate
## in English and French; each stands beside its tent, off the pack's own
## square; out once its pack is cleared, gone with the pack back unopened,
## there for good once opened, and it opens once.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## The most a find is worth: a health potion or two, a little gold.
const SMALL := 60


static func _wild_maps() -> Array[String]:
	var out: Array[String] = []
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if String(spawn["mapId"]) not in out:
			out.append(String(spawn["mapId"]))
	return out


func test_every_day_camp_hides_a_stash_beside_its_tent() -> void:
	var camped: Array[String] = []
	for map_id in _wild_maps():
		var map := MapData.load_by_id(map_id)
		var camps := CampsLayer.plan_camps(map)
		var cells := CampStashes.plan_on(map, camps)
		var apart := {}
		for cell: Vector2i in cells.values():
			apart[cell] = true
		assert_eq(apart.size(), cells.size(), "%s: one stash to a cell" % map_id)
		for tent: Vector2i in camps:
			var spawn_id := String(camps[tent].get("spawn", ""))
			if spawn_id == "":
				continue
			camped.append(spawn_id)
			assert_true(cells.has(spawn_id), "%s's camp has its stash" % spawn_id)
			if not cells.has(spawn_id):
				continue
			var cell: Vector2i = cells[spawn_id]
			var spawn: Dictionary = Bestiary.spawns_on(map_id).filter(func(row: Dictionary) -> bool: return row["id"] == spawn_id)[0]
			var home := Vector2i(spawn["x"], spawn["y"])
			assert_eq(maxi(absi(cell.x - home.x), absi(cell.y - home.y)), 2, "%s's stash off its pack's square" % spawn_id)
			assert_lte(maxi(absi(cell.x - tent.x), absi(cell.y - tent.y)), 2, "%s's stash by its tent" % spawn_id)
			assert_true(map.is_walkable(cell) and not map.portals.has(cell) and not camps.has(cell), "%s's stash on open ground" % spawn_id)
	camped.sort()
	var listed: Array[String] = []
	listed.assign(CampStashes.stashes().keys())
	listed.sort()
	assert_eq(listed, camped, "a stash for every day camp, and only for one")


## Drawn as the game draws a map (MapView.plan): out of the way of what
## its props, bushes and the Post's pieces cover.
func test_a_stash_finds_its_place_among_what_the_map_draws() -> void:
	var placed := 0
	for map_id in _wild_maps():
		var map := MapData.load_by_id(map_id)
		var view := MapView.new(map, null)
		view.plan(map.spawn)
		placed += view.get_meta(CampStashes.META, {}).size()
	assert_eq(placed, CampStashes.stashes().size(), "every camp's stash finds its place")


func test_each_find_is_small_and_known() -> void:
	for spawn_id: String in CampStashes.stashes():
		var loot: Dictionary = CampStashes.chest(spawn_id)["loot"]
		if loot["kind"] == "gold":
			assert_lte(int(loot["amount"]), SMALL, "%s's gold" % spawn_id)
			continue
		assert_eq(loot["kind"], "item", "%s: no gear" % spawn_id)
		var item := Catalog.item(String(loot["itemId"]))
		assert_false(item.is_empty() or item.has("slot"), "%s: a known item, not a piece to wear" % spawn_id)
		assert_lte(int(item.get("value", 0)) * int(loot["qty"]), SMALL, "%s's find" % spawn_id)


## Tom dislikes big text boxes: a line or two of the plate, in either language.
func test_each_note_is_a_line_or_two_in_english_and_french() -> void:
	var locale := TranslationServer.get_locale()
	for lang: String in ["en", "fr"]:
		TranslationServer.set_locale(lang)
		for spawn_id: String in CampStashes.stashes():
			var english := String(CampStashes.chest(spawn_id)["said"])
			var said := Text.t(english)
			if lang == "fr":
				assert_ne(said, english, "%s's note in French" % spawn_id)
			var wide := UiStyle.body_font().get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.reading(16)).x
			assert_lte(wide, Messages.MESSAGE_WIDTH * 2.0, "%s: %s" % [spawn_id, said])
	TranslationServer.set_locale(locale)


func test_out_once_cleared_and_open_for_good() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	assert_false(CampStashes.shown(state.world, "mire_2"), "hidden while the pack stands")
	state.spoils.clear_pack("mire_2")
	assert_true(CampStashes.shown(state.world, "mire_2"), "out once it's cleared")
	state.spoils.revive_pack("mire_2")
	assert_false(CampStashes.shown(state.world, "mire_2"), "gone with the pack back, unopened")
	state.spoils.clear_pack("mire_2")
	var gold: int = state.pack.gold
	var opened: Dictionary = state.spoils.open_chest(CampStashes.chest("mire_2"))
	assert_true(opened["opened"])
	assert_eq(state.pack.gold, gold + 30, "its find")
	assert_string_contains(opened["message"], "rota", "and its note")
	state.spoils.wake_the_wilds()
	assert_true(CampStashes.shown(state.world, "mire_2"), "open for good, the pack back or not")
	state.spoils.clear_pack("mire_2")
	assert_false(state.spoils.open_chest(CampStashes.chest("mire_2"))["opened"], "it opens once")
