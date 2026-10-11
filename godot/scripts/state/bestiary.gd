class_name Bestiary
## The monsters and what fighting them pays, ported from src/game/combat
## (monsters, encounters, drops, combat formulas) and hero/mastery.ts. Pure
## functions over combat.json; every chance arrives as a `roll` callable
## returning 0..1, called in the web's order, so tests can replay its dice.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/combat.json")))
		# A region dungeon's planned floors keep their packs in their plans
		# (PIX-255): they live here with the others.
		_doc["spawns"].append_array(Depths.planned_spawns())
	return _doc


static func monster(id: String) -> Dictionary:
	return _data()["monsters"].get(id, {})


static func is_boss(id: String) -> bool:
	return id in _data()["bossIds"]


## A boss, or a named monster (PIX-156): it fights like one - the boss bar,
## its music and its roar - never gives up the chase, and falls like one,
## the world holding its breath (PIX-232).
static func fights_like_boss(fighter: Dictionary) -> bool:
	return is_boss(String(fighter["id"])) or fighter.has("named")


## A fighting monster (spawnMonster): elites hit and pay half again, and armor
## up 30%; their health grows by combat.json's eliteHp (PIX-186: sized for
## real time, where a hero swings every 0.45 s).
static func spawn(monster_id: String, elite := false, lift := 0) -> Dictionary:
	var base := monster(monster_id)
	# Lifted above its kind on the mountain, or below it on the Night of
	# Ash (PIX-197: the hounds and embers a first-night hero can take).
	if lift != 0:
		base = lifted(base, lift)
	var mult := 1.5 if elite else 1.0
	var max_hp := roundi(base["maxHp"] * (float(_data()["eliteHp"]) if elite else 1.0))
	var fighter := {
		"id": monster_id,
		"name": Text.t("Elite %s") % base["name"] if elite else String(base["name"]),
		"elite": elite,
		"hp": max_hp,
		"maxHp": max_hp,
		"attack": roundi(base["attack"] * mult),
		"defense": roundi(base["defense"] * (1.3 if elite else 1.0)),
		"xp": roundi(base["xp"] * mult),
		"gold": roundi(base["gold"] * mult),
		"inflicts": base.get("inflicts"),
	}
	if lift != 0:
		fighter["level"] = base["level"]
	return fighter


## A fighter's level: lifted on the mountain, else its kind's (PIX-188).
static func level_of(fighter: Dictionary) -> int:
	return int(fighter.get("level", monster(fighter["id"]).get("level", 1)))


## How a level reads beside the hero's (PIX-188): a colour for the gap.
static func gap_color(level: int, hero_level: int) -> Color:
	var gap := level - hero_level
	if gap >= 3:
		return Color("ff5a4a")
	if gap >= 1:
		return Color("ffb347")
	if gap >= -1:
		return Color("f3e6c4")
	return Color("a8a294")


## A monster `lift` levels above its kind (PIX-170; a dungeon floor's foes,
## the Kings' Vault's the highest, PIX-257): each stat grows by the ratio of combat.json's floorLift
## curve at the new level to the curve at its own.
## Its poison and burn bite harder by the attack curve's ratio (PIX-186: a
## floor-2 goblin at level 12 no longer poisons for 2).
static func lifted(base: Dictionary, lift: int) -> Dictionary:
	var out := base.duplicate()
	var level := int(base["level"])
	var curves: Dictionary = _data()["floorLift"]["curves"]
	for stat: String in curves:
		out[stat] = roundi(float(base[stat]) * _grown(curves[stat], level, level + lift))
	if base.get("inflicts") is Dictionary:
		var inflicts: Dictionary = base["inflicts"].duplicate()
		inflicts["power"] = roundi(float(inflicts["power"]) * _grown(curves["attack"], level, level + lift))
		out["inflicts"] = inflicts
	out["level"] = level + lift
	return out


## A curve (a + b*L + c*L*L) at `to` over at `from`.
static func _grown(curve: Array, from: int, to: int) -> float:
	var at := func(l: int) -> float: return float(curve[0]) + float(curve[1]) * l + float(curve[2]) * l * l
	return at.call(to) / at.call(from)


## The lift that brings `monster_id` to `level` (none below its own).
static func lift_to(monster_id: String, level: int) -> int:
	return maxi(0, level - int(monster(monster_id).get("level", level)))


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
## kind -> the regions where it comes out only after dark, named so (PIX-252).
static var _found_at_night := {}
## kind -> the first spawn whose pack is of it: {mapId, x, y} (PIX-239).
static var _homes := {}


## Where a monster lives: the regions with a pack of it (a dungeon's floors
## are its region's), then the regions where it comes out only after dark,
## saying so ("the Ash Fields by night", PIX-252): a hint's first few are
## where it is at any hour.
static func where_found(monster_id: String) -> Array[String]:
	_learn_places()
	var out: Array[String] = []
	out.assign(_found.get(monster_id, []))
	out.append_array(_found_at_night.get(monster_id, []))
	return out


## The first spawn in the wild whose pack is of `monster_id`: {mapId, x, y},
## or {} when none is (the way to a hunting quest, PIX-239). A pack out at
## every hour first (PIX-252), so the way never leads to an empty camp;
## then one out by day, then one of the night.
static func home_of(monster_id: String) -> Dictionary:
	_learn_places()
	return _homes.get(monster_id, {})


## Who lives where, learned once from the spawns.
static func _learn_places() -> void:
	if not _found.is_empty():
		return
	var maps := {}
	# kind -> region name -> whether a pack of it is out there by day.
	var by_day := {}
	var home_rank := {}
	for spawn: Dictionary in _data()["spawns"]:
		if not maps.has(spawn["mapId"]):
			maps[spawn["mapId"]] = MapData.load_by_id(spawn["mapId"])
		var region_id: String = maps[spawn["mapId"]].region_at(Vector2i(spawn["x"], spawn["y"]))
		var species := species_of(spawn, region_id)
		var name: String = region(region_id).get("name", region_id)
		var seen: Dictionary = by_day.get(species, {})
		seen[name] = seen.get(name, false) or Packs.is_out(spawn, false)
		by_day[species] = seen
		var rank: int = {"": 0, "day": 1}.get(String(spawn.get("hours", "")), 2)
		if rank < int(home_rank.get(species, 99)):
			home_rank[species] = rank
			_homes[species] = {"mapId": spawn["mapId"], "x": int(spawn["x"]), "y": int(spawn["y"])}
	for species: String in by_day:
		var places: Array[String] = []
		var at_night: Array[String] = []
		for name: String in by_day[species]:
			if by_day[species][name]:
				places.append(name)
			else:
				at_night.append(Text.t("%s by night") % name)
		_found[species] = places
		_found_at_night[species] = at_night


## Weighted as the region says (PIX-183: an Ash Fields spawn is twice as
## likely orcs as imps), picked by the cell so it stays put.
static func species_at(region_id: String, cell: Vector2i) -> String:
	var monsters: Array = region(region_id)["monsters"]
	var total := 0
	for entry: Dictionary in monsters:
		total += int(entry.get("weight", 1))
	var pick := absi(hash(cell)) % maxi(1, total)
	for entry: Dictionary in monsters:
		pick -= int(entry.get("weight", 1))
		if pick < 0:
			return entry["monsterId"]
	return monsters[0]["monsterId"]


## The loot pool a wild kill rolls from (PIX-183): its region's, but never
## above the foe's own level - a Mirefen skeleton drops a skeleton's loot,
## its mimic a mimic's.
static func wild_drop_floor(region_id: String, fighter: Dictionary) -> int:
	var cap := int(region(region_id).get("dropFloor", 1))
	var level := int(fighter.get("level", monster(fighter["id"]).get("level", 1)))
	return clampi(level, 1, cap)


## Wild kills pay reduced xp and gold: dungeons stay the main progression
## (XP more so than gold, PIX-141: the wilds are for gathering, not farming).
## The Reach's chapters and their caves pay more XP than the fields (PIX-189):
## a region's "wildXp" over the game's.
static func wild(fighter: Dictionary, region_id := "") -> Dictionary:
	var share := float(region(region_id).get("wildXp", _data()["wildXpMult"]))
	fighter["xp"] = roundi(fighter["xp"] * share)
	fighter["gold"] = roundi(fighter["gold"] * float(_data()["wildRewardMult"]))
	return fighter


## The XP a kill pays a hero of `hero_level` (PIX-141): full against a match,
## 15% less per level the hero stands above the monster, never under a tenth;
## 5% more per level the monster stands above the hero, up to a quarter (PIX-189).
static func xp_for(fighter: Dictionary, hero_level: int) -> int:
	var gap: Dictionary = _data()["xpGap"]
	var monster: Dictionary = _data()["monsters"].get(fighter["id"], {})
	# A named monster (PIX-156) stands at its own level, not its kind's.
	var above := hero_level - int(fighter.get("level", monster.get("level", hero_level)))
	var share := clampf(1.0 - float(gap["falloff"]) * maxi(0, above), float(gap["floor"]), 1.0)
	share += minf(float(gap["aboveBonus"]) * maxi(0, -above), float(gap["aboveCap"]))
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


## What gets through armour (PIX-185): a hit loses the share
## weight*armor / (raw + weight*armor) of itself, so every point of armour
## helps, ever less, and none makes anyone immune.
static func through_armor(raw: int, armor: float) -> int:
	var weighted := float(_data()["armor"]["weight"]) * maxf(0.0, armor)
	return maxi(1, roundi(float(raw) * raw / (raw + weighted)))


## The share of a hit `armor` turns aside, 0..1.
static func turned_aside(raw: float, armor: float) -> float:
	var weighted := float(_data()["armor"]["weight"]) * maxf(0.0, armor)
	return weighted / (raw + weighted) if raw + weighted > 0 else 0.0


## How hard a foe of `level` hits: the median attack of every kind (bosses
## aside) brought to that level along the floorLift curve. What the stat
## sheet measures armour against, and the balance test fights.
static func matched_attack(level: int) -> float:
	var attacks: Array[int] = []
	for id: String in _data()["monsters"]:
		if is_boss(id):
			continue
		var base := monster(id)
		attacks.append(int(lifted(base, level - int(base["level"]))["attack"]))
	attacks.sort()
	var middle := attacks.size() / 2
	return attacks[middle] if attacks.size() % 2 == 1 else (attacks[middle - 1] + attacks[middle]) / 2.0


## A skill that lands (heroSkillDamage): the skill's power, sharpened by
## mastery of the foe's family, through the variance; skills pierce half
## the foe's armour.
static func hero_skill_damage(hero: HeroState, pack: InventoryState, skill: Dictionary, fighter: Dictionary, roll: Callable) -> int:
	# Skill-power passives (PIX-190) and the hero's mastery of the kind.
	var raw := Skills.skill_power(hero, pack, skill) * (1.0 + float(HeroRules.passives(hero)["skillPower"])) * (1.0 + mastery_bonus(hero.mastery, fighter["id"]))
	return through_armor(variance(raw, roll), int(fighter["defense"]) / 2.0)


## A swing that lands (heroAttackDamage): scaling stat plus weapon, crits,
## execution bonus, mastery, through the monster's defense.
## `song_crit`: what Loras's song adds when `inspired` (more with his horn, PIX-157).
## `extra_crit`: a crit chance from outside the hero's skills (PIX-179: a banner at home).
static func hero_attack_damage(hero: HeroState, pack: InventoryState, fighter: Dictionary, inspired: bool, roll: Callable, song_crit := 0.12, extra_crit := 0.0) -> int:
	return int(hero_attack(hero, pack, fighter, inspired, roll, song_crit, extra_crit)["damage"])


## The same swing as {damage, crit} (PIX-209), so a crit can look like one.
static func hero_attack(hero: HeroState, pack: InventoryState, fighter: Dictionary, inspired: bool, roll: Callable, song_crit := 0.12, extra_crit := 0.0) -> Dictionary:
	var held := HeroRules.weapon(pack)
	var scaling: String = Catalog.item(held["itemId"]).get("scaling", "strength") if not held.is_empty() else "strength"
	var raw := float(HeroRules.effective_stat(hero, pack, scaling) + (HeroRules.gear_damage(held) if not held.is_empty() else 2))
	var passives := HeroRules.passives(hero)
	var chance: float = passives["critChance"] + (song_crit if inspired else 0.0) + extra_crit
	var crit: bool = chance > 0 and roll.call() < chance
	if crit:
		raw *= 1.5
	if passives["lowHpBonus"] > 0 and float(fighter["hp"]) / fighter["maxHp"] < 0.3:
		raw *= 1 + passives["lowHpBonus"]
	raw *= 1 + mastery_bonus(hero.mastery, fighter["id"])
	return {"damage": through_armor(variance(raw, roll), int(fighter["defense"])), "crit": crit}


## A monster's hit on the hero (monsterAttackDamage), through the hero's armour.
static func monster_attack_damage(fighter: Dictionary, hero: HeroState, pack: InventoryState, roll: Callable) -> int:
	return through_armor(variance(fighter["attack"], roll), HeroRules.total_defense(hero, pack))


## A kill's drop, or {} (rollDrop): chance by kind, then gear (gearShare by
## kind: a boss always drops gear, PIX-191) with a rarity roll, or a stack.
## Kills roll dropPools by the foe's level (`floor_level`, never above its
## region's cap); a floor that forges (`forged`: the Kings' Vault's, PIX-257)
## forges its gear that deep (InventoryState.deepen, PIX-191).
## Returns {kind: "gear"|"stack", ...}.
static func roll_drop(floor_level: int, kind: String, roll: Callable, forged := 0, luck := 0.0) -> Dictionary:
	if roll.call() >= float(_data()["dropChance"][kind]) + luck:
		return {}
	var pools: Array = _data()["dropPools"]
	var pool: Dictionary = pools[0]
	for entry: Dictionary in pools:
		if int(entry["floor"]) <= floor_level:
			pool = entry
	if roll.call() < float(_data()["gearShare"][kind]):
		var item_id: String = _pick(pool["gearIds"], roll)
		var rarity := _roll_rarity(_data()["rarityWeights"][kind], roll)
		var gear := InventoryState.create_gear(item_id, rarity, roll)
		if forged > 0:
			InventoryState.deepen(gear, forged, roll)
		return {"kind": "gear", "gear": gear}
	return {"kind": "stack", "itemId": _pick(pool["stackIds"], roll)}


## Who stands in a wild pack (PIX-191): the spawn's own kind leads, the rest
## are the region's mix by weight - never more than four levels above the
## leader, so a pack of orcs by the road hides no imp.
static func pack_species(spawn: Dictionary, region_id: String, index: int, cell: Vector2i) -> String:
	var leader := species_of(spawn, region_id)
	# What comes out after dark comes out together (PIX-252): a night pack
	# is all of its kind, no orc among the ash hounds.
	if index == 0 or Packs.of_the_night(spawn):
		return leader
	var other := species_at(region_id, cell + Vector2i(index * 7, index * 13))
	# Never a stronger kind than the leader (PIX-203): a pack of slimes is
	# slimes, a pack of orcs by the road hides no wyvern.
	if int(monster(other)["level"]) > int(monster(leader)["level"]):
		return leader
	return other


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
