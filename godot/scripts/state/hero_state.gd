class_name HeroState
extends Resource
## The hero record, field for field the web `Hero` (src/game/types.ts). The
## real-time combat keeps its own action-scale HP until combat v2 maps these
## stats onto it (PIX-126), so hp/mp/stats travel through Godot untouched.

const JOBS := ["smithing", "alchemy", "foraging"]

var hero_name := ""
var role_id := "warrior"
var level := 1
var xp := 0
var xp_to_next := 46
var hp := 0
var mp := 0
## maxHp, maxMp, strength, intelligence, dexterity, defense, endurance
var stats := {}
var stat_points := 0
var skill_points := 0
var skill_nodes: Array[String] = []
## The skill on each of the six keys (PIX-190), by key; empty until the hero
## sets it or learns a seventh (Skills.dock_keys).
var skill_dock: Array[String] = []
## Ranks bought beyond a finished tree (PIX-217): track id -> rank.
var beyond := {}
## job id -> {level, xp}
var jobs := {}
## Additive web fields: null means absent, and absent stays absent on save.
var look: Variant = null
var spec: Variant = null
var path: Variant = null
var mastery: Variant = null


## XP from one level to the next (PIX-141): it climbs, so kills that pay
## more deeper down don't shrink each level to a fight or two.
static func xp_to_next_for(at_level: int) -> int:
	return 30 + 12 * at_level + 4 * at_level * at_level


static func fresh_jobs() -> Dictionary:
	var out := {}
	for job: String in JOBS:
		out[job] = {"level": 1, "xp": 0}
	return out


## A level-1 hero of the role (createHero in character.ts).
static func create(name: String, role: String, look_index := 0) -> HeroState:
	var base: Dictionary = Catalog.role(role)["baseStats"]
	var hero := HeroState.new()
	hero.hero_name = name
	hero.role_id = role
	hero.look = look_index
	hero.xp_to_next = xp_to_next_for(1)
	hero.hp = base["maxHp"]
	hero.mp = base["maxMp"]
	hero.stats = base.duplicate()
	hero.skill_nodes.assign([Catalog.skill_roots(role)[0]])
	hero.jobs = fresh_jobs()
	return hero


static func from_dict(data: Dictionary) -> HeroState:
	var hero := HeroState.new()
	hero.hero_name = data["name"]
	hero.role_id = data["roleId"]
	hero.level = data["level"]
	hero.xp = data["xp"]
	hero.xp_to_next = data["xpToNext"]
	hero.hp = data["hp"]
	hero.mp = data["mp"]
	hero.stats = data["stats"].duplicate()
	hero.stat_points = data["statPoints"]
	hero.skill_points = data["skillPoints"]
	hero.skill_nodes.assign(data["skillNodes"])
	hero.skill_dock.assign(data.get("skillDock", []))
	hero.beyond = data.get("beyond", {}).duplicate()
	hero.jobs = data["jobs"].duplicate(true)
	hero.look = data.get("look")
	hero.spec = data.get("spec")
	hero.path = data.get("path")
	hero.mastery = data.get("mastery")
	return hero


func to_dict() -> Dictionary:
	var out := {
		"name": hero_name,
		"roleId": role_id,
		"level": level,
		"xp": xp,
		"xpToNext": xp_to_next,
		"hp": hp,
		"mp": mp,
		"stats": stats.duplicate(),
		"statPoints": stat_points,
		"skillPoints": skill_points,
		"skillNodes": skill_nodes.duplicate(),
		"jobs": jobs.duplicate(true),
	}
	if look != null:
		out["look"] = look
	if spec != null:
		out["spec"] = spec
	if path != null:
		out["path"] = path.duplicate()
	if mastery != null:
		out["mastery"] = mastery.duplicate()
	if not skill_dock.is_empty():
		out["skillDock"] = skill_dock.duplicate()
	if not beyond.is_empty():
		out["beyond"] = beyond.duplicate()
	return out

