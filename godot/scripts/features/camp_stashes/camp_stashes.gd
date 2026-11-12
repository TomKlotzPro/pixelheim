class_name CampStashes
extends MapLayer
## areas: field combat travel +overworld* +deepwood* +mirefen* +saltmere* +blackiron* +greyhold* +frostgate* +mountain_road*
## A stash by a camp's tent once its pack is cleared (PIX-453). A camp was
## a tent, a torch and a fight, and nothing made it worth seeking out. Each
## day camp (assets/data/camp_stashes.json, one a day pack's spawn) hides a
## small find and a line or two about whoever camped there, said as it
## opens. It shows while its pack is down (WorldState.slain, which saves),
## so a pack back before the hero looked takes its stash with it; once
## opened (opened_chests, as any chest) it stands open for good. Shut, it is
## a chest as the core's are (Interaction's own opening, the chest's look):
## no art of its own.

const DATA := "res://assets/data/camp_stashes.json"
## The stashes of the map drawn, on its view: {spawn id: cell}.
const META := "camp_stashes"

static var _stashes := {}


## Every camp's stash by its spawn's id: {loot, said}.
static func stashes() -> Dictionary:
	if _stashes.is_empty():
		_stashes = JSON.parse_string(FileAccess.get_file_as_string(DATA))["stashes"]
	return _stashes


## A camp's stash as a chest Spoils opens: its find, and its note said as
## it opens.
static func chest(spawn_id: String) -> Dictionary:
	return stashes()[spawn_id].merged({"id": "stash_" + spawn_id, "look": "chest"})


## Out while its pack is down; once opened, there for good.
static func shown(world: WorldState, spawn_id: String) -> bool:
	return spawn_id in world.slain or chest(spawn_id)["id"] in world.opened_chests


## Where each camp's stash stands on `map` ({spawn id: cell}), `camps` its
## pieces (CampsLayer.plan_camps): a cell of the camp's ring two off its
## home, the pack's own square left to it (a pack back at an open stash
## stands clear of it), beside the tent, else within two of it; open
## ground of the home's region that nothing covers yet, nor another camp's
## stash, nor a mining country's workings (`worked`, MapView.worked, laid
## before this plan). A camp left without one says so (a prop over its whole ring).
static func plan_on(map: MapData, camps: Dictionary, worked := {}) -> Dictionary:
	var out := {}
	for tent: Vector2i in camps:
		var spawn_id := String(camps[tent].get("spawn", ""))
		if not stashes().has(spawn_id):
			continue
		var spawn: Dictionary = Bestiary.spawns_on(map.id).filter(func(row: Dictionary) -> bool: return row["id"] == spawn_id)[0]
		var cell := _beside(map, camps, Vector2i(spawn["x"], spawn["y"]), tent, out.values(), worked)
		if cell.x >= 0:
			out[spawn_id] = cell
		else:
			push_warning("%s: no cell by %s's tent for its stash" % [map.id, spawn_id])
	return out


static func _beside(map: MapData, camps: Dictionary, home: Vector2i, tent: Vector2i, taken: Array, worked: Dictionary) -> Vector2i:
	for reach in [1, 2]:
		for offset: Vector2i in CampsLayer.CAMP_RING:
			var cell: Vector2i = home + offset
			if maxi(absi(offset.x), absi(offset.y)) == 2 and maxi(absi(cell.x - tent.x), absi(cell.y - tent.y)) <= reach \
					and map.is_walkable(cell) and map.region_at(cell) == map.region_at(home) and not map.portals.has(cell) \
					and not camps.has(cell) and not map.covered.has(cell) and not worked.has(cell) and cell not in taken:
				return cell
	return Vector2i(-1, -1)


## The shut stash a cell holds on the map drawn, as a chest standing there
## (Interaction's opening raises its find from its cell), or {}.
static func shut_at(view: MapView, cell: Vector2i) -> Dictionary:
	var cells: Dictionary = view.get_meta(META, {})
	for spawn_id: String in cells:
		var stash := chest(spawn_id)
		if cells[spawn_id] == cell and view.chest_sprites.has(stash["id"]) and stash["id"] not in GameState.world.opened_chests:
			return stash.merged({"x": cell.x, "y": cell.y})
	return {}


## Each stash out or gone as its camp stands now (on drawing, and each
## second): a chest among the core's (MapView.chest_sprites), so E opens it
## as one. Never put down on the hero's own cell; it waits a step.
static func refresh(view: MapView, hero: Vector2i) -> void:
	var cells: Dictionary = view.get_meta(META, {})
	for spawn_id: String in cells:
		var stash := chest(spawn_id)
		var cell: Vector2i = cells[spawn_id]
		var drawn := view.chest_sprites.has(stash["id"])
		if shown(GameState.world, spawn_id) and not drawn and cell != hero:
			var sprite := Sprite2D.new()
			sprite.texture = MapView.treasure_texture(stash, stash["id"] in GameState.world.opened_chests)
			sprite.position = MapView.center(cell)
			sprite.add_to_group("decor")
			var body := StaticBody2D.new()
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(TILE, TILE)
			shape.shape = rect
			body.add_child(shape)
			sprite.add_child(body)
			view.actors.add_child(sprite)
			view.chest_sprites[stash["id"]] = sprite
		elif drawn and not shown(GameState.world, spawn_id):
			view.chest_sprites[stash["id"]].queue_free()
			view.chest_sprites.erase(stash["id"])


## What the harness reports (stashes=): each camp's stash on the map drawn,
## where and how it stands (none, shut, open): mire_1@31,40:shut.
static func describe(view: MapView) -> String:
	var cells: Dictionary = view.get_meta(META, {})
	var out := PackedStringArray()
	for spawn_id: String in cells:
		var stash := chest(spawn_id)
		var cell: Vector2i = cells[spawn_id]
		var state := "none"
		if view.chest_sprites.has(stash["id"]):
			state = "open" if stash["id"] in GameState.world.opened_chests else "shut"
		out.append("%s@%d,%d:%s" % [spawn_id, cell.x, cell.y, state])
	return ",".join(out)


# --- The layer ------------------------------------------------------------------

## The stashes' cells taken before anything is drawn, so no bush grows nor
## pack paces there, out or not.
func plan(view: MapView, slices: Slicer) -> void:
	slices.add("plan_camp_stashes", func() -> void:
		var cells := plan_on(view.data, view.camps, view.worked)
		for cell: Vector2i in cells.values():
			view.data.covered[cell] = true
			view.bare[cell] = true
		view.set_meta(META, cells))


func build(view: MapView, slices: Slicer) -> void:
	slices.add("camp_stashes", func() -> void: refresh(view, view.arrival))
