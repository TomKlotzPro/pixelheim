class_name Economy
## The town economy's rules, ported from src/game/economy/{shop,jobs,recipes,
## rarity}.ts: what each shop stocks, what things cost and fetch, the forge,
## crafting and the trades' levels. Pure functions over the exported data
## (assets/data/economy.json); GameState applies them.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/economy.json")))
	return _doc


static func shop(shop_id: String) -> Dictionary:
	return _data()["shops"].get(shop_id, {})


## The shop whose building this map is (activeShopId); "" anywhere else.
static func shop_at(map_id: String) -> String:
	return _data()["shopMaps"].get(map_id, "")


## Item ids a shop stocks at a stage (`stock_stage`: floors or relics), catalog
## order; then what the town's age has brought (PIX-159): stock the shop
## carries early once Pixelheim has grown, and each age's signature item.
static func shop_stock(shop_id: String, unlocked_level: int, town_tier := 0) -> Array[String]:
	var stock: Array[String] = []
	var entries: Dictionary = shop(shop_id).get("stock", {})
	for item_id: String in entries:
		if int(entries[item_id]) <= unlocked_level:
			stock.append(item_id)
	var by_age: Dictionary = shop(shop_id).get("ageStock", {})
	for item_id: String in by_age:
		if int(by_age[item_id]) <= town_tier and item_id not in stock:
			stock.append(item_id)
	return stock


## How far along the shops' stock is (PIX-176): the floors climbed, or -
## out in the Reach before the mountain - the relics won, each a step up
## (economy.json "stockByRelics"), whichever is further.
static func stock_stage(unlocked_level: int, relics: int) -> int:
	var steps: Array = _data()["stockByRelics"]
	return maxi(unlocked_level, int(steps[clampi(relics, 0, steps.size() - 1)]))


## The age that brings an item to a shop, or 0.
static func age_of(shop_id: String, item_id: String) -> int:
	return int(shop(shop_id).get("ageStock", {}).get(item_id, 0))


static func buy_price(item_id: String) -> int:
	return Catalog.item(item_id)["value"]


## City merchants (town tier 4) pay a premium on everything.
static func sell_multiplier(town_tier: int) -> float:
	return 1.2 if town_tier >= 4 else 1.0


## Scrap sells at half; specialists pay their listed rate (sellPriceAt).
static func sell_price_at(shop_id: String, item_id: String, town_tier := 1) -> int:
	var item := Catalog.item(item_id)
	var rate: float = shop(shop_id)["buyRates"].get(item["category"], 0.5)
	return maxi(1, floori(item["value"] * rate * sell_multiplier(town_tier)))


## What a gear piece is worth with its rarity priced in (gearValue).
## Each affix adds half again, each deep tier a whole (PIX-191).
static func gear_value(instance: Dictionary) -> int:
	var mult: float = _data()["rarities"][instance["rarity"]]["valueMult"]
	mult *= 1.0 + 0.5 * instance.get("affixes", {}).size()
	mult *= 1.0 + float(_data()["deepTiers"]["valuePerTier"]) * int(instance.get("deep", 0))
	return roundi(Catalog.item(instance["itemId"])["value"] * mult)


static func gear_sell_price_at(shop_id: String, instance: Dictionary, town_tier := 1) -> int:
	var category: String = Catalog.item(instance["itemId"])["category"]
	var rate: float = shop(shop_id)["buyRates"].get(category, 0.5)
	return maxi(1, floori(gear_value(instance) * rate * sell_multiplier(town_tier)))


## Each +1 costs more as the piece grows (forgeCost).
static func forge_cost(item_id: String, current_bonus: int) -> int:
	return maxi(20, roundi(buy_price(item_id) * 0.25 * (current_bonus + 1)))


## Smithing shaves 4% per level off Hilda's prices; the 20g floor holds.
static func forge_cost_for(item_id: String, current_bonus: int, smithing: int) -> int:
	return maxi(20, roundi(forge_cost(item_id, current_bonus) * (1 - 0.04 * (smithing - 1))))


## Smithing 5 unlocks the +8 masterwork cap.
static func forge_cap_for(smithing: int) -> int:
	# And Smithing 9 raises it once more (PIX-181: the top levels give something).
	return int(_data()["forgeBonusCap"]) + (1 if smithing >= 5 else 0) + (1 if smithing >= int(_data()["jobUnlocks"]["smithingCapAt"]) else 0)


## Masterwork (PIX-180): from Smithing 8, forging past the cap up to the
## masterwork max, each step `growth` times the last and a gem.
static func masterwork_open(smithing: int, bonus: int) -> bool:
	var rules: Dictionary = _data()["masterwork"]
	return smithing >= int(rules["smithing"]) and bonus < int(rules["max"])


static func masterwork_cost(item_id: String, bonus: int, smithing: int) -> int:
	var cap := forge_cap_for(smithing)
	var base := forge_cost_for(item_id, maxi(0, cap - 1), smithing)
	return roundi(base * pow(float(_data()["masterwork"]["growth"]), bonus - cap + 1))


## A crafted piece's rarity (PIX-182): the more trade levels above the
## recipe's (`bonus_levels` more at the home workbench), the likelier Fine,
## and past a couple, Epic.
static func craft_rarity(job_level: int, recipe_level: int, roll: Callable, bonus_levels := 0) -> String:
	var rules: Dictionary = _data()["craftRarity"]
	var over := maxi(0, job_level + bonus_levels - recipe_level)
	var epic := float(rules["epicPerLevel"]) * maxi(0, over - int(rules["epicAfter"]))
	var fine := float(rules["finePerLevel"]) * over
	var value: float = roll.call()
	if value < epic:
		return "epic"
	if value < epic + fine:
		return "fine"
	return "common"


## What Hilda gives back for a piece broken down (PIX-182): item -> count.
static func salvage_yield(instance: Dictionary) -> Dictionary:
	var rules: Dictionary = _data()["salvage"]
	for entry: Dictionary in recipes():
		if entry["itemId"] == instance["itemId"]:
			var out := {}
			for item_id: String in entry["needs"]:
				var count := floori(int(entry["needs"][item_id]) * float(rules["share"]))
				if count > 0:
					out[item_id] = count
			if out.is_empty():
				out[entry["needs"].keys()[0]] = 1
			return out
	return {String(rules["fallback"]): int(rules["fallbackCount"].get(instance["rarity"], 1))}


## What Hilda asks to reforge a piece (PIX-182).
static func reforge_cost(instance: Dictionary) -> int:
	return maxi(1, roundi(gear_value(instance) * float(_data()["reforge"]["costShare"])))


## Smithing 10 (PIX-181): every forged piece comes out at least Fine.
static func forges_fine(smithing: int) -> bool:
	return smithing >= int(_data()["jobUnlocks"]["smithingFineAt"])


static func job_xp_to_next(level: int) -> int:
	return 20 + level * 15


## Adds job xp and applies level-ups up to the cap; returns levels gained.
## Mutates `jobs` (the hero's job id -> {level, xp} record).
static func grant_job_xp(jobs: Dictionary, job: String, xp: int) -> int:
	var progress: Dictionary = jobs[job]
	var cap := int(_data()["jobLevelCap"])
	if progress["level"] >= cap:
		return 0
	progress["xp"] += xp
	var gained := 0
	while progress["level"] < cap and progress["xp"] >= job_xp_to_next(progress["level"]):
		progress["xp"] -= job_xp_to_next(progress["level"])
		progress["level"] += 1
		gained += 1
	return gained


## What one craft teaches its trade (PIX-181): more the harder the recipe,
## 5 + 5 a level, so a trade keeps up with what it makes.
static func craft_xp(entry: Dictionary) -> int:
	return 5 + 5 * int(entry["job"]["level"])


## The trades by name, for the player's language (PIX-196).
const JOB_NAMES := {"smithing": "Smithing", "alchemy": "Alchemy", "foraging": "Foraging", "fishing": "Fishing"}


static func job_name(job: String) -> String:
	return Text.t(JOB_NAMES.get(job, job.capitalize()))


## A trade's standing for the Craft tab: "Smithing 2 (15/50 XP)".
static func job_line(jobs: Dictionary, job: String) -> String:
	var progress: Dictionary = jobs[job]
	if int(progress["level"]) >= int(_data()["jobLevelCap"]):
		return Text.t("%s %d (mastered)") % [job_name(job), progress["level"]]
	return Text.t("%s %d (%d/%d XP)") % [job_name(job), progress["level"], progress["xp"], job_xp_to_next(progress["level"])]


## How far into the Reach a place lies (PIX-184), in the order a hero takes
## it, so the nearest lead comes first: the fields, the coast, the road through
## the Ash, the mines, the Deepwood, Greyhold, the Frostgate, then the
## mountain's floors, and the Mirefen last.
const REGION_STAGE := {
	"forest": 1, "marsh": 1, "coast": 2, "seacave": 2, "ash": 3, "mines": 4, "shafts": 4,
	"deepwood": 5, "castle": 6, "cellars": 6, "frost": 7, "icecave": 7, "mire": 12,
}
const MAP_STAGE := {
	"overworld": 1, "saltmere": 2, "seacave": 2, "blackiron": 4, "shafts": 4, "deepwood": 5,
	"greyhold": 6, "cellars": 6, "frostgate": 7, "icecave": 7, "mirefen": 12,
}
## At the same stage, the surer lead first.
const KIND_ORDER := ["shop", "forage", "chest", "fishing", "quest", "drop", "loot", "patch", "hoard"]

static var _maps := {}


static func _map(map_id: String) -> MapData:
	if not _maps.has(map_id):
		_maps[map_id] = MapData.load_by_id(map_id)
	return _maps[map_id]


static func floor_stage(level: int) -> float:
	return 8.0 + 0.3 * level


## A place's stage: its region's where it has one, else its map's.
static func place_stage(map_id: String, region_id := "") -> float:
	if REGION_STAGE.has(region_id):
		return float(REGION_STAGE[region_id])
	if map_id.begins_with("town"):
		return 0.0
	return float(MAP_STAGE.get(map_id, 8))


## The region names of `regions`, nearest first, at most three.
static func _region_names(regions: Array) -> String:
	var sorted := regions.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return place_stage("", a) < place_stage("", b))
	return ", ".join(sorted.slice(0, 3).map(func(region_id: String) -> String: return Bestiary.region(region_id)["name"]))


## "floor 4", "floors 4-6", "the mountain from floor 8": the floors listed.
static func _floor_span(floors: Array) -> String:
	if floors.size() == 1:
		return Text.t("floor %d") % floors[0]
	if int(floors[-1]) == Dungeons.floor_count():
		return Text.t("the mountain from floor %d") % floors[0]
	return Text.t("floors %d-%d") % [floors[0], floors[-1]]


static func _lead(kind: String, text: String, stage: float) -> Dictionary:
	return {"kind": kind, "text": text, "stage": stage}


## Where a quest's reward is earned: no nearer than its giver, nor than
## what it asks for - Hilda pays her shard for ore from the mines.
static func _quest_stage(quest: Dictionary) -> float:
	var stage := place_stage(Npcs.by_id(quest["giver"], []).get("mapId", ""))
	var objective: Dictionary = quest["objective"]
	match String(objective["kind"]):
		"kill":
			stage = maxf(stage, _monster_stage(objective["monsterId"]))
		"hunt":
			var named := Hunts.named(objective["named"])
			if named.has("mapId"):
				var lair: Dictionary = named.get("lair", {"x": 0, "y": 0})
				stage = maxf(stage, place_stage(named["mapId"], _map(named["mapId"]).region_at(Vector2i(lair["x"], lair["y"]))))
		"deliver":
			var leads := material_sources(objective["itemId"], 4, 99, false)
			if not leads.is_empty():
				stage = maxf(stage, leads[0]["stage"])
		"relics":
			stage = maxf(stage, float(REGION_STAGE["frost"]))
	return stage


## Where a material comes from (PIX-143; PIX-184 made it whole and true), the
## nearest lead first: [{kind, text, stage}], kind one of shop, forage (a
## region's patches and its fights), chest, fishing, quest (a reward), drop
## (a monster's own), loot (the wilds' and the mountain's), patch (the floors')
## and hoard (a floor's first clear). A shop counts only with it on its
## shelves at `stock_stage` and the town's age `town_tier`.
static func material_sources(item_id: String, town_tier := 4, stock_stage := 99, with_quests := true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat := Bestiary._data()
	var shop_maps := {}
	for map_id: String in _data()["shopMaps"]:
		shop_maps[_data()["shopMaps"][map_id]] = map_id
	for npc: Dictionary in Npcs._data()["npcs"]:
		if npc.has("shop"):
			shop_maps[npc["shop"]] = npc["mapId"]
	for shop_id: String in _data()["shops"]:
		if item_id in shop_stock(shop_id, stock_stage, town_tier):
			out.append(_lead("shop", Text.t("sold by %s") % shop(shop_id)["keeper"], place_stage(shop_maps.get(shop_id, ""))))
	# A region's own material grows in its patches and turns up after its fights.
	var home: Array = combat["regionMaterials"].keys().filter(func(region_id: String) -> bool: return combat["regionMaterials"][region_id] == item_id)
	if not home.is_empty():
		var nearest: float = home.map(func(region_id: String) -> float: return place_stage("", region_id)).min()
		out.append(_lead("forage", Text.t("picked from patches and foraged after fights in %s") % _region_names(home), nearest))
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest.get("loot", {}).get("itemId", "") == item_id:
			var region_id: String = _map(chest["mapId"]).region_at(Vector2i(chest["x"], chest["y"]))
			var where: String = Bestiary.region(region_id).get("name", Text.mid(Catalog.place_name(chest["mapId"])))
			out.append(_lead("chest", Text.t("in a chest in %s") % where, place_stage(chest["mapId"], region_id)))
	var waters: Array[String] = []
	var water_stage := 99.0
	for spot: Dictionary in combat.get("fishingSpots", []):
		var catches: Array = spot.get("catches", combat["fishing"]["catches"])
		if catches.any(func(entry: Array) -> bool: return entry[0] == item_id):
			var place := Text.mid(Catalog.place_name(spot["mapId"]))
			if place not in waters:
				waters.append(place)
			water_stage = minf(water_stage, place_stage(spot["mapId"]))
	if not waters.is_empty():
		out.append(_lead("fishing", Text.t("caught fishing at %s") % ", ".join(waters), water_stage))
	for quest: Dictionary in Quests.all() if with_quests else []:
		if quest["reward"].get("itemId", "") == item_id:
			var giver := Npcs.by_id(quest["giver"], [])
			out.append(_lead("quest", Text.t("%s's reward for %s") % [giver.get("name", quest["giver"]), quest["name"]], _quest_stage(quest)))
	for monster_id: String in combat["monsters"]:
		for carried: Dictionary in Bestiary.drops_of(monster_id):
			if carried["itemId"] != item_id:
				continue
			var places := Bestiary.where_found(monster_id)
			var odds := Text.t("every time") if float(carried["chance"]) >= 1.0 else "%d%%" % roundi(float(carried["chance"]) * 100)
			if carried.has("once"):
				# Sure once a hero, then a chance (PIX-180: Fafnyr's scale).
				odds = Text.t("sure the first time, then %d%%") % roundi(float(carried["after"]) * 100)
			out.append(_lead("drop", "%s, %s%s" % [
				Bestiary.monster(monster_id)["name"], odds, " (%s)" % ", ".join(places.slice(0, 3)) if not places.is_empty() else "",
			], _monster_stage(monster_id)))
	# The wilds' loot rolls by the foe's level, never past its region's
	# dropFloor (PIX-183); the mountain's by the floor.
	var looted: Array = combat["regions"].keys().filter(func(region_id: String) -> bool: return _region_loots(region_id, item_id))
	if not looted.is_empty():
		var nearest: float = looted.map(func(region_id: String) -> float: return place_stage("", region_id)).min()
		out.append(_lead("loot", Text.t("now and then in loot in %s") % _region_names(looted), nearest))
	var loot_floors: Array = range(1, Dungeons.floor_count() + 1).filter(func(level: int) -> bool:
		return item_id in _pool_for(combat["floorPools"]["pools"], level)["stackIds"])
	if not loot_floors.is_empty():
		out.append(_lead("loot", Text.t("now and then in loot on %s") % _floor_span(loot_floors), floor_stage(loot_floors[0])))
	var patch_floors: Array = range(1, Dungeons.floor_count() + 1).filter(func(level: int) -> bool: return Gathering.floor_material(level) == item_id)
	if not patch_floors.is_empty():
		out.append(_lead("patch", Text.t("picked from the patch on %s") % _floor_span(patch_floors), floor_stage(patch_floors[0])))
	var hoards: Array = range(1, combat["levels"].size() + 1).filter(func(level: int) -> bool:
		return item_id in combat["levels"][level - 1].get("rewardItemIds", []))
	if hoards.size() == 1:
		out.append(_lead("hoard", Text.t("the hoard of %s") % Text.mid(combat["levels"][hoards[0] - 1]["name"]), floor_stage(hoards[0])))
	elif hoards.size() > 1:
		out.append(_lead("hoard", Text.t("the hoards of floors %s") % ", ".join(hoards.map(func(level: int) -> String: return str(level))), floor_stage(hoards[0])))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a["stage"], b["stage"]):
			return a["stage"] < b["stage"]
		return KIND_ORDER.find(a["kind"]) < KIND_ORDER.find(b["kind"]))
	return out


## The loot pool a level rolls from: the deepest whose floor it has reached.
static func _pool_for(pools: Array, at: int) -> Dictionary:
	var pool: Dictionary = pools[0]
	for entry: Dictionary in pools:
		if int(entry["floor"]) <= at:
			pool = entry
	return pool


## Whether a region's foes can drop `item_id` as loot: each foe that lives
## there rolls the pool of its level, held to the region's dropFloor.
static func _region_loots(region_id: String, item_id: String) -> bool:
	var combat := Bestiary._data()
	var species: Array = Bestiary.region(region_id).get("monsters", []).map(func(entry: Dictionary) -> String: return entry["monsterId"])
	for spawn: Dictionary in combat["spawns"]:
		if _map(spawn["mapId"]).region_at(Vector2i(spawn["x"], spawn["y"])) == region_id:
			species.append(Bestiary.species_of(spawn, region_id))
	for monster_id: String in species:
		var fighter := {"id": monster_id, "level": int(Bestiary.monster(monster_id).get("level", 1))}
		if item_id in _pool_for(combat["dropPools"], Bestiary.wild_drop_floor(region_id, fighter))["stackIds"]:
			return true
	return false


## The nearest place a monster is met: its wild packs' regions, its floors.
static func _monster_stage(monster_id: String) -> float:
	var combat := Bestiary._data()
	var nearest := 99.0
	for spawn: Dictionary in combat["spawns"]:
		var region_id: String = _map(spawn["mapId"]).region_at(Vector2i(spawn["x"], spawn["y"]))
		if Bestiary.species_of(spawn, region_id) == monster_id:
			nearest = minf(nearest, place_stage(spawn["mapId"], region_id))
	for level in range(1, combat["levels"].size() + 1):
		for encounter: Dictionary in combat["levels"][level - 1]["encounters"]:
			if encounter["monsterId"] == monster_id:
				nearest = minf(nearest, floor_stage(level))
	return nearest


## The materials a recipe still lacks, as "2 Marsh Reed".
static func missing_names(entry: Dictionary, items: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for need: String in entry["needs"]:
		var short := int(entry["needs"][need]) - int(items.get(need, 0))
		if short > 0:
			out.append("%d %s" % [short, Catalog.item_name(need)])
	return out


## The best lead for a material, as one line: "Wolf Pelt: Dire Wolf, 50% (...)".
static func where_to_find(item_id: String, town_tier := 4, stock_stage := 99) -> String:
	var sources := material_sources(item_id, town_tier, stock_stage)
	if sources.is_empty():
		return ""
	return "%s: %s" % [Catalog.item_name(item_id), sources[0]["text"]]


## Alchemy: 6% per level to brew a second one free, capped at 50%.
static func double_brew_chance(alchemy: int) -> float:
	return minf(0.5, 0.06 * (alchemy - 1))


## Crafts happen at the trade's station, or anywhere in the house once its
## workbench is fitted (atJobStation).
static func at_job_station(job: String, map_id: String, home_workbench: bool) -> bool:
	return map_id == _data()["jobStations"][job]["mapId"] or (home_workbench and map_id == "town_house")


## The shop whose keeper runs a trade's station (smithing: Hilda's).
static func station_shop(job: String) -> String:
	return shop_at(_data()["jobStations"][job]["mapId"])


## The trades a hero can craft where they stand (the pack's Craft tab).
static func jobs_here(map_id: String, home_workbench: bool) -> Array[String]:
	var jobs: Array[String] = []
	for job: String in _data()["jobStations"]:
		if at_job_station(job, map_id, home_workbench):
			jobs.append(job)
	return jobs


## Where a trade crafts, as the web says it ("Craft at Hilda's forge - the
## FORGE door in town").
static func station_hint(job: String) -> String:
	return _data()["jobStations"][job]["hint"]


static func recipes() -> Array:
	return _data()["recipes"]


static func recipe(recipe_id: String) -> Dictionary:
	for entry: Dictionary in recipes():
		if entry["id"] == recipe_id:
			return entry
	return {}


## The job level and the full bill of materials (canCraft).
static func can_craft(entry: Dictionary, items: Dictionary, jobs: Dictionary) -> bool:
	if jobs[entry["job"]["id"]]["level"] < entry["job"]["level"]:
		return false
	for item_id: String in entry["needs"]:
		if items.get(item_id, 0) < entry["needs"][item_id]:
			return false
	return true
