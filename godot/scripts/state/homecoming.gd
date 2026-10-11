class_name Homecoming
## Coming Home (PIX-253 step 10, chapter 8): Morvax's choice and the
## endings. Once the collar is off he waits by the fountain - at his forge
## for a hero who slew Fafnyr on the old mountain and never had the night -
## with one question: "Do they want me back?" The courier's answer is the
## story's last word. "Come home." plays the festival ending, and he takes
## a room at the inn and the bench by the fountain and argues with Maren
## every day; "Stay with them." plays the lanterns ending, and he goes back
## up to the three and comes down on festival days. Both endings stop at
## Hilda's forge (Fafnyr warming his belly on her roof, or Hilda alone for
## a hero who slew him) and at Maren, then roll the credits.
##
## Old saves, no new field: the answer is its ending's scene in the story
## ledger (story.json's moments `ending:home` and `ending:stay`). A hero who
## saw the old game's ending (Morvax destroyed or laid to rest at his
## throne), or the late web hero who cast him down, has the step met and
## keeps it: nobody asks, and Morvax stays where step 8 left him. Pure,
## over progression.json's "home"; the world's Stage and Folk act on it.

## Morvax, by his id in the villagers' data (his forge's).
const MORVAX := "mountain_morvax"
## The two answers, as the story ledger keeps them (Story.ending_of).
const HOME := "home"
const STAY := "stay"


static func data() -> Dictionary:
	return Quests._data()["home"]


## The answers, in the choice's order: [{id, label, detail, reply, at?}].
static func choices() -> Array:
	return data()["choices"]


static func choice(choice_id: String) -> Dictionary:
	for entry: Dictionary in choices():
		if entry["id"] == choice_id:
			return entry
	return {}


## The chapter's title, over the choice: "Coming Home".
static func title() -> String:
	return String(MainQuest.step("morvax_choice").get("chapter", ""))


## What this hero answered Morvax: "home", "stay", or "" - not yet, or an
## old game's ending (he was destroyed or laid to rest at his throne).
static func chosen(progression: ProgressionState) -> String:
	var ending := Story.ending_of(progression.story_seen)
	return ending if ending in [HOME, STAY] else ""


## Whether this hero slew Fafnyr on the old mountain: the Night of Bells
## is the chapter they skip (its `skipIf`).
static func slew_fafnyr(progression: ProgressionState, settlement: SettlementState) -> bool:
	for number in range(1, MainQuest.chapters().size() + 1):
		if MainQuest.chapters()[number - 1].has("skipIf"):
			return MainQuest.skips(number, progression, settlement)
	return false


## Whether the dragon's night is behind this hero: freed at dawn (the
## collar off), or slain on the old mountain by a hero who never had the
## night. The City asks it (town.json's `freed`).
static func dragon_done(progression: ProgressionState, settlement: SettlementState) -> bool:
	return Bells.over(progression) or slew_fafnyr(progression, settlement)


## Whether Morvax's question is the story's next step: an ending to choose
## (the night over, or the letter read to a quiet mountain).
static func choice_due(progression: ProgressionState, settlement: SettlementState) -> bool:
	var step := MainQuest.next_step(progression, settlement)
	return not step.is_empty() and String(step["when"]["kind"]) == "chosen"


## The cell by the fountain where Morvax waits after the collar, and his
## bench once he's home.
static func bench() -> Vector2i:
	var at: Array = data()["waits"]
	return Vector2i(int(at[0]), int(at[1]))


## Where Morvax stands now: {mapId, x, y, bench (sitting on it)}. At his
## forge as step 8 left him; by the fountain once the collar is off,
## waiting with his question; home, on his bench there; staying, at his
## forge, and on his bench on festival days.
static func place(progression: ProgressionState, festival := false) -> Dictionary:
	var forge := Npcs.by_id(MORVAX, [])
	var at_forge := {"mapId": String(forge["mapId"]), "x": int(forge["x"]), "y": int(forge["y"]), "bench": false}
	var by_fountain := {"mapId": "town", "x": bench().x, "y": bench().y, "bench": true}
	match chosen(progression):
		HOME:
			return by_fountain
		STAY:
			return by_fountain if festival else at_forge
	if Bells.over(progression):
		by_fountain["bench"] = false
		return by_fountain
	return at_forge


## What Morvax says where he stands, or [] to say as he always did (step
## 8's words, and his letter's after it): his question while the choice
## waits; home, the day's side of his argument with Maren, then his bench;
## staying, his peace at the forge, or his festival word in town.
static func lines(progression: ProgressionState, settlement: SettlementState, festival: bool, day: int) -> Array:
	if choice_due(progression, settlement):
		return data()["ask"]
	match chosen(progression):
		HOME:
			return [String(argument(day)[0])] + Array(data()["bench"])
		STAY:
			return data()["festival"] if festival else data()["peace"]
	return []


## The day's argument, a pair: Morvax's side, and Maren's. One a day, in
## turn.
static func argument(day: int) -> Array:
	var pairs: Array = data()["argument"]
	return pairs[posmod(day, pairs.size())]


## What Maren says first, about him, "" for nothing: home, her side of the
## day's argument; staying, her word about festival days.
static func maren_word(progression: ProgressionState, day: int) -> String:
	match chosen(progression):
		HOME:
			return String(argument(day)[1])
		STAY:
			return String(data()["marenStay"])
	return ""


## The folk of `map_id` with Morvax where he stands now (place), saying
## what he says there: taken off his forge when he's in town, and onto the
## town map then. `folk` as Npcs.on_map gives them.
static func placed(folk: Array[Dictionary], map_id: String, progression: ProgressionState, settlement: SettlementState, festival: bool, day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc in folk:
		if npc.get("id", "") != MORVAX:
			out.append(npc)
	var where := place(progression, festival)
	if where["mapId"] != map_id:
		return out
	var morvax := Npcs.by_id(MORVAX, []).duplicate()
	morvax.merge(where, true)
	morvax["wander"] = false
	var said := lines(progression, settlement, festival, day)
	if not said.is_empty():
		morvax["lines"] = said
	out.append(morvax)
	return out


## Morvax's answer as the ending begins, and where the town's tour shows
## it: at his bench coming home, at the town's gate going back up.
static func reply(choice_id: String) -> String:
	return String(choice(choice_id).get("reply", ""))


static func reply_at(choice_id: String) -> Vector2i:
	var at: Array = choice(choice_id).get("at", [])
	return Vector2i(int(at[0]), int(at[1])) if at.size() == 2 else bench()


## Hilda's forge on the ending's tour: {line, detail} - Fafnyr warming his
## belly on her roof every morning, or, for a hero who slew him on the old
## mountain, Hilda lighting it herself.
static func forge_words(progression: ProgressionState, settlement: SettlementState) -> Dictionary:
	var forge: Dictionary = data()["forge"]
	if slew_fafnyr(progression, settlement):
		return {"line": String(forge["alone"]), "detail": String(forge["aloneDetail"])}
	return {"line": String(forge["line"]), "detail": String(forge["detail"])}


## Where Fafnyr lies on Hilda's forge.
static func dragon_cell() -> Vector2i:
	var at: Array = data()["forge"]["dragon"]
	return Vector2i(int(at[0]), int(at[1]))


## Maren's word to the courier, the ending's last stop.
static func maren_line() -> String:
	return String(data()["maren"])


## A delivered letter's row in the satchel (Journal): the fifth says how it
## came out once Morvax has his answer - home, or up with the three - and
## any other its own `answered`.
static func answered(quest: Dictionary, progression: ProgressionState) -> String:
	var by_answer: Dictionary = data()["answered"]
	var choice := chosen(progression)
	if quest.get("id", "") == Letters.fifth_quest()["id"] and by_answer.has(choice):
		return String(by_answer[choice])
	return String(quest["answered"])
