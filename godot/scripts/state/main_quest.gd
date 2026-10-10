class_name MainQuest
## The main quest (PIX-144): chapters of steps read from the save, so the
## game can always say what comes next - on the line above the dock, in the
## journal, from the elder and the mayor. Since PIX-253 it is the story of
## Maren's letters in eight chapters: the tin, a letter and its region's
## relic for each of the four, then the mountain, the Night of Bells and
## home (the last three still today's climb, to be replaced). A step is met
## by the save's own records (a quest taken or kept, a letter delivered, a
## floor cleared, a project, a settler);
## the next step is the first unmet one after the furthest met, so a hero who
## runs ahead is never sent back for a side errand. Optional steps (errands
## and village projects) never count as the furthest: a town grown before
## its hero went deep doesn't skip the mountain. Pure, over
## progression.json's "mainQuest"; Phase 2's village projects slot in as
## more kinds of step.


static func _doc() -> Dictionary:
	return Quests._data()["mainQuest"]


static func chapters() -> Array:
	return _doc()["chapters"]


## Every step in order, each with its chapter's title and number.
static func steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in chapters().size():
		var chapter: Dictionary = chapters()[index]
		for step: Dictionary in chapter["steps"]:
			var entry := step.duplicate()
			entry["chapter"] = chapter["title"]
			entry["chapter_number"] = index + 1
			out.append(entry)
	return out


## A step by its id, {} if there is none.
static func step(step_id: String) -> Dictionary:
	for entry: Dictionary in steps():
		if entry["id"] == step_id:
			return entry
	return {}


## Whether the save has met a step.
static func is_met(step: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	var when: Dictionary = step["when"]
	match String(when["kind"]):
		"questTaken":
			return progression.quests.has(when["questId"])
		"questDone":
			return progression.quests.get(when["questId"], {}).get("done", false)
		"cleared":
			return int(when["level"]) in progression.cleared_levels
		"townTier":
			return settlement.town_tier >= int(when["tier"])
		"settler":
			return when["settlerId"] in settlement.settlers
		"settlers":
			return settlement.settlers.size() >= int(when["count"])
		"project":
			return when["projectId"] in Town.done_projects(settlement)
		"seen":
			return when["sceneId"] in progression.story_seen
		"hunted":
			# A relic's chapter boss laid low (PIX-170).
			return when["named"] in progression.hunted
		"delivered":
			# One of Maren's letters handed over, or its keepsake already
			# home: an old save is never sent back with it (PIX-253).
			return Letters.delivered(Quests.by_id(when["questId"]), progression)
	push_warning("MainQuest: unknown step kind %s" % when["kind"])
	return false


## The step to do next, or {} when the story is done.
static func next_step(progression: ProgressionState, settlement: SettlementState) -> Dictionary:
	var all := steps()
	var furthest := -1
	for index in all.size():
		if not all[index].get("optional", false) and is_met(all[index], progression, settlement):
			furthest = index
	for index in range(furthest + 1, all.size()):
		if not is_met(all[index], progression, settlement):
			return all[index]
	return {}


## The line above the dock: "Next: ...", or "" once the story is done.
static func objective(progression: ProgressionState, settlement: SettlementState) -> String:
	var step := next_step(progression, settlement)
	return Text.t("Next: %s") % step["text"] if not step.is_empty() else ""


## What the elder and the mayor say about it. Maren says it in her own
## words where the step names her (PIX-204), or nothing rather than "ask
## Maren" to her face.
static func hint(progression: ProgressionState, settlement: SettlementState, speaker := "") -> String:
	var step := next_step(progression, settlement)
	if step.is_empty():
		return String(_doc()["done"])
	if speaker == "elder":
		if step.has("elderHint"):
			return String(step["elderHint"])
		if "Maren" in String(step["hint"]):
			return ""
	return String(step["hint"])
