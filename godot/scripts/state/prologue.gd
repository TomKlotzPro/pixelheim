class_name Prologue
## The Night of Ash (PIX-152): the courier's first night, played. A new hero
## starts on the road with the Chancellor's letter; drives off a scavenger at
## the gate; walks into the burning village; frees Bram, is bandaged by Sela,
## gives Maren the letter; and at dawn the survivors decide to rebuild. The
## save holds the step (1-5) only while it runs; 0 is done (and every hero
## from before). Pure, over progression.json's "prologue" and the survivors'
## "prologue" entries in npcs.json; GameState and the world act on it.

const DONE := 0
const SCAVENGER := 1
const GATE := 2
const BRAM := 3
const SELA := 4
const MAREN := 5


static func data() -> Dictionary:
	return Quests._data()["prologue"]


## What the line above the dock says at a step, "" outside the prologue.
static func objective(step: int) -> String:
	var steps: Array = data()["steps"]
	return String(steps[step - 1]["text"]) if step >= 1 and step <= steps.size() else ""


## The survivors on the square that night, where the fire put them, saying
## what they say then: [npc as for Npcs.on_map].
static func survivors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc: Dictionary in Npcs._data()["npcs"]:
		if not npc.has("prologue"):
			continue
		var at: Dictionary = npc["prologue"]
		var survivor := npc.duplicate()
		survivor.merge({"mapId": "town", "x": at["x"], "y": at["y"], "wander": false, "lines": at["lines"]}, true)
		survivor.erase("stall")
		out.append(survivor)
	return out


## The step a conversation with `npc_id` finishes, or DONE when it finishes none.
static func step_of(npc_id: String) -> int:
	for npc: Dictionary in Npcs._data()["npcs"]:
		if npc["id"] == npc_id and npc.has("prologue"):
			return int(npc["prologue"]["step"])
	return DONE


## Where a fresh hero stands when the night begins.
static func start() -> Dictionary:
	return data()["start"]


## The middle of the night on the day/night wheel, and the dawn after it.
static func night_steps() -> float:
	return 0.72 * DayNight.DAY_CYCLE_STEPS


static func dawn_steps() -> float:
	return 0.95 * DayNight.DAY_CYCLE_STEPS
