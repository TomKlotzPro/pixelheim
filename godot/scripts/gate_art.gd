class_name GateArt
## areas: travel story +overworld*
## What a shut gate looks like (PIX-254, Gates): the road still there and the
## land past it in sight, something drawn across it that blocks like any
## prop. The cliff road's rockfall is a heap of boulders fallen from the
## cliff, tallest in the middle, in the cliff's own rock, small up top and
## big at its foot, a broken trunk across it, its scree lying on the road at
## its foot and beside its flanks (PIX-556); the river bridge
## burnt on the Night of Ash is its planks gone in the middle, the ruins'
## charred posts standing in the water and a burnt log drifting; Ulla's
## barricade is a log fence and crates across the Greyhold road, one of her
## old guard in front of it; the avalanche on the Frostgate road is a bank of
## snow in lumps, shaded on its east side, a snowed pine snapped and lying
## half buried in its crest, sparkling by day (PIX-556). The heap, its scree
## and the bank are drawn here in code in Shade's palette (his Puny World
## rock, HamletArt's inks), the same with or without the paid pack
## (PunyProps; Shade draws rocks a tile's size only, and a heap of them
## read as a wall);
## the pine is the Medieval Age's with it and ours without, its snapped
## trunk ours in both; without it the fence and the crates are the
## dungeon's palisade; the rest is CC0.
## Pure but for texture(): MapView draws the pieces, and its bodies stop the
## hero on the gate's cells.

const TILE := 16
## A piece: on `cell`, its sprite's top-left `at` px from the cell's (a
## standing one's bottom `at.y` below its cell's bottom), from `sheet`
## ("world": PunyTerrain's, "dungeon": PunyDungeon's, "props": the paid
## Medieval Age's, "villager": PunyArt's, `sprite` its id, "gate": drawn
## here, `sprite` its name, "glint": HamletArt's sparkle), `tone`
## ("charred" or ""), `flat` lying on the ground under everyone; sorted among
## the actors on its own foot otherwise. `turn`: laid on its side, its top
## to the west; `day`: shown by day only; `cast`: ours, standing on the
## ground, casting the sun's shadow.
const DRIFTWOOD := 703
## Shade's log fence down a run (PunyProps.FENCE by N=1, S=4): its top,
## middle and bottom posts; his crate; the CC0 dungeon's palisade.
const FENCE_TOP := 3643
const FENCE_RUN := 3863
const FENCE_END := 4083
const POST := 4303
const CRATE := 1024
const PALISADE := 460
const DUNGEON_POST := 512
## How dark a burnt post is.
const CHARRED := Color(0.42, 0.34, 0.3)

## The rockfall (PIX-556): the heap's picture, a little wider than the road
## so it lies against the cliffs, its foot this far below its cell's (it
## fills the pass's last row too, a way on that nothing grows on).
const HEAP := Vector2i(54, 44)
const HEAP_DROP := 12
## Its boulders, each the box it's drawn in on the picture, from its crest
## down: small up top, bigger down its sides, the biggest at its foot and
## smaller toward its ends, so its foot rounds in; each sits on a row of its
## own (no courses, as a wall's), its foot wandering a few pixels, and each
## overlaps the ones behind it, so the heap reads as one mass.
const BOULDERS: Array[Rect2i] = [
	Rect2i(25, 5, 7, 6), Rect2i(19, 8, 6, 5), Rect2i(31, 9, 6, 5),
	Rect2i(12, 11, 9, 7), Rect2i(21, 12, 12, 7), Rect2i(34, 12, 9, 8), Rect2i(41, 17, 7, 5),
	Rect2i(6, 17, 9, 7), Rect2i(14, 16, 11, 9), Rect2i(25, 18, 9, 8), Rect2i(33, 18, 12, 9), Rect2i(44, 22, 7, 7),
	Rect2i(3, 24, 7, 6), Rect2i(19, 23, 10, 8), Rect2i(28, 25, 8, 7),
	Rect2i(2, 30, 8, 6), Rect2i(44, 30, 8, 7), Rect2i(8, 27, 15, 12), Rect2i(32, 29, 14, 12), Rect2i(20, 30, 14, 14),
]
## How round a boulder is (2 an ellipse, more a block; each a little more
## or less), and how far its outline wanders in and out (a share of its
## radius).
const BOULDER_ROUND := 2.0
const BOULDER_ROUNDS := 0.35
const BOULDER_WOBBLE := 0.2
## Shade's rock, the Puny World's cliffs and boulder, from the light to the
## dark: a boulder's sunlit rim, its top, two shades of it, its face toward
## us, its face's shade, and its outline, the cracks between them and a
## pebble's shadow.
const ROCK: Array[Color] = [
	Color("c3cb8f"), Color("b2ba82"), Color("a6ae78"), Color("8a925d"), Color("787f4f"), Color("5c633a"), Color("4b4f2b"),
]
## A boulder as Shade draws one: its top lit from the north-west, its face
## toward us darker under it. Where its face begins (a share of its radius
## below its middle, its rim wandering), and how lit each tone is at least:
## its top's (from ROCK's first, lit from the north-west), its face's (from
## its fifth, lit from the west).
const BOULDER_FACE := 0.15
const TOP_LIT := [0.28, -0.08, -0.42]
const FACE_LIT := [0.25]
## The broken trunk lying across its front: its splintered end (sticking out
## past the heap's west shoulder) and its root end, buried, on the picture,
## laid over the boulders behind it, under those sitting on this row or
## lower.
const TRUNK_FROM := Vector2i(6, 12)
const TRUNK_TO := Vector2i(27, 26)
const TRUNK_UNDER := 32
## The scree, flat on the ground: the heap's picture widened this much each
## side and down, its pebbles lying along the heap's foot and up its flanks
## this far from its foot, thinning out away from it, none higher; this
## many, each tried where it lies clear.
const SCREE_FLANK := 6
const SCREE_FRONT := 9
const SCREE_RISE := 12
const PEBBLES := 110

## The avalanche (PIX-556): the bank's picture, a little wider than the
## road, the ground it covers that deep along its bottom; the domes of snow
## it's heaped of, on that ground, each its middle (x, y) and its (radius x,
## radius y, height) in px, every one inside the picture, so its ends are
## round: a long low bank, lumps on it.
const BANK := Vector2i(62, 46)
const BANK_DEPTH := 26
const DOMES: Array[AABB] = [
	AABB(Vector3(31, 13, 0), Vector3(30, 12, 9)),
	AABB(Vector3(14, 9, 0), Vector3(12, 8, 15)), AABB(Vector3(30, 7, 0), Vector3(13, 7, 18)),
	AABB(Vector3(46, 10, 0), Vector3(11, 8, 14)), AABB(Vector3(7, 17, 0), Vector3(7, 7, 8)),
	AABB(Vector3(22, 18, 0), Vector3(10, 7, 10)), AABB(Vector3(38, 19, 0), Vector3(10, 6, 9)),
	AABB(Vector3(53, 17, 0), Vector3(7, 8, 11)),
]
## The light on it, from the north-west and above, and snow's tones by how
## much falls (HamletArt's inks), `y` in the sun to `W` in the shade; its
## east end this much darker; its rim `S`, `w` along the ground.
const SUN := Vector3(-0.55, -0.15, 0.82)
const SNOW_TONES := [[0.76, "y"], [0.44, "s"], [0.16, "S"], [-2.0, "W"]]
const EAST_SHADE := 0.25
## The snapped pine: the Medieval Age's tall snowy pine (its crown's tile,
## its trunk's under it), or ours; where it lies across the bank's crest
## from the cell behind the bank's, half of it behind the crest, half
## against the road beyond. Ours: its picture, lying, its crown's tiers of
## needles this long from its tip, each this long, and its trunk's
## splintered end; with the pack its trunk and break alone lie under the
## Medieval Age's crown.
const PINE_TOP := 2216
const PINE_AT := Vector2(-15, 0)
const PINE := Vector2i(45, 16)
const PINE_CROWN := 30
const PINE_TIER := 6
const PINE_BREAK := Vector2i(39, 5)
## The sparkles by day, on its lit crest: each on the bank's foot row x
## cells from its middle, (y, z) px from that cell's top-left.
const GLINTS: Array[Vector3] = [Vector3(-1, -1, -27), Vector3(0, -2, -31), Vector3(1, -4, -25)]

static var _drawn := {}


## The pieces of `gate`'s look, and the cells whose own objects (a bridge's
## planks) aren't drawn while it's shut: {pieces: [piece], hides: [cell]}.
## `paid`: the Medieval Age pack is here (PunyProps.available()).
static func plan(gate: Dictionary, paid: bool) -> Dictionary:
	var cells := Gates.cells_of(gate)
	match String(gate["look"]):
		"rockfall":
			return {"pieces": _rockfall(cells), "hides": []}
		"burnt_bridge":
			return {"pieces": _burnt_bridge(cells, paid), "hides": cells}
		"barricade":
			return {"pieces": _barricade(cells, paid), "hides": []}
		"avalanche":
			return {"pieces": _avalanche(cells, paid), "hides": []}
	return {"pieces": [], "hides": []}


static func _piece(cell: Vector2i, sheet: String, tile: int, at: Vector2, tone := "", flat := false) -> Dictionary:
	return {"cell": cell, "sheet": sheet, "tile": tile, "sprite": "", "at": at, "tone": tone, "flat": flat}


## One of ours, drawn here (texture()), casting unless it lies flat.
static func _ours(cell: Vector2i, name: String, at: Vector2, flat := false) -> Dictionary:
	var piece := _piece(cell, "gate", -1, at, "", flat)
	piece["sprite"] = name
	piece["cast"] = not flat
	return piece


## The heap across the middle of the road, its scree round its foot (its
## picture the heap's, widened).
static func _rockfall(cells: Array[Vector2i]) -> Array[Dictionary]:
	var middle := cells[cells.size() / 2]
	var at := Vector2((TILE - HEAP.x) / 2, HEAP_DROP)
	return [
		_ours(middle, "scree", Vector2(at.x - SCREE_FLANK, TILE + HEAP_DROP - HEAP.y), true),
		_ours(middle, "rockfall", at),
	]


## The middle of the span gone: charred posts where its planks were, a
## burnt log in the water.
static func _burnt_bridge(cells: Array[Vector2i], paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var post_sheet := "props" if paid else "dungeon"
	var post := POST if paid else DUNGEON_POST
	var west := cells[0].x
	for cell: Vector2i in cells:
		var side := -6.0 if cell.x == west else 6.0
		out.append(_piece(cell, post_sheet, post, Vector2(side, -3 + (absi(hash(cell)) >> 4) % 6), "charred"))
	out.append(_piece(cells[-1], "world", DRIFTWOOD, Vector2(-9, -6), "charred", true))
	return out


## A log fence down the road's width, crates at its ends, and one of
## Ulla's old guard in front of it between them, facing whoever comes up
## the road.
static func _barricade(cells: Array[Vector2i], paid: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cells.size():
		var cell := cells[i]
		var fence := FENCE_RUN if i > 0 and i < cells.size() - 1 else (FENCE_TOP if i == 0 else FENCE_END)
		out.append(_piece(cell, "props" if paid else "dungeon", fence if paid else PALISADE, Vector2(4, 0)))
		if i != cells.size() / 2:
			out.append(_piece(cell, "props" if paid else "dungeon", CRATE if paid else PALISADE, Vector2(-2, 1)))
	var guard := _piece(cells[cells.size() / 2], "villager", -1, Vector2(-1, 0))
	guard["sprite"] = "guard"
	out.append(guard)
	return out


## A bank of snow across the road, a snapped pine lying half buried on its
## crest (sorted behind it), a few sparkles on it by day (in front of it).
static func _avalanche(cells: Array[Vector2i], paid: bool) -> Array[Dictionary]:
	var low := cells[0]
	var high := cells[0]
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var middle := Vector2i((low.x + high.x) / 2, high.y)
	var behind := Vector2i(middle.x, low.y - 1)
	# Ours first, so the Medieval Age's crown lies over its trunk's end; it
	# lies on the bank, so casts nothing on the road.
	var out: Array[Dictionary] = [_ours(behind, "snag" if paid else "pine", PINE_AT)]
	out[0]["cast"] = false
	if paid:
		for i in 2:
			var crown := _piece(behind, "props", PINE_TOP + i * PunyTown.COLUMNS, PINE_AT + Vector2(i * TILE, 0))
			crown["turn"] = true
			out.append(crown)
	out.append(_ours(middle, "avalanche", Vector2((TILE - BANK.x) / 2, 0)))
	for glint: Vector3 in GLINTS:
		var sparkle := _piece(middle + Vector2i(int(glint.x), 0), "glint", -1, Vector2(glint.y, glint.z))
		sparkle["day"] = true
		out.append(sparkle)
	return out


## Our piece `name` ("rockfall", "scree", "avalanche", "pine" or "snag"),
## drawn once a session, the same every time.
static func texture(name: String) -> Texture2D:
	if not _drawn.has(name):
		var dice := RandomNumberGenerator.new()
		dice.seed = hash(name)
		var image: Image
		match name:
			"rockfall":
				image = _heap(dice)
			"scree":
				image = _scree(dice)
			"pine", "snag":
				image = _pine(name == "pine")
			_:
				image = _bank()
		_drawn[name] = ImageTexture.create_from_image(image)
	return _drawn[name]


## The rockfall's heap: its boulders back to front, the broken trunk among
## them, the cracks between them dark.
static func _heap(dice: RandomNumberGenerator) -> Image:
	var image := Image.create(HEAP.x, HEAP.y, false, Image.FORMAT_RGBA8)
	var trunk := true
	for rect: Rect2i in BOULDERS:
		if trunk and rect.end.y > TRUNK_UNDER:
			_trunk(image, TRUNK_FROM, TRUNK_TO)
			trunk = false
		_boulder(image, rect, dice)
	# The cracks between them: what's left open with the heap above and
	# below it and either side.
	var ends := _ends(image)
	var tops: PackedInt32Array = ends[0]
	var bottoms: PackedInt32Array = ends[1]
	var wests: PackedInt32Array = ends[2]
	var easts: PackedInt32Array = ends[3]
	for y in HEAP.y:
		for x in range(wests[y] + 1, easts[y]):
			if tops[x] < y and y < bottoms[x] and image.get_pixel(x, y).a == 0.0:
				image.set_pixel(x, y, ROCK[-1])
	return image


## Where `image` is drawn: each column's top and bottom pixel (its height
## and -1 for none) and each row's west and east (its width and -1).
static func _ends(image: Image) -> Array[PackedInt32Array]:
	var size := image.get_size()
	var tops := PackedInt32Array()
	var bottoms := PackedInt32Array()
	var wests := PackedInt32Array()
	var easts := PackedInt32Array()
	tops.resize(size.x)
	tops.fill(size.y)
	bottoms.resize(size.x)
	bottoms.fill(-1)
	wests.resize(size.y)
	wests.fill(size.x)
	easts.resize(size.y)
	easts.fill(-1)
	for y in size.y:
		for x in size.x:
			if image.get_pixel(x, y).a > 0.0:
				tops[x] = mini(tops[x], y)
				bottoms[x] = y
				wests[y] = mini(wests[y], x)
				easts[y] = x
	return [tops, bottoms, wests, easts]


## A boulder in `rect` of `image`: a rounded lump whose outline wanders,
## its top lit from the north-west over its face in shade, outlined.
static func _boulder(image: Image, rect: Rect2i, dice: RandomNumberGenerator) -> void:
	var middle := Vector2(rect.position) + Vector2(rect.size - Vector2i.ONE) / 2.0
	var radius := Vector2(rect.size) / 2.0
	var phase := Vector2(dice.randf() * TAU, dice.randf() * TAU)
	var roundness := BOULDER_ROUND + dice.randf_range(-BOULDER_ROUNDS, BOULDER_ROUNDS)
	# How far out each point of its box (and a pixel round it) lies, 1 its edge.
	var box := rect.grow(1)
	var reach := PackedFloat32Array()
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var off := (Vector2(x, y) - middle) / radius
			var wobble := 1.0 + BOULDER_WOBBLE * (sin(2.0 * off.angle() + phase.x) + 0.6 * sin(3.0 * off.angle() + phase.y)) / 1.6
			reach.append(pow(pow(absf(off.x), roundness) + pow(absf(off.y), roundness), 1.0 / roundness) / wobble)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var at := (y - box.position.y) * box.size.x + x - box.position.x
			if reach[at] >= 1.0:
				continue
			var edge := reach[at - 1] >= 1.0 or reach[at + 1] >= 1.0 or reach[at - box.size.x] >= 1.0 or reach[at + box.size.x] >= 1.0
			var tone := ROCK.size() - 1
			if not edge:
				var off := (Vector2(x, y) - middle) / radius
				var top := off.y < BOULDER_FACE + 0.12 * sin(4.0 * off.x + phase.x)
				var lit := -0.6 * off.x - (0.4 * off.y if top else 0.0)
				var steps: Array = TOP_LIT if top else FACE_LIT
				tone = 0 if top else 4
				for step: float in steps:
					if lit > step:
						break
					tone += 1
			image.set_pixel(x, y, ROCK[tone])


## A pine's trunk lying from its splintered end `from` (the pale wood of
## the break, sticking out) to `to`, east or west of it, in HamletArt's
## woods: lit along its top, its bark streaked.
static func _trunk(image: Image, from: Vector2i, to: Vector2i) -> void:
	var inks := HamletArt.INKS
	var run := to - from
	var way := signi(run.x)
	for i in absi(run.x) + 1:
		var top := from + Vector2i(i * way, roundi(float(i) * run.y / absi(run.x)))
		var bark := PackedStringArray(["o", "3", "2", "1" if i % 5 == 2 else "2", "1", "o"] if i > 0 else ["o", "5", "6", "5", "4", "o"])
		for row in bark.size():
			var ink: Color = inks[bark[row]]
			image.set_pixelv(top + Vector2i(0, row), ink)
	# The break: splinters of pale wood, each ending in a dark tip.
	var reaches := PackedInt32Array([1, 3, 0, 2])
	for row in range(1, 5):
		var reach := reaches[row - 1]
		for k in range(1, reach + 2):
			var ink: Color = inks["o" if k > reach else ("6" if k < reach else "5")]
			image.set_pixelv(from + Vector2i(-k * way, row), ink)


## The avalanche's snapped pine, ours, lying: its crown's tiers of needles
## to the west, widening from its tip, each drooping back toward the trunk,
## snow along their tops; its trunk running east out of them to the break.
## `crown` false: the trunk and its break alone (under the Medieval Age's).
static func _pine(crown: bool) -> Image:
	var image := Image.create(PINE.x, PINE.y, false, Image.FORMAT_RGBA8)
	_trunk(image, PINE_BREAK, Vector2i(PINE_CROWN - PINE_TIER, PINE_BREAK.y))
	if crown:
		var inks := HamletArt.INKS
		var mid := PINE_BREAK.y + 2
		for x in range(1, PINE_CROWN):
			var reach := roundi((2.5 + 4.5 * x / PINE_CROWN) * (0.65 + 0.35 * (x % PINE_TIER) / (PINE_TIER - 1.0)))
			for y in range(mid - reach, mid + reach + 1):
				var depth := y - (mid - reach)
				image.set_pixel(x, y, inks["y" if depth == 1 else ("s" if depth == 2 else ("F" if y < mid else ("f" if y < mid + reach - 1 else "t")))])
	var outline: Color = HamletArt.INKS["o"]
	_rim(image, outline, outline)
	return image


## The scree round the heap's foot, flat on the ground: pebbles spilt from
## its foot down the road and from its flanks either side, up them no higher
## than SCREE_RISE, fewer the further out, each lit on top with a pixel of
## shadow under it, none under the heap (its picture is the heap's, widened).
static func _scree(dice: RandomNumberGenerator) -> Image:
	var heap := texture("rockfall").get_image()
	var size := HEAP + Vector2i(2 * SCREE_FLANK, SCREE_FRONT)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var ends := _ends(heap)
	var bottoms: PackedInt32Array = ends[1]
	var wests: PackedInt32Array = ends[2]
	var easts: PackedInt32Array = ends[3]
	# Where they spill from (on the heap's picture) and which way: down from
	# its foot, out from its flanks.
	var spills: Array[Array] = []
	for x in HEAP.x:
		if bottoms[x] >= HEAP.y - SCREE_RISE:
			spills.append([Vector2i(x, bottoms[x]), Vector2i.DOWN])
	for y in range(HEAP.y - SCREE_RISE, HEAP.y):
		if easts[y] >= 0:
			spills.append([Vector2i(wests[y], y), Vector2i.LEFT])
			spills.append([Vector2i(easts[y], y), Vector2i.RIGHT])
	var flank := Vector2i(SCREE_FLANK, 0)
	# Clear: on the picture off its sides, under no heap, touching no pebble.
	var clear := func(pixel: Vector2i) -> bool:
		var under := pixel - flank
		if pixel.x < 1 or pixel.x > size.x - 2 or pixel.y >= size.y:
			return false
		if Rect2i(Vector2i.ZERO, HEAP).has_point(under) and heap.get_pixelv(under).a > 0.0:
			return false
		for near: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if Rect2i(Vector2i.ZERO, size).has_point(pixel + near) and image.get_pixelv(pixel + near).a > 0.0:
				return false
		return true
	for i in PEBBLES:
		var spill: Array = spills[dice.randi() % spills.size()]
		var from: Vector2i = spill[0]
		var way: Vector2i = spill[1]
		var out := 1 + roundi(pow(dice.randf(), 2.0) * (SCREE_FRONT if way == Vector2i.DOWN else SCREE_FLANK))
		# One or two wide, or two tall and as wide as three near the heap.
		var tall := dice.randi_range(1, 2 if out < 6 else 1)
		var pebble := Vector2i(dice.randi_range(tall, 3 if tall == 2 and out < 4 else tall), tall)
		var at := from + flank + way * out + (Vector2i(dice.randi_range(-1, 1), 0) if way == Vector2i.DOWN else Vector2i(0, dice.randi_range(0, 2)))
		if way == Vector2i.LEFT:
			at.x -= pebble.x - 1
		# The pebble and its shadow under it.
		var pixels: Array[Vector2i] = []
		for y in pebble.y + 1:
			for x in pebble.x:
				# Three wide and two tall, its top's corners round off.
				if y > 0 or pebble != Vector2i(3, 2) or x == 1:
					pixels.append(at + Vector2i(x, y))
		if not pixels.all(clear):
			continue
		for pixel: Vector2i in pixels:
			var row := pixel.y - at.y
			image.set_pixelv(pixel, ROCK[-1] if row == pebble.y else ROCK[4 if row == 1 else (1 if pebble.y == 2 else 2)])
	return image


## The avalanche's bank: its domes of snow raised back to front, each point
## lit by its slope from the west and above and the east end darker, a rim
## round it all.
static func _bank() -> Image:
	var image := Image.create(BANK.x, BANK.y, false, Image.FORMAT_RGBA8)
	var inks := HamletArt.INKS
	var height := func(x: int, y: int) -> float:
		var top := 0.0
		for dome: AABB in DOMES:
			var d := (Vector2(x, y) - Vector2(dome.position.x, dome.position.y)) / Vector2(dome.size.x, dome.size.y)
			if d.length_squared() < 1.0:
				top = maxf(top, dome.size.z * sqrt(1.0 - d.length_squared()))
		return top
	var sun := SUN.normalized()
	var snow := func(x: int, _y: int, normal: Vector3) -> Color:
		var lit := normal.dot(sun) - EAST_SHADE * clampf((x - BANK.x * 0.55) / (BANK.x * 0.45), 0.0, 1.0)
		for tone: Array in SNOW_TONES:
			if lit > tone[0]:
				return inks[tone[1]]
		return inks["W"]
	_raise(image, BANK_DEPTH, height, snow)
	var rim: Color = inks["S"]
	var lip: Color = inks["w"]
	_rim(image, rim, lip)
	return image


## Ground `depth` px deep along `image`'s bottom raised to `height`
## (Callable(x, y) -> px, 0 off it), drawn back to front: each point a
## column from the ground up in `ink` (Callable(x, y, its normal) -> Color),
## so the rows in front hide what they should.
static func _raise(image: Image, depth: int, height: Callable, ink: Callable) -> void:
	# Each point's height once, with a point's margin round them for slopes.
	var wide := image.get_width() + 2
	var heights := PackedFloat32Array()
	heights.resize(wide * (depth + 2))
	for y in depth + 2:
		for x in wide:
			heights[y * wide + x] = height.call(x - 1, y - 1)
	for y in depth:
		var ground := image.get_height() - depth + y
		for x in image.get_width():
			var at := (y + 1) * wide + x + 1
			var h := heights[at]
			if h <= 0.0:
				continue
			var slope := Vector3(heights[at - 1] - heights[at + 1], heights[at - wide] - heights[at + wide], 2.0)
			var color: Color = ink.call(x, y, slope.normalized())
			for up in range(maxi(0, ground - roundi(h)), ground + 1):
				image.set_pixel(x, up, color)


## Every drawn pixel of `image` beside an empty one in `side`, or in
## `bottom` when the empty one is below it (where it meets the ground).
static func _rim(image: Image, side: Color, bottom: Color) -> void:
	var size := image.get_size()
	var bounds := Rect2i(Vector2i.ZERO, size)
	for y in size.y:
		for x in size.x:
			if image.get_pixel(x, y).a == 0.0:
				continue
			var below := Vector2i(x, y + 1)
			if not bounds.has_point(below) or image.get_pixelv(below).a == 0.0:
				image.set_pixel(x, y, bottom)
				continue
			for beside: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1)]:
				if not bounds.has_point(beside) or image.get_pixelv(beside).a == 0.0:
					image.set_pixel(x, y, side)
					break
