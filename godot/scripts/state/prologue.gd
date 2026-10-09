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
## The night as the tutorial (PIX-197): beats added after the first five,
## numbered on so a save made mid-night still means what it meant.
const HOUNDS := 6
const CAP := 7
const FIRES := 8
const EMBERS := 9
## The order the night is played in; each beat teaches one thing: strike,
## enter, roll, help, rest, wear, carry, use a skill, deliver.
const ORDER := [SCAVENGER, GATE, HOUNDS, BRAM, SELA, CAP, FIRES, EMBERS, MAREN]


## The beat after `step` (DONE after the last).
static func next(step: int) -> int:
	var at := ORDER.find(step)
	return ORDER[at + 1] if at >= 0 and at + 1 < ORDER.size() else DONE


## How many burning homes the hero puts out with the well's water.
static func fires_needed() -> int:
	return int(data()["fires"]["needed"])


static func data() -> Dictionary:
	return Quests._data()["prologue"]


## What the line above the dock says at a step, "" outside the prologue;
## `doused`: the fires out so far (the carrying beat counts them).
static func objective(step: int, doused := 0, heals_first := false) -> String:
	var steps: Array = data()["steps"]
	if step < 1 or step > steps.size():
		return ""
	# A hero whose first skill mends hears how to fight without it (PIX-205).
	var line: String = steps[step - 1].get("textHeal", steps[step - 1]["text"]) if heals_first else steps[step - 1]["text"]
	var text := line.replace("{fires}", "%d/%d" % [doused, fires_needed()])
	return Controls.say(text)


## A wave of the night's foes (the hounds at the gate, the embers on the
## square): {monsterId, level, elite, name, cells}.
static func wave(step: int) -> Dictionary:
	match step:
		HOUNDS:
			return data()["hounds"]
		EMBERS:
			return data()["embers"]
	return {}


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


## The dawn after the night (PIX-197), beat by beat: [{who, line, shadow?}],
## `who` a survivor's id (or the mayor's), "" for the telling.
static func dawn() -> Array:
	return data()["dawn"]


## Where each survivor stands on the square at dawn, round its heart: the
## elder before the hall, the mayor beside her, Bram and Sela either side.
static func dawn_places() -> Dictionary:
	var heart := Town.square()
	return {
		"elder": heart + Vector2i(0, -1), "mayor": heart + Vector2i(-2, 0),
		"villager_bram": heart + Vector2i(-3, 2), "innkeeper": heart + Vector2i(3, 2),
	}
