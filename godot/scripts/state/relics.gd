class_name Relics
## The five relics (PIX-170): what the five climbers left in the Reach - Tam's
## ladle at Saltmere, the Black Ingot at Blackiron, Oskar's shield at
## Greyhold, Liane's lantern on the Frostgate - each won from its chapter's
## boss, and Maren's promise, given with the fifth letter once all four are
## home with her and she has told it all (PIX-253 step 8). With it the
## mountain's gate opens, on the road up to Morvax's forge. A hero who
## climbed before keeps it open. Pure, over progression.json's "relics".


static func _doc() -> Dictionary:
	return Quests._data()["relics"]


## The four out in the Reach: {itemId, named, place}.
static func all() -> Array:
	return _doc()["items"]


## Maren's quest that takes them home.
static func quest_id() -> String:
	return _doc()["questId"]


## The fifth relic, Maren's promise (an item), given with the fifth letter.
static func promise_id() -> String:
	return _doc()["promise"]


static func home(progression: ProgressionState) -> bool:
	return progression.quests.get(quest_id(), {}).get("done", false)


## How many are won: one for each chapter boss laid low, all of them once
## Maren has them.
static func found(progression: ProgressionState) -> int:
	if home(progression):
		return all().size()
	return all().filter(func(relic: Dictionary) -> bool: return relic["named"] in progression.hunted).size()


## Whether the mountain's gate stands open: Maren's promise given, with the
## fifth letter, as she tells it all once the relics are home (PIX-253 step
## 8: her confession, or the letter given to a hero who heard her old one),
## or any of the old mountain's floors ever cleared (a hero from before the
## gate was barred, or before the floors left play, PIX-257). It opens on
## the mountain road now, up to Morvax's forge.
static func gate_open(progression: ProgressionState) -> bool:
	return Letters.confession_id() in progression.story_seen or not Letters.fifth_kept(progression) \
			or not progression.cleared_levels.is_empty()


## What the barred gate says to a hero who tries it.
static func barred_line() -> String:
	return _doc()["barred"]
