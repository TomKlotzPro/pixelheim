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
## The burning homes put out with the well's water on that night (their
## ruin indices, PIX-197); saved only while there are some and it runs.
var prologue_doused: Array[int] = []
## The Night of Bells' beat while it runs (Bells, PIX-253 step 9): never
## written to the save, so a save made in the night plays it again from its
## start (the format stays web v4, no new field); 0 when it isn't running.
var bells := 0
## The named monsters killed (Hunts, PIX-156): they stay dead. Saved only
## once there is one.
var hunted: Array[String] = []
## The deepest depth of the Deep Hunt cleared (PIX-161); saved only once
## there is one.
var deepest := 0
## The deeds done (PIX-219); saved only once there is one.
var deeds: Array[String] = []
## Once-per-hero drops already taken (PIX-180: Fafnyr's first scale); saved
## only once there is one.
var firsts: Array[String] = []
## Every kind met in a fight (PIX-188: the codex by species, not family),
## with the highest level it was met at; saved once there is one.
var met := {}
## item id -> how many the hero has made at a station (PIX-231), so a
## crafting quest taken after the work counts it; saved once there is one.
var crafted := {}
## What the hero chose to follow in the journal (PIX-239): a quest's id, or a
## bounty's named monster; "" for the main story's next step. Let go once
## it's done (Journal.let_go); saved only while there is one.
var tracked := ""


static func from_dict(data: Dictionary) -> ProgressionState:
	var progress := ProgressionState.new()
	progress.unlocked_level = data["unlockedLevel"]
	progress.cleared_levels.assign(data["clearedLevels"])
	progress.quests = data["quests"].duplicate(true)
	progress.intro_seen = data["introSeen"]
	progress.story_seen.assign(data.get("storySeen", []))
	progress.prologue = int(data.get("prologue", 0))
	progress.prologue_doused.assign(data.get("prologueDoused", []))
	progress.hunted.assign(data.get("hunted", []))
	progress.deepest = int(data.get("deepHunt", 0))
	progress.deeds.assign(data.get("deeds", []))
	progress.firsts.assign(data.get("firsts", []))
	progress.met = data.get("met", {}).duplicate()
	progress.crafted = data.get("crafted", {}).duplicate()
	progress.tracked = String(data.get("tracked", ""))
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
		if not prologue_doused.is_empty():
			state["prologueDoused"] = prologue_doused.duplicate()
	if not hunted.is_empty():
		state["hunted"] = hunted.duplicate()
	if not firsts.is_empty():
		state["firsts"] = firsts.duplicate()
	if not met.is_empty():
		state["met"] = met.duplicate()
	if not crafted.is_empty():
		state["crafted"] = crafted.duplicate()
	if tracked != "":
		state["tracked"] = tracked
	if deepest > 0:
		state["deepHunt"] = deepest
	if not deeds.is_empty():
		state["deeds"] = deeds.duplicate()
