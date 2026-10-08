extends GutTest
## Worn gear drawn on the hero (PIX-129): a helmet is another of Shade's
## sheets' heads and armour another's body, cut at the neck in every frame.


func test_nothing_drawable_worn_keeps_the_look() -> void:
	var plain := PunyArt.hero("warrior", 0)
	# An iron sword is Shade's own blade: nothing to recolour.
	var spec := PunyArt.dressed("warrior", 0, {"weapon": "iron_sword", "ring1": "band_of_grit"})
	assert_eq(spec["sheet"], plain["sheet"])
	assert_false(spec.has("head"))


func test_the_weapon_in_hand_is_the_weapon_swung() -> void:
	# PIX-172: the attack follows the weapon, not the role.
	assert_eq(PunyArt.dressed("warrior", 0, {"weapon": "hunting_bow"})["attack"], "bow")
	assert_eq(PunyArt.dressed("mage", 0, {"weapon": "war_hammer"})["attack"], "sword")
	assert_eq(PunyArt.dressed("ranger", 0, {"weapon": "shadow_dagger"})["attack"], "sword", "a dagger slashes")
	assert_eq(PunyArt.dressed("ranger", 0, {"weapon": "arch_staff"})["attack"], "staff")
	assert_eq(PunyArt.dressed("cleric", 0, {})["attack"], "staff", "bare hands keep the role's own")
	for item_id: String in Catalog._data()["items"]:
		var item: Dictionary = Catalog.item(item_id)
		if item.get("slot", "") == "weapon":
			assert_true(PunyArt.WEAPON_ATTACKS.has(item["sprite"]), "%s swings something" % item_id)


func test_a_coloured_weapon_recolours_the_blade_and_nothing_else() -> void:
	var spec := PunyArt.dressed("warrior", 0, {"weapon": "dragonbane"})
	assert_ne(spec["sheet"], PunyArt.hero("warrior", 0)["sheet"], "dragonbane has its own colour")
	var sheet := PunyArt.outfit_texture(spec["head"], spec["body"], spec["weapon_tint"]).get_image()
	var plain: Image = (load(PunyArt.path(spec["body"])) as Texture2D).get_image()
	var changed := 0
	for cell: Vector2i in PunyArt._weapon_mask():
		if sheet.get_pixelv(cell) != plain.get_pixelv(cell):
			changed += 1
	assert_gt(changed, 50, "the blade takes the colour")
	# The idle and walk columns are untouched.
	for y in range(0, 32):
		for x in range(0, 4 * 32):
			if sheet.get_pixel(x, y) != plain.get_pixel(x, y):
				fail_test("idle pixel %d,%d changed" % [x, y])
				return


func test_casters_start_with_a_staff() -> void:
	var state: Node = autofree(preload("res://scripts/state/game_state.gd").new())
	for role_id: String in ["mage", "cleric", "necromancer"]:
		state.new_game("Robin", role_id)
		assert_eq(state.pack.worn_items().get("weapon", ""), "apprentice_staff", role_id)


func test_a_helmet_brings_its_head_and_keeps_the_body() -> void:
	var spec := PunyArt.dressed("mage", 1, {"head": "iron_helm"})
	assert_eq(spec["head"], PunyArt.HEADS["iron_helm"])
	assert_eq(spec["body"], PunyArt.hero("mage", 1)["sheet"])
	assert_eq(spec["attack"], "staff", "a mage in a helm still casts")


func test_armour_brings_its_body() -> void:
	var spec := PunyArt.dressed("ranger", 0, {"body": "iron_armor", "head": "leather_cap"})
	assert_eq(spec["body"], PunyArt.BODIES["iron_armor"])
	assert_eq(spec["head"], PunyArt.HEADS["leather_cap"])


func test_every_drawn_piece_is_real_gear_with_a_sheet() -> void:
	for table: Dictionary in [PunyArt.HEADS, PunyArt.BODIES]:
		for item_id: String in table:
			assert_false(Catalog.item(item_id).is_empty(), "%s is an item" % item_id)
			assert_true(ResourceLoader.exists(PunyArt.path(table[item_id])), "%s has its sheet" % item_id)
	for item_id: String in PunyArt.HEADS:
		assert_eq(Catalog.item(item_id).get("slot", ""), "head")
	for item_id: String in PunyArt.BODIES:
		assert_eq(Catalog.item(item_id).get("slot", ""), "body")


func test_the_outfit_is_the_head_above_the_neck_and_the_body_below() -> void:
	var head_path := PunyArt.HEADS["iron_helm"]
	var body_path := PunyArt.BODIES["mage_robe"]
	var outfit := PunyArt.outfit_texture(head_path, body_path).get_image()
	var heads: Image = (load(PunyArt.path(head_path)) as Texture2D).get_image()
	var bodies: Image = (load(PunyArt.path(body_path)) as Texture2D).get_image()
	assert_eq(outfit.get_size(), bodies.get_size())
	# The first frame facing down: its head ends seven rows below its top.
	var base: Image = (load(PunyArt.path(PunyArt.BASE)) as Texture2D).get_image()
	var top := base.get_region(Rect2i(0, 0, 32, 32)).get_used_rect().position.y
	var neck := top + PunyArt.HEAD_ROWS
	for x in range(8, 24):
		assert_eq(outfit.get_pixel(x, top + 2), heads.get_pixel(x, top + 2), "head at x %d" % x)
		assert_eq(outfit.get_pixel(x, neck + 2), bodies.get_pixel(x, neck + 2), "body at x %d" % x)


func test_the_pack_says_what_is_worn_where() -> void:
	var pack := InventoryState.new()
	var helm := InventoryState.create_gear("iron_helm")
	var robe := InventoryState.create_gear("mage_robe")
	pack.gear.append_array([helm, robe])
	pack.equipped = {"head": helm["uid"], "body": robe["uid"], "feet": "gone"}
	assert_eq(pack.worn_items(), {"head": "iron_helm", "body": "mage_robe"})
