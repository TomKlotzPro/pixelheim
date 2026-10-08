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
## A spawn's species: the one its data names (PIX-143: the forest's wolves),
## else what its region and position decide.
static func species_of(spawn: Dictionary, region_id: String) -> String:
	if spawn.has("species"):
		return spawn["species"]
	return species_at(region_id, Vector2i(spawn["x"], spawn["y"]))


## What a monster may drop besides the floor's loot (PIX-143): [{itemId,
## chance}] - a wolf's pelt, an imp's horn, Fafnyr's scale.
static func drops_of(monster_id: String) -> Array:
	return monster(monster_id).get("drops", [])


static var _found := {}


## Where a monster lives: the wild regions with a pack of it, then the floors
## that field it (for "where to find" hints).
static func where_found(monster_id: String) -> Array[String]:
	if _found.is_empty():
		var maps := {}
		for spawn: Dictionary in _data()["spawns"]:
			if not maps.has(spawn["mapId"]):
				maps[spawn["mapId"]] = MapData.load_by_id(spawn["mapId"])
			var region_id: String = maps[spawn["mapId"]].region_at(Vector2i(spawn["x"], spawn["y"]))
			var species := species_of(spawn, region_id)
			var name: String = region(region_id).get("name", region_id)
			var places: Array = _found.get(species, [])
			if name not in places:
				places.append(name)
			_found[species] = places
		for level in range(1, _data()["levels"].size() + 1):
			for encounter: Dictionary in _data()["levels"][level - 1]["encounters"]:
				var places: Array = _found.get(encounter["monsterId"], [])
				var floor_name := "floor %d" % level
				if floor_name not in places:
					places.append(floor_name)
				_found[encounter["monsterId"]] = places
	var out: Array[String] = []
	out.assign(_found.get(monster_id, []))
	return out


static func species_at(region_id: String, cell: Vector2i) -> String:
	var monsters: Array = region(region_id)["monsters"]
	return monsters[(cell.x * 31 + cell.y) % monsters.size()]["monsterId"]


## Wild kills pay reduced xp and gold: dungeons stay the main progression
## (XP more so than gold, PIX-141: the wilds are for gathering, not farming).
static func wild(fighter: Dictionary) -> Dictionary:
	fighter["xp"] = roundi(fighter["xp"] * float(_data()["wildXpMult"]))
	fighter["gold"] = roundi(fighter["gold"] * float(_data()["wildRewardMult"]))
	return fighter


## The XP a kill pays a hero of `hero_level` (PIX-141): full against a match,
## 15% less per level the hero stands above the monster, never under a tenth.
static func xp_for(fighter: Dictionary, hero_level: int) -> int:
	var gap: Dictionary = _data()["xpGap"]
	var monster: Dictionary = _data()["monsters"].get(fighter["id"], {})
	# A named monster (PIX-156) stands at its own level, not its kind's.
	var above := hero_level - int(fighter.get("level", monster.get("level", hero_level)))
	var share := clampf(1.0 - float(gap["falloff"]) * maxi(0, above), float(gap["floor"]), 1.0)
	return roundi(int(fighter["xp"]) * share)


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


## A skill that lands (heroSkillDamage): the skill's power, sharpened by
## mastery of the foe's family, through the variance, minus half its armor.
static func hero_skill_damage(hero: HeroState, pack: InventoryState, skill: Dictionary, fighter: Dictionary, roll: Callable) -> int:
	var raw := Skills.skill_power(hero, pack, skill) * (1.0 + mastery_bonus(hero.mastery, fighter["id"]))
	return maxi(1, variance(raw, roll) - floori(int(fighter["defense"]) / 2.0))


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
