extends GutTest
## Item icons (PIX-138): every item and ailment has one of Shade's icons, and
## every source the map names is really there.


func test_every_item_has_an_icon() -> void:
	for id: String in Catalog._data()["items"]:
		assert_ne(ItemIcons.source(id), "", "%s needs an entry in assets/puny/icons.json" % id)


func test_every_ailment_has_a_mark() -> void:
	for kind: String in ["poison", "burn", "stun"]:
		assert_true(ItemIcons._data()["ailments"].has(kind), kind)


func test_free_sheets_and_medieval_tiles_exist_and_hold_the_cells() -> void:
	for id: String in Catalog._data()["items"]:
		var src := ItemIcons.source(id)
		var where := ItemIcons.resolve(src)
		if src.begins_with("medieval@"):
			assert_between(int(where["tile"]), 0, 220 * 132 - 1, id)
			continue
		if not src.begins_with("free/"):
			continue
		assert_true(ResourceLoader.exists(where["path"]), "%s: %s" % [id, where["path"]])
		var size: Vector2 = (load(where["path"]) as Texture2D).get_size()
		var cell: Vector2i = where["cell"]
		if cell.x >= 0:
			assert_true(cell.x * 16 + 16 <= size.x and cell.y * 16 + 16 <= size.y, "%s: cell %s inside %s" % [id, cell, size])


## The paid icons are fetched (scripts/fetch-private-art.sh); where they are,
## every file the map names must be.
func test_the_fetched_paid_icons_are_all_there() -> void:
	if not DirAccess.dir_exists_absolute(ItemIcons.PRIVATE):
		pass_test("no paid art here (a fork, or the key is missing)")
		return
	var files := ItemIcons.private_files()
	assert_gt(files.size(), 50)
	for file: String in files:
		assert_true(ResourceLoader.exists(ItemIcons.PRIVATE + file), file)


## Every skill a hero can cast (each role's actives, every path's signature)
## has an icon for the dock.
func test_every_skill_has_an_icon() -> void:
	var names: Array[String] = []
	for role: String in Bestiary._data()["skillTrees"]:
		for entry: Dictionary in Skills.tree(role):
			if entry["kind"] == "active":
				names.append(entry["skill"]["name"])
	for path: Dictionary in Bestiary._data()["pathNodes"]:
		if path.has("signature"):
			names.append(path["signature"]["name"])
	assert_gt(names.size(), 60)
	for skill_name: String in names:
		assert_true(ItemIcons._data()["skills"].has(skill_name), "%s needs an icon" % skill_name)
