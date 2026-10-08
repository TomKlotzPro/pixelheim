class_name Dungeons
## The dungeons behind the overworld's gates and their fifteen floors
## (src/game/hero/levels.ts), the floor select's rules (DungeonSelect.tsx)
## and the floor a first clear unlocks (grantFloorRewards). Pure, over the
## exported combat.json.


static func dungeon(dungeon_id: String) -> Dictionary:
	return Bestiary._data()["dungeons"].get(dungeon_id, {})


static func floor_def(level: int) -> Dictionary:
	if is_deep(level):
		return deep_def(level - floor_count())
	return Bestiary._data()["levels"][level - 1]


## Below the fifteenth floor lies the Deep Hunt (PIX-161), once Morvax is
## down: depths without end, one floor level each past 15.
static func is_deep(level: int) -> bool:
	return level > floor_count()


static func depth_of(level: int) -> int:
	return level - floor_count()


static var _deep := {}


## A depth of the Deep Hunt, generated from its number so it's the same
## every visit: more foes the deeper (three to six), drawn from every family,
## each lifted to the depth's level; every few depths an elite guards it.
static func deep_def(depth: int) -> Dictionary:
	if _deep.has(depth):
		return _deep[depth]
	var rules: Dictionary = Bestiary._data()["deepHunt"]
	var rng := RandomNumberGenerator.new()
	rng.seed = depth * 104729 + 3
	var foes: Array = rules["foes"]
	var target := int(rules["startLevel"]) + depth - 1
	var count := mini(3 + depth / 3, 6)
	var encounters: Array = []
	var start := rng.randi_range(0, foes.size() - 1)
	for i in count:
		# Stepping through the list by a prime keeps neighbours apart: one
		# depth's foes come from many families.
		var monster_id: String = foes[(start + i * 7) % foes.size()]
		var encounter := {"monsterId": monster_id, "lift": maxi(0, target - int(Bestiary.monster(monster_id)["level"]))}
		if i == count - 1 and depth % int(rules["eliteEvery"]) == 0:
			encounter["elite"] = true
		encounters.append(encounter)
	var gold: Array = rules["rewardGold"]
	var descriptions: Array = rules["descriptions"]
	_deep[depth] = {
		"level": floor_count() + depth,
		"name": Text.t("%s, depth %d") % [rules["names"][0], depth],
		"description": descriptions[(depth - 1) % descriptions.size()],
		"encounters": encounters,
		"rewardItemIds": ["greater_potion", "gem"] if depth % int(rules["eliteEvery"]) == 0 else ["greater_potion"],
		"rewardGold": int(gold[0]) + int(gold[1]) * depth,
	}
	return _deep[depth]


## How many levels above their kind a floor's foes stand (PIX-170).
static func lift(level: int) -> int:
	return int(floor_def(level).get("lift", 0))


## The loot a floor's kills roll from: the pools of the depth its foes now
## fight at, the mountain's best.
static func drop_floor(level: int) -> int:
	return mini(level + lift(level), floor_count())


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
