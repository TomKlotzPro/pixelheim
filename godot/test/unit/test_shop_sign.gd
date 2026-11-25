extends GutTest
## Shop signs (PIX-134, redrawn in PIX-553): every town sign hangs a board of
## its own from a wrought-iron bracket at the eave, the trade's icon painted
## on it in its own colours, swinging in the wind; the nameplate names the
## place and its keeper from the game's own data.


func test_every_town_sign_has_a_trade_icon() -> void:
	for owned: bool in [false, true]:
		for sign_def: Dictionary in Interactables.signs_on("town", owned):
			assert_true(ShopSign.ICONS.has(sign_def["label"]), "%s has an icon" % sign_def["label"])


func test_nameplates_name_the_place_and_its_keeper() -> void:
	assert_eq(ShopSign.about("GOODS", "town_shop", false), {"name": "Odo's Emporium", "about": "Merchant Odo"})
	assert_eq(ShopSign.about("FORGE", "town_smith", false), {"name": "Hilda's Smithy", "about": "Smith Hilda"})
	assert_eq(ShopSign.about("BREWS", "town_alchemist", false), {"name": "Vex's Workshop", "about": "Alchemist Vex"})
	assert_eq(ShopSign.about("INN", "town_inn", false), {"name": "The Inn", "about": "Innkeeper Sela"})
	assert_eq(ShopSign.about("HALL", "town_hall", false), {"name": "Town Hall", "about": "Mayor Aldric"})


func test_the_house_is_for_sale_then_home() -> void:
	var sale := ShopSign.about("FOR SALE", "", false)
	assert_eq(sale["name"], "For sale")
	assert_string_contains(sale["about"], "%dg" % int(Town._data()["houseDeedCost"]))
	assert_eq(ShopSign.about("HOME", "", true), {"name": "Home", "about": "Your house"})


## PIX-196: in French the boards keep their icons (the label is an id).
func test_a_sign_keeps_its_icon_in_another_language() -> void:
	TranslationServer.set_locale("fr")
	Text.forget()
	for sign_def: Dictionary in Interactables._data()["signs"]["town"]:
		assert_true(ShopSign.ICONS.has(sign_def["label"]), "%s keeps its icon" % sign_def["label"])
	assert_ne(Catalog.item_name("bread"), "Bread", "the rest of the data does speak French")
	Text.apply("en")


## PIX-543: Odo's plate, over a door near the top of the screen, was cut by
## the edge. The whole plate stays on the canvas; elsewhere it stands over
## its door as it did.
func test_a_doors_plate_keeps_to_the_screen() -> void:
	var view := Vector2(1280, 720)
	var plate := Vector2(190, 72)
	assert_eq(Hud.plate_spot(Vector2(640, 300), plate, view), Vector2(545, 228), "over its door")
	assert_eq(Hud.plate_spot(Vector2(640, 60), plate, view).y, Hud.PLATE_EDGE, "pushed down under the top edge")
	assert_eq(Hud.plate_spot(Vector2(20, 300), plate, view).x, Hud.PLATE_EDGE, "and in from the left")
	assert_eq(Hud.plate_spot(Vector2(1270, 300), plate, view).x, 1280 - 190 - Hud.PLATE_EDGE, "and from the right")


## PIX-553: every sign has a look of its own, a board drawn in its shape
## under its two chains, never smaller than the old 22x20 board, and no two
## signs hang the same board.
func test_every_sign_has_its_own_board() -> void:
	var seen := {}
	for label: String in ShopSign.ICONS:
		assert_true(ShopSign.LOOKS.has(label), "%s has a look" % label)
		var look: Dictionary = ShopSign.LOOKS[label]
		var rows: Array = ShopSign.SHAPES[look["shape"]]
		var art := ShopSign.board_image(look)
		assert_eq(art.get_size(), Vector2i(ShopSign.BOARD.x, int(look["drop"]) + rows.size()), "%s: its chains then its board" % label)
		assert_true(ShopSign.BOARD.x >= 22 and rows.size() >= 20, "%s: as big as the old board at least" % label)
		assert_lte(art.get_height(), ShopSign.HINGE_UP, "%s ends over the door" % label)
		assert_lte(rows.size(), ShopSign.BOARD.y)
		for x: int in ShopSign.CHAINS:
			assert_gt(art.get_pixel(x, 0).a, 0.5, "%s: a chain on the hinge" % label)
		var middle := Vector2i(ShopSign.BOARD.x / 2, int(look["drop"]) + rows.size() / 2)
		assert_eq(art.get_pixelv(middle).a, 1.0, "%s: wood under the icon" % label)
		# A dark outline round the shape: the first wood down the middle.
		assert_eq(art.get_pixel(middle.x, int(look["drop"])).to_html(), ShopSign.RIM.to_html(), "%s: outlined" % label)
		var key := "%s %s" % [look["shape"], look["wood"]]
		assert_false(seen.has(key), "%s hangs a board of its own" % label)
		seen[key] = label
	assert_eq(ShopSign.board_texture("INN"), ShopSign.board_texture("INN"), "drawn once")


## Each icon is painted on its board's field, in its own colours: every
## pixel of its drawing on the wood (never the outline or past it), in the
## board's middle.
func test_each_icon_is_painted_on_the_wood() -> void:
	if not ShopSign.available():
		pass_test("the doors stand bare without the paid pack")
		return
	var sheet := (load(PunyTown.SHEET) as Texture2D).get_image()
	for label: String in ShopSign.ICONS:
		var look: Dictionary = ShopSign.LOOKS[label]
		var board := ShopSign.board_image(look)
		var tile: int = ShopSign.ICONS[label]
		var icon := sheet.get_region(Rect2i((tile % PunyTown.COLUMNS) * 16, (tile / PunyTown.COLUMNS) * 16, 16, 16))
		var at: Vector2i = (look["icon"] as Vector2i) + Vector2i(0, int(look["drop"]))
		for y in 16:
			for x in 16:
				if icon.get_pixel(x, y).a < 0.5:
					continue
				var on := at + Vector2i(x, y)
				assert_true(on.y < board.get_height() and board.get_pixelv(on).a == 1.0 and board.get_pixelv(on).to_html() != ShopSign.RIM.to_html(), "%s: its icon on the wood at %s" % [label, on])
		var used := icon.get_used_rect()
		var middle := Vector2(at) + Vector2(used.position) + Vector2(used.size) / 2.0
		var field := Vector2(ShopSign.BOARD.x / 2.0, (board.get_height() + int(look["drop"])) / 2.0)
		assert_almost_eq(middle.x, field.x, 0.5, "%s: in the middle across" % label)
		# A little higher on a shield or a tun, whose foot narrows.
		assert_almost_eq(middle.y, field.y, 2.0, "%s: and down" % label)


## The bracket: a plate on the wall, the arm over the board, a curl past it.
func test_the_bracket_reaches_over_the_board() -> void:
	var art := ShopSign.bracket_texture().get_image()
	assert_eq(art.get_width() % 2, 0, "flipped about the door's middle")
	var arm := ShopSign.ARM_ROWS - 1
	for x: int in ShopSign.CHAINS:
		assert_gt(art.get_pixel(art.get_width() / 2 - ShopSign.BOARD.x / 2 + x, arm).a, 0.5, "the arm over each chain")
	assert_gt(art.get_pixel(0, art.get_height() - 2).a, 0.5, "its plate down the wall")
	assert_gt(art.get_used_rect().end.x, art.get_width() / 2 + ShopSign.BOARD.x / 2, "its curl past the board")
	assert_eq(art.get_used_rect().position.y, 0, "the curl's top: ShopSign.HIGH over the door, the nameplate over it")


## With the paid pack each town sign is built whole, hung where the old
## board was: the bracket at the eave over the door, its board and icon
## under the arm, what hangs wearing the sway, all answering to the signs'
## own light.
func test_each_sign_gets_its_board_bracket_and_icon() -> void:
	if not ShopSign.available():
		pass_test("the doors stand bare without the paid pack")
		return
	for owned: bool in [false, true]:
		for sign_def: Dictionary in Interactables.signs_on("town", owned):
			var label: String = sign_def["label"]
			var door := Vector2i(int(sign_def["x"]), int(sign_def["y"]))
			var built := ShopSign.build(label, door)
			var bracket := built.get_node("bracket") as Sprite2D
			var board := built.get_node("board") as Sprite2D
			var icon := built.get_node("icon") as Sprite2D
			assert_eq(bracket.texture, ShopSign.bracket_texture(), "%s: the bracket" % label)
			assert_eq(bracket.flip_h, not ShopSign.LOOKS[label]["left"])
			assert_eq(bracket.material, Relief.material(Relief.DOMED, false), "%s: iron rimmed as a prop" % label)
			assert_eq(board.texture, ShopSign.board_texture(label), "%s: its own board" % label)
			assert_eq(board.material, ShopSign.sway_material(true), "%s: the board swings, rimmed" % label)
			assert_eq(icon.material, ShopSign.sway_material(false), "%s: the icon swings with it, no edge" % label)
			var region := icon.texture as AtlasTexture
			var tile: int = ShopSign.ICONS[label]
			assert_eq(region.region, Rect2((tile % PunyTown.COLUMNS) * 16, (tile / PunyTown.COLUMNS) * 16, 16, 16), "%s: its trade's icon" % label)
			for piece: Sprite2D in [bracket, board, icon]:
				assert_true(piece.light_mask & Lights.SIGN != 0, "%s: lit by its door's lantern" % label)
				assert_eq(piece.offset, piece.offset.round(), "%s: on whole pixels" % label)
				assert_eq(piece.scale, Vector2.ONE, "%s: never scaled" % label)
			assert_eq(built.position, Vector2(door.x * 16 + 8, door.y * 16 - ShopSign.HINGE_UP), "%s: hinged at the eave over its door" % label)
			assert_eq(built.position.y + bracket.position.y, door.y * 16.0 - ShopSign.HIGH, "%s: its curl ShopSign.HIGH over the door" % label)
			var foot := built.position.y + board.offset.y + board.texture.get_height()
			assert_true(foot < door.y * 16.0 and foot >= door.y * 16.0 - 5, "%s: its foot just over the door, as the old board's" % label)
			built.free()


## Without the paid pack the doors stand bare: no sign and no plate.
func test_without_the_pack_the_doors_stand_bare() -> void:
	var map := MapData.load_by_id("town")
	var actors := Node2D.new()
	var view := MapView.new(map, actors)
	var withheld := PunyTown.withheld
	PunyTown.withheld = true
	var bare := view._build_props(map)
	assert_eq(bare.get_child_count(), 0, "no sign over any door")
	assert_eq(view.door_signs, [], "and none to light or name")
	bare.free()
	PunyTown.withheld = withheld
	actors.free()


## A burnt house has lost its sign with its roof (PIX-146).
func test_burnt_houses_have_no_sign() -> void:
	var signs := Interactables.signs_on("town")
	assert_eq(ShopSign.standing(signs, []).size(), signs.size(), "every sign in a whole town")
	var ashes := ShopSign.standing(signs, Town.ruins([]))
	assert_lt(ashes.size(), signs.size(), "none on the Ashes' ruins")
	for ruin: Dictionary in Town.ruins([]):
		for sign_def: Dictionary in ashes:
			assert_false((ruin["rect"] as Rect2i).has_point(Vector2i(int(sign_def["x"]), int(sign_def["y"]))))
	var labels := func(left: Array) -> Array: return left.map(func(sign_def: Dictionary) -> String: return sign_def["label"])
	assert_does_not_have(labels.call(ashes), "INN", "Sela's inn burnt")
	assert_has(labels.call(ShopSign.standing(signs, Town.ruins(["the_inn"]))), "INN", "and its sign back with its roof")


## The sway is the world's wind alone (shaders/sign.gdshader): with Reduce
## motion the LightRig drops the wind to nothing and the signs hang still;
## a storm's wind swings them more.
func test_reduce_motion_stills_the_sway() -> void:
	var code := FileAccess.get_file_as_string("res://shaders/sign.gdshader")
	var vertex := code.substr(code.find("void vertex()"), code.find("void fragment()") - code.find("void vertex()"))
	assert_string_contains(vertex, "wind_lean(hinge, phase)", "the gust, world_wind times its lean")
	assert_string_contains(vertex, "0.5 * world_wind * ", "and the swing under it")
	assert_false(vertex.contains("TIME"), "on the world's clock alone, stopped with the game")
	var was: bool = GameState.settings.reduce_motion
	var rig := LightRig.new()
	GameState.settings.reduce_motion = true
	rig.tick(0.1)
	assert_eq(rig.wind, 0.0, "no wind with Reduce motion")
	GameState.settings.reduce_motion = false
	rig.tick(0.1)
	assert_eq(rig.wind, 1.0, "a breeze")
	rig.gale = 1.0
	rig.tick(0.1)
	assert_gt(rig.wind, 1.0, "more in a storm")
	GameState.settings.reduce_motion = was
	rig.gale = 0.0
	rig.tick(0.0)
	rig.free()


## At night a door's lantern lights the sign by it and that sign alone, with
## a light of the signs' own bit, steady (the night's shadows cast from
## flames alone); a door with no lantern keeps its sign dark, and a
## signpost's entry (no node) is passed over.
func test_a_doors_lantern_lights_its_sign() -> void:
	var board := Node2D.new()
	var signs := [{"door": Vector2i(30, 10), "node": board}, {"door": Vector2i(32, 10), "node": null}]
	var halo := Node2D.new()
	ShopSign.light(signs, Vector2i(34, 10), halo)
	ShopSign.light(signs, Vector2i(31, 11), halo)
	assert_eq(halo.get_child_count(), 0, "a lantern down the street lights no sign")
	ShopSign.light(signs, Vector2i(31, 10), halo)
	assert_eq(halo.get_child_count(), 1, "the one by the door does, the signpost's none")
	var lamp := halo.get_child(0) as PointLight2D
	assert_eq(lamp.range_item_cull_mask, Lights.SIGN, "the signs alone: nothing of the ground's budget")
	assert_false(lamp.get_meta("flicker", false), "steady: no flame for the shadows")
	assert_eq(Lights.SIGN & (NightShadows.LAMP | NightShadows.SKY | NightShadows.LANTERN), 0, "and no lamp's shadow falls on a sign")
	board.free()
	halo.free()
