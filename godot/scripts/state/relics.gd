class_name Relics
## The five relics (PIX-170): what the five climbers left in the Reach - Tam's
## ladle at Saltmere, the Black Ingot at Blackiron, Oskar's shield at
## Greyhold, Liane's lantern on the Frostgate - each won from its chapter's
## boss, and Maren's promise once all four are home with her. With them the
## mountain's gate opens. A hero who climbed before the gate was barred keeps
## it open. Pure, over progression.json's "relics".


static func _doc() -> Dictionary:
	return Quests._data()["relics"]


## The four out in the Reach: {itemId, named, place}.
static func all() -> Array:
	return _doc()["items"]


## Maren's quest that takes them home.
static func quest_id() -> String:
	return _doc()["questId"]


static func home(progression: ProgressionState) -> bool:
	return progression.quests.get(quest_id(), {}).get("done", false)


## How many are won: one for each chapter boss laid low, all of them once
## Maren has them.
static func found(progression: ProgressionState) -> int:
	if home(progression):
		return all().size()
	return all().filter(func(relic: Dictionary) -> bool: return relic["named"] in progression.hunted).size()


## Whether the mountain's gate stands open: the relics home with Maren, or
## any floor ever cleared (a hero from before the gate was barred).
static func gate_open(progression: ProgressionState) -> bool:
	return home(progression) or not progression.cleared_levels.is_empty()


## What the barred gate says to a hero who tries it.
static func barred_line() -> String:
	return _doc()["barred"]
