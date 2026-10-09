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
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/town.json")))
	return _doc


## A town age by number, 0 (the Ashes, PIX-146) to MAX_TIER (the City).
static func tier(number: int) -> Dictionary:
	return _data()["tiers"][clampi(number, 0, MAX_TIER)]


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
			"relics":
				# The ages come from the Reach's chapters too (PIX-170); a
				# hero who climbed first still has the floor that did it.
				met = Relics.found(progression) >= int(need["count"]) or int(need.get("orCleared", 0)) in progression.cleared_levels
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
		return Text.t("Already built.")
	var tier_number := age_of(project_id)
	if tier_number != current_age(settlement):
		return Text.t("Finish the %s first.") % tier(current_age(settlement))["name"]
	var blockers := age_blockers(tier_number, progression, settlement)
	if not blockers.is_empty():
		return blockers[0] + "."
	if gold < int(entry["cost"]["gold"]):
		return Text.t("The treasury asks %d gold.") % entry["cost"]["gold"]
	for item_id: String in entry["cost"]["items"]:
		if int(items.get(item_id, 0)) < int(entry["cost"]["items"][item_id]):
			return Text.t("It takes %d %s.") % [entry["cost"]["items"][item_id], Catalog.item_name(item_id)]
	return ""


## A project's price as one line: "250g, 2 Wolf Pelt".
static func cost_line(project_id: String) -> String:
	var cost: Dictionary = project(project_id)["cost"]
	var parts: Array[String] = [Text.coins(int(cost["gold"]))]
	for item_id: String in cost["items"]:
		parts.append("%d %s" % [cost["items"][item_id], Catalog.item_name(item_id)])
	return ", ".join(parts)


## What the town says when a hero comes home from a boss's floor (PIX-147).
static func homecoming(level: int) -> String:
	return String(_data()["homecomings"].get(str(level), ""))


## The heart of the square (PIX-198): where the fountain rises, the town
## gathers at dusk and the ending's tour stands. town.json "square".
static func square() -> Vector2i:
	var at: Dictionary = _data()["square"]
	return Vector2i(int(at["x"]), int(at["y"]))


## The five lanterns of the ending (PIX-157), on the square: town.json "lanterns".
static func lanterns() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for at: Dictionary in _data()["lanterns"]:
		out.append(Vector2i(int(at["x"]), int(at["y"])))
	return out


## The notice board on the square that opens the projects ledger.
static func project_board() -> Vector2i:
	var at: Dictionary = _data()["projectBoard"]
	return Vector2i(int(at["x"]), int(at["y"]))


## The festival day's numbers and places (town.json "festival").
static func festival(key: String) -> Variant:
	return _data()["festival"][key]


## Where the town stands about at dusk (PIX-159): a loose ring around the
## square's heart, open ground only.
static func gathering_spots(map: MapData) -> Array[Vector2i]:
	var square := square()
	var out: Array[Vector2i] = []
	for offset: Vector2i in [
		Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-3, 1), Vector2i(3, 1), Vector2i(-1, 2), Vector2i(1, 2),
		Vector2i(-2, 3), Vector2i(2, 3), Vector2i(0, -2), Vector2i(-4, -1), Vector2i(4, -1), Vector2i(0, 4),
	]:
		var cell := square + offset
		if map.is_walkable(cell) and not map.covered.has(cell) and not map.portals.has(cell):
			out.append(cell)
	return out


## The bounty board beside it, where the named monsters are posted (PIX-156).
static func bounty_board() -> Vector2i:
	var at: Dictionary = _data()["bountyBoard"]
	return Vector2i(int(at["x"]), int(at["y"]))


## What Fafnyr left (PIX-146): each Hamlet project not yet built stands as
## ruins - [{rect: Rect2i, door: Vector2i (-1, -1 for a house with none),
## project}] - its doors shut.
static func ruins(done: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for project_entry: Dictionary in age(1).get("projects", []):
		if project_entry["id"] in done:
			continue
		for ruin: Dictionary in project_entry.get("ruins", []):
			var r: Array = ruin["rect"]
			var door: Array = ruin.get("door", [-1, -1])
			out.append({
				"rect": Rect2i(int(r[0]), int(r[1]), int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1),
				"door": Vector2i(int(door[0]), int(door[1])),
				"project": project_entry["id"],
			})
	return out


## A ruin as tiles: ash where the house stood, its burnt frame as a log fence
## (open where the door was), rubble here and there inside.
static func ruin_tiles(ruin: Dictionary) -> Dictionary:
	var out := {}
	var rect: Rect2i = ruin["rect"]
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var edge := x == rect.position.x or x == rect.end.x - 1 or y == rect.position.y or y == rect.end.y - 1
			if cell == ruin["door"]:
				out[cell] = "ash"
			elif edge:
				out[cell] = "fence"
			elif (x * 7 + y * 13) % 9 == 0:
				out[cell] = "crate" if (x + y) % 2 == 0 else "barrel"
			else:
				out[cell] = "ash"
	return out


## Where the keepers stand at their stalls while their roofs are rubble, a
## crate of their wares beside them; and Sela's tent, while the inn is.
static func stall_crates(done: Array) -> Dictionary:
	var out := {}
	for npc: Dictionary in Npcs._data()["npcs"]:
		var stall: Dictionary = npc.get("stall", {})
		if stall.is_empty() or stall["project"] in done or npc["id"] == "innkeeper":
			continue
		# The crate stands on the side away from the square's heart.
		var side := -1 if int(stall["x"]) < square().x else 1
		out[Vector2i(int(stall["x"]) + side, int(stall["y"]))] = "crate"
	return out


static func ashes_tent(done: Array) -> Vector2i:
	if "the_inn" in done:
		return Vector2i(-1, -1)
	var tent: Dictionary = _data()["ashesCamp"]["tent"]
	return Vector2i(int(tent["x"]), int(tent["y"]))


## The age the town is building given what's built (current_age's rule).
static func building_age(done: Array) -> int:
	for entry: Dictionary in ages():
		for candidate: Dictionary in entry["projects"]:
			if candidate["id"] not in done:
				return int(entry["tier"])
	return 0


## The construction sites (PIX-147): the building age's unbuilt projects that
## have a plot - [{project, rect: Rect2i}] - staked out with a log fence and
## a crate of materials until they're funded.
static func sites(done: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for candidate: Dictionary in age(building_age(done)).get("projects", []):
		if candidate["id"] in done or not candidate.has("site"):
			continue
		var r: Array = candidate["site"]
		out.append({"project": candidate["id"], "rect": Rect2i(int(r[0]), int(r[1]), int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1)})
	return out


static func site_tiles(site: Dictionary) -> Dictionary:
	var out := {}
	var rect: Rect2i = site["rect"]
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x == rect.position.x or x == rect.end.x - 1 or y == rect.position.y or y == rect.end.y - 1:
				out[Vector2i(x, y)] = "fence"
	out[rect.get_center()] = "crate"
	return out


## A builder by each site, waiting on the ledger: who they are, and what the
## project still asks (as villagers for Npcs.on_map).
static func site_workers(done: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for site: Dictionary in sites(done):
		var entry := project(site["project"])
		var worker: Dictionary = entry["worker"]
		out.append({
			"id": "worker_%s" % entry["id"], "mapId": "town", "name": worker["name"],
			"x": worker["x"], "y": worker["y"], "wander": false,
			"sprite": "worker" if out.size() % 2 == 0 else "worker_alt",
			"lines": [
				String(entry["blurb"]),
				Text.t("All it wants is %s. The board on the square takes it, and we'll have it up by the time you're back.") % cost_line(entry["id"]),
			],
		})
	return out


## Where a project stands on the map, for the camera to show it built.
static func project_center(project_id: String) -> Vector2i:
	var entry := project(project_id)
	var cells: Array[Vector2i] = []
	for cell: Array in entry["tiles"]:
		cells.append(Vector2i(int(cell[0]), int(cell[1])))
	for ruin: Dictionary in entry.get("ruins", []):
		var r: Array = ruin["rect"]
		cells.append_array([Vector2i(int(r[0]), int(r[1])), Vector2i(int(r[2]), int(r[3]))])
	if cells.is_empty():
		return square()
	var low := cells[0]
	var high := cells[0]
	for cell in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	return (low + high) / 2


## The town map's cells a set of finished projects changes: cell -> tile,
## the ruins of what isn't rebuilt yet and the sites of what's planned included.
static func town_patches(done: Array) -> Dictionary:
	var out := {}
	for ruin: Dictionary in ruins(done):
		out.merge(ruin_tiles(ruin), true)
	out.merge(stall_crates(done), true)
	for site: Dictionary in sites(done):
		out.merge(site_tiles(site), true)
	for entry: Dictionary in ages():
		for candidate: Dictionary in entry["projects"]:
			if candidate["id"] in done:
				for cell: Array in candidate["tiles"]:
					out[Vector2i(int(cell[0]), int(cell[1]))] = cell[2]
	return out


## Village rent: one coin more per property from tier 2 (rentPerProperty).
## A property's rent for a day of the day-wheel (PIX-178): a share of its
## deed, a tenth more from the Village, more again expanded.
static func daily_rent(map_id: String, expanded: bool, current: int) -> int:
	var rules: Dictionary = _data()["rent"]
	var rent := float(deeds()[map_id]["cost"]) * float(rules["dailyShare"])
	if current >= 2:
		rent *= 1.0 + float(rules["villageBoost"])
	if expanded:
		rent *= 1.0 + float(rules["expansionBoost"])
	return roundi(rent)


## The most a till holds before someone empties it.
static func till_cap(map_id: String, expanded: bool, current: int) -> int:
	return daily_rent(map_id, expanded, current) * int(_data()["rent"]["tillDays"])


## The shop a property is (economy.json shopMaps), or "".
static func shop_of(map_id: String) -> String:
	return String(Economy._data()["shopMaps"].get(map_id, ""))


## The commissions offered once every age is built (PIX-180).
static func commissions() -> Array:
	return _data()["commissions"]["list"]


static func commission(commission_id: String) -> Dictionary:
	for entry: Dictionary in commissions():
		if entry["id"] == commission_id:
			return entry
	return {}


## The day's owner's pick in a shop the hero owns (PIX-178).
static func owner_pick(shop_id: String, day: int) -> String:
	var picks: Array = _data()["rent"]["ownerPicks"].get(shop_id, [])
	return String(picks[day % picks.size()]) if not picks.is_empty() else ""


## Town inns honor their patron: half price from tier 3 (restCostFor).
static func rest_cost_for(current: int) -> int:
	var cost := int(_data()["restCost"])
	return ceili(cost / 2.0) if current >= 3 else cost


## Business deeds: map id -> {name, cost}.
static func deeds() -> Dictionary:
	return _data()["properties"]


static func bank(key: String) -> Variant:
	return _data()["bank"][key]


## The day's rate: Mirelle's savings pay more once her arc is done (PIX-157).
static func savings_rate(upgraded := false) -> float:
	return float(arc("mirelleRate")) if upgraded else float(bank("savingsRate"))


## A pot's interest brought up to `steps` (PIX-177): simple interest on what
## was put in, for each whole day since it was last counted, kept apart
## (it never earns interest itself) and never past the pot's cap. Returns
## the pot as it stands now: {principal, earned, at}.
static func savings_accrued(savings: Dictionary, steps: int, upgraded := false) -> Dictionary:
	var principal := int(savings["principal"])
	var at := int(savings["at"])
	var days := maxi(0, floori((steps - at) / float(bank("daySteps"))))
	var earned := mini(savings_cap(principal), int(savings.get("earned", 0)) + floori(principal * savings_rate(upgraded) * days))
	return {"principal": principal, "earned": earned, "at": at + days * int(bank("daySteps"))}


## The most a pot of `principal` can earn.
static func savings_cap(principal: int) -> int:
	return floori(principal * float(bank("savingsCapShare")))


## What a pot is worth to take out now: what went in and what it earned.
static func savings_value(savings: Dictionary, steps: int, upgraded := false) -> int:
	var now := savings_accrued(savings, steps, upgraded)
	return int(now["principal"]) + int(now["earned"])


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


## What still blocks a recruit from taking up their story: "tier" or "".
## Their price is their quest now (PIX-148).
static func recruit_blocker(recruit: Dictionary, town_tier: int) -> String:
	return "tier" if int(recruit.get("minTownTier", 1)) > town_tier else ""


## The recruits who live in town now, with the perk each brings (PIX-148),
## grown where their arc is done (PIX-157).
static func settler_perks(settlers: Array, quests := {}) -> Array[String]:
	var out: Array[String] = []
	for recruit_entry: Dictionary in Npcs._data()["recruits"]:
		if recruit_entry["id"] in settlers:
			var grown := perk_upgraded(recruit_entry["id"], quests)
			out.append(String(recruit_entry["perkUp" if grown else "perk"]))
	return out


## A settler's arc (PIX-157): after moving in, two more asks, the last of
## which grows their perk. True once that last one is turned in.
static func perk_upgraded(recruit_id: String, quests: Dictionary) -> bool:
	for quest: Dictionary in Quests.all():
		if quest.get("upgrades", "") == recruit_id:
			return quests.get(quest["id"], {}).get("done", false)
	return false


## The grown perks' numbers (town.json "settlerArcs").
static func arc(key: String) -> Variant:
	return _data()["settlerArcs"][key]


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
			return {"strength": 2, "intelligence": 2, "dexterity": 2, "defense": 2, "endurance": 2}
	return {}


static func trophy_buffs() -> Dictionary:
	return _data()["trophyBuffs"]


static func nook_combines() -> Array:
	return _data()["nookCombines"]


## Rugs lie flat underfoot; everything else takes the tile.
static func furniture_blocks(item_id: String) -> bool:
	return item_id != "furn_rug"


## Herbs and reeds for the cauldron, turn and turn about (PIX-179: the
## manor garden grows what crafting needs; it used to be bread and cheese).
static func garden_yield(harvests: int) -> String:
	var crops: Array = _data()["gardenYields"]
	return String(crops[harvests % crops.size()])


static func house_door() -> Vector2i:
	var door: Dictionary = _data()["houseDoor"]
	return Vector2i(door["x"], door["y"])
