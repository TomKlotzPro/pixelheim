class_name Vault
## The Kings' Vault (PIX-257, the main story's step 11): what comes after
## the story. The old kings chained Fafnyr to the summit to sit on their
## gold; once he's freed he shows the courier the hoard he hated ("Take it.
## It's all corners."). It is a dungeon like the Reach's (depths.json
## "vault": five floors laid from seeds, the old foes of the mountain's deep
## floors, a guardian a floor, the very best gear), behind a door of black
## iron on the mountain road, shut until the dragon is freed - or open at
## once for a hero who slew him on the old mountain. It replaces the Deep
## Hunt. Nothing of it is saved but what any dungeon's is (fog, chests,
## named hunts), and the story ledger's word that the door was first opened.
## Pure, over depths.json; the world draws the door (Ways.barred) and plays
## the first word.

const DUNGEON := "vault"
## The story's scenes at the door's first opening: Fafnyr showing the hoard,
## or, for a hero who slew him on the old mountain, the door alone.
const FIRST_WORD := "vault_door"
const QUIET_WORD := "vault_door_quiet"


static func dungeon() -> Dictionary:
	return Depths.dungeon(DUNGEON)


## The Vault's first floor, where its door leads.
static func first_floor() -> String:
	return String(Depths.floors(DUNGEON)[0]["mapId"])


## Whether the door under the summit stands open for this hero: the dragon
## freed (depths.json `opens`, as MainQuest reads a step: the Night of
## Bells' chapter done), or slain on the old mountain (an old save's floors).
static func door_open(progression: ProgressionState, settlement: SettlementState) -> bool:
	return MainQuest.holds(dungeon()["opens"], progression, settlement)


## What the shut door says to a hero who tries it.
static func barred_line() -> String:
	return String(dungeon()["barred"])


## The scene the door's first opening plays as the hero steps through
## (`target`, the portal): Fafnyr's word, or the quiet one for a hero who
## slew him; "" for any other way, or once it's been heard.
static func first_word(target: Dictionary, progression: ProgressionState) -> String:
	# The mountain's gate says `barred: true`: str, never String(), reads both.
	if str(target.get("barred", "")) != DUNGEON:
		return ""
	if FIRST_WORD in progression.story_seen or QUIET_WORD in progression.story_seen:
		return ""
	return QUIET_WORD if slew_fafnyr(progression) else FIRST_WORD


## Whether this hero slew Fafnyr on the old mountain (its floor 10, or the
## floors past it): he's no one to show them the hoard.
static func slew_fafnyr(progression: ProgressionState) -> bool:
	return 10 in progression.cleared_levels or 15 in progression.cleared_levels
