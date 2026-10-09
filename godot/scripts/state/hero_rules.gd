class_name HeroRules
## What the hero's numbers add up to, ported from src/game/hero/{character,
## skillTree,paths,ranks}.ts: stats with gear, armor, the passives of owned
## skills and the walked path, level-ups. Pure functions over HeroState +
## InventoryState and the exported skill/path tables (combat.json).

const ARMOR_SLOTS := ["body", "offhand", "head", "hands", "feet", "neck", "ring1", "ring2"]
## What every passive can grant. The web's flee chance did nothing in a
## real-time fight; PIX-190 made those nodes move speed, a quicker dodge and
## a sure crit after one ("dodgeCrit"), and the later tiers add a share of
## damage dealt back as health ("lifeSteal"), stronger skills and heals.
const NO_PASSIVES := {
	"defense": 0, "carryBonus": 0, "critChance": 0.0, "killRefundMp": 0,
	"goldBonus": 0.0, "lowHpBonus": 0.0, "stunResist": false, "poisonResist": false,
	"attackInflict": null, "moveSpeed": 0.0, "dodgeCooldown": 0.0, "dodgeCrit": false,
	"lifeSteal": 0.0, "skillPower": 0.0, "healBonus": 0.0,
}
## However many nodes stack them: a hero no more than 40% quicker, a dodge
## no more than 60% sooner.
const MAX_MOVE_SPEED := 0.4
const MAX_DODGE_CUT := 0.6


static func _combat() -> Dictionary:
	return Bestiary._data()


## Base stat plus everything worn (effectiveStat).
static func effective_stat(hero: HeroState, pack: InventoryState, stat: String) -> int:
	return int(hero.stats.get(stat, 0)) + pack.granted_stat(stat)


## A gear piece's armor: the item's, plus the forge's and the deep's bonus
## on apparel (gearArmor; PIX-218 keeps the deep's apart).
static func gear_armor(instance: Dictionary) -> int:
	var item := Catalog.item(instance["itemId"])
	return int(item.get("armor", 0)) + (_bonus(instance) if item["category"] == "apparel" else 0)


## A weapon's damage: the item's, plus the forge's and the deep's bonus (gearDamage).
static func gear_damage(instance: Dictionary) -> int:
	var item := Catalog.item(instance["itemId"])
	return int(item.get("damage", 0)) + (_bonus(instance) if item["category"] == "weapons" else 0)


static func _bonus(instance: Dictionary) -> int:
	return int(instance["bonus"]) + int(instance.get("deepBonus", 0))


static func total_armor(pack: InventoryState) -> int:
	# A worn set's own armour bonus (PIX-166) on top of its pieces'.
	var total := int(pack.set_bonus()["armor"])
	for slot: String in ARMOR_SLOTS:
		var instance := pack.gear_by_uid(pack.equipped.get(slot, ""))
		if not instance.is_empty():
			total += gear_armor(instance)
	return total


## Innate defense plus armor plus passives (totalDefense).
static func total_defense(hero: HeroState, pack: InventoryState) -> int:
	return int(hero.stats.get("defense", 0)) + total_armor(pack) + int(passives(hero)["defense"])


static func weapon(pack: InventoryState) -> Dictionary:
	return pack.gear_by_uid(pack.equipped.get("weapon", ""))


## The path walked so far; pre-graph saves walk their spec (heroPath).
static func walked(hero: HeroState) -> Array:
	if hero.path is Array and not hero.path.is_empty():
		return hero.path
	return [hero.spec] if hero.spec else []


static func path_node(id: String) -> Dictionary:
	for node: Dictionary in _combat()["pathNodes"]:
		if node["id"] == id:
			return node
	return {}


## Owned passive skills plus the deepest path step (getPassives + activeNode).
static func passives(hero: HeroState) -> Dictionary:
	var merged := NO_PASSIVES.duplicate()
	var sources: Array = []
	var path := walked(hero)
	if not path.is_empty():
		sources.append(path_node(path[-1]).get("passive", {}))
	for node: Dictionary in _combat()["skillTrees"].get(hero.role_id, []):
		if node["kind"] == "passive" and node["id"] in hero.skill_nodes and node.has("passive"):
			sources.append(node["passive"])
	for effects: Dictionary in sources:
		for key: String in effects:
			if key == "attackInflict":
				# The deepest node's bite: the tree lists it after the one it betters.
				if effects[key] != null:
					merged[key] = effects[key]
			elif NO_PASSIVES[key] is bool:
				merged[key] = merged[key] or effects[key]
			else:
				merged[key] += effects[key]
	# Ranks beyond a finished tree (PIX-217).
	for track: Dictionary in Skills.beyond_tracks():
		var rank := int(hero.beyond.get(track["id"], 0))
		for key: String in ["skillPower", "lifeSteal"]:
			merged[key] += float(track.get(key, 0.0)) * rank
	merged["moveSpeed"] = minf(merged["moveSpeed"], MAX_MOVE_SPEED)
	merged["dodgeCooldown"] = minf(merged["dodgeCooldown"], MAX_DODGE_CUT)
	return merged


## Five ranks: 1, 5, 10, 15 and 20 (PIX-190 added the last).
static func rank_index(level: int) -> int:
	return mini(4, floori(level / 5.0))


## The health a hero of their level has grown into under today's growth
## (PIX-185 made casters and rogues sturdier): the role's base, a level's
## growth for every level past the first, a point per END spent, and what
## owned skills grant. Saves from before catch up to it (SaveCodec).
static func grown_hp(hero: Dictionary) -> int:
	var role := Catalog.role(hero["roleId"])
	var hp := int(role["baseStats"]["maxHp"]) + int(role["growth"]["maxHp"]) * (int(hero["level"]) - 1)
	hp += maxi(0, int(hero["stats"].get("endurance", 0)) - int(role["baseStats"]["endurance"]))
	for node: Dictionary in _combat()["skillTrees"].get(hero["roleId"], []):
		if node["id"] in hero.get("skillNodes", []):
			hp += int(node.get("grantStats", {}).get("maxHp", 0))
	for track: Dictionary in Skills.beyond_tracks():
		hp += int(track.get("maxHp", 0)) * int(hero.get("beyond", {}).get(track["id"], 0))
	return hp


## Applies pending XP; returns levels gained. A level grows HP/MP by role,
## heals half of them (levelUpHeal, PIX-141: a level is a lift, not a free
## refill mid-fight), banks the stat points (statPointsPerLevel) and a skill
## point (two on reaching a new rank).
static func apply_level_ups(hero: HeroState) -> int:
	var growth: Dictionary = Catalog.role(hero.role_id)["growth"]
	var points := int(_combat()["statPointsPerLevel"])
	var gained := 0
	while hero.xp >= hero.xp_to_next:
		hero.xp -= hero.xp_to_next
		hero.level += 1
		hero.xp_to_next = HeroState.xp_to_next_for(hero.level)
		hero.stats["maxHp"] = int(hero.stats["maxHp"]) + int(growth["maxHp"])
		hero.stats["maxMp"] = int(hero.stats["maxMp"]) + int(growth["maxMp"])
		hero.stat_points += points
		hero.skill_points += 1
		if rank_index(hero.level) > rank_index(hero.level - 1):
			hero.skill_points += 1
		var heal := float(_combat()["levelUpHeal"])
		hero.hp = mini(int(hero.stats["maxHp"]), hero.hp + ceili(int(hero.stats["maxHp"]) * heal))
		hero.mp = mini(int(hero.stats["maxMp"]), hero.mp + ceili(int(hero.stats["maxMp"]) * heal))
		gained += 1
	return gained
