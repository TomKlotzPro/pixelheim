extends GutTest
## Worn gear drawn on the hero (PIX-129): a helmet is another of Shade's
## sheets' heads and armour another's body, cut at the neck in every frame.


func test_nothing_drawable_worn_keeps_the_look() -> void:
	var plain := PunyArt.hero("warrior", 0)
	var spec := PunyArt.dressed("warrior", 0, {"weapon": "rusty_sword", "ring1": "band_of_grit"})
	assert_eq(spec["sheet"], plain["sheet"])
	assert_false(spec.has("head"))


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
