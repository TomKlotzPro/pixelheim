class_name Ranks
## Rank evolution (src/game/hero/ranks.ts): every 5 levels the hero ascends
## to a new title, stands a touch taller with an aura under them, and banks a
## bonus skill point (HeroRules.apply_level_ups). Rank comes from level, never
## stored, so old saves are already ranked. Also the Path Graph's choices
## (hero/paths.ts): which step the hero may take now, and from where.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/progression.json")))
	return _doc


## The role's title at this level (rankTitle).
static func title(role_id: String, level: int) -> String:
	return _data()["rankTitles"][role_id][HeroRules.rank_index(level)]


## The aura under the ascended: none, then silver, gold, radiant.
static func aura(level: int) -> Variant:
	var hex: Variant = _data()["rankAuras"][HeroRules.rank_index(level)]
	return Color(hex) if hex != null else null


## How much bigger the hero stands at this rank (rankPresence).
static func presence(level: int) -> float:
	return 1.0 + HeroRules.rank_index(level) * 0.05


## The path tier the hero may choose right now, 0 if none (pendingTier): one
## step per rank, three steps in all.
static func pending_tier(hero: HeroState) -> int:
	var walked := HeroRules.walked(hero).size()
	if walked >= 3:
		return 0
	return walked + 1 if HeroRules.rank_index(hero.level) >= walked + 1 else 0


## The nodes on offer for the pending choice (pathChoices): the role's, at
## that tier, reachable from the last step (tier 1 takes either spec).
static func path_choices(hero: HeroState) -> Array:
	var tier := pending_tier(hero)
	if tier == 0:
		return []
	var path := HeroRules.walked(hero)
	var last: String = path[-1] if not path.is_empty() else ""
	return Bestiary._data()["pathNodes"].filter(func(node: Dictionary) -> bool:
		return node["roleId"] == hero.role_id and int(node["tier"]) == tier and (tier == 1 or last in node["from"])
	)
