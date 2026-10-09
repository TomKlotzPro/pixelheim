extends GutTest
## Combat rules, ported from src/game/combat, hero/{character,mastery,
## skillTree}.ts and the battle engine's victory/defeat. Every number in the
## *_match_the_web tests was printed from the web functions with the same
## scripted dice (Math.random replaced by the sequences below).

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())


## A loaded die: returns the values in order, then 0.5 forever.
func _dice(values: Array) -> Callable:
	var sequence := values.duplicate()
	return func() -> float: return sequence.pop_front() if not sequence.is_empty() else 0.5


## A level-1 warrior with a rusty sword and leather armor, like the reference.
func _warrior() -> Array:
	var hero := HeroState.create("T", "warrior")
	var pack := InventoryState.new()
	var sword := InventoryState.create_gear("rusty_sword")
	var armor := InventoryState.create_gear("leather_armor")
	pack.gear.assign([sword, armor])
	pack.equipped = {"weapon": sword["uid"], "body": armor["uid"]}
	return [hero, pack]


## The web's packs, but for the wolves PIX-143 sets in the forest and marsh.
func test_spawn_species() -> void:
	var expected := "ash_1=orc ash_2=orc ash_3=wyvern ash_4=wyvern forest_1=slime forest_2=goblin forest_3=wolf marsh_1=skeleton marsh_2=ghost marsh_3=wolf deep_1=troll deep_2=troll deep_3=troll deep_4=golem mire_1=ghost mire_2=skeleton mire_3=ghost mire_4=skeleton"
	var got: Array[String] = []
	for map_id in ["overworld", "deepwood", "mirefen"]:
		var map := MapData.load_by_id(map_id)
		for spawn: Dictionary in Bestiary.spawns_on(map_id):
			var cell := Vector2i(spawn["x"], spawn["y"])
			got.append("%s=%s" % [spawn["id"], Bestiary.species_of(spawn, map.region_at(cell))])
	assert_eq(" ".join(got), expected)


func test_elites_match_the_web() -> void:
	var orc := Bestiary.spawn("orc", true)
	assert_eq(orc["name"], "Elite Orc Raider")
	# PIX-186: an elite's health grows 2.25 times for real time (the web's 1.5 made it 63).
	assert_eq([orc["hp"], orc["attack"], orc["defense"], orc["xp"], orc["gold"]], [95, 21, 5, 45, 33])


func test_hero_damage_matches_the_web() -> void:
	var w := _warrior()
	assert_eq(Bestiary.hero_attack_damage(w[0], w[1], Bestiary.spawn("orc"), false, _dice([0.5])), 9)
	# PIX-185: armour takes a share, not a flat cut (the web's was 7).
	assert_eq(Bestiary.hero_attack_damage(w[0], w[1], Bestiary.spawn("orc"), false, _dice([0.0])), 8)
	assert_eq(Bestiary.hero_attack_damage(w[0], w[1], Bestiary.spawn("slime"), false, _dice([0.99])), 15)


func test_an_inspired_crit_matches_the_web() -> void:
	var ranger := HeroState.create("R", "ranger")
	ranger.skill_nodes.append("ranger_deadeye")
	ranger.path = ["beastmaster"]
	var pack := InventoryState.new()
	var bow := InventoryState.create_gear("hunting_bow")
	pack.gear.assign([bow])
	pack.equipped = {"weapon": bow["uid"]}
	assert_eq(Bestiary.hero_attack_damage(ranger, pack, Bestiary.spawn("wolf"), true, _dice([0.05, 0.5])), 21)
	var passives := HeroRules.passives(ranger)
	assert_eq(passives["carryBonus"], 20)
	assert_almost_eq(passives["critChance"], 0.1, 0.0001)
	assert_true(passives["poisonResist"])
	assert_false(passives["stunResist"])


## PIX-185: a hit of 14 against DEF 8 loses 10/(14+10) of itself (the web
## cut it flat to 6, and a slime's to 1 whatever the armour).
func test_armor_turns_aside_a_share_of_monster_hits() -> void:
	var w := _warrior()
	assert_eq(HeroRules.total_defense(w[0], w[1]), 8)
	assert_eq(Bestiary.monster_attack_damage(Bestiary.spawn("orc"), w[0], w[1], _dice([0.5])), 8)
	assert_eq(Bestiary.monster_attack_damage(Bestiary.spawn("slime"), w[0], w[1], _dice([0.5])), 2)


## PIX-141: the curve climbs (46, 70, 102...), a level banks 3 stat points
## and heals half, not all.
func test_level_ups_climb_the_curve_and_heal_half() -> void:
	var hero := HeroState.create("L", "warrior")
	hero.xp = 200
	hero.hp = 1
	assert_eq(HeroRules.apply_level_ups(hero), 2)
	assert_eq([hero.level, hero.xp, hero.xp_to_next, hero.stats["maxHp"]], [3, 84, 102, 56])
	assert_eq([hero.stat_points, hero.skill_points], [6, 2])
	assert_eq(hero.hp, 1 + 25 + 28, "half of each new max, not a refill")
	var ranked := HeroState.create("L", "warrior")
	ranked.level = 4
	ranked.xp_to_next = HeroState.xp_to_next_for(4)
	ranked.xp = ranked.xp_to_next
	HeroRules.apply_level_ups(ranked)
	assert_eq([ranked.level, ranked.skill_points], [5, 2], "a new rank pays a bonus point")


func test_drops_match_the_web() -> void:
	var gear := Bestiary.roll_drop(7, "elite", _dice([0.1, 0.2, 0.5, 0.05, 0.9]))
	assert_eq(gear["kind"], "gear")
	assert_eq([gear["gear"]["itemId"], gear["gear"]["rarity"], gear["gear"]["bonus"]], ["iron_armor", "epic", 5])
	assert_eq(Bestiary.roll_drop(1, "normal", _dice([0.1, 0.9, 0.3])), {"kind": "stack", "itemId": "apple"})
	assert_eq(Bestiary.roll_drop(1, "normal", _dice([0.3])), {}, "no drop")


func test_mastery_announces_a_crossed_tier() -> void:
	state.hero.mastery = {"beasts": 9}
	state.roll = _dice([0.99, 0.99])  # no drop, no forage
	var log: Array[String] = state.defeat_monster(Bestiary.wild(Bestiary.spawn("wolf")), "forest", "forest_2", 1)
	assert_eq(log[0], "Mastery: Beasts Slayer I. +5% damage against beasts.")
	assert_almost_eq(Bestiary.mastery_bonus(state.hero.mastery, "slime"), 0.05, 0.0001)


func test_a_kill_pays_xp_gold_rent_and_clears_the_spawn() -> void:
	state.settlement.properties.assign(["town_shop"])
	state.settlement.bard_song = true
	state.roll = _dice([0.99, 0.99])
	var wolf := Bestiary.wild(Bestiary.spawn("wolf"))
	var slain := []
	state.monster_slain.connect(func(id: String) -> void: slain.append(id))
	var log: Array[String] = state.defeat_monster(wolf, "forest", "forest_2", 1)
	assert_has(log, "Rent from your properties: +2 gold.")
	assert_has(log, "Dire Wolf is defeated! +8 XP, +9 gold.")
	assert_eq(state.hero.xp, 8)
	assert_eq(state.pack.gold, 30 + 2 + 9)
	assert_eq(state.world.slain, ["forest_2"])
	assert_eq(slain, ["wolf"])
	assert_eq(state.settlement.bard_song, false, "the song fades with the fight")


func test_foraging_and_drops_land_in_the_pack() -> void:
	# drop: chance yes, stack, apple; forage: yes, double yes
	state.roll = _dice([0.1, 0.9, 0.3, 0.1, 0.1])
	var log: Array[String] = state.defeat_monster(Bestiary.wild(Bestiary.spawn("slime")), "forest", "", 1)
	assert_eq(state.pack.items["apple"], 1)
	assert_eq(state.pack.items["forest_herb"], 2)
	assert_has(log, "You forage 2 Forest Herbs.")
	assert_eq(state.hero.jobs["foraging"]["xp"], 5)


func test_the_manor_garden_ripens_on_the_sixth_win() -> void:
	state.settlement.house["owned"] = true
	state.settlement.house["tier"] = 3
	state.settlement.house["gardenWins"] = 5
	state.roll = _dice([0.99, 0.99])
	var log: Array[String] = state.defeat_monster(Bestiary.spawn("slime"), "", "", 1)
	assert_has(log, "Your garden ripens: +1 Bread Loaf.")
	assert_eq(state.settlement.house["gardenWins"], 0)
	assert_eq(state.settlement.house["gardenHarvests"], 1)


func test_defeat_wakes_the_hero_at_the_inn() -> void:
	state.settlement.town_tier = 1
	state.settlement.bard_song = true
	assert_false(state.hurt(5))
	assert_true(state.hurt(999))
	assert_eq(state.hero.hp, 0)
	var inn: Dictionary = state.wake_at_inn()
	assert_eq([inn["mapId"], inn["x"], inn["y"]], ["town_inn", 2, 3])
	assert_eq(state.hero.hp, state.hero.stats["maxHp"])
	assert_eq(state.settlement.bard_song, false)


## In the Ashes (PIX-146) the inn is rubble: Sela's tent on the square.
func test_in_the_ashes_the_hero_wakes_by_selas_tent() -> void:
	state.settlement.town_tier = 0
	var inn: Dictionary = state.wake_at_inn()
	var tent := Town.ashes_tent([])
	assert_eq([inn["mapId"], inn["x"], inn["y"]], ["town", tent.x, tent.y + 1])
