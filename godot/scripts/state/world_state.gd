class_name WorldState
extends Resource
## areas: travel
## Where the hero stands and what they have explored (web WorldState plus the
## top-level worldSteps). Discovery is kept as map_id -> {Vector2i: true} for
## fast lookups, and packed a bit per cell for the save (PIX-302).

const FACINGS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

var map_id := "town"
var cell := Vector2i.ZERO
var facing := "down"
var discovered := {}
var opened_chests: Array[String] = []
## Visible-spawn ids whose packs are cleared, on any map (PIX-142: no longer
## reset at every door). A pack comes back after Packs' respawnSteps or a
## night at the inn.
var slain: Array[String] = []
## Spawn id -> the step it was cleared on (saved as slainAt, only when kept).
var slain_at := {}
## Gathering spot id -> the step it was picked on (saved as gatheredAt, only
## when kept; PIX-143).
var gathered_at := {}
## Tiles walked: turns the day/night wheel. Fractional in play, whole in saves.
var steps := 0.0
## Per map, its fog as last packed for a save (`packed_fog`): {seen, count, fog}.
var _packed := {}


static func facing_name(direction: Vector2) -> String:
	for name: String in FACINGS:
		if FACINGS[name] == direction:
			return name
	return "down"


## A map's seen cells as a save holds them (PIX-302): the box they lie in
## and a bit per cell of it, row by row from its top left, in base64 (all
## 40,000 cells of every map on disk take some 7 KB, where "x,y" strings
## took 290). A map with nothing seen keeps an empty box.
static func pack_fog(seen: Dictionary) -> Dictionary:
	if seen.is_empty():
		return {"x": 0, "y": 0, "w": 0, "h": 0, "bits": ""}
	var low := Vector2i(1 << 30, 1 << 30)
	var high := -low
	for cell: Vector2i in seen:
		low = low.min(cell)
		high = high.max(cell)
	var size := high - low + Vector2i.ONE
	var bits := PackedByteArray()
	bits.resize((size.x * size.y + 7) / 8)
	for cell: Vector2i in seen:
		var at := (cell.y - low.y) * size.x + cell.x - low.x
		bits[at >> 3] |= 1 << (at & 7)
	return {"x": low.x, "y": low.y, "w": size.x, "h": size.y, "bits": Marshalls.raw_to_base64(bits)}


## The seen cells a packed map holds ({Vector2i: true}).
static func unpack_fog(packed: Variant) -> Dictionary:
	var seen := {}
	if not packed is Dictionary or not packed.get("bits") is String or packed["bits"] == "":
		return seen
	var origin := Vector2i(int(packed.get("x", 0)), int(packed.get("y", 0)))
	var width := int(packed.get("w", 0))
	var cells := width * int(packed.get("h", 0))
	var bits := Marshalls.base64_to_raw(packed["bits"])
	for index in mini(bits.size(), (cells + 7) / 8):
		var byte := bits[index]
		if byte == 0:
			continue
		for bit in 8:
			var at := index * 8 + bit
			if byte & (1 << bit) and at < cells:
				seen[origin + Vector2i(at % width, at / width)] = true
	return seen


## Every map's fog packed (a fresh world's).
static func pack_all(discovered: Dictionary) -> Dictionary:
	var out := {}
	for id: String in discovered:
		out[id] = pack_fog(discovered[id])
	return out


## The fog as the save holds it, each map packed again only when more of it
## was seen since its last save (cells are only ever added): walking saves
## every few seconds, and a well-explored hero's other maps cost nothing.
func packed_fog() -> Dictionary:
	var out := {}
	for id: String in discovered:
		var seen: Dictionary = discovered[id]
		var kept: Dictionary = _packed.get(id, {})
		if kept.is_empty() or not is_same(kept["seen"], seen) or int(kept["count"]) != seen.size():
			kept = {"seen": seen, "count": seen.size(), "fog": pack_fog(seen)}
			_packed[id] = kept
		out[id] = kept["fog"].duplicate()
	return out


static func from_dict(data: Dictionary) -> WorldState:
	var world := WorldState.new()
	var world_data: Dictionary = data["world"]
	var position: Dictionary = world_data["position"]
	world.map_id = position["mapId"]
	world.cell = Vector2i(position["x"], position["y"])
	world.facing = position.get("facing", "down")
	var fog: Variant = world_data.get("discovered", {})
	if fog is Dictionary:
		for id: String in fog:
			var seen := unpack_fog(fog[id])
			world.discovered[id] = seen
			# What was loaded is what a save writes, until more is seen.
			var packed: Dictionary = fog[id] if fog[id] is Dictionary else pack_fog(seen)
			world._packed[id] = {"seen": seen, "count": seen.size(), "fog": packed}
	world.opened_chests.assign(world_data.get("openedChests", []))
	world.slain.assign(world_data.get("slain", []))
	var cleared: Dictionary = world_data.get("slainAt", {})
	for spawn_id: String in cleared:
		world.slain_at[spawn_id] = int(cleared[spawn_id])
	var picked: Dictionary = world_data.get("gatheredAt", {})
	for spot_id: String in picked:
		world.gathered_at[spot_id] = int(picked[spot_id])
	world.steps = data.get("worldSteps", 0)
	return world


func write_into(state: Dictionary) -> void:
	state["world"] = {
		"position": {"mapId": map_id, "x": cell.x, "y": cell.y, "facing": facing},
		"discovered": packed_fog(),
		"openedChests": opened_chests.duplicate(),
		"slain": slain.duplicate(),
	}
	if not slain_at.is_empty():
		state["world"]["slainAt"] = slain_at.duplicate()
	if not gathered_at.is_empty():
		state["world"]["gatheredAt"] = gathered_at.duplicate()
	state["worldSteps"] = int(steps)
