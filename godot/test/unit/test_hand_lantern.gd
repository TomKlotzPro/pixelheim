extends GutTest
## The light comes from its sources (PIX-530): no light follows a hero
## without one, the Tin Lantern they carry brings it back (Odo sells it, the
## pack keeps it in the save), Aske keeps it trimmed, and it hangs lit in
## their hand where the frame holds it.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var _items := {}
var _settlers: Array[String] = []


func before_each() -> void:
	_items = GameState.pack.items.duplicate()
	_settlers = GameState.settlement.settlers.duplicate()
	GameState.pack.items.erase(Lights.HAND_LANTERN)
	GameState.settlement.settlers.erase("frost_aske")


func after_each() -> void:
	GameState.pack.items = _items
	GameState.settlement.settlers.assign(_settlers)


# --- The item ---------------------------------------------------------------

func test_the_lantern_is_carried_only_when_the_pack_holds_one() -> void:
	assert_false(Lights.carried({}), "no light without one")
	assert_true(Lights.carried({Lights.HAND_LANTERN: 1}))
	assert_false(Lights.carried({Lights.HAND_LANTERN: 0}))


func test_the_tin_lantern_is_a_carried_thing_odo_sells() -> void:
	var item := Catalog.item(Lights.HAND_LANTERN)
	assert_eq(item.get("category", ""), "misc", "carried, not worn: no fight with the shield")
	assert_false(item.get("quest", false), "sold, stored or dropped, its light goes with it")
	assert_eq(Trade.junk_count(Lights.HAND_LANTERN, 1), 0, "\"Sell all junk\" never sells it")
	assert_eq(ItemIcons.source(Lights.HAND_LANTERN), "medieval@1902", "the small twin of Liane's lantern")
	assert_has(Economy.shop_stock("odo", 1), Lights.HAND_LANTERN, "on Odo's shelf from the first stage")


# --- The LightRig -----------------------------------------------------------

func _rig() -> LightRig:
	var hero: Player = autofree(preload("res://test/bare_hero.gd").new())
	var rig: LightRig = autofree(preload("res://scripts/light_rig.gd").new())
	rig.give_lantern(hero)
	return rig


func test_no_light_follows_a_hero_with_none_and_the_lantern_brings_it() -> void:
	var rig := _rig()
	assert_eq(float(rig.lantern.get_meta("energy")), 0.0, "no light follows a hero with none")
	GameState.pack.add_item(Lights.HAND_LANTERN)
	GameState.pack_changed()
	assert_eq(float(rig.lantern.get_meta("energy")), Lights.LANTERN_ENERGY, "bought, it burns as the lantern always did")
	GameState.settlement.settlers.append("frost_aske")
	GameState.settlers_changed.emit()
	assert_almost_eq(rig.lantern.texture_scale, LightRig.lantern_reach(0.33) * 2.0 / Lights.TEXTURE_PX, 0.0001, "Aske keeps it trimmed")
	GameState.pack.remove_item(Lights.HAND_LANTERN)
	GameState.pack_changed()
	assert_eq(float(rig.lantern.get_meta("energy")), 0.0, "sold, its light goes")


# --- The save ---------------------------------------------------------------

func test_the_lantern_is_kept_in_the_save() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.pack.add_item(Lights.HAND_LANTERN)
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.reread(state.to_dict()))
	assert_true(Lights.carried(reloaded.pack.items), "in the pack, no field of its own")


# --- The art ----------------------------------------------------------------

func test_the_lantern_hangs_in_the_hand_inside_the_cell() -> void:
	var size := Vector2i(String(LampArt.HAND[0]).length(), LampArt.HAND.size())
	for row in 8:
		for column in 24:
			var hand := PunyArt.held_at(row, column)
			var shown := column < 4 or (column >= 18 and column < 21)
			assert_eq(not hand.is_empty(), shown, "row %d column %d: in hand standing, walking or hurt, put away otherwise" % [row, column])
			if hand.is_empty():
				continue
			var at: Vector2i = hand["at"]
			assert_true(Rect2i(0, 0, 32, 32).encloses(Rect2i(at, size)), "row %d column %d: never cut by the cell" % [row, column])
			assert_lte(at.y + size.y, PunyArt._figure(row * 24 + column).end.y, "row %d column %d: never below the feet" % [row, column])


func test_the_glass_lights_only_where_the_glass_is() -> void:
	assert_eq(LampArt.HAND_LIT.size(), LampArt.HAND.size())
	var lit := 0
	for y in LampArt.HAND.size():
		var cold := String(LampArt.HAND[y])
		var glass := String(LampArt.HAND_LIT[y])
		assert_eq(glass.length(), cold.length())
		for x in glass.length():
			if glass[x] != ".":
				lit += 1
				assert_true(cold[x] in ["G", "g"], "the light at (%d, %d) lies on the glass" % [x, y])
	assert_gt(lit, 0)
	for key: String in "".join(PackedStringArray(LampArt.HAND + LampArt.HAND_LIT)).replace(".", ""):
		assert_true(LampArt.PALETTE.has(key), "%s is Shade's" % key)
