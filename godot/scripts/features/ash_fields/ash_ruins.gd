class_name AshRuins
extends MapLayer
## areas: travel field night +overworld*
## The Ash Fields' burnt farmsteads (PIX-397, step 2; the v0.307 world
## audit: « a flat grey plain with blobs, in a rectangle »). Five steads
## the Night of Ash burnt, each where it stood (STEADS, by hand): the house's
## frame charred black, its log walls fallen here and there, a charred keg
## or crate in what was its floor; a handcart left scorched by the door; a
## dead orchard in its rows (AshArt's trees, standing as they died); and a
## paddock's fence along its edge, fallen in places, the logs lying in the
## ash. Where the land heals round a lit ember lamp (Lamps, the Post's
## waystations) an orchard mends with it, tree by tree on the healed cells:
## a young tree where a dead one stood. Two steads' orchards lie by a
## waystation (Blackiron's, Greyhold's) so they half mend as a ring grows;
## every frame, cart and fence lies past the widest ring's reach and stays
## burnt (a piece laid on healed ground would mend as well: the char gone,
## the wood weathered, a floor gone). The Medieval Age's log fence
## (PunyProps.FENCE, joined to the posts beside it) and its kegs and crates
## are the pack's, and its young tree; so is the sooty floor, which without
## a frame round it read as a bare grey rectangle in the ash. The dead trees
## and the charred logs are AshArt's and the handcart HamletArt's, so
## without the pack a stead is its orchard, its cart and its fallen logs.
## What stands blocks open ground only, never a road, a portal, a pack's
## home, a chest or a way (Hamlet.fits, piece by piece in order: no way
## closed), and keeps clear of every waystation's and signpost's cell
## (test_ash_ruins); what lies flat blocks nothing. The field decor and a
## day's patch are lifted off a stead's cells, and any rock round its frame,
## so a stead is the same whatever the field grew, every day. The map is
## untouched.

const MAP := "overworld"
## Each stead: its house's frame (the rect its log walls ring) open at its
## `door` and fallen at its `fallen` cells (a log lying there instead);
## `rubble` on its floor (never beside a fallen wall: it would cut the
## ground round it in two, Hamlet.fits); its handcart's left cell; its orchard (a dead tree
## every other cell of the rect, row and column); its paddock's fence (a
## rect a cell thick) and the gaps where it fell.
const STEADS: Array[Dictionary] = [
	# West, its cart left past its orchard.
	{"frame": Rect2i(4, 22, 4, 3), "door": Vector2i(5, 24), "fallen": [Vector2i(4, 22)], "rubble": [Vector2i(6, 23)],
		"cart": Vector2i(16, 24), "orchard": Rect2i(10, 21, 5, 5), "paddock": Rect2i(2, 26, 8, 1), "gaps": [Vector2i(5, 26), Vector2i(8, 26)]},
	# Below Blackiron's waystation: its orchard half in the lamp's ring.
	{"frame": Rect2i(31, 22, 4, 3), "door": Vector2i(32, 24), "fallen": [Vector2i(31, 22)], "rubble": [Vector2i(33, 23)],
		"cart": Vector2i(35, 23), "orchard": Rect2i(22, 22, 7, 3), "paddock": Rect2i(30, 26, 7, 1), "gaps": [Vector2i(33, 26)]},
	# Between the roads north of the Ash's middle, its paddock by the road.
	{"frame": Rect2i(33, 13, 5, 3), "door": Vector2i(35, 15), "fallen": [Vector2i(37, 13), Vector2i(37, 14)], "rubble": [Vector2i(34, 14)],
		"cart": Vector2i(39, 16), "orchard": Rect2i(25, 13, 5, 3), "paddock": Rect2i(38, 12, 6, 1), "gaps": [Vector2i(40, 12), Vector2i(41, 12)]},
	# Below Greyhold's waystation: its orchard in the lamp's ring.
	{"frame": Rect2i(53, 17, 4, 3), "door": Vector2i(54, 19), "fallen": [Vector2i(53, 17)], "rubble": [Vector2i(55, 18)],
		"cart": Vector2i(57, 20), "orchard": Rect2i(60, 17, 7, 3), "paddock": Rect2i(52, 22, 5, 1), "gaps": [Vector2i(54, 22)]},
	# East, toward Greyhold's road out.
	{"frame": Rect2i(70, 21, 4, 3), "door": Vector2i(71, 23), "fallen": [Vector2i(70, 21)], "rubble": [Vector2i(72, 22)],
		"cart": Vector2i(75, 24), "orchard": Rect2i(76, 19, 5, 5), "paddock": Rect2i(68, 25, 8, 1), "gaps": [Vector2i(71, 25), Vector2i(74, 25)]},
]
## What burnt is drawn this dark (a shade lighter than the gate's burnt
## posts, GateArt.CHARRED, so a wall still reads as logs on the dark ash);
## what has mended, weathered grey-brown.
const CHARRED := Color(0.5, 0.42, 0.38)
const WEATHERED := Color(0.86, 0.8, 0.74)
## A log lying where a wall or a fence fell: AshArt's charred log (Shade's
## fallen log is drawn in his rock's olive greys, and any tint left it a
## mossy blob); once mended, his log (Skyline's debris, CC0) weathered.
const LOG := 703
## A young tree where a dead one stood, once the ground has healed: the
## Medieval Age's small tree (Farmland's orchard's).
const YOUNG := 16
## What lay on the floor: a keg or a crate (HamletArt's, at the Puny folk's
## scale).
const RUBBLE := ["keg", "box"]
## A burnt floor's soot under its frame, so a stead reads as a house's
## footprint (AshArt's inks: soot, char, heaped ash, by a die out of a
## hundred), in blocks of BLOCK pixels, its edge breaking up over EDGE
## pixels so it lies in the ash, not on it.
const SOOT := [[70, "N"], [90, "X"], [100, "Q"]]
const SOOT_ALPHA := 0.7
const BLOCK := 2
const EDGE := 6

static var _floors := {}


## The steads on `map` as they're laid: a list of pieces, each {"kind":
## "floor" (flat under a frame, its `size`), "post" (a frame's or a
## paddock's log wall, its fence `mask`), "log" (flat), "rubble" (its
## `art`), "cart", "tree" (its `variant`), "cell",
## "cells" it blocks, "mended" where the ground under it has healed
## (`healed`, MapView's)}, and "blocks", every cell blocked. `kept`: cells
## nothing may stand on (Hamlet.kept_on); `paid`: the pack's pieces laid.
static func lay(map: MapData, kept: Dictionary, healed: Dictionary, paid: bool) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var blocks: Array[Vector2i] = []
	var out := {"pieces": pieces, "blocks": blocks}
	if map.id != MAP:
		return out
	for stead: Dictionary in STEADS:
		# The orchard, then the frame from beside its door round to its other
		# side (so each wall leaves the ground round it one until the door is
		# all that's open), then the cart, the rubble and the paddock.
		var orchard: Rect2i = stead["orchard"]
		for y in range(orchard.position.y, orchard.end.y, 2):
			for x in range(orchard.position.x, orchard.end.x, 2):
				var cell := Vector2i(x, y)
				_stand(map, kept, out, {"kind": "tree", "cell": cell, "variant": absi(hash(cell)) % 3})
		var frame: Rect2i = stead["frame"]
		if paid:
			pieces.append({"kind": "floor", "cell": frame.position, "size": frame.size, "cells": [] as Array[Vector2i], "middle": frame.get_center()})
		var walls := ring(frame, stead["door"])
		for cell: Vector2i in walls:
			if cell in stead["fallen"]:
				_lie(map, kept, out, cell)
			elif paid:
				_stand(map, kept, out, {"kind": "post", "cell": cell, "set": walls})
		var cart: Vector2i = stead["cart"]
		_stand(map, kept, out, {"kind": "cart", "cell": cart, "cells": [cart, cart + Vector2i.RIGHT] as Array[Vector2i]})
		for i in stead["rubble"].size():
			if paid:
				_stand(map, kept, out, {"kind": "rubble", "cell": stead["rubble"][i], "art": RUBBLE[i % RUBBLE.size()]})
		var paddock: Rect2i = stead["paddock"]
		var fence: Array[Vector2i] = []
		for x in range(paddock.position.x, paddock.end.x):
			fence.append(Vector2i(x, paddock.position.y))
		for cell: Vector2i in fence:
			if cell in stead["gaps"]:
				_lie(map, kept, out, cell)
			elif paid:
				_stand(map, kept, out, {"kind": "post", "cell": cell, "set": fence})
	# Each post's fence joined to the posts that stand beside it.
	var standing := {}
	for piece: Dictionary in pieces:
		if piece["kind"] == "post":
			standing[piece["cell"]] = true
	for piece: Dictionary in pieces:
		piece["mended"] = healed.has(piece.get("middle", piece["cell"]))
		piece.erase("middle")
		if piece["kind"] == "post":
			var mask := 0
			for bit: Array in [[Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.DOWN, 4], [Vector2i.LEFT, 8]]:
				if standing.has(piece["cell"] + bit[0]) and (piece["cell"] + bit[0]) in piece["set"]:
					mask |= bit[1]
			piece["mask"] = mask
			piece.erase("set")
	return out


## A frame's walls round `rect`, from beside `door` round to its other side.
static func ring(rect: Rect2i, door: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		cells.append(Vector2i(x, rect.position.y))
	for y in range(rect.position.y + 1, rect.end.y):
		cells.append(Vector2i(rect.end.x - 1, y))
	for x in range(rect.end.x - 2, rect.position.x - 1, -1):
		cells.append(Vector2i(x, rect.end.y - 1))
	for y in range(rect.end.y - 2, rect.position.y, -1):
		cells.append(Vector2i(rect.position.x, y))
	var start := cells.find(door)
	return cells.slice(start + 1) + cells.slice(0, start)


## A piece standing on its cells, if it fits (Hamlet.fits: open ground,
## nothing kept, no way closed).
static func _stand(map: MapData, kept: Dictionary, out: Dictionary, piece: Dictionary) -> void:
	var cells: Array[Vector2i] = piece.get("cells", [piece["cell"]] as Array[Vector2i])
	if not Hamlet.fits(map, cells, kept, out["blocks"]):
		return
	piece["cells"] = cells
	out["pieces"].append(piece)
	out["blocks"].append_array(cells)


## A log lying flat on open ground.
static func _lie(map: MapData, kept: Dictionary, out: Dictionary, cell: Vector2i) -> void:
	if map.is_walkable(cell) and not kept.has(cell) and not Hamlet.is_way(map.id, map.tile_at(cell)) and cell not in out["blocks"]:
		out["pieces"].append({"kind": "log", "cell": cell, "cells": [] as Array[Vector2i]})


## Every cell a stead may lay a piece on, to lift the field decor off: its
## orchard's trees, its frame's walls, its cart, its rubble and its fence.
static func cells_of(stead: Dictionary) -> Array[Vector2i]:
	var out := ring(stead["frame"], stead["door"])
	var orchard: Rect2i = stead["orchard"]
	for y in range(orchard.position.y, orchard.end.y, 2):
		for x in range(orchard.position.x, orchard.end.x, 2):
			out.append(Vector2i(x, y))
	var paddock: Rect2i = stead["paddock"]
	for x in range(paddock.position.x, paddock.end.x):
		out.append(Vector2i(x, paddock.position.y))
	out.append_array([stead["cart"], stead["cart"] + Vector2i.RIGHT])
	out.append_array(stead["rubble"])
	return out


# --- The layer ------------------------------------------------------------------

func plan(view: MapView, slices: Slicer) -> void:
	if view.data.id != MAP:
		return
	slices.add("plan_ash_ruins", func() -> void:
		# The field's decor lifted off the steads, and a day's patch dealt
		# there (as under a lantern, Waysides): what stands there is theirs,
		# the same every day.
		for stead: Dictionary in STEADS:
			for cell: Vector2i in cells_of(stead):
				view.bare[cell] = true
				view.patches.erase(cell)
				if view.solid_scatter.has(cell):
					view.solid_scatter.erase(cell)
					view.data.covered.erase(cell)
			# And a rock it grew round a frame: beside a wall it shut the
			# ground round it, and the wall wasn't laid (Hamlet.fits).
			var round_it: Rect2i = (stead["frame"] as Rect2i).grow(1)
			for y in range(round_it.position.y, round_it.end.y):
				for x in range(round_it.position.x, round_it.end.x):
					var cell := Vector2i(x, y)
					if view.solid_scatter.has(cell):
						view.bare[cell] = true
						view.solid_scatter.erase(cell)
						view.data.covered.erase(cell)
		var kept := Hamlet.kept_on(view.data, {})
		kept[view.arrival] = true
		var laid := lay(view.data, kept, view.healed, PunyTown.available())
		for cell: Vector2i in laid["blocks"]:
			view.data.covered[cell] = true
		view.set_meta("ash_ruins", laid))


func build(view: MapView, slices: Slicer) -> void:
	if not view.has_meta("ash_ruins"):
		return
	var laid: Dictionary = view.get_meta("ash_ruins")
	slices.add("decor_ash_ruins", func() -> void:
		for piece: Dictionary in laid["pieces"]:
			_draw(view, piece)
		# A keepsake still waiting at a door (PIX-448) glints in its ash as
		# the Vault's gold does, day and night, so the stead reads as worth a
		# search: a glint, not the keepsake lying as a pickup does, which
		# would ask to be walked over.
		var lying := {}
		for stead: Dictionary in STEADS:
			if not Quests.keepsake_at(MAP, stead["door"], GameState.progression.quests).is_empty():
				var glint := AnimatedSprite2D.new()
				glint.sprite_frames = HamletArt.glint()
				glint.centered = false
				glint.material = Lights.unshaded()
				glint.position = Vector2(stead["door"] * TILE)
				glint.add_to_group("decor")
				glint.play()
				view.ground.add_child(glint)
				lying[stead["door"]] = glint
		view.set_meta("keepsakes", lying))


## The keepsake at `cell` found (PIX-448): no longer lying in the ash.
static func take_keepsake(view: MapView, cell: Vector2i) -> void:
	var lying: Dictionary = view.get_meta("keepsakes", {})
	if lying.has(cell):
		lying[cell].queue_free()
		lying.erase(cell)


## One piece: standing among the actors (and blocking its cells), or a log
## lying on the ground; charred, or mended on healed ground.
static func _draw(view: MapView, piece: Dictionary) -> void:
	var cell: Vector2i = piece["cell"]
	var mended: bool = piece["mended"]
	var h := absi(hash(Vector3i(cell.x, cell.y, 397)))
	var sprite := Sprite2D.new()
	sprite.centered = false
	match String(piece["kind"]):
		"floor":
			# Gone under the healed ground.
			if mended:
				return
			sprite.texture = floor_texture(piece["size"])
			sprite.position = Vector2(cell * TILE)
			sprite.add_to_group("decor")
			view.ground.add_child(sprite)
			return
		"log":
			sprite.texture = PunyTerrain.sheet().tile_texture(LOG) if mended else AshArt.texture("log")
			sprite.flip_h = h % 2 == 1
			sprite.position = Vector2(cell * TILE) + Vector2(h % 5 - 2, (h >> 3) % 3)
			if mended:
				sprite.modulate = WEATHERED
			sprite.add_to_group("decor")
			view.ground.add_child(sprite)
			return
		"post":
			sprite.texture = PunyProps.texture(PunyProps.FENCE[piece["mask"]])
			stand_on(view, sprite, cell, Vector2.ZERO)
		"rubble":
			sprite.texture = HamletArt.texture(piece["art"])
			stand_on(view, sprite, cell, Vector2(0, TILE - HamletArt.size(piece["art"]).y))
		"cart":
			sprite.texture = HamletArt.texture("handcart")
			sprite.flip_h = h % 2 == 1
			stand_on(view, sprite, cell, Vector2(0, TILE - HamletArt.size("handcart").y))
		"tree":
			if mended and not PunyTown.available():
				# Without the pack the healed ground's own saplings stand there.
				return
			if mended:
				sprite.texture = PunyProps.texture(YOUNG)
				stand_on(view, sprite, cell, Vector2.ZERO)
			else:
				# Standing as it died, a pixel or two off its row.
				sprite.texture = AshArt.texture("snag_%d" % piece["variant"])
				sprite.flip_h = h % 2 == 1
				stand_on(view, sprite, cell, Vector2(h % 3 - 1, TILE - AshArt.SNAG_HEIGHT))
	if piece["kind"] != "tree":
		sprite.modulate = WEATHERED if mended else CHARRED
	for taken: Vector2i in piece["cells"]:
		block(view, taken)


## A burnt house's floor `size` cells: soot in blocks, char and heaped ash
## here and there, its edge broken; made once a session for each size.
static func floor_texture(size: Vector2i) -> Texture2D:
	if not _floors.has(size):
		var width := size.x * TILE
		var height := size.y * TILE
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		for y in height:
			for x in width:
				var edge := mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
				var roll := absi(hash(Vector3i(x / BLOCK, y / BLOCK, 3971))) % 100
				if edge < EDGE and roll >= edge * 100 / EDGE:
					continue
				for soot: Array in SOOT:
					if roll < soot[0]:
						image.set_pixel(x, y, Color(AshArt.INKS[soot[1]], SOOT_ALPHA))
						break
		_floors[size] = ImageTexture.create_from_image(image)
	return _floors[size]


## What the harness reports (ashruins=): the pieces laid by kind, and how
## many stand mended: floors 5 posts 65 trees 40 carts 5 rubble 5 logs 14
## mended 0.
static func describe(view: MapView) -> String:
	if view == null or not view.has_meta("ash_ruins"):
		return ""
	var counts := {"floor": 0, "post": 0, "tree": 0, "cart": 0, "rubble": 0, "log": 0}
	var mended := 0
	for piece: Dictionary in view.get_meta("ash_ruins")["pieces"]:
		counts[piece["kind"]] += 1
		mended += 1 if piece["mended"] else 0
	return "floors %d posts %d trees %d carts %d rubble %d logs %d mended %d" % [
		counts["floor"], counts["post"], counts["tree"], counts["cart"], counts["rubble"], counts["log"], mended]
