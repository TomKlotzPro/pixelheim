class_name WorldState
extends Resource
## Where the hero stands and what they have explored (web WorldState plus the
## top-level worldSteps). Discovery is kept as map_id -> {Vector2i: true} for
## fast lookups and converted to the web's "x,y" string lists at the edges.

const FACINGS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

var map_id := "town"
var cell := Vector2i.ZERO
var facing := "down"
var discovered := {}
var opened_chests: Array[String] = []
## Visible-spawn ids cleared on the CURRENT map (web semantics); reset on map change.
var slain: Array[String] = []
## Tiles walked: turns the day/night wheel. Fractional in play, whole in saves.
var steps := 0.0


static func facing_name(direction: Vector2) -> String:
	for name: String in FACINGS:
		if FACINGS[name] == direction:
			return name
	return "down"


static func discovered_from_json(data: Dictionary) -> Dictionary:
	var out := {}
	for id: String in data:
		var seen := {}
		for key: String in data[id]:
			var parts := key.split(",")
			if parts.size() == 2:
				seen[Vector2i(int(parts[0]), int(parts[1]))] = true
		out[id] = seen
	return out


static func discovered_to_json(data: Dictionary) -> Dictionary:
	var out := {}
	for id: String in data:
		var keys: Array[String] = []
		for seen: Vector2i in data[id]:
			keys.append("%d,%d" % [seen.x, seen.y])
		out[id] = keys
	return out


static func from_dict(data: Dictionary) -> WorldState:
	var world := WorldState.new()
	var world_data: Dictionary = data["world"]
	var position: Dictionary = world_data["position"]
	world.map_id = position["mapId"]
	world.cell = Vector2i(position["x"], position["y"])
	world.facing = position.get("facing", "down")
	world.discovered = discovered_from_json(world_data.get("discovered", {}))
	world.opened_chests.assign(world_data.get("openedChests", []))
	world.slain.assign(world_data.get("slain", []))
	world.steps = data.get("worldSteps", 0)
	return world


func write_into(state: Dictionary) -> void:
	state["world"] = {
		"position": {"mapId": map_id, "x": cell.x, "y": cell.y, "facing": facing},
		"discovered": discovered_to_json(discovered),
		"openedChests": opened_chests.duplicate(),
		"slain": slain.duplicate(),
	}
	state["worldSteps"] = int(steps)
