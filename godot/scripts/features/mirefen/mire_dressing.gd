class_name MireDressing
extends MapLayer
## areas: field night +mirefen*
## The Mirefen alive (PIX-401, the v0.307 world audit: « a uniform fen of
## puddles and a few shrubs, one ruin and two camps »): dead trees standing
## in the mud, reed beds thick by the water and here and there in the fen,
## boardwalks over the wet ground from the bridges' and the ruin's ends to
## the paths, and the road west of the middle bridge going on as one to a
## stilt hut, another hut by the south bridge, and will-o'-wisps drifting
## over the fen at night, each a soft light. The walks and huts are placed
## by hand (WALKS, HUTS), the trees and reeds by the cell's own dice
## (`lay`, pure). What stands blocks only open ground off the paths, never
## a pack's home, a chest, a lair, today's patches nor a walk (no patch
## grows under it after), and never so as to close a way (Hamlet.fits); a walk lies flat and blocks
## nothing; reeds are walked through, as the woods are. The map itself is
## untouched. All drawn in code (MireArt), so the same without the paid
## pack.

const MAP := "mirefen"
## The boardwalks: each a strip two cells thick along its length, drawn down
## its middle (the line between its two rows or columns) so it runs on from
## a road or a bridge two cells wide: the middle road's west end to the
## west hut; the south bridge's two ends to the paths beside it, past the
## south hut; the north bridge's west end to its path; the ruin's doorway
## down to the road.
const WALKS: Array[Rect2i] = [
	Rect2i(4, 24, 8, 2), Rect2i(8, 34, 10, 2), Rect2i(26, 34, 6, 2), Rect2i(14, 14, 4, 2), Rect2i(44, 18, 2, 6),
]
## The stilt huts, by their left cell (two cells wide, facing a walk).
const HUTS: Array[Vector2i] = [Vector2i(5, 23), Vector2i(28, 33)]
## The share (per mille) of the fen's open cells growing a dead tree, and a
## reed bed: by the water (within REEDS_NEAR cells of it) and out in the fen.
const TREES := 60
const REEDS_BY_WATER := 300
const REEDS_OUT := 40
const REEDS_NEAR := 2
## The will-o'-wisps by night, over the fen and the channel, far apart.
const WISPS: Array[Vector2i] = [
	Vector2i(9, 9), Vector2i(34, 7), Vector2i(23, 19), Vector2i(37, 29), Vector2i(11, 41), Vector2i(24, 41),
	Vector2i(47, 40), Vector2i(55, 13), Vector2i(4, 29),
]
## A wisp's light: how far it reaches and how bright, and how far and how
## slowly it drifts about its place.
const WISP_REACH := 56.0
const WISP_ENERGY := 0.7
const WISP_DRIFT := 12.0
const WISP_HOP := 2.6
## A named monster's lair keeps this many cells clear round it (Gulp is
## twice a mimic's size).
const LAIR_CLEAR := 2


## What the Mirefen stands in, as it is laid: {"walks": [Rect2i],
## "huts": [cell], "trees": {cell: variant}, "reeds": {cell: variant},
## "blocks": [cells]}. `kept`: cells nothing may stand on (Hamlet.kept_on
## without the patches' decks, today's patches, where the hero arrives);
## `opened`: the field decor that blocks, which a walk lifts off its cells.
static func lay(map: MapData, kept: Dictionary, opened := {}) -> Dictionary:
	var blocks: Array[Vector2i] = []
	var out := {"walks": [] as Array[Rect2i], "huts": [] as Array[Vector2i], "trees": {}, "reeds": {}, "blocks": blocks}
	if map.id != MAP:
		return out
	var clear := kept.duplicate()
	for entry: Dictionary in Hunts.all():
		if String(entry.get("mapId", "")) == map.id and entry.has("lair"):
			var lair := Hunts.lair(entry)
			for dy in range(-LAIR_CLEAR, LAIR_CLEAR + 1):
				for dx in range(-LAIR_CLEAR, LAIR_CLEAR + 1):
					clear[lair + Vector2i(dx, dy)] = true
	for walk in WALKS:
		if _all_open(map, walk, opened):
			out["walks"].append(walk)
			for cell in _cells(walk.grow(1)):
				clear[cell] = true
	for hut in HUTS:
		var foot: Array[Vector2i] = [hut, hut + Vector2i.RIGHT]
		if Hamlet.fits(map, foot, kept, blocks):
			out["huts"].append(hut)
			blocks.append_array(foot)
			for cell in _cells(Rect2i(hut - Vector2i.ONE, Vector2i(4, 3))):
				clear[cell] = true
	var cells: Array = map.grid.keys()
	cells.sort()
	for cell: Vector2i in cells:
		if map.grid[cell] != "marsh" or clear.has(cell) or Scatter.choice(map.grid, cell) >= 0 or not map.is_walkable(cell):
			continue
		var h := absi(hash(Vector3i(cell.x, cell.y, 401)))
		if h % 1000 < TREES:
			var one: Array[Vector2i] = [cell]
			if Hamlet.fits(map, one, kept, blocks):
				out["trees"][cell] = (h >> 10) % AshArt.SNAGS.size()
				blocks.append(cell)
			continue
		var share := REEDS_BY_WATER if _by_water(map, cell) else REEDS_OUT
		if (h >> 4) % 1000 < share:
			out["reeds"][cell] = (h >> 14) % MireArt.REED_BEDS
	return out


## Whether every cell of `rect` is open ground, or only field decor stands
## there (`opened`): a walk lies on it.
static func _all_open(map: MapData, rect: Rect2i, opened: Dictionary) -> bool:
	return _cells(rect).all(func(cell: Vector2i) -> bool: return map.is_walkable(cell) or (opened.has(cell) and not map.portals.has(cell)))


static func _cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out


static func _by_water(map: MapData, cell: Vector2i) -> bool:
	for dy in range(-REEDS_NEAR, REEDS_NEAR + 1):
		for dx in range(-REEDS_NEAR, REEDS_NEAR + 1):
			if map.grid.get(cell + Vector2i(dx, dy), "") == "water":
				return true
	return false


# --- The layer ------------------------------------------------------------------

func plan(view: MapView, slices: Slicer) -> void:
	if view.data.id != MAP:
		return
	slices.add("plan_mire", func() -> void:
		# Today's patches kept clear; no later day's grows under what stands
		# (PatchesLayer.deal_patches).
		var kept := Hamlet.kept_on(view.data, {})
		kept.merge(view.patches)
		kept[view.arrival] = true
		var laid := lay(view.data, kept, view.solid_scatter)
		for walk: Rect2i in laid["walks"]:
			for cell in _cells(walk):
				view.bare[cell] = true
				if view.solid_scatter.has(cell):
					view.solid_scatter.erase(cell)
					view.data.covered.erase(cell)
		for cell: Vector2i in laid["blocks"]:
			view.data.covered[cell] = true
		# No field decor under what the fen grows.
		for cell: Vector2i in laid["trees"].keys() + laid["reeds"].keys() + laid["blocks"]:
			view.bare[cell] = true
		view.set_meta("mire", laid))


func build(view: MapView, slices: Slicer) -> void:
	if not view.has_meta("mire"):
		return
	var laid: Dictionary = view.get_meta("mire")
	slices.add("decor_mire_walks", func() -> void:
		for walk: Rect2i in laid["walks"]:
			_lay_walk(view, walk))
	slices.add("decor_mire_huts", func() -> void:
		for hut: Vector2i in laid["huts"]:
			_raise_hut(view, hut))
	slices.add("decor_mire_trees", func() -> void:
		for cell: Vector2i in laid["trees"]:
			var tree := _sprite(MireArt.texture("snag_%d" % laid["trees"][cell]))
			# Turned and set off its cell's middle a little, as the burnt
			# land's are (MapView._add_field_decor).
			var h := absi(hash(cell))
			tree.flip_h = (h >> 20) % 2 == 1
			stand_on(view, tree, cell, Vector2((h >> 12) % 5 - 2, -AshArt.SNAG_HEIGHT + TILE))
			block(view, cell))
	slices.add("decor_mire_reeds", func() -> void:
		for cell: Vector2i in laid["reeds"]:
			var bed := _sprite(MireArt.texture("reeds_%d" % laid["reeds"][cell]))
			var h := absi(hash(cell))
			bed.flip_h = (h >> 18) % 2 == 1
			stand_on(view, bed, cell, Vector2((h >> 9) % 7 - 3, TILE - MireArt.REED_SIZE.y)))
	slices.add("decor_mire_wisps", func() -> void:
		var wisps: Array[Node2D] = []
		for at: Vector2i in WISPS:
			wisps.append(_wisp(view, at))
		view.set_meta("mire_wisps", wisps))


## A walk's planks along its middle, flat on the ground.
func _lay_walk(view: MapView, walk: Rect2i) -> void:
	var across := walk.size.x >= walk.size.y
	var length := walk.size.x if across else walk.size.y
	for i in length:
		var cell := walk.position + (Vector2i(i, 0) if across else Vector2i(0, i))
		var n := absi(hash(Vector3i(cell.x, cell.y, 4011))) % MireArt.PLANKINGS
		var planks := _sprite(MireArt.texture("walk_%d%s" % [n, "" if across else "_down"]))
		# The planks' middle on the line between the strip's two rows (or
		# columns).
		var half := MireArt.WALK_ACROSS / 2
		planks.position = Vector2(cell * TILE) + (Vector2(0, TILE - half) if across else Vector2(TILE - (MireArt.WALK_SIZE.y - half), 0))
		planks.add_to_group("decor")
		view.ground.add_child(planks)


## A stilt hut on its two cells, its pool and ladder reaching down onto the
## walk before it; its window lit at night (no light of its own).
func _raise_hut(view: MapView, hut: Vector2i) -> void:
	var at := Vector2(0, TILE + MireArt.HUT_BELOW - MireArt.HUT_SIZE.y)
	var root := stand_on(view, _sprite(MireArt.texture("hut")), hut, at)
	var lit := _sprite(MireArt.texture("hut_lit"))
	lit.material = Lights.unshaded()
	lit.position = at - Vector2(0, TILE)
	lit.visible = false
	root.add_child(lit)
	view.night_glows.append(lit)
	var halo := _sprite(MireArt.halo(MapView.HALO_TINT, MapView.LAMP_HALO - 3, MapView.LAMP_HALO_PEAK))
	halo.centered = true
	halo.material = Lights.glow()
	halo.position = at - Vector2(0, TILE) + Vector2(MireArt.HUT_WINDOW.get_center())
	halo.visible = false
	root.add_child(halo)
	view.night_glows.append(halo)
	for cell: Vector2i in [hut, hut + Vector2i.RIGHT]:
		block(view, cell)


## A will-o'-wisp over `cell`: its heart, its halo and a soft light, shown
## at night, drifting about its place (still with Reduce motion).
func _wisp(view: MapView, cell: Vector2i) -> Node2D:
	var wisp := Node2D.new()
	wisp.position = MapView.center(cell)
	wisp.z_index = 5
	wisp.visible = false
	wisp.add_to_group("decor")
	var halo := _sprite(MireArt.halo())
	halo.centered = true
	halo.material = Lights.glow()
	wisp.add_child(halo)
	var heart := _sprite(MireArt.texture("wisp"))
	heart.centered = true
	heart.material = Lights.unshaded()
	wisp.add_child(heart)
	wisp.add_child(Lights.make(Vector2.ZERO, WISP_REACH, MireArt.WISP, WISP_ENERGY))
	view.props.add_child(wisp)
	view.night_glows.append(wisp)
	if not GameState.settings.reduce_motion:
		var drift := wisp.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for hop in 4:
			var h := absi(hash(Vector3i(cell.x, cell.y, hop)))
			var off := Vector2((h % 200) / 100.0 - 1.0, ((h >> 8) % 200) / 100.0 - 1.0) * WISP_DRIFT
			drift.tween_property(wisp, "position", MapView.center(cell) + off.round(), WISP_HOP + (h % 7) * 0.2)
		var breathe := wisp.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		breathe.tween_property(wisp, "modulate:a", 0.55, 1.7 + (cell.x % 3) * 0.3)
		breathe.tween_property(wisp, "modulate:a", 1.0, 1.7 + (cell.y % 3) * 0.3)
	return wisp


static func _sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	return sprite


## What the harness reports (mire=): how many trees, reed beds, walks and
## huts stand, how many wisps, and whether they're out ("lit" at night).
static func describe(view: MapView) -> String:
	if view == null or not view.has_meta("mire"):
		return ""
	var laid: Dictionary = view.get_meta("mire")
	var wisps: Array = view.get_meta("mire_wisps", [])
	var lit := wisps.any(func(wisp: Node2D) -> bool: return is_instance_valid(wisp) and wisp.visible)
	return "trees %d reeds %d walks %d huts %d wisps %d %s" % [
		laid["trees"].size(), laid["reeds"].size(), laid["walks"].size(), laid["huts"].size(), wisps.size(), "lit" if lit else "dark"]
