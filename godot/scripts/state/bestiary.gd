class_name Bestiary
## The monsters and what fighting them pays, ported from src/game/combat
## (monsters, encounters, drops, combat formulas) and hero/mastery.ts. Pure
## functions over combat.json; every chance arrives as a `roll` callable
## returning 0..1, called in the web's order, so tests can replay its dice.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/combat.json"))
	return _doc


static func monster(id: String) -> Dictionary:
	return _data()["monsters"].get(id, {})


static func is_boss(id: String) -> bool:
	return id in _data()["bossIds"]


## A fighting monster (spawnMonster): elites hit and pay half again, and armor up 30%.
static func spawn(monster_id: String, elite := false) -> Dictionary:
	var base := monster(monster_id)
	var mult := 1.5 if elite else 1.0
	var max_hp := roundi(base["maxHp"] * mult)
	return {
		"id": monster_id,
		"name": "Elite %s" % base["name"] if elite else String(base["name"]),
		"elite": elite,
		"hp": max_hp,
		"maxHp": max_hp,
		"attack": roundi(base["attack"] * mult),
		"defense": roundi(base["defense"] * (1.3 if elite else 1.0)),
		"xp": roundi(base["xp"] * mult),
		"gold": roundi(base["gold"] * mult),
		"inflicts": base.get("inflicts"),
	}


static func region(region_id: String) -> Dictionary:
	return _data()["regions"].get(region_id, {})


## Visible spawn points on a map (SPAWNS).
static func spawns_on(map_id: String) -> Array:
	return _data()["spawns"].filter(func(spawn: Dictionary) -> bool: return spawn["mapId"] == map_id)


## Who lives at a spawn, fixed per spawn: what you see is what you fight (spawnSpecies).
static func species_at(region_id: String, cell: Vector2i) -> String:
	var monsters: Array = region(region_id)["monsters"]
	return monsters[(cell.x * 31 + cell.y) % monsters.size()]["monsterId"]


## Wild kills pay reduced xp/gold: dungeons stay the main progression.
static func wild(fighter: Dictionary) -> Dictionary:
	var mult := float(_data()["wildRewardMult"])
	fighter["xp"] = roundi(fighter["xp"] * mult)
	fighter["gold"] = roundi(fighter["gold"] * mult)
	return fighter


static func variance(base: float, roll: Callable) -> int:
	return maxi(1, roundi(base * (0.85 + roll.call() * 0.3)))


static func family_of(monster_id: String) -> String:
	return _data()["families"].get(monster_id, "")


static func mastery_tier(mastery: Variant, family: String) -> int:
	var kills: int = (mastery if mastery is Dictionary else {}).get(family, 0)
	var tier := 0
	for entry: Dictionary in _data()["masteryTiers"]:
		if kills >= entry["kills"]:
			tier += 1
	return tier


## Damage bonus against a monster's family (masteryBonus).
static func mastery_bonus(mastery: Variant, monster_id: String) -> float:
	var family := family_of(monster_id)
	if family == "":
		return 0.0
	var tier := mastery_tier(mastery, family)
	return float(_data()["masteryTiers"][tier - 1]["bonus"]) if tier > 0 else 0.0


## A swing that lands (heroAttackDamage): scaling stat plus weapon, crits,
## execution bonus, mastery, minus the monster's defense.
static func hero_attack_damage(hero: HeroState, pack: InventoryState, fighter: Dictionary, inspired: bool, roll: Callable) -> int:
	var held := HeroRules.weapon(pack)
	var scaling: String = Catalog.item(held["itemId"]).get("scaling", "strength") if not held.is_empty() else "strength"
	var raw := float(HeroRules.effective_stat(hero, pack, scaling) + (HeroRules.gear_damage(held) if not held.is_empty() else 2))
	var passives := HeroRules.passives(hero)
	var crit: float = passives["critChance"] + (0.12 if inspired else 0.0)
	if crit > 0 and roll.call() < crit:
		raw *= 1.5
	if passives["lowHpBonus"] > 0 and float(fighter["hp"]) / fighter["maxHp"] < 0.3:
		raw *= 1 + passives["lowHpBonus"]
	raw *= 1 + mastery_bonus(hero.mastery, fighter["id"])
	return maxi(1, variance(raw, roll) - int(fighter["defense"]))


## A monster's hit on the hero (monsterAttackDamage), armor absorbing.
static func monster_attack_damage(fighter: Dictionary, hero: HeroState, pack: InventoryState, roll: Callable) -> int:
	return maxi(1, variance(fighter["attack"], roll) - HeroRules.total_defense(hero, pack))


## A kill's drop, or {} (rollDrop): chance by kind, the floor's pool, a third
## of drops are gear with a rarity roll. Returns {kind: "gear"|"stack", ...}.
static func roll_drop(floor_level: int, kind: String, roll: Callable) -> Dictionary:
	if roll.call() >= float(_data()["dropChance"][kind]):
		return {}
	var pool: Dictionary = _data()["dropPools"][0]
	for entry: Dictionary in _data()["dropPools"]:
		if int(entry["floor"]) <= floor_level:
			pool = entry
	if roll.call() < 0.35:
		var item_id: String = _pick(pool["gearIds"], roll)
		var rarity := _roll_rarity(_data()["rarityWeights"][kind], roll)
		return {"kind": "gear", "gear": InventoryState.create_gear(item_id, rarity, roll)}
	return {"kind": "stack", "itemId": _pick(pool["stackIds"], roll)}


static func _pick(list: Array, roll: Callable) -> String:
	return list[floori(roll.call() * list.size())]


static func _roll_rarity(weights: Dictionary, roll: Callable) -> String:
	var value: float = roll.call()
	if value < weights["epic"]:
		return "epic"
	if value < weights["epic"] + weights["fine"]:
		return "fine"
	return "common"


static func forage_chance(foraging: int) -> float:
	return minf(0.95, 0.6 + 0.03 * (foraging - 1))


static func double_forage_chance(foraging: int) -> float:
	return minf(0.8, 0.35 + 0.04 * (foraging - 1))
