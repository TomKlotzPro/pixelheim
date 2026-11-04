extends GutTest
## The Ash Fields' burnt farmsteads (PIX-397, step 2): every piece of every
## stead is laid where it's placed; all of them in the Ash, off its roads,
## portals, packs, chests and patches, the story's spots and every cell a
## waystation or a signpost stands on (built or not), and no way closed;
## on ground healed round a lamp they mend, nowhere else; without the paid
## pack only the trees, carts and logs; nothing off the Reach.

const Hamlets := preload("res://test/unit/test_hamlet.gd")
const Farmlands := preload("res://test/unit/test_farmland.gd")


static func _laid(healed := {}, paid := true) -> Dictionary:
	var map := MapData.load_by_id(AshRuins.MAP)
	return {"map": map, "kept": Hamlet.kept_on(map, {}), "laid": AshRuins.lay(map, Hamlet.kept_on(map, {}), healed, paid)}


## The ground healed round every lamp on the Reach, each ring whole and
## Aske keeping them a third wider: as far as healing ever reaches.
static func _healed_whole(map: MapData) -> Dictionary:
	var rings: Array[Dictionary] = []
	for place: String in Routes.places():
		var lamp := Routes.lamp_of(place)
		if lamp.is_empty():
			continue
		var reach := Lamps.REACH + int(Lamps.KINDS.get(lamp["kind"], {}).get("reach", 0))
		rings.append({"place": place, "cell": lamp["cell"], "kind": lamp["kind"], "reach": roundi(reach * (1.0 + 1.0 / 3.0)), "mornings": 30})
	return Lamps.healed(map.grid, rings)


## How many pieces a stead lays: its orchard's trees, its frame's walls
## standing and fallen, its cart, its rubble, its paddock's posts and gaps.
static func _expected(stead: Dictionary) -> int:
	var orchard: Rect2i = stead["orchard"]
	var trees := ceili(orchard.size.x / 2.0) * ceili(orchard.size.y / 2.0)
	var frame: Rect2i = stead["frame"]
	var walls := 2 * (frame.size.x + frame.size.y) - 4 - 1
	return 1 + trees + walls + 1 + stead["rubble"].size() + (stead["paddock"] as Rect2i).size.x


func test_every_piece_of_every_stead_is_laid() -> void:
	var laid: Dictionary = _laid()["laid"]
	var cells := {}
	var floors := 0
	for piece: Dictionary in laid["pieces"]:
		if piece["kind"] == "floor":
			floors += 1
			continue
		cells[piece["cell"]] = piece["kind"]
	assert_eq(floors, AshRuins.STEADS.size(), "a floor under every frame")
	var expected := 0
	for stead: Dictionary in AshRuins.STEADS:
		expected += _expected(stead)
		var orchard: Rect2i = stead["orchard"]
		for y in range(orchard.position.y, orchard.end.y, 2):
			for x in range(orchard.position.x, orchard.end.x, 2):
				assert_eq(cells.get(Vector2i(x, y), ""), "tree", "a tree at %s" % Vector2i(x, y))
		for cell: Vector2i in AshRuins.ring(stead["frame"], stead["door"]):
			assert_eq(cells.get(cell, ""), "log" if cell in stead["fallen"] else "post", "the frame's wall at %s" % cell)
		assert_eq(cells.get(stead["cart"], ""), "cart", "the cart at %s" % stead["cart"])
		for cell: Vector2i in stead["rubble"]:
			assert_eq(cells.get(cell, ""), "rubble", "rubble at %s" % cell)
		var paddock: Rect2i = stead["paddock"]
		for x in range(paddock.position.x, paddock.end.x):
			var cell := Vector2i(x, paddock.position.y)
			assert_eq(cells.get(cell, ""), "log" if cell in stead["gaps"] else "post", "the paddock's fence at %s" % cell)
		assert_false(cells.has(stead["door"]), "the door at %s open" % stead["door"])
	assert_eq(laid["pieces"].size(), expected, "every piece laid")


func test_all_in_the_ash_off_every_road_spot_and_station() -> void:
	var at := _laid()
	var map: MapData = at["map"]
	var spots := Farmlands._spots(map)
	# Every cell a waystation, a lamp of its own or a signpost stands on,
	# built or not, and the ring round each; and under each signpost.
	var stations := {}
	for place: String in Routes.places():
		var station := Routes.station(place)
		for part: String in ["hut", "lamp", "box", "bench", "arrival", "find", "visit"]:
			if station.has(part):
				var cell := Routes.cell_of(station[part])
				for dy in range(-1, 2):
					for dx in range(-1, 3 if part == "hut" else 2):
						stations[cell + Vector2i(dx, dy)] = true
	for fork: Dictionary in Routes.forks():
		var cell := Routes.cell_of(fork["at"])
		for dy in range(-1, 3):
			for dx in range(-1, 2):
				stations[cell + Vector2i(dx, dy)] = true
	for piece: Dictionary in at["laid"]["pieces"]:
		var cell: Vector2i = piece["cell"]
		var where := "%s at %s" % [piece["kind"], cell]
		assert_eq(map.region_at(cell), "ash", where + " in the Ash")
		assert_does_not_have(Hamlet.WAYS, map.tile_at(cell), where + " off the roads")
		assert_false(map.portals.has(cell), where + " off the portals")
		assert_false(spots.has(cell), where + " off the story's spots")
		assert_false(at["kept"].has(cell), where + " off the packs, chests and patches")
		assert_false(stations.has(cell), where + " clear of the waystations and signposts")


func test_no_way_is_closed() -> void:
	var at := _laid()
	var map: MapData = at["map"]
	var before := Hamlets._reach(map, map.spawn)
	var blocks: Array = at["laid"]["blocks"]
	for cell: Vector2i in blocks:
		map.covered[cell] = true
	var after := Hamlets._reach(map, map.spawn)
	for cell: Vector2i in before:
		if cell not in blocks:
			assert_true(after.has(cell), "%s still reached from the spawn" % cell)
	for portal: Vector2i in map.portals:
		assert_true(after.has(portal) or not before.has(portal), "the way out at %s" % portal)


func test_they_mend_on_healed_ground_and_nowhere_else() -> void:
	assert_false(_laid()["laid"]["pieces"].any(func(piece: Dictionary) -> bool: return piece["mended"]), "nothing mends in the ash")
	var map := MapData.load_by_id(AshRuins.MAP)
	var healed := _healed_whole(map)
	var laid: Dictionary = _laid(healed)["laid"]
	var mended: Array = laid["pieces"].filter(func(piece: Dictionary) -> bool: return piece["mended"])
	for piece: Dictionary in laid["pieces"]:
		# A floor by its middle: it lies under the whole frame.
		var under: Vector2i = Rect2i(piece["cell"], piece["size"]).get_center() if piece["kind"] == "floor" else piece["cell"]
		assert_eq(piece["mended"], healed.has(under), "%s at %s mends with its ground" % [piece["kind"], piece["cell"]])
	# The orchards by Blackiron's and Greyhold's waystations mend; the
	# steads west and east, beyond every ring's widest reach, stay burnt
	# whatever the lamps do.
	assert_gt(mended.filter(func(piece: Dictionary) -> bool: return piece["kind"] == "tree").size(), 5, "an orchard mends")
	for i: int in [0, 4]:
		for cell: Vector2i in AshRuins.cells_of(AshRuins.STEADS[i]):
			assert_false(healed.has(cell), "the stead at %s beyond every ring" % AshRuins.STEADS[i]["frame"].position)
	# What mends is what was laid: the ruins are the same, healed or not.
	assert_eq(laid["pieces"].size(), _laid()["laid"]["pieces"].size(), "the same pieces")


func test_without_the_pack_and_off_the_reach() -> void:
	var laid: Dictionary = _laid({}, false)["laid"]
	var kinds := {}
	for piece: Dictionary in laid["pieces"]:
		kinds[piece["kind"]] = true
	assert_eq_deep(kinds.keys().filter(func(kind: String) -> bool: return kind in ["post", "rubble"]), [])
	assert_true(kinds.has("tree") and kinds.has("cart") and kinds.has("log"), "the trees, carts and logs without the pack")
	assert_eq(AshRuins.lay(MapData.load_by_id("blackiron"), {}, {}, true)["pieces"].size(), 0, "nothing off the Reach")


## Drawn as MapView draws the Reach: every piece, the burnt ones charred,
## each standing piece blocking its cells.
func test_drawn_on_the_reach() -> void:
	var map := MapData.load_by_id(AshRuins.MAP)
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	assert_true(view.has_meta("ash_ruins"), "the Ash's ruins planned")
	var laid: Dictionary = view.get_meta("ash_ruins")
	assert_gt(laid["pieces"].size(), 100, "five steads")
	for cell: Vector2i in laid["blocks"]:
		assert_false(map.is_walkable(cell), "%s blocked" % cell)
	assert_string_starts_with(AshRuins.describe(view), "floors 5 posts ")
	var charred := actors.find_children("*", "Sprite2D", true, false).filter(func(sprite: Sprite2D) -> bool: return sprite.modulate == AshRuins.CHARRED)
	assert_gt(charred.size(), 20, "the frames and carts charred")
