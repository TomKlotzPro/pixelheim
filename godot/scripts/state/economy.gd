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


## Alchemy: 6% per level to brew a second one free, capped at 50%.
static func double_brew_chance(alchemy: int) -> float:
	return minf(0.5, 0.06 * (alchemy - 1))


## Crafts happen at the trade's station, or anywhere in the house once its
## workbench is fitted (atJobStation).
static func at_job_station(job: String, map_id: String, home_workbench: bool) -> bool:
	return map_id == _data()["jobStations"][job]["mapId"] or (home_workbench and map_id == "town_house")


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
