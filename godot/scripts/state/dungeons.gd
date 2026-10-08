class_name Dungeons
## The dungeons behind the overworld's gates and their fifteen floors
## (src/game/hero/levels.ts), the floor select's rules (DungeonSelect.tsx)
## and the floor a first clear unlocks (grantFloorRewards). Pure, over the
## exported combat.json.


static func dungeon(dungeon_id: String) -> Dictionary:
	return Bestiary._data()["dungeons"].get(dungeon_id, {})


static func floor_def(level: int) -> Dictionary:
	return Bestiary._data()["levels"][level - 1]


## XP for clearing a floor the first time (clearXpPerFloor per floor deep).
static func clear_xp(level: int) -> int:
	return int(Bestiary._data()["clearXpPerFloor"]) * level


static func floor_count() -> int:
	return Bestiary._data()["levels"].size()


## The floor's last encounter: its boss, or the elite that guards it.
static func boss_of(level: int) -> Dictionary:
	var encounters: Array = floor_def(level)["encounters"]
	return encounters[encounters.size() - 1]


## Floors open one by one: the first clear of a floor unlocks the next.
static func is_open(level: int, unlocked_level: int) -> bool:
	return level <= unlocked_level


## A sealed dungeon (the Undermountain) shows its seal until any floor opens.
static func any_open(dungeon_id: String, unlocked_level: int) -> bool:
	for level: int in dungeon(dungeon_id)["floors"]:
		if is_open(level, unlocked_level):
			return true
	return false


static func unlocked_after(level: int, unlocked_level: int) -> int:
	return maxi(unlocked_level, mini(level + 1, floor_count()))


## Clearing the last floor for the first time wins the game (the Victory screen).
static func is_final(level: int) -> bool:
	return level == floor_count()
