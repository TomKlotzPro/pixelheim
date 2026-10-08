extends GutTest
## Armour as a ratio (PIX-185). Armour used to come off a hit flat, so a
## warrior with DEF points stood immune from level 5 on (every Saltmere foe
## hit for 1) while a mage died in two to five bites at every stage. Now a
## hit loses a share of itself, and every role, in what it would wear at the
## pacing model's marks (level 5 on the road to Saltmere, 12 at the gate, 19
## at the bottom), takes about 6-15 hits from a foe of its own level.

## What each kind of hero wears at each mark: plate for fighters, the
## regions' leathers for rogues and rangers, cloth for casters. At level 19
## every piece is forged up two (the forge caps at 7).
const KITS := {
	5: {
		"plate": ["leather_armor", "leather_cap", "reed_buckler", "wool_gloves", "worn_boots"],
		"leather": ["leather_armor", "leather_cap", "wool_gloves", "worn_boots"],
		"cloth": ["traveler_cloak", "leather_cap", "wool_gloves", "worn_boots"],
	},
	12: {
		"plate": ["blackiron_helm", "blackiron_plate", "blackiron_gauntlets", "blackiron_sabatons", "blackiron_bulwark"],
		"leather": ["warden_helm", "warden_hauberk", "warden_gloves", "warden_boots", "warden_kite"],
		"cloth": ["frost_hood", "frostweave_robe", "frost_mitts", "frost_boots", "frost_ward"],
	},
	19: {
		"plate": ["wyrm_visor", "city_plate", "blackiron_gauntlets", "scaled_greaves", "cinderscale_shield"],
		"leather": ["warden_helm", "warden_hauberk", "warden_gloves", "warden_boots", "warden_kite"],
		"cloth": ["frost_hood", "frostweave_robe", "frost_mitts", "frost_boots", "frost_ward"],
	},
}
const KIND := {
	"warrior": "plate", "paladin": "plate", "rogue": "leather", "ranger": "leather",
	"mage": "cloth", "cleric": "cloth", "necromancer": "cloth",
}
## Fighters in plate put a point a level into DEF; everyone else spends all
## three on what they hit with.
const DEF_A_LEVEL := {"warrior": 1, "paladin": 1}


func test_every_role_takes_six_to_fifteen_hits_from_its_match() -> void:
	for level: int in KITS:
		var foe := Bestiary.matched_attack(level)
		for role: String in KIND:
			var kit := _kitted(role, level)
			var hero: HeroState = kit[0]
			var hit := foe * (1.0 - Bestiary.turned_aside(foe, HeroRules.total_defense(hero, kit[1])))
			var hits := float(hero.stats["maxHp"]) / hit
			gut.p("L%d %s: HP %d, DEF %d, %.1f a hit, %.1f hits" % [level, role, hero.stats["maxHp"], HeroRules.total_defense(hero, kit[1]), hit, hits])
			assert_between(hits, 6.0, 17.0, "a level-%d %s against a foe of their level" % [level, role])


func test_armour_never_makes_anyone_immune() -> void:
	var hero := HeroState.create("Wall", "warrior")
	hero.stats["defense"] = 200
	var hit := Bestiary.through_armor(46, HeroRules.total_defense(hero, InventoryState.new()))
	assert_gt(hit, 6, "DEF 200 still lets more than a seventh of a level-19 hit through")


func test_every_point_of_armour_helps_less_than_the_last() -> void:
	var before := 1.0
	var gained := 1.0
	for armour in range(0, 120, 10):
		var share := 1.0 - Bestiary.turned_aside(30.0, armour)
		assert_lt(share, before + 0.0001, "more armour never lets more through")
		if armour > 0:
			assert_lt(before - share, gained + 0.0001, "and each ten counts for less")
			gained = before - share
		before = share


func test_the_heros_swings_still_cut_through_a_monsters_light_armour() -> void:
	# Monsters wear little (0-16), so a swing loses about what it used to.
	var orc := Bestiary.spawn("orc")
	assert_eq(Bestiary.through_armor(23, orc["defense"]), 19, "the web's flat cut made it 19 too")
	assert_eq(Bestiary.through_armor(30, 0), 30, "no armour, no loss")


func test_a_foe_of_a_level_hits_like_the_kinds_brought_to_it() -> void:
	assert_eq([Bestiary.matched_attack(5), Bestiary.matched_attack(12), Bestiary.matched_attack(19)], [13.5, 30.0, 46.0])


func test_casters_and_rogues_who_levelled_before_catch_up() -> void:
	var mage := HeroState.create("Old", "mage")
	mage.level = 12
	mage.stats["maxHp"] = 28 + 4 * 11
	mage.hp = 50
	var state := SaveCodec.initial_state()
	state["hero"] = mage.to_dict()
	var hero: Dictionary = SaveCodec.normalize(state)["hero"]
	assert_eq(hero["stats"]["maxHp"], 28 + 6 * 11, "a mage grows 6 a level now")
	assert_eq(hero["hp"], 50 + 22, "and the difference is healed in")
	state["hero"] = hero
	assert_eq(SaveCodec.normalize(state)["hero"]["stats"]["maxHp"], 28 + 6 * 11, "once")
	var warrior := HeroState.create("Old", "warrior")
	warrior.level = 12
	warrior.stats["maxHp"] = 200
	state["hero"] = warrior.to_dict()
	assert_eq(SaveCodec.normalize(state)["hero"]["stats"]["maxHp"], 200, "never lowered")


## A hero of the role at `level`, grown, their points spent, their defensive
## passives learned, in their kind's kit for that mark.
func _kitted(role: String, level: int) -> Array:
	var hero := HeroState.create("Model", role)
	while hero.level < level:
		hero.xp = hero.xp_to_next
		HeroRules.apply_level_ups(hero)
	for i in int(DEF_A_LEVEL.get(role, 0)) * (level - 1):
		Skills.apply_stat_point(hero, "defense")
	for entry: Dictionary in Skills.tree(role):
		if entry["kind"] == "passive" and int(entry.get("passive", {}).get("defense", 0)) > 0 and Skills.tier_level(entry) <= level:
			hero.skill_nodes.append(entry["id"])
	var pack := InventoryState.new()
	for item_id: String in KITS[level][KIND[role]]:
		var piece := InventoryState.create_gear(item_id)
		piece["bonus"] = 2 if level >= 19 else 0
		pack.gear.append(piece)
		pack.equipped[Catalog.item(item_id)["slot"]] = piece["uid"]
	return [hero, pack]
