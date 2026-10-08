class_name ProgressionState
extends Resource
## Dungeon unlocks and the quest ledger (web GameState: unlockedLevel,
## clearedLevels, quests, introSeen). Quests and floors play again with
## PIX-125/126; the ledger is kept faithfully until then.

var unlocked_level := 1
var cleared_levels: Array[int] = []
## quest id -> {progress, done}
var quests := {}
var intro_seen := true
## Story moments already played for this hero (PIX-32: boss intros once).
## Saved only once there is one, so saves from before stay byte for byte.
var story_seen: Array[String] = []
## The Night of Ash's step while it runs (Prologue, PIX-152); 0 when done,
## and saved only while it isn't.
var prologue := 0


static func from_dict(data: Dictionary) -> ProgressionState:
	var progress := ProgressionState.new()
	progress.unlocked_level = data["unlockedLevel"]
	progress.cleared_levels.assign(data["clearedLevels"])
	progress.quests = data["quests"].duplicate(true)
	progress.intro_seen = data["introSeen"]
	progress.story_seen.assign(data.get("storySeen", []))
	progress.prologue = int(data.get("prologue", 0))
	return progress


func write_into(state: Dictionary) -> void:
	state["unlockedLevel"] = unlocked_level
	state["clearedLevels"] = cleared_levels.duplicate()
	state["quests"] = quests.duplicate(true)
	state["introSeen"] = intro_seen
	if not story_seen.is_empty():
		state["storySeen"] = story_seen.duplicate()
	if prologue > 0:
		state["prologue"] = prologue
