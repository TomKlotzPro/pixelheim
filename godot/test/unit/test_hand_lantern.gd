extends GutTest
## The light comes from its sources (PIX-530): no light follows a hero
## without one, the Tin Lantern they carry brings it back (Odo sells it, the
## pack keeps it in the save), Aske keeps it trimmed, and it hangs lit in
## their hand where the frame holds it.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var _items := {}
var _settlers: Array[String] = []
var _steps := 0.0


func before_each() -> void:
	_items = GameState.pack.items.duplicate()
	_settlers = GameState.settlement.settlers.duplicate()
	_steps = GameState.world.steps
	for id: String in Lights.LANTERNS:
		GameState.pack.items.erase(id)
	GameState.settlement.settlers.erase("frost_aske")


func after_each() -> void:
	GameState.pack.items = _items
	GameState.settlement.settlers.assign(_settlers)
	GameState.world.steps = _steps


# --- The item ---------------------------------------------------------------

func test_the_lantern_is_carried_only_when_the_pack_holds_one() -> void:
	assert_false(Lights.carried({}), "no light without one")
	assert_true(Lights.carried({Lights.HAND_LANTERN: 1}))
	assert_false(Lights.carried({Lights.HAND_LANTERN: 0}))
	assert_true(Lights.carried({"lianes_lantern": 1}), "Liane's lights the way too (PIX-535)")


func test_the_tin_lantern_is_a_carried_thing_odo_sells() -> void:
	var item := Catalog.item(Lights.HAND_LANTERN)
	assert_eq(item.get("category", ""), "misc", "carried, not worn: no fight with the shield")
	assert_false(item.get("quest", false), "sold, stored or dropped, its light goes with it")
	assert_eq(Trade.junk_count(Lights.HAND_LANTERN, 1), 0, "\"Sell all junk\" never sells it")
	assert_eq(ItemIcons.source(Lights.HAND_LANTERN), "drawn@lantern", "drawn as the lantern in hand, with or without the paid art")
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
	GameState.pack.add_item("lianes_lantern")
	GameState.pack_changed()
	assert_eq(float(rig.lantern.get_meta("energy")), Lights.LANTERN_ENERGY, "Liane's Lantern burns as Odo's does (PIX-535)")
	assert_almost_eq(rig.lantern.texture_scale, LightRig.lantern_reach(0.33) * 2.0 / Lights.TEXTURE_PX, 0.0001, "trimmed by Aske the same")


## A rig lighting a world on `map`, the hero carrying the lantern.
func _lit_rig(map: String) -> LightRig:
	var world: World = preload("res://test/bare_world.gd").new()
	add_child_autofree(world)
	world.map = MapData.load_by_id(map)
	var hero: Player = preload("res://test/bare_hero.gd").new()
	world.add_child(hero)
	var rig: LightRig = preload("res://scripts/light_rig.gd").new()
	rig.world = world
	world.add_child(rig)
	rig.give_lantern(hero)
	GameState.pack.add_item(Lights.HAND_LANTERN)
	GameState.pack_changed()
	return rig


## The pool burns only with its source in sight (the review: the hero fell
## and lay dead, the lantern put away, the pool still round them).
func test_the_fallen_hero_puts_the_lantern_out() -> void:
	var rig := _lit_rig("seacave")
	var hero := rig.lantern.get_parent() as Player
	rig._process(1.0 / 60.0)
	assert_true(rig.lantern.visible, "carried underground, it burns")
	hero.dead = true
	rig._process(1.0 / 60.0)
	assert_false(rig.lantern.visible, "put away as the hero falls, it goes out")
	hero.dead = false
	rig._process(1.0 / 60.0)
	assert_true(rig.lantern.visible, "back in hand, it burns again")


## Lit only in the real dark (the review: a room's dim day burnt a faint
## pool round a cold glass, the glass in hand reads lantern.visible).
func test_the_lantern_is_out_in_a_room_by_day_and_lit_there_at_night() -> void:
	var rig := _lit_rig("town_shop")
	GameState.world.steps = 0.2 * DayNight.DAY_CYCLE_STEPS
	rig._process(1.0 / 60.0)
	assert_gt(rig.dark, 0.1, "a room is dim by day")
	assert_false(rig.lantern.visible, "but no lantern is lit by day")
	GameState.world.steps = Prologue.night_steps()
	rig._process(1.0 / 60.0)
	assert_true(rig.lantern.visible, "lit in the room at night")


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
			var shown := column < 4 or (column >= 18 and column <= 20)
			assert_eq(not hand.is_empty(), shown, "row %d column %d: in hand standing, walking or hurt, put away otherwise" % [row, column])
			if hand.is_empty():
				continue
			var at: Vector2i = hand["at"]
			assert_true(Rect2i(0, 0, 32, 32).encloses(Rect2i(at, size)), "row %d column %d: never cut by the cell" % [row, column])
			assert_lte(at.y + size.y, PunyArt._figure(row * 24 + column).end.y, "row %d column %d: never below the feet" % [row, column])


## Held, never floating a pixel off the hand (the review: mid-step the arm
## swings but the figure's box stands still): in every frame it shows, an
## inked pixel of the lantern overlaps or shares an edge with the bare
## figure's, the template every hero is dressed over.
func test_the_lantern_touches_the_figure_in_every_frame() -> void:
	var template: Image = (load(PunyArt.path(PunyArt.BASE)) as Texture2D).get_image()
	for row in 8:
		for column in 24:
			var hand := PunyArt.held_at(row, column)
			if hand.is_empty():
				continue
			var frame := template.get_region(Rect2i(column * 32, row * 32, 32, 32))
			var gap := 99
			for y in LampArt.HAND.size():
				var line := String(LampArt.HAND[y])
				for x in line.length():
					if line[x] == ".":
						continue
					var p: Vector2i = hand["at"] + Vector2i(x, y)
					for fy in 32:
						for fx in 32:
							if frame.get_pixel(fx, fy).a > 0.0:
								gap = mini(gap, absi(fx - p.x) + absi(fy - p.y))
			assert_lte(gap, 1, "row %d column %d: in the hand, not beside it" % [row, column])


## Never on the shield's side (the review's down-left, row 7, hung both on
## the screen-left hand): where both are drawn in front, they hang either
## side of the figure's middle. A shield's x is its middle, the lantern's
## its left column.
func test_the_lantern_never_hangs_on_the_shield_side() -> void:
	var half := String(LampArt.HAND[0]).length() / 2
	for row in 8:
		var shield: Array = PunyArt.SHIELD_AT[row - row % 2]
		var lantern: Array = PunyArt.LANTERN_AT[row]
		if shield[2] and lantern[2]:
			assert_ne(signf(float(shield[0])), signf(float(int(lantern[0]) + half)), "row %d: the lantern in the hand away from the shield" % row)


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


## PIX-535: Shade's tile for it read as a small brazier, half the size of
## its neighbours in Odo's list. Drawn in his palette at an icon's size:
## iron round blue glass, a flame in it, most of the cell filled.
func test_the_shop_icon_is_the_lantern_in_hand_at_icon_size() -> void:
	var icon := ItemIcons.texture(Lights.HAND_LANTERN)
	assert_not_null(icon, "there without the paid art")
	assert_eq(icon.get_size(), Vector2(16, 16))
	var inked := icon.get_image().get_used_rect()
	assert_gte(inked.size.x, 12, "as wide as its neighbours")
	assert_gte(inked.size.y, 13, "and as tall")
	var keys := "".join(PackedStringArray(LampArt.ICON))
	for key: String in keys.replace(".", ""):
		assert_true(LampArt.PALETTE.has(key), "%s is Shade's" % key)
	for key: String in "".join(PackedStringArray(LampArt.HAND + LampArt.HAND_LIT)).replace(".", ""):
		assert_true(key in keys, "%s of the lantern in hand is in its icon" % key)
