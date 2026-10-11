class_name Journal
## The journal's quest page as rows (PIX-239, after Tom's playtest: "le
## journal c'est pas clair"): every open thread in one list, grouped - the
## main story (its chapter and next step, then the quests that carry it),
## the town and its people (the quests taken from them), the bounty board
## (its notices still wanted). Each row says its next step in the words the
## line above the dock uses (Bearing), how far along it is, and whether it's
## ready to hand in. One row is followed: ProgressionState.tracked names a
## quest or a bounty's named monster, and "" follows the main story. Pure:
## everything it needs is passed in.

## The groups, in the order the page shows them, and their headings.
const GROUPS := ["story", "people", "bounties"]
const GROUP_NAMES := {"story": "Main story", "people": "Town and people", "bounties": "Bounties"}
## The main story's row: following it follows nothing else.
const STORY := ""


## The quests that carry the story (PIX-171): Maren's relics, her letters
## (PIX-253) and each relic's hunt.
static func is_main_line(quest: Dictionary) -> bool:
	if quest["id"] == Relics.quest_id() or Letters.is_letter(quest):
		return true
	var named: String = quest["objective"].get("named", "")
	return Relics.all().any(func(relic: Dictionary) -> bool: return relic["named"] == named)


## Every row of the page in its order, group by group: {group, id, title,
## line (the next step and where, as Bearing.line says it, without the
## count), progress ("2/3", "" for a single thing), ready (it can be handed
## in), bounty (a notice's gold, 0 otherwise), lead (Bearing's), detail
## (the longer word: the elder's hint, what the giver asked, the lair),
## letter (one of Maren's, in the satchel), delivered (a letter handed
## over and answered), follows (whether E can follow it: not a letter
## delivered)}. The main story is its chapter, then the courier's satchel
## (PIX-253 step 2: Maren's letters, those delivered with their answer),
## then the other quests that carry it. A thread whose place lies past a
## gate still shut says the gate's line and leads to what opens it
## (PIX-254, Gates.detour; `discovered`: the save's fog of war).
static func rows(progression: ProgressionState, settlement: SettlementState, items: Dictionary, discovered: Dictionary = {}) -> Array[Dictionary]:
	var by_group := {"story": [], "people": [], "bounties": []}
	var past_gates := func(lead: Dictionary) -> Dictionary: return Gates.detour(lead, progression, settlement, items, discovered)
	var step := MainQuest.next_step(progression, settlement)
	if not step.is_empty():
		var lead: Dictionary = past_gates.call(Bearing.of_step(step, progression, settlement, items))
		by_group["story"].append(_row("story", STORY, chapter_title(step), lead, String(step.get("hint", ""))))
	for carried: Dictionary in Letters.satchel(progression):
		by_group["story"].append(_letter(carried["quest"], carried["delivered"], progression, settlement, items, discovered))
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		if entry.is_empty() or entry.get("done", false) or Letters.is_letter(quest):
			continue
		var group := "story" if is_main_line(quest) else "people"
		var row := _row(group, quest["id"], quest["name"], past_gates.call(Bearing.of_quest(quest, progression, settlement, items)), _asked(quest, progression, settlement))
		row["ready"] = Quests.is_ready(quest, progression.quests, items)
		by_group[group].append(row)
	for notice: Dictionary in Hunts.notices(Bearing.board_floors(progression, settlement), progression.hunted):
		if notice["id"] in progression.hunted:
			continue
		var row := _row("bounties", notice["id"], notice["name"], past_gates.call(Bearing.of_bounty(notice)), Text.t("Its lair: %s. %s.") % [notice["where"], Hunts.reward_line(notice)])
		row["bounty"] = int(notice["bounty"])
		by_group["bounties"].append(row)
	var out: Array[Dictionary] = []
	for group: String in GROUPS:
		for row: Dictionary in by_group[group]:
			out.append(row)
	return out


## "Chapter 2: The Relics": a main story step's chapter, numbered.
static func chapter_title(step: Dictionary) -> String:
	return Text.t("Chapter %d: %s") % [step["chapter_number"], step["chapter"]]


## The row followed now: the active lead's quest or bounty, or STORY while
## the main story leads (or once it's told and nothing is followed).
static func followed(progression: ProgressionState, settlement: SettlementState, items: Dictionary) -> String:
	var lead := Bearing.active(progression, settlement, items)
	if lead.is_empty() or lead["main"]:
		return STORY
	return String(lead["quest_id"]) if String(lead["quest_id"]) != "" else String(lead["named"])


## Follows row `id` (STORY: the main story); whether that changed anything.
## A letter already delivered is read, not followed: nothing changes.
static func follow(progression: ProgressionState, id: String) -> bool:
	if progression.tracked == id or progression.quests.get(id, {}).get("done", false):
		return false
	progression.tracked = id
	return true


## A quest handed in, or a bounty's quarry slain, isn't followed any more:
## the main story leads again, and the save forgets it.
static func let_go(progression: ProgressionState) -> void:
	var id := progression.tracked
	if id != "" and (progression.quests.get(id, {}).get("done", false) or id in progression.hunted):
		progression.tracked = ""


## The quests handed in, outside the main line: the page's last word.
static func kept(progression: ProgressionState) -> Array:
	return Quests.all().filter(func(quest: Dictionary) -> bool:
		return not is_main_line(quest) and progression.quests.get(quest["id"], {}).get("done", false))


static func _row(group: String, id: String, title: String, lead: Dictionary, detail: String) -> Dictionary:
	var bare := lead.duplicate()
	bare["progress"] = ""
	return {
		"group": group, "id": id, "title": title, "line": Bearing.line(bare), "progress": String(lead["progress"]),
		"ready": false, "bounty": 0, "lead": lead, "detail": detail, "letter": false, "delivered": false, "follows": true,
	}


## One of Maren's letters in the satchel (PIX-253 step 2), by its address
## ("Letter to Old Wenna, Saltmere"): to deliver, it leads to its recipient
## and says what the envelope says; delivered, it's answered - who answered
## and with what, and under the list the answer's heart - and there's
## nothing left to follow.
static func _letter(quest: Dictionary, delivered: bool, progression: ProgressionState, settlement: SettlementState, items: Dictionary, discovered: Dictionary = {}) -> Dictionary:
	var lead := Gates.detour(Bearing.of_quest(quest, progression, settlement, items), progression, settlement, items, discovered)
	var row := _row("story", quest["id"], String(quest["addressed"]), lead, Catalog.item(quest["objective"]["itemId"]).get("description", ""))
	row["letter"] = true
	if delivered:
		row.merge({"line": String(quest["answered"]), "detail": String(quest["gist"]), "delivered": true, "follows": false}, true)
	return row


## What a giver asked, who and where they are, and where to look (PIX-171);
## for a letter, who it goes to (PIX-253).
static func _asked(quest: Dictionary, progression: ProgressionState, settlement: SettlementState) -> String:
	var objective: Dictionary = quest["objective"]
	var who: String = objective["to"] if objective["kind"] == "deliverTo" else quest["giver"]
	var npc: Dictionary = Npcs.by_id(who, settlement.settlers)
	var asked := "%s (%s, %s)" % [quest["brief"], npc.get("name", ""), Catalog.place_name(npc.get("mapId", ""))]
	if objective["kind"] == "deliverTo":
		return asked
	var where := Quests.where(quest, Town.done_projects(settlement))
	return asked + ("  " + where if where != "" else "")
