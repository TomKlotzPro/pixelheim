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
## each lifted to the depth's level; every few depths an elite guards it, and
## every tenth a warden (PIX-216). A twisted depth's hoard is a quarter
## richer, and a milestone's brings its crystal home.
static func deep_def(depth: int) -> Dictionary:
	if _deep.has(depth):
		return _deep[depth]
	var rules: Dictionary = _rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = depth * 104729 + 3
	var foes: Array = rules["foes"]
	# Foes climb faster than a hero levels (PIX-217): the deepest depth
	# measures a build, not the hours.
	var target := int(rules["startLevel"]) + floori((depth - 1) * float(rules["levelsPerDepth"]))
	var count := mini(3 + depth / 3, 6)
	var encounters: Array = []
	var start := rng.randi_range(0, foes.size() - 1)
	var twist := String(modifier_at(depth).get("id", ""))
	for i in count:
		# Stepping through the list by a prime keeps neighbours apart: one
		# depth's foes come from many families.
		var monster_id: String = foes[(start + i * 7) % foes.size()]
		var encounter := {"monsterId": monster_id, "lift": maxi(0, target - int(Bestiary.monster(monster_id)["level"]))}
		if i == count - 1 and depth % int(rules["eliteEvery"]) == 0:
			encounter["elite"] = true
		# A proud depth: two of its foes elites besides the guardian.
		if twist == "proud" and i < 2 and count > 2:
			encounter["elite"] = true
		encounters.append(encounter)
	if is_warden_depth(depth):
		# The warden stands where the guardian would, a boss with its own
		# attacks, lifted to the depth and named for the deep.
		var wardens: Array = rules["wardens"]
		var warden: Dictionary = wardens[(depth / int(rules["bossEvery"]) - 1) % wardens.size()]
		encounters[encounters.size() - 1] = {
			"monsterId": warden["monsterId"], "name": warden["name"], "warden": true,
			"lift": maxi(0, target - int(Bestiary.monster(warden["monsterId"])["level"])),
		}
	var gold: Array = rules["rewardGold"]
	var descriptions: Array = rules["descriptions"]
	# The hoard's potion grows with the depth (PIX-217).
	var potion := ""
	for step: Dictionary in rules["hoardPotions"]:
		if depth >= int(step["from"]):
			potion = step["itemId"]
	var rewards: Array = [potion, "gem"] if depth % int(rules["eliteEvery"]) == 0 else [potion]
	var mark := milestone(depth)
	if not mark.is_empty():
		rewards.append(mark["itemId"])
	_deep[depth] = {
		"level": floor_count() + depth,
		"name": Text.t("%s, depth %d") % [rules["names"][0], depth],
		"description": descriptions[(depth - 1) % descriptions.size()],
		"encounters": encounters,
		"rewardItemIds": rewards,
		"rewardGold": roundi((int(gold[0]) + int(gold[1]) * depth) * (1.25 if twist != "" else 1.0)),
		"modifier": twist,
	}
	return _deep[depth]


static func _rules() -> Dictionary:
	return Bestiary._data()["deepHunt"]


## Every bossEvery-th depth a warden guards (PIX-216).
static func is_warden_depth(depth: int) -> bool:
	return depth % int(_rules()["bossEvery"]) == 0


## A depth's one twist (PIX-216), the same every visit: swift, warded,
## venomous or proud. None on the first depth, nor where a warden stands
## (the warden is twist enough).
static func modifier_at(depth: int) -> Dictionary:
	if depth <= 1 or is_warden_depth(depth):
		return {}
	var twists: Array = _rules()["modifiers"]
	var rng := RandomNumberGenerator.new()
	rng.seed = depth * 6151 + 11
	return twists[rng.randi_range(0, twists.size() - 1)]


## The twist of the floor at `level`, {} above the Deep Hunt.
static func modifier(level: int) -> Dictionary:
	return modifier_at(depth_of(level)) if is_deep(level) else {}


## How much more often a twisted depth's foes drop something (PIX-216).
static func loot_luck(level: int) -> float:
	return float(_rules()["modifierLuck"]) if not modifier(level).is_empty() else 0.0


## The milestone at `depth` ({depth, itemId, elder, homecoming}), or {}.
static func milestone(depth: int) -> Dictionary:
	for mark: Dictionary in _rules()["milestones"]:
		if int(mark["depth"]) == depth:
			return mark
	return {}


## The first milestone past `deepest`, {} once all are reached.
static func next_milestone(deepest: int) -> Dictionary:
	for mark: Dictionary in _rules()["milestones"]:
		if int(mark["depth"]) > deepest:
			return mark
	return {}


## The deepest milestone reached, {} before the first.
static func milestone_reached(deepest: int) -> Dictionary:
	var reached := {}
	for mark: Dictionary in _rules()["milestones"]:
		if int(mark["depth"]) <= deepest:
			reached = mark
	return reached


## The depths the gate opens (PIX-216): the first, the first of every tier
## (deepTiers.every) the hero has reached, and the one past the deepest.
static func deep_entries(deepest: int) -> Array[int]:
	var every := int(Economy._data()["deepTiers"]["every"])
	var out: Array[int] = [1]
	var depth := 1 + every
	while depth <= deepest:
		out.append(depth)
		depth += every
	if deepest > 0 and deepest + 1 not in out:
		out.append(deepest + 1)
	return out


## How many levels above their kind a floor's foes stand (PIX-170).
static func lift(level: int) -> int:
	return int(floor_def(level).get("lift", 0))


## The loot a floor's kills roll from: the pools of the depth its foes now
## fight at, the mountain's best.
static func drop_floor(level: int) -> int:
	return mini(level + lift(level), floor_count())


## The name a floor's lifted foes wear (PIX-188): "Cellar", "Deep".
static func epithet(level: int) -> String:
	if is_deep(level):
		return String(Bestiary._data()["deepHunt"]["epithet"])
	return String(floor_def(level).get("epithet", ""))


## How deep the Deep Hunt forges its gear at `level` (PIX-191): 0 above it,
## then a tier more every deepTiers.every depths.
static func deep_tier(level: int) -> int:
	if not is_deep(level):
		return 0
	return 1 + (depth_of(level) - 1) / int(Economy._data()["deepTiers"]["every"])


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
