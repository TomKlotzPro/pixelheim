class_name MainQuest
## The main quest (PIX-144): chapters of steps read from the save, so the
## game can always say what comes next - on the line above the dock, in the
## journal, from the elder and the mayor. Since PIX-253 it is the story of
## Maren's letters in eight chapters: the tin, a letter and its region's
## relic for each of the four, then the fifth letter up the mountain road
## (step 8), the Night of Bells (step 9: its beats, `bells` steps met while
## the night runs past them or once it's over) and home (step 10: Morvax's
## choice, a `chosen` step met once an ending is in the story ledger). A
## step the story hasn't written yet would be `unbuilt`, never met, with
## the honest card (`continued`) where it waits.
## A step is met by the save's own records (a quest taken or kept, a letter
## delivered, a project, a settler, a scene seen, a named foe down); the
## next step is the first unmet one after the furthest met, so a hero who
## runs ahead is never sent back for a side errand. Optional steps (errands
## and village projects) never count as the furthest: a town grown before
## its hero went deep doesn't skip the mountain. Pure, over
## progression.json's "mainQuest"; Phase 2's village projects slot in as
## more kinds of step. (The old mountain's floors, which met steps by an
## `or` and skipped a chapter for a hero who slew Fafnyr there, left with
## the old saves, PIX-319.)


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


## Whether the save has met a step: its condition.
static func is_met(step: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	return _holds(step["when"], progression, settlement)


## Whether a condition written as a step's is met by the save (the Kings'
## Vault's door asks this way, PIX-257).
static func holds(when: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	return _holds(when, progression, settlement)


## Whether every step of chapter `number` (from 1) is met, its optional
## errands aside: the chapter is done. A chapter with no step yet isn't.
static func chapter_done(number: int, progression: ProgressionState, settlement: SettlementState) -> bool:
	var asked: Array = chapters()[number - 1]["steps"].filter(func(step: Dictionary) -> bool: return not step.get("optional", false))
	return not asked.is_empty() and asked.all(func(step: Dictionary) -> bool: return is_met(step, progression, settlement))


## Whether a step's condition holds for the save (`when`).
static func _holds(when: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	match String(when["kind"]):
		"questTaken":
			return progression.quests.has(when["questId"])
		"questDone":
			return progression.quests.get(when["questId"], {}).get("done", false)
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
			# won: a hero who ran ahead is never sent back with it (PIX-253).
			return Letters.delivered(Quests.by_id(when["questId"]), progression)
		"bells":
			# A beat of the Night of Bells (PIX-253 step 9): met while the
			# night runs past it, or once the collar is off.
			return Bells.step_met(when, progression)
		"chosen":
			# Morvax's choice made (PIX-253 step 10): one of his two
			# endings in the story ledger.
			return Story.ending_of(progression.story_seen) != ""
		"unbuilt":
			# A step the story hasn't written yet (PIX-253 steps 8 and 9
			# had home waiting so, until step 10 wrote it): never met.
			return false
		"chapterDone":
			# A whole chapter told (PIX-257: the Night of Bells, the dragon
			# freed, opens the Kings' Vault).
			return chapter_done(int(when["chapter"]), progression, settlement)
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


## The honest card's chapter (PIX-253 step 8: "To be continued: the Night
## of Bells.", then "...: Coming Home." until step 10 wrote it, and none
## since): once the fifth letter is delivered, the title of the
## chapter where the story runs out for this hero - the one its next step
## waits in while that step isn't written (`unbuilt`), or, with no step
## left, the first chapter that has none yet; "" while there's a step to
## take, or before the fifth letter.
static func continued(progression: ProgressionState, settlement: SettlementState) -> String:
	if not progression.quests.get(Letters.fifth_quest()["id"], {}).get("done", false):
		return ""
	var step := next_step(progression, settlement)
	if not step.is_empty():
		return String(step["chapter"]) if step["when"]["kind"] == "unbuilt" else ""
	for number in range(1, chapters().size() + 1):
		if chapters()[number - 1]["steps"].is_empty():
			return title_of(number)
	return ""


## The card's word over the chapter's title: "To be continued".
static func continued_word() -> String:
	return String(_doc()["continued"])


## The chapter whose card is due (PIX-253 step 2: a card like the dawn's
## "Day one" as a chapter opens): the one the next step is in, once the
## Night of Ash is over, until its card has been shown; 0 when none is. Each
## is shown once, and the story ledger keeps it ("chapter_3"). A hero who runs ahead past a chapter, or loads a save from
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
