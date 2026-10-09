class_name Training
extends RefCounted
## The hero's skills and stats (PIX-261, out of game_state.gd): a skill's
## price paid, stat points spent, skill nodes and ranks beyond the tree
## bought or forgotten in the village, steps on the Path Graph, and the skill
## dock. It holds nothing of its own: the hero is GameState's, reached
## through `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one. Signals are its too.
var owner: GameStateScript


func _init(state: GameStateScript) -> void:
	owner = state


## A skill's price, paid (heroSkill): its mana or stamina, and its health
## price if it has one. False when it can't be paid.
func pay_for_skill(skill: Dictionary) -> bool:
	if Skills.cast_block(owner.hero, skill) != "":
		return false
	owner.hero.mp -= int(skill["mpCost"])
	owner.hero.hp -= int(skill.get("hpCost", 0))
	owner.mark_dirty()
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	return true


## A stat point, spent (SPEND_STAT_POINT).
func spend_stat_point(stat: String) -> bool:
	if owner.hero.stat_points <= 0 or stat not in Skills.STATS:
		return false
	Skills.apply_stat_point(owner.hero, stat)
	owner.hero.stat_points -= 1
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	owner.mark_dirty()
	return true


## A rank beyond a whole tree, for a skill point (PIX-217): its track's
## edge at once, and its health for good.
func buy_beyond(track_id: String) -> bool:
	for track: Dictionary in Skills.beyond_tracks():
		if track["id"] != track_id or not Skills.can_buy_beyond(owner.hero, track):
			continue
		owner.hero.skill_points -= 1
		owner.hero.beyond[track_id] = int(owner.hero.beyond.get(track_id, 0)) + 1
		var grown := int(track.get("maxHp", 0))
		owner.hero.stats["maxHp"] = int(owner.hero.stats["maxHp"]) + grown
		owner.hero.hp += grown
		owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
		owner.mark_dirty()
		return true
	return false


## Every bought skill forgotten for its point back (PIX-86): in the village,
## for Skills.forget_cost gold. What a skill grew (max HP or MP) shrinks back.
func forget_skills() -> bool:
	var forgotten := Skills.forgettable(owner.hero)
	var cost := Skills.forget_cost(owner.hero)
	if forgotten.is_empty() or not Skills.can_forget_at(owner.world.map_id) or owner.pack.gold < cost:
		return false
	for node_id: String in forgotten:
		var grants: Dictionary = Skills.node(owner.hero.role_id, node_id).get("grantStats", {})
		for stat: String in ["maxHp", "maxMp"]:
			if grants.has(stat):
				owner.hero.stats[stat] = int(owner.hero.stats[stat]) - int(grants[stat])
		owner.hero.skill_nodes.erase(node_id)
		if node_id in owner.hero.skill_dock:
			owner.hero.skill_dock[owner.hero.skill_dock.find(node_id)] = ""
	# Ranks beyond the tree go back with it, and what they grew (PIX-217).
	var ranks := 0
	for track: Dictionary in Skills.beyond_tracks():
		var rank := int(owner.hero.beyond.get(track["id"], 0))
		ranks += rank
		owner.hero.stats["maxHp"] = int(owner.hero.stats["maxHp"]) - int(track.get("maxHp", 0)) * rank
	owner.hero.beyond = {}
	owner.hero.hp = mini(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	owner.hero.mp = mini(owner.hero.mp, int(owner.hero.stats["maxMp"]))
	owner.hero.skill_points += forgotten.size() + ranks
	owner.pack.gold -= cost
	owner.pack_changed()
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	owner.save_now()
	return true


## A skill node learned for a point (BUY_SKILL_NODE): kept until forgotten
## (forget_skills), and some grow the hero's pools while they're known.
func buy_skill_node(node_id: String) -> bool:
	var entry := Skills.node(owner.hero.role_id, node_id)
	if entry.is_empty() or not Skills.can_buy(owner.hero, entry):
		return false
	var active: bool = entry.get("kind", "") == "active"
	if active:
		Skills.pin_dock(owner.hero)
	owner.hero.skill_nodes.append(node_id)
	owner.hero.skill_points -= 1
	if active:
		owner.skill_learned.emit(entry, Skills.place_on_dock(owner.hero, node_id))
	var grants: Dictionary = entry.get("grantStats", {})
	if grants.has("maxHp"):
		owner.hero.stats["maxHp"] = int(owner.hero.stats["maxHp"]) + int(grants["maxHp"])
		owner.hero.hp += int(grants["maxHp"])
	if grants.has("maxMp"):
		owner.hero.stats["maxMp"] = int(owner.hero.stats["maxMp"]) + int(grants["maxMp"])
		owner.hero.mp += int(grants["maxMp"])
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	owner.save_now()
	return true


## One step deeper into the Path Graph (CHOOSE_PATH): only a node on offer,
## and for good; `spec` mirrors the first step for older code and saves.
func choose_path(node_id: String) -> bool:
	var offered := Ranks.path_choices(owner.hero).any(func(node: Dictionary) -> bool: return node["id"] == node_id)
	if not offered:
		return false
	Skills.pin_dock(owner.hero)
	var path := HeroRules.walked(owner.hero).duplicate()
	path.append(node_id)
	owner.hero.path = path
	owner.hero.spec = path[0]
	# The first step brings a signature skill; later steps change it in place.
	Skills.place_on_dock(owner.hero, "path")
	owner.save_now()
	return true


## A known skill onto dock key `index` (0-5), from the skill tree (PIX-190).
func dock_skill(key: String, index: int) -> bool:
	if not Skills.bind(owner.hero, key, index):
		return false
	owner.save_now()
	return true
