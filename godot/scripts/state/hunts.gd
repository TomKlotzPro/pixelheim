class_name Hunts
## The named monsters (PIX-156): one notorious creature per wild region, each
## bigger and meaner than its kind, with a lair it keeps to and one move of
## its own. The bounty board on the square posts each once the hero has
## cleared the floor its notice waits for, or won enough relics (PIX-170); the bounty is paid where it falls,
## with a drop nothing else gives, and Pixelheim talks about it. A named
## monster killed stays dead (ProgressionState.hunted). Pure, over
## combat.json's "named"; the world spawns them and enemy.gd fights them.


static func _named() -> Dictionary:
	return Bestiary._data()["named"]


## Every named monster, in the order the board posts them, each with its "id".
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for named_id: String in _named():
		out.append(named(named_id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["postedAfter"]) < int(b["postedAfter"]))
	return out


static func named(named_id: String) -> Dictionary:
	var entry: Dictionary = _named().get(named_id, {}).duplicate()
	if not entry.is_empty():
		entry["id"] = named_id
		if entry.has("deepDepth"):
			entry.merge(_deep_numbers(entry), true)
	return entry


## A Deep Hunt named monster (PIX-219): posted once the depth above its own
## is cleared, and as strong as an elite of its kind at its depth, made
## bigger (combat.json "namedDeep").
static func _deep_numbers(entry: Dictionary) -> Dictionary:
	var depth := int(entry["deepDepth"])
	var rules: Dictionary = Bestiary._data()["namedDeep"]
	var kind := Bestiary.monster(entry["monsterId"])
	var elite := Bestiary.spawn(entry["monsterId"], true, maxi(0, Dungeons.deep_level(depth) - int(kind["level"])))
	return {
		"postedAfter": Dungeons.floor_count() + depth - 1,
		"level": Dungeons.deep_level(depth) + int(rules["levels"]),
		"maxHp": roundi(int(elite["maxHp"]) * float(rules["hp"])),
		"attack": roundi(int(elite["attack"]) * float(rules["attack"])),
		"defense": int(elite["defense"]),
		"xp": roundi(int(elite["xp"]) * float(rules["xp"])),
		"gold": roundi(int(elite["gold"]) * float(rules["gold"])),
	}


## The named monster guarding a depth of the Deep Hunt now (PIX-219):
## posted and still alive, or {}.
static func deep_guardian(depth: int, cleared: Array, hunted: Array) -> Dictionary:
	for entry in all():
		if int(entry.get("deepDepth", 0)) == depth and status(entry, cleared, hunted) == "wanted":
			return entry
	return {}


## On the board: its floor is cleared. A chapter's boss (postedAfter 0,
## PIX-165: the Tidecaller) is in its lair from the start.
static func is_posted(entry: Dictionary, cleared: Array) -> bool:
	return int(entry["postedAfter"]) == 0 or int(entry["postedAfter"]) in cleared


## The floors the board counts as cleared (PIX-170): the hero's own, and a
## notice's floor once enough relics are won ("postedRelics"), so a hero out
## in the Reach before the mountain gets the bounties too.
static func board_floors(cleared: Array, relics: int, deepest := 0) -> Array:
	var out := cleared.duplicate()
	# Depths of the Deep Hunt cleared count as floors past the fifteenth
	# (PIX-219): the deep's own notices wait on them.
	for depth in range(1, deepest + 1):
		out.append(Dungeons.floor_count() + depth)
	for entry in all():
		if entry.has("postedRelics") and relics >= int(entry["postedRelics"]) and int(entry["postedAfter"]) not in out:
			out.append(int(entry["postedAfter"]))
	return out


## Whether the bounty board lists it: a chapter's boss is a quest, not a bounty.
static func on_board(entry: Dictionary) -> bool:
	return entry.get("board", true)


## "wanted" (posted, alive), "slain", or "" (not posted yet).
static func status(entry: Dictionary, cleared: Array, hunted: Array) -> String:
	if entry["id"] in hunted:
		return "slain"
	return "wanted" if is_posted(entry, cleared) else ""


## The posted, living named monsters whose lairs are on `map_id`.
static func living_on(map_id: String, cleared: Array, hunted: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in all():
		if entry["mapId"] == map_id and status(entry, cleared, hunted) == "wanted":
			out.append(entry)
	return out


## The board's notices: every posted one, wanted first, then the slain.
static func notices(cleared: Array, hunted: Array) -> Array[Dictionary]:
	var wanted: Array[Dictionary] = []
	var slain: Array[Dictionary] = []
	for entry in all():
		if not on_board(entry):
			continue
		match status(entry, cleared, hunted):
			"wanted":
				wanted.append(entry)
			"slain":
				slain.append(entry)
	wanted.append_array(slain)
	return wanted


## The next notice the board will post, or {} when all are up.
static func next_notice(cleared: Array) -> Dictionary:
	for entry in all():
		if on_board(entry) and not is_posted(entry, cleared):
			return entry
	return {}


## A named foe that stands down rather than falls (PIX-255): the Hollow
## Captain, once he's low enough to hear Maren's line read to him. The
## share of its health it yields at (`yieldsAt`), 0 for one that fights to
## the end.
static func yields_at(named_id: String) -> float:
	return float(named(named_id).get("yieldsAt", 0.0))


## Whether a fighter stands down now, with the health it has left: a named
## foe at or under its `yieldsAt` share.
static func yields(fighter: Dictionary) -> bool:
	var share := yields_at(String(fighter.get("named", "")))
	return share > 0.0 and int(fighter["hp"]) <= ceili(int(fighter["maxHp"]) * share)


## What a named foe says as it stands down ({lines, card, line}: its
## words heard out, then the card over the world), {} for one that doesn't.
static func standing_down(named_id: String) -> Dictionary:
	return named(named_id).get("yields", {})


static func lair(entry: Dictionary) -> Vector2i:
	return Vector2i(int(entry["lair"]["x"]), int(entry["lair"]["y"]))


## Its fighting record, as Bestiary.spawn makes one: its kind's sprite and
## family (its "id" is the kind's), its own name and numbers, and "named"
## for the bounty. It fights as an elite (its family's trick, gold bar).
static func fighter(named_id: String) -> Dictionary:
	var entry := named(named_id)
	var kind := Bestiary.monster(entry["monsterId"])
	return {
		"id": entry["monsterId"],
		"named": named_id,
		"name": entry["name"],
		"elite": true,
		"hp": int(entry["maxHp"]),
		"maxHp": int(entry["maxHp"]),
		"attack": int(entry["attack"]),
		"defense": int(entry["defense"]),
		"xp": int(entry["xp"]),
		"gold": int(entry["gold"]),
		"level": int(entry["level"]),
		"inflicts": kind.get("inflicts"),
	}


## What the town knows of one: where, what it pays, what it leaves.
static func reward_line(entry: Dictionary) -> String:
	return Text.t("Bounty %dg, and %s") % [int(entry["bounty"]), Catalog.item_name(entry["drop"])]
