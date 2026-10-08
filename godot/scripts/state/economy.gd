class_name Economy
## The town economy's rules, ported from src/game/economy/{shop,jobs,recipes,
## rarity}.ts: what each shop stocks, what things cost and fetch, the forge,
## crafting and the trades' levels. Pure functions over the exported data
## (assets/data/economy.json); GameState applies them.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/economy.json"))
	return _doc


static func shop(shop_id: String) -> Dictionary:
	return _data()["shops"].get(shop_id, {})


## The shop whose building this map is (activeShopId); "" anywhere else.
static func shop_at(map_id: String) -> String:
	return _data()["shopMaps"].get(map_id, "")


## Item ids a shop stocks once `unlocked_level` floors are open, catalog order.
static func shop_stock(shop_id: String, unlocked_level: int) -> Array[String]:
	var stock: Array[String] = []
	var entries: Dictionary = shop(shop_id).get("stock", {})
	for item_id: String in entries:
		if int(entries[item_id]) <= unlocked_level:
			stock.append(item_id)
	return stock


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
static func gear_value(instance: Dictionary) -> int:
	var mult: float = _data()["rarities"][instance["rarity"]]["valueMult"]
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
	return int(_data()["forgeBonusCap"]) + (1 if smithing >= 5 else 0)


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


## What one craft teaches its trade: the forge 10, the cauldron 8.
static func craft_xp(job: String) -> int:
	return 10 if job == "smithing" else 8


## A trade's standing for the Craft tab: "Smithing 2 (15/50 XP)".
static func job_line(jobs: Dictionary, job: String) -> String:
	var progress: Dictionary = jobs[job]
	if int(progress["level"]) >= int(_data()["jobLevelCap"]):
		return "%s %d (mastered)" % [job.capitalize(), progress["level"]]
	return "%s %d (%d/%d XP)" % [job.capitalize(), progress["level"], progress["xp"], job_xp_to_next(progress["level"])]


## Where a material comes from (PIX-143), best leads first: [{kind, text}],
## kind one of drop, forage, shop, loot, hoard (once per hero).
static func material_sources(item_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var combat := Bestiary._data()
	for monster_id: String in combat["monsters"]:
		for carried: Dictionary in Bestiary.drops_of(monster_id):
			if carried["itemId"] != item_id:
				continue
			var places := Bestiary.where_found(monster_id)
			var odds := "every time" if float(carried["chance"]) >= 1.0 else "%d%%" % roundi(float(carried["chance"]) * 100)
			out.append({"kind": "drop", "text": "%s, %s%s" % [
				Bestiary.monster(monster_id)["name"], odds, " (%s)" % ", ".join(places.slice(0, 3)) if not places.is_empty() else "",
			]})
	for region_id: String in combat["regionMaterials"]:
		if combat["regionMaterials"][region_id] == item_id:
			out.append({"kind": "forage", "text": "foraged after fights in %s" % Bestiary.region(region_id)["name"]})
	for shop_id: String in _data()["shops"]:
		if shop(shop_id).get("stock", {}).has(item_id):
			out.append({"kind": "shop", "text": "sold by %s" % shop(shop_id)["keeper"]})
	for pool: Dictionary in combat["dropPools"]:
		if item_id in pool["stackIds"]:
			out.append({"kind": "loot", "text": "now and then in loot from floor %d on" % pool["floor"]})
			break
	for level in range(1, combat["levels"].size() + 1):
		if item_id in combat["levels"][level - 1].get("rewardItemIds", []):
			out.append({"kind": "hoard", "text": "the hoard of %s" % combat["levels"][level - 1]["name"]})
	return out


## The materials a recipe still lacks, as "2 Marsh Reed".
static func missing_names(entry: Dictionary, items: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for need: String in entry["needs"]:
		var short := int(entry["needs"][need]) - int(items.get(need, 0))
		if short > 0:
			out.append("%d %s" % [short, Catalog.item_name(need)])
	return out


## The best lead for a material, as one line: "Wolf Pelt: Dire Wolf, 50% (...)".
static func where_to_find(item_id: String) -> String:
	var sources := material_sources(item_id)
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
