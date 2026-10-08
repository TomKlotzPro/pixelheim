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
	# Real-time fights have no fleeing yet; DEX keeps its web meaning for now.
	"dexterity": "Your chance to flee a fight you want no part of (turn-based battles; none yet in real time).",
	"defense": "Damage shaved off every hit you take.",
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
	return "MP" if Catalog.role(role_id)["resource"] == "mana" else "EN"


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
## signature (getHeroSkills).
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
		skills.append(skill)
	var path := HeroRules.walked(hero)
	if not path.is_empty():
		skills.append(HeroRules.path_node(path[-1])["signature"])
	return skills


## Why a skill can't be cast right now, "" when it can: its level, its
## mana or stamina, and the health price some skills take (heroSkill's checks).
static func cast_block(hero: HeroState, skill: Dictionary) -> String:
	if hero.level < int(skill.get("unlockLevel", 1)):
		return "%s needs level %d." % [skill["name"], skill["unlockLevel"]]
	if hero.mp < int(skill["mpCost"]):
		return "Not enough %s for %s." % [resource_label(hero.role_id), skill["name"]]
	if int(skill.get("hpCost", 0)) > 0 and hero.hp <= int(skill["hpCost"]):
		return "Too hurt to pay %s's price." % skill["name"]
	return ""


static func skill_power(hero: HeroState, pack: InventoryState, skill: Dictionary) -> int:
	return roundi(HeroRules.effective_stat(hero, pack, skill["stat"]) * float(skill["multiplier"]))


static func flee_chance(hero: HeroState, pack: InventoryState) -> float:
	return minf(0.95, 0.4 + HeroRules.effective_stat(hero, pack, "dexterity") * 0.02 + HeroRules.passives(hero)["fleeBonus"])


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
				parts.append("ATK %d" % (int(hero.stats["strength"]) + (HeroRules.gear_damage(weapon) if not weapon.is_empty() else 2)))
			parts.append("carry %d" % carry_capacity(hero, pack))
		"intelligence":
			if scaling == "intelligence":
				parts.append("ATK %d" % (int(hero.stats["intelligence"]) + HeroRules.gear_damage(weapon)))
			var strongest := -1
			for skill: Dictionary in hero_skills(hero):
				if skill.get("stat") == "intelligence":
					strongest = maxi(strongest, skill_power(hero, pack, skill))
			if strongest >= 0:
				parts.append("skill power %d" % strongest)
			if Catalog.role(hero.role_id)["resource"] == "mana":
				parts.append("MP %d" % hero.stats["maxMp"])
			if parts.is_empty():
				parts.append("powers INT skills")
		"dexterity":
			parts.append("flee %d%%" % roundi(flee_chance(hero, pack) * 100))
		"defense":
			parts.append("blocks %d per hit" % HeroRules.total_defense(hero, pack))
		"endurance":
			parts.append("HP %d" % hero.stats["maxHp"])
			if Catalog.role(hero.role_id)["resource"] == "endurance":
				parts.append("%s %d" % [resource_label(hero.role_id), hero.stats["maxMp"]])
				parts.append("regen %d/turn" % stamina_regen(hero))
	return " · ".join(parts)


## What a stat does, its numbers now, and after one more point (statInfo).
static func info(stat: String, hero: HeroState, pack: InventoryState) -> Dictionary:
	var after := HeroState.from_dict(hero.to_dict())
	apply_stat_point(after, stat)
	return {"blurb": BLURBS[stat], "now": readout(stat, hero, pack), "next": readout(stat, after, pack)}
