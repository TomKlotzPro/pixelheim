extends GutTest
## Worn gear drawn on the hero (PIX-129): a helmet is another of Shade's
## sheets' heads and armour another's body, cut at the neck in every frame.


func test_nothing_drawable_worn_keeps_the_look() -> void:
	var plain := PunyArt.plain("warrior", 0)
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
	assert_ne(spec["sheet"], PunyArt.plain("warrior", 0)["sheet"], "dragonbane has its own colour")
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
	assert_eq(spec["body"], PunyArt.plain("mage", 1)["sheet"])
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


## The share of a frame's lower body (legs and belt) one sheet has in common
## with another: 1.0 for the same pose.
func _lower_body_overlap(a: Image, b: Image, column: int, row: int) -> float:
	var common := 0
	var either := 0
	for y in range(16, 32):
		for x in 32:
			var in_a := a.get_pixel(column * 32 + x, row * 32 + y).a > 0.0
			var in_b := b.get_pixel(column * 32 + x, row * 32 + y).a > 0.0
			common += int(in_a and in_b)
			either += int(in_a or in_b)
	return float(common) / maxf(1.0, either)


func test_every_worn_and_hero_sheet_keeps_the_templates_poses() -> void:
	# PIX-173: a head from one sheet on a body from another must share the
	# frame's pose; the Human Soldier sheets were drawn a column late.
	var base: Image = (load(PunyArt.path(PunyArt.BASE)) as Texture2D).get_image()
	var sheets := {}
	for table: Dictionary in [PunyArt.HEADS, PunyArt.BODIES]:
		for item_id: String in table:
			sheets[table[item_id]] = true
	for role_id: String in PunyArt.HEROES:
		for sheet: String in PunyArt.HEROES[role_id][0]:
			sheets[sheet] = true
	for sheet: String in sheets:
		var image: Image = (load(PunyArt.path(sheet)) as Texture2D).get_image()
		var total := 0.0
		var frames := 0
		for row in [0, 2, 4, 6]:
			for column in range(2, 22):
				total += _lower_body_overlap(base, image, column, row)
				frames += 1
		assert_gt(total / frames, 0.9, "%s keeps the template's poses" % sheet)


func test_every_piece_has_a_look_of_its_own() -> void:
	# No two helms, and no two bodies, look alike, and none is a hero's own
	# sheet (on which it would change nothing).
	var own := {}
	for role_id: String in PunyArt.HEROES:
		for sheet: String in PunyArt.HEROES[role_id][0]:
			own[sheet] = true
	for table: Dictionary in [PunyArt.HEADS, PunyArt.BODIES]:
		var seen := {}
		for item_id: String in table:
			var sheet: String = table[item_id]
			assert_false(own.has(sheet), "%s isn't any hero's own look" % item_id)
			assert_false(seen.has(sheet), "%s and %s share a look" % [item_id, seen.get(sheet, "")])
			seen[sheet] = item_id
	# Every helm and body in the catalogue is drawn.
	for item_id: String in Catalog._data()["items"]:
		var slot: String = Catalog.item(item_id).get("slot", "")
		if slot == "head":
			assert_true(PunyArt.HEADS.has(item_id), "%s is drawn" % item_id)
		elif slot == "body":
			assert_true(PunyArt.BODIES.has(item_id), "%s is drawn" % item_id)
	# Every hero, whatever their look, changes when armour goes on.
	for role_id: String in PunyArt.HEROES:
		for look in PunyArt.looks(role_id):
			var plain: String = PunyArt.plain(role_id, look)["sheet"]
			for item_id: String in PunyArt.BODIES:
				assert_ne(PunyArt.dressed(role_id, look, {"body": item_id})["sheet"], plain, "%s on %s %d" % [item_id, role_id, look])


func test_gloves_boots_and_shields_show() -> void:
	# PIX-174: every hand, foot and off-hand piece has a colour, and the
	# off hand a shape, and wearing it changes the hero.
	for item_id: String in Catalog._data()["items"]:
		var item: Dictionary = Catalog.item(item_id)
		var slot: String = item.get("slot", "")
		if slot in ["hands", "feet", "offhand"]:
			assert_true(item.has("tint"), "%s has a colour" % item_id)
			assert_ne(PunyArt.dressed("warrior", 0, {slot: item_id})["sheet"], PunyArt.plain("warrior", 0)["sheet"], "%s shows" % item_id)
		if slot == "offhand":
			assert_true(PunyArt.SHIELDS.has(item.get("shape", "")), "%s has a shape" % item_id)
	var plain: Image = (load(PunyArt.path(PunyArt.plain("warrior", 0)["sheet"])) as Texture2D).get_image()
	var spec := PunyArt.dressed("warrior", 0, {"hands": "blackiron_gauntlets", "feet": "frost_boots", "offhand": "warden_kite"})
	var worn := PunyArt.outfit_texture(spec["head"], spec["body"], spec["weapon_tint"], spec["gear"]).get_image()
	# The first frame: the hands (rows 19-20) are no longer skin, the boots
	# (the last two rows) no longer leather, and a shield hangs on the off hand.
	var skin := 0
	var leather := 0
	for y in range(19, 23):
		for x in 32:
			var code := worn.get_pixel(x, y).to_html(false)
			skin += int(code in PunyArt.SKIN_RAMP and y < 21)
			leather += int(code in PunyArt.BOOT_RAMP and y >= 21)
	assert_eq(skin, 0, "gloves over the hands")
	assert_eq(leather, 0, "boots over the boots")
	var changed := 0
	for y in 32:
		for x in 32:
			changed += int(worn.get_pixel(x, y) != plain.get_pixel(x, y))
	assert_gt(changed, 20)
	# A bow drawn puts the shield away: the bow columns match the plain sheet
	# but for the gloves and boots.
	var bow_spec := PunyArt.dressed("warrior", 0, {"offhand": "warden_kite"})
	var bow_sheet := PunyArt.outfit_texture(bow_spec["head"], bow_spec["body"], bow_spec["weapon_tint"], bow_spec["gear"]).get_image()
	for y in 32:
		for x in range(8 * 32, 9 * 32):
			assert_eq(bow_sheet.get_pixel(x, y), plain.get_pixel(x, y))


## PIX-175: the hero looks the same everywhere.
func test_the_fallen_lie_in_one_sheet() -> void:
	var head_path := PunyArt.HEADS["wyrm_visor"]
	var body_path := PunyArt.BODIES["leather_armor"]
	var outfit := PunyArt.outfit_texture(head_path, body_path).get_image()
	var bodies: Image = (load(PunyArt.path(body_path)) as Texture2D).get_image()
	bodies.convert(Image.FORMAT_RGBA8)
	for frame: Vector2i in PunyArt.LYING:
		var cell := Rect2i(frame * 32, Vector2i(32, 32))
		assert_eq(outfit.get_region(cell).get_data(), bodies.get_region(cell).get_data(), "frame %s is the body sheet's" % frame)


func test_the_necromancers_violet_is_their_kits() -> void:
	# The grave violet is the necromancer's kit (PIX-175), the picture hero
	# creation shows; plain clothes (PIX-242) and borrowed armour keep their
	# own colours.
	assert_ne(PunyArt.hero("necromancer", 0)["tint"], Color.WHITE, "the kit is violet")
	var bare := PunyArt.dressed("necromancer", 0, {})
	assert_eq(bare["tint"], Color.WHITE, "plain clothes aren't")
	var armoured := PunyArt.dressed("necromancer", 0, {"body": "iron_armor"})
	assert_eq(armoured["tint"], Color.WHITE, "no sprite-wide tint once dressed")
	assert_eq(armoured["gear"]["head_tint"], Color.WHITE, "the plain head keeps its colour")
	assert_eq(armoured["gear"]["body_tint"], Color.WHITE, "borrowed armour keeps its colour")
	var outfit := PunyArt.sheet_texture(armoured).get_image()
	var bodies: Image = (load(PunyArt.path(PunyArt.BODIES["iron_armor"])) as Texture2D).get_image()
	bodies.convert(Image.FORMAT_RGBA8)
	var base: Image = (load(PunyArt.path(PunyArt.BASE)) as Texture2D).get_image()
	var neck := base.get_region(Rect2i(0, 0, 32, 32)).get_used_rect().position.y + PunyArt.HEAD_ROWS
	for x in range(8, 24):
		assert_eq(outfit.get_pixel(x, neck + 3), bodies.get_pixel(x, neck + 3), "iron at x %d" % x)
	assert_eq(PunyArt.dressed("warrior", 0, {"body": "iron_armor"})["gear"]["head_tint"], Color.WHITE)


func test_every_hero_starts_in_plain_clothes() -> void:
	# A survivor, not a soldier (PIX-242): every role and look starts in the
	# worker's clothes, the look picking their colour; the role's kit is what
	# hero creation shows of what they become.
	for role_id: String in PunyArt.HEROES:
		for look in PunyArt.looks(role_id):
			var spec := PunyArt.dressed(role_id, look, {})
			assert_has(PunyArt.PLAIN, spec["sheet"], "%s %d starts plain" % [role_id, look])
			assert_ne(spec["sheet"], PunyArt.hero(role_id, look)["sheet"], "not in the kit")
	assert_eq(PunyArt.dressed("mage", 0, {})["attack"], "staff", "the role still casts")
	assert_eq(PunyArt.dressed("necromancer", 0, {})["tint"], Color.WHITE, "no grave violet on plain clothes")
