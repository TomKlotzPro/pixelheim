class_name Skills
## The skill trees (hero/skillTree.ts) and the stat sheet (hero/statInfo.ts,
## applyStatPoint): what a point buys, which nodes can be learned, and the
## live numbers each stat drives, read through the real combat formulas so
## the sheet can't drift from the fight. Pure; GameState spends the points.

const STATS := ["strength", "intelligence", "dexterity", "defense", "endurance"]
const ABBR := {"strength": "STR", "intelligence": "INT", "dexterity": "DEX", "defense": "DEF", "endurance": "END"}
const BLURBS := {
	"strength": "Melee attack with STR weapons, and how much you can carry.",
	"intelligence": "The power of your skills and heals - and for casters, the size of the mana pool.",
	"dexterity": "Attack with bows, daggers and DEX skills (Aimed Shot, Backstab).",
	"defense": "The share of every hit you turn aside: each point helps, a little less than the last.",
	"endurance": "Grit: a little health for everyone, and for fighters the stamina pool and how fast it refills.",
}


static func tree(role_id: String) -> Array:
	return Bestiary._data()["skillTrees"].get(role_id, [])


static func node(role_id: String, node_id: String) -> Dictionary:
	for entry: Dictionary in tree(role_id):
		if entry["id"] == node_id:
			return entry
	return {}


## Forgetting (PIX-86): every bought skill, for its point back, at 20 gold a
## skill; the one a hero starts with stays. Only in the village, whose quiet
## lets a fighter unlearn (any of its maps, inside or out).
const FORGET_GOLD_PER_SKILL := 20


static func forgettable(hero: HeroState) -> Array[String]:
	var born: String = Catalog.skill_roots(hero.role_id)[0]
	var out: Array[String] = []
	for node_id: String in hero.skill_nodes:
		if node_id != born:
			out.append(node_id)
	return out


static func forget_cost(hero: HeroState) -> int:
	return FORGET_GOLD_PER_SKILL * forgettable(hero).size()


static func can_forget_at(map_id: String) -> bool:
	return map_id.begins_with("town")


## A point to spend, not yet owned, its parent owned (canBuyNode), and the
## level its tier asks (PIX-141: tiers open at levels 1, 3, 6 and 10).
static func can_buy(hero: HeroState, entry: Dictionary) -> bool:
	if hero.skill_points <= 0 or entry["id"] in hero.skill_nodes or hero.level < tier_level(entry):
		return false
	return not entry.has("requires") or entry["requires"] in hero.skill_nodes


## The level a node's tier opens at (skillTierLevels).
static func tier_level(entry: Dictionary) -> int:
	var levels: Array = Bestiary._data()["skillTierLevels"]
	return int(levels[clampi(int(entry.get("tier", 0)), 0, levels.size() - 1)])


## Casters spend mana, fighters endurance (resourceLabel).
static func resource_label(role_id: String) -> String:
	return Text.t("MP") if Catalog.role(role_id)["resource"] == "mana" else Text.t("EN")


## One stat point, spent (applyStatPoint): INT grows a caster's mana, END
## everyone's health and a fighter's stamina.
static func apply_stat_point(hero: HeroState, stat: String) -> void:
	hero.stats[stat] = int(hero.stats[stat]) + 1
	var resource: String = Catalog.role(hero.role_id)["resource"]
	if stat == "intelligence" and resource == "mana":
		hero.stats["maxMp"] = int(hero.stats["maxMp"]) + 2
		hero.mp += 2
	if stat == "endurance":
		hero.stats["maxHp"] = int(hero.stats["maxHp"]) + 1
		hero.hp += 1
		if resource == "endurance":
			hero.stats["maxMp"] = int(hero.stats["maxMp"]) + 2
			hero.mp += 2


static func stamina_regen(hero: HeroState) -> int:
	if Catalog.role(hero.role_id)["resource"] != "endurance":
		return 0
	return 1 + floori(int(hero.stats["endurance"]) / 6.0)


## Owned actives with their owned upgrades applied, then the path's
## signature (getHeroSkills). Each carries its "key" for the dock: its node's
## id, or "path" for the signature (one at a time, whichever step it is).
static func hero_skills(hero: HeroState) -> Array:
	var skills: Array = []
	var nodes := tree(hero.role_id)
	for entry: Dictionary in nodes:
		if entry["kind"] != "active" or entry["id"] not in hero.skill_nodes:
			continue
		var skill: Dictionary = entry["skill"].duplicate()
		for upgrade: Dictionary in nodes:
			if upgrade["kind"] == "upgrade" and upgrade["id"] in hero.skill_nodes and upgrade.get("requires") == entry["id"]:
				skill.merge(upgrade["patch"], true)
		skill["key"] = entry["id"]
		skills.append(skill)
	var path := HeroRules.walked(hero)
	if not path.is_empty():
		var signature: Dictionary = HeroRules.path_node(path[-1])["signature"].duplicate()
		signature["key"] = "path"
		skills.append(signature)
	return skills


## The dock (PIX-190): six keys, a skill on each the hero chose. A hero who
## never chose has the first six they know, in the tree's order (as before
## the dock could be set); once a seventh is learned the dock is pinned, so
## learning never shuffles the keys under the hero's fingers.
const DOCK_SIZE := 6


## The skill keys on the dock, "" for an empty key.
static func dock_keys(hero: HeroState) -> Array[String]:
	var keys: Array[String] = []
	if hero.skill_dock.is_empty():
		for skill: Dictionary in hero_skills(hero).slice(0, DOCK_SIZE):
			keys.append(skill["key"])
	else:
		keys.assign(hero.skill_dock.slice(0, DOCK_SIZE))
	while keys.size() < DOCK_SIZE:
		keys.append("")
	return keys


## The skill on each key, {} where there's none (or one since forgotten).
static func docked(hero: HeroState) -> Array:
	var known := {}
	for skill: Dictionary in hero_skills(hero):
		known[skill["key"]] = skill
	return dock_keys(hero).map(func(key: String) -> Dictionary: return known.get(key, {}))


## Pins the dock as it stands (before a new skill could reorder the default).
static func pin_dock(hero: HeroState) -> void:
	hero.skill_dock = dock_keys(hero)


## A newly known skill takes the first free key; returns it (1-6), or 0 when
## the dock is full or the skill was already on it.
static func place_on_dock(hero: HeroState, key: String) -> int:
	if not hero_skills(hero).any(func(skill: Dictionary) -> bool: return skill["key"] == key):
		return 0
	pin_dock(hero)
	var known := docked(hero)
	if key in hero.skill_dock and not known[hero.skill_dock.find(key)].is_empty():
		return 0
	for index in DOCK_SIZE:
		if known[index].is_empty():
			hero.skill_dock[index] = key
			return index + 1
	return 0


## Puts a known skill on key `index` (0-5); the skill already there moves to
## where this one was, or off the dock.
static func bind(hero: HeroState, key: String, index: int) -> bool:
	if index < 0 or index >= DOCK_SIZE or not hero_skills(hero).any(func(skill: Dictionary) -> bool: return skill["key"] == key):
		return false
	pin_dock(hero)
	var was := hero.skill_dock.find(key)
	if was >= 0:
		hero.skill_dock[was] = hero.skill_dock[index]
	hero.skill_dock[index] = key
	return true


## Why a skill can't be cast right now, "" when it can: its level, its
## mana or stamina, and the health price some skills take (heroSkill's checks).
static func cast_block(hero: HeroState, skill: Dictionary) -> String:
	if hero.level < int(skill.get("unlockLevel", 1)):
		return Text.t("%s needs level %d.") % [skill["name"], skill["unlockLevel"]]
	if hero.mp < int(skill["mpCost"]):
		return Text.t("Not enough %s for %s.") % [resource_label(hero.role_id), skill["name"]]
	if int(skill.get("hpCost", 0)) > 0 and hero.hp <= int(skill["hpCost"]):
		return Text.t("Too hurt to pay %s's price.") % skill["name"]
	return ""


static func skill_power(hero: HeroState, pack: InventoryState, skill: Dictionary) -> int:
	return roundi(HeroRules.effective_stat(hero, pack, skill["stat"]) * float(skill["multiplier"]))


## What a healing skill restores, with the passives that bless heals (PIX-190).
static func heal_power(hero: HeroState, pack: InventoryState, skill: Dictionary) -> int:
	return roundi(skill_power(hero, pack, skill) * (1.0 + float(HeroRules.passives(hero)["healBonus"])))


static func carry_capacity(hero: HeroState, pack: InventoryState) -> int:
	return 60 + HeroRules.effective_stat(hero, pack, "strength") * 3 + int(HeroRules.passives(hero)["carryBonus"])


## The numbers a stat drives right now (statInfo's readout).
static func readout(stat: String, hero: HeroState, pack: InventoryState) -> String:
	var weapon := HeroRules.weapon(pack)
	var scaling: String = Catalog.item(weapon["itemId"]).get("scaling", "strength") if not weapon.is_empty() else "strength"
	var parts: Array[String] = []
	match stat:
		"strength":
			if scaling == "strength":
				parts.append(Text.t("ATK %d") % (int(hero.stats["strength"]) + (HeroRules.gear_damage(weapon) if not weapon.is_empty() else 2)))
			parts.append(Text.t("carry %d") % carry_capacity(hero, pack))
		"intelligence":
			if scaling == "intelligence":
				parts.append(Text.t("ATK %d") % (int(hero.stats["intelligence"]) + HeroRules.gear_damage(weapon)))
			var strongest := -1
			for skill: Dictionary in hero_skills(hero):
				if skill.get("stat") == "intelligence":
					strongest = maxi(strongest, skill_power(hero, pack, skill))
			if strongest >= 0:
				parts.append(Text.t("skill power %d") % strongest)
			if Catalog.role(hero.role_id)["resource"] == "mana":
				parts.append(Text.t("MP %d") % hero.stats["maxMp"])
			if parts.is_empty():
				parts.append(Text.t("powers INT skills"))
		"dexterity":
			# A DEX weapon's swing, as STR's and INT's show theirs (PIX-188).
			if scaling == "dexterity":
				parts.append(Text.t("ATK %d") % (int(hero.stats["dexterity"]) + HeroRules.gear_damage(weapon)))
			var strongest := -1
			for skill: Dictionary in hero_skills(hero):
				if skill.get("stat") == "dexterity":
					strongest = maxi(strongest, skill_power(hero, pack, skill))
			if strongest >= 0:
				parts.append(Text.t("skill power %d") % strongest)
			if parts.is_empty():
				parts.append(Text.t("powers bows, daggers and DEX skills"))
		"defense":
			# Measured against a foe of the hero's own level (PIX-185).
			var defense := HeroRules.total_defense(hero, pack)
			parts.append(Text.t("DEF %d") % defense)
			parts.append(Text.t("turns aside %d%% of a level-%d hit") % [roundi(Bestiary.turned_aside(Bestiary.matched_attack(hero.level), defense) * 100), hero.level])
		"endurance":
			parts.append(Text.t("HP %d") % hero.stats["maxHp"])
			if Catalog.role(hero.role_id)["resource"] == "endurance":
				parts.append("%s %d" % [resource_label(hero.role_id), hero.stats["maxMp"]])
				parts.append(Text.t("regen %d/turn") % stamina_regen(hero))
	return " · ".join(parts)


## What a stat does, its numbers now, and after one more point (statInfo).
static func info(stat: String, hero: HeroState, pack: InventoryState) -> Dictionary:
	var after := HeroState.from_dict(hero.to_dict())
	apply_stat_point(after, stat)
	return {"blurb": Text.t(BLURBS[stat]), "now": readout(stat, hero, pack), "next": readout(stat, after, pack)}
