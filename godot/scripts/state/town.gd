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


## The web's requirement predicates, by key (TOWN_TIERS[].requires.met).
static func requirement_met(key: String, house_owned: bool, properties: Array) -> bool:
	match key:
		"own_house":
			return house_owned
		"own_all_properties":
			return deeds().keys().all(func(map_id: String) -> bool: return map_id in properties)
	return true


## Why the next tier can't be funded, or "" when it can (fundBlocker).
static func fund_blocker(current: int, gold: int, house_owned: bool, properties: Array) -> String:
	var next := next_tier(current)
	if next.is_empty():
		return "Pixelheim stands at its full height."
	var requires: Dictionary = next.get("requires", {})
	if not requires.is_empty() and not requirement_met(requires["key"], house_owned, properties):
		return requires["line"]
	if gold < int(next.get("cost", 0)):
		return "The treasury asks %dg." % next["cost"]
	return ""


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
