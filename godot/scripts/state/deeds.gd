class_name Deeds
## Deeds (PIX-219): long goals for a hero who has done the rest, read off
## what the save already knows - how deep, every bounty, every family's
## mastery, a whole set worn, the whole bestiary met. Each one done stays
## done (ProgressionState.deeds) and brings a medal home for the trophy
## shelf. Pure, over progression.json's "deeds".


static func all() -> Array:
	return Quests._data()["deeds"]


## Whether `deed` is done for this hero now.
static func met(deed: Dictionary, hero: HeroState, pack: InventoryState, progression: ProgressionState) -> bool:
	var counted := count(deed, hero, pack, progression)
	return counted[0] >= counted[1]


## How far along a deed is: [have, need].
static func count(deed: Dictionary, hero: HeroState, pack: InventoryState, progression: ProgressionState) -> Array:
	match String(deed["kind"]):
		"deepest":
			return [mini(progression.deepest, int(deed["count"])), int(deed["count"])]
		"hunts":
			var named := Hunts.all()
			return [named.filter(func(entry: Dictionary) -> bool: return entry["id"] in progression.hunted).size(), named.size()]
		"masteries":
			var families: Array = Bestiary._data()["familyNames"].keys()
			var top: int = Bestiary._data()["masteryTiers"].size()
			return [families.filter(func(family: String) -> bool: return Bestiary.mastery_tier(hero.mastery, family) >= top).size(), families.size()]
		"set":
			# The most of any one set worn, against that set's whole.
			var best := [0, 1]
			var worn := pack.set_counts()
			for set_id: String in Catalog._data()["sets"]:
				var whole: int = Catalog._data()["sets"][set_id]["pieces"].size()
				var have := int(worn.get(set_id, 0))
				if float(have) / whole > float(best[0]) / best[1]:
					best = [have, whole]
			if best[0] == 0:
				best = [0, Catalog._data()["sets"].values()[0]["pieces"].size()]
			return best
		"bestiary":
			var kinds: Array = Bestiary._data()["monsters"].keys()
			return [kinds.filter(func(kind: String) -> bool: return progression.met.has(kind)).size(), kinds.size()]
	return [0, 1]
