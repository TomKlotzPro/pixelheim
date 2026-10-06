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


static func from_dict(data: Dictionary) -> ProgressionState:
	var progress := ProgressionState.new()
	progress.unlocked_level = data["unlockedLevel"]
	progress.cleared_levels.assign(data["clearedLevels"])
	progress.quests = data["quests"].duplicate(true)
	progress.intro_seen = data["introSeen"]
	return progress


func write_into(state: Dictionary) -> void:
	state["unlockedLevel"] = unlocked_level
	state["clearedLevels"] = cleared_levels.duplicate()
	state["quests"] = quests.duplicate(true)
	state["introSeen"] = intro_seen
