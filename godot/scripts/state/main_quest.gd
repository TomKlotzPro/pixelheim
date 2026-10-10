class_name MainQuest
## The main quest (PIX-144): chapters of steps read from the save, so the
## game can always say what comes next - on the line above the dock, in the
## journal, from the elder and the mayor. Since PIX-253 it is the story of
## Maren's letters in eight chapters: the tin, a letter and its region's
## relic for each of the four, then the fifth letter up the mountain road
## (step 8), the Night of Bells and home (steps 9 and 10, not written yet:
## the Night's first step is `unbuilt`, never met, and home has no step).
## A step is met by the save's own records (a quest taken or kept, a letter
## delivered, a floor cleared, a project, a settler), or by its `or`, the
## same kind of condition another way (an old save's floors: past the
## mountain's gate, or Morvax cast down);
## the next step is the first unmet one after the furthest met, so a hero who
## runs ahead is never sent back for a side errand. Optional steps (errands
## and village projects) never count as the furthest: a town grown before
## its hero went deep doesn't skip the mountain. A chapter may be skipped
## by a save (`skipIf`): a hero who slew Fafnyr on the old mountain keeps
## him slain and never plays the Night of Bells. Pure, over
## progression.json's "mainQuest"; Phase 2's village projects slot in as
## more kinds of step.


static func _doc() -> Dictionary:
	return Quests._data()["mainQuest"]


static func chapters() -> Array:
	return _doc()["chapters"]


## Every step in order, each with its chapter's title and number (and the
## chapter's `skipIf`, as `skip_if`, where it has one).
static func steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in chapters().size():
		var chapter: Dictionary = chapters()[index]
		for step: Dictionary in chapter["steps"]:
			var entry := step.duplicate()
			entry["chapter"] = chapter["title"]
			entry["chapter_number"] = index + 1
			if chapter.has("skipIf"):
				entry["skip_if"] = chapter["skipIf"]
			out.append(entry)
	return out


## Whether this save skips chapter `number` (from 1): its `skipIf` met.
static func skips(number: int, progression: ProgressionState, settlement: SettlementState) -> bool:
	var chapter: Dictionary = chapters()[number - 1]
	return chapter.has("skipIf") and _holds(chapter["skipIf"], progression, settlement)


## A step by its id, {} if there is none.
static func step(step_id: String) -> Dictionary:
	for entry: Dictionary in steps():
		if entry["id"] == step_id:
			return entry
	return {}


## Whether the save has met a step: its condition, or its `or`.
static func is_met(step: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	return _holds(step["when"], progression, settlement)


## Whether a step's condition holds for the save (`when`, with its `or`).
static func _holds(when: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	if when.has("or") and _holds(when["or"], progression, settlement):
		return true
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
		"climbed":
			# Any of the old mountain's floors cleared (PIX-257): a hero
			# who went up before the mountain's gate was barred, or before
			# the floors left play, is past the gate.
			return not progression.cleared_levels.is_empty()
		"unbuilt":
			# A step the story hasn't written yet (PIX-253 step 8: the
			# Night of Bells' first, which step 9 builds): never met.
			return false
	push_warning("MainQuest: unknown step kind %s" % when["kind"])
	return false


## The step to do next, or {} when the story is done. A chapter the save
## skips (`skipIf`) is no part of it.
static func next_step(progression: ProgressionState, settlement: SettlementState) -> Dictionary:
	var all := steps().filter(func(step: Dictionary) -> bool:
		return not step.has("skip_if") or not _holds(step["skip_if"], progression, settlement))
	var furthest := -1
	for index in all.size():
		if not all[index].get("optional", false) and is_met(all[index], progression, settlement):
			furthest = index
	for index in range(furthest + 1, all.size()):
		if not is_met(all[index], progression, settlement):
			return all[index]
	return {}


## The honest card's chapter (PIX-253 step 8: "To be continued: the Night
## of Bells."): once the fifth letter is delivered, the title of the
## chapter where the story runs out for this hero - the one its next step
## waits in while that step isn't written (`unbuilt`), or, with no step
## left, the first chapter this hero plays that has none yet (home, for a
## hero who skips the Night of Bells); "" while there's a step to take, or
## before the fifth letter.
static func continued(progression: ProgressionState, settlement: SettlementState) -> String:
	if not progression.quests.get(Letters.fifth_quest()["id"], {}).get("done", false):
		return ""
	var step := next_step(progression, settlement)
	if not step.is_empty():
		return String(step["chapter"]) if step["when"]["kind"] == "unbuilt" else ""
	for number in range(1, chapters().size() + 1):
		if chapters()[number - 1]["steps"].is_empty() and not skips(number, progression, settlement):
			return title_of(number)
	return ""


## The card's word over the chapter's title: "To be continued".
static func continued_word() -> String:
	return String(_doc()["continued"])


## The chapter whose card is due (PIX-253 step 2: a card like the dawn's
## "Day one" as a chapter opens): the one the next step is in, once the
## Night of Ash is over, until its card has been shown; 0 when none is. Each
## is shown once, and the story ledger keeps it ("chapter_3"): no new field
## in the save. A hero who runs ahead past a chapter, or loads a save from
## before the cards, sees only the card of the chapter they're in.
static func card_due(progression: ProgressionState, settlement: SettlementState) -> int:
	if progression.prologue != Prologue.DONE:
		return 0
	var step := next_step(progression, settlement)
	if step.is_empty():
		return 0
	var number := int(step["chapter_number"])
	return 0 if card_id(number) in progression.story_seen else number


## A chapter card's id in the story ledger.
static func card_id(number: int) -> String:
	return "chapter_%d" % number


## A chapter's title by its number, from 1.
static func title_of(number: int) -> String:
	return String(chapters()[number - 1]["title"])


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
