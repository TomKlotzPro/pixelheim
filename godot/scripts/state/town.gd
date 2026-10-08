class_name Town
## Pixelheim's growth and money that works, ported from src/game/economy/
## {town,bank}.ts and settlers.ts: town tiers and what they require, rent and
## rest perks, the bank's savings and caravans, and what recruits ask. Pure
## functions over assets/data/town.json and npcs.json.

const MAX_TIER := 4
const TWO_32 := 4294967296

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/town.json"))
	return _doc


static func tier(number: int) -> Dictionary:
	return _data()["tiers"][clampi(number, 1, MAX_TIER) - 1]


## The tier the ledger offers next; {} at the cap.
static func next_tier(current: int) -> Dictionary:
	return {} if current >= MAX_TIER else tier(current + 1)


# ---- village projects (PIX-145) ------------------------------------------------
# Each age past the Hamlet is a handful of projects, each paid in gold and a
# region's material, each changing the town the moment it's funded; the last
# of an age raises the town to that age (and its perks). They replace the
# web's charters, which cost more than the game ever paid and changed a few
# cells of the map.

## The ages, from the Village up: {tier, requires: [{kind, line, ...}], projects}.
static func ages() -> Array:
	return _data()["ages"]


static func age(tier_number: int) -> Dictionary:
	for entry: Dictionary in ages():
		if int(entry["tier"]) == tier_number:
			return entry
	return {}


static func project(project_id: String) -> Dictionary:
	for entry: Dictionary in ages():
		for candidate: Dictionary in entry["projects"]:
			if candidate["id"] == project_id:
				return candidate
	return {}


## The age a project belongs to.
static func age_of(project_id: String) -> int:
	for entry: Dictionary in ages():
		for candidate: Dictionary in entry["projects"]:
			if candidate["id"] == project_id:
				return int(entry["tier"])
	return 0


## The projects done: the save's list, or for a save from before projects
## every project of the ages its town tier had reached.
static func done_projects(settlement: SettlementState) -> Array[String]:
	var out: Array[String] = []
	if not settlement.projects.is_empty():
		out.assign(settlement.projects)
		return out
	for entry: Dictionary in ages():
		if int(entry["tier"]) <= settlement.town_tier:
			for candidate: Dictionary in entry["projects"]:
				out.append(candidate["id"])
	return out


## Every project of the ages up to `tier_number` (a town grown that far).
static func projects_through(tier_number: int) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in ages():
		if int(entry["tier"]) <= tier_number:
			for candidate: Dictionary in entry["projects"]:
				out.append(candidate["id"])
	return out


## The age's requirements still unmet, as their lines.
static func age_blockers(tier_number: int, progression: ProgressionState, settlement: SettlementState) -> Array[String]:
	var out: Array[String] = []
	for need: Dictionary in age(tier_number).get("requires", []):
		var met := true
		match String(need["kind"]):
			"cleared":
				met = int(need["level"]) in progression.cleared_levels
			"settlers":
				met = settlement.settlers.size() >= int(need["count"])
		if not met:
			out.append(need["line"])
	return out


## The age the ledger works on: the first not finished, or 0 when all are.
static func current_age(settlement: SettlementState) -> int:
	var done := done_projects(settlement)
	for entry: Dictionary in ages():
		for candidate: Dictionary in entry["projects"]:
			if candidate["id"] not in done:
				return int(entry["tier"])
	return 0


## Why a project can't be funded now, or "".
static func project_blocker(project_id: String, progression: ProgressionState, settlement: SettlementState, gold: int, items: Dictionary) -> String:
	var entry := project(project_id)
	if project_id in done_projects(settlement):
		return "Already built."
	var tier_number := age_of(project_id)
	if tier_number != current_age(settlement):
		return "Finish the %s first." % tier(current_age(settlement))["name"]
	var blockers := age_blockers(tier_number, progression, settlement)
	if not blockers.is_empty():
		return blockers[0] + "."
	if gold < int(entry["cost"]["gold"]):
		return "The treasury asks %dg." % entry["cost"]["gold"]
	for item_id: String in entry["cost"]["items"]:
		if int(items.get(item_id, 0)) < int(entry["cost"]["items"][item_id]):
			return "It takes %d %s." % [entry["cost"]["items"][item_id], Catalog.item_name(item_id)]
	return ""


## A project's price as one line: "250g, 2 Wolf Pelt".
static func cost_line(project_id: String) -> String:
	var cost: Dictionary = project(project_id)["cost"]
	var parts: Array[String] = ["%dg" % cost["gold"]]
	for item_id: String in cost["items"]:
		parts.append("%d %s" % [cost["items"][item_id], Catalog.item_name(item_id)])
	return ", ".join(parts)


## The notice board on the square that opens the projects ledger.
static func project_board() -> Vector2i:
	var at: Dictionary = _data()["projectBoard"]
	return Vector2i(int(at["x"]), int(at["y"]))


## The town map's cells a set of finished projects changes: cell -> tile.
static func town_patches(done: Array) -> Dictionary:
	var out := {}
	for entry: Dictionary in ages():
		for candidate: Dictionary in entry["projects"]:
			if candidate["id"] in done:
				for cell: Array in candidate["tiles"]:
					out[Vector2i(int(cell[0]), int(cell[1]))] = cell[2]
	return out


## Village rent: one coin more per property from tier 2 (rentPerProperty).
static func rent_per_property(current: int) -> int:
	return int(_data()["rentPerVictory"]) + (1 if current >= 2 else 0)


## Town inns honor their patron: half price from tier 3 (restCostFor).
static func rest_cost_for(current: int) -> int:
	var cost := int(_data()["restCost"])
	return ceili(cost / 2.0) if current >= 3 else cost


## Business deeds: map id -> {name, cost}.
static func deeds() -> Dictionary:
	return _data()["properties"]


static func bank(key: String) -> Variant:
	return _data()["bank"][key]


## Days of interest so far, capped: patience pays, parking doesn't.
static func savings_days(at: int, steps: int) -> int:
	return mini(int(bank("savingsMaxDays")), maxi(0, floori((steps - at) / float(bank("daySteps")))))


static func savings_value(principal: int, at: int, steps: int) -> int:
	return floori(principal * (1 + float(bank("savingsRate")) * savings_days(at, steps)))


static func venture_ready(at: int, steps: int) -> bool:
	return steps - at >= int(bank("ventureSteps"))


## The caravan's fate, sealed at departure (ventureOutcome): the web's 32-bit
## hash replayed exactly, including JS's signed XOR and double rounding.
static func venture_outcome(stake: int, at: int) -> Dictionary:
	var h := posmod(at * 2654435761 + stake * 97, TWO_32)
	var mixed := h ^ (h >> 13)
	if mixed >= TWO_32 / 2:
		mixed -= TWO_32  # JS `^` yields a signed 32-bit integer
	h = posmod(int(float(mixed) * 1274126177.0), TWO_32)
	var won := h % 100 < 65
	return {"won": won, "payout": floori(stake * (1.6 if won else 0.4))}


## What still blocks a recruit from joining: "tier", "ask" or "" (recruitBlocker).
static func recruit_blocker(recruit: Dictionary, town_tier: int, gold: int, items: Dictionary) -> String:
	if int(recruit.get("minTownTier", 1)) > town_tier:
		return "tier"
	var ask: Dictionary = recruit["ask"]
	if ask["kind"] == "gold" and gold < ask["amount"]:
		return "ask"
	if ask["kind"] == "deliver" and items.get(ask["itemId"], 0) < ask["count"]:
		return "ask"
	return ""


static func recruit(id: String) -> Dictionary:
	for entry: Dictionary in Npcs._data()["recruits"]:
		if entry["id"] == id:
			return entry
	return {}


# ---- the growing house (house.ts) -----------------------------------------------

## 0 without a deed, else the house level (houseTier).
static func house_tier(owned: bool, tier: int) -> int:
	return maxi(1, tier) if owned else 0


## The next deed Odo can sell; {} without a house or at the Manor.
static func next_house_tier(owned: bool, tier: int) -> Dictionary:
	var current := house_tier(owned, tier)
	if current == 0:
		return {}
	for entry: Dictionary in _data()["houseTiers"]:
		if entry["tier"] == current + 1:
			return entry
	return {}


## Stats a trophy lends while it stands on the shelf (trophyStatDelta).
static func trophy_stat_delta(item_id: String) -> Dictionary:
	match item_id:
		"dragon_scale":
			return {"defense": 2}
		"lich_crown":
			return {"strength": 2, "intelligence": 2, "dexterity": 2, "defense": 2}
	return {}


static func trophy_buffs() -> Dictionary:
	return _data()["trophyBuffs"]


static func nook_combines() -> Array:
	return _data()["nookCombines"]


## Rugs lie flat underfoot; everything else takes the tile.
static func furniture_blocks(item_id: String) -> bool:
	return item_id != "furn_rug"


## Bread and cheese, turn and turn about (gardenYield).
static func garden_yield(harvests: int) -> String:
	return "bread" if harvests % 2 == 0 else "cheese_wheel"


static func house_door() -> Vector2i:
	var door: Dictionary = _data()["houseDoor"]
	return Vector2i(door["x"], door["y"])
