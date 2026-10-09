extends GutTest
## The board's named monsters (PIX-156): one per wild region, each in a lair of its own
## away from the packs, posted as the hero clears floors; the bounty, the
## drop nothing else gives and the town's talk come with the kill, and a
## named monster killed stays dead in the save.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## The moves elite_brain.gd knows.
const MOVES := ["lunge", "cleave", "stamp", "guard", "firebolt", "howl", "grasp", "boulder", "leap", "firefan"]


## The bounty board's own out in the Reach: a chapter's boss (the
## Tidecaller) is a quest's, and the Deep Hunt's (PIX-219) have no lairs.
func _board() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in Hunts.all():
		if Hunts.on_board(entry) and not entry.has("deepDepth"):
			out.append(entry)
	return out

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_one_named_monster_per_wild_region_in_board_order() -> void:
	var ids := _board().map(func(entry: Dictionary) -> String: return entry["id"])
	assert_eq(ids, ["greymaw", "drowned_knight", "cinderjaw", "mossback", "gulp"])
	var regions := _board().map(func(entry: Dictionary) -> String:
		return MapData.load_by_id(entry["mapId"]).region_at(Hunts.lair(entry))
	)
	assert_eq(regions, ["forest", "marsh", "ash", "deepwood", "mire"])


func test_each_lair_is_open_ground_well_away_from_the_packs() -> void:
	for entry in Hunts.all():
		if entry.has("deepDepth"):
			continue
		var map := MapData.load_by_id(entry["mapId"])
		var lair := Hunts.lair(entry)
		assert_true(map.is_walkable(lair), "%s's lair is walkable" % entry["id"])
		assert_false(map.portals.has(lair), "%s's lair is no doorway" % entry["id"])
		for spawn: Dictionary in Bestiary.spawns_on(entry["mapId"]):
			var home := Vector2i(spawn["x"], spawn["y"])
			assert_gt(Vector2(lair).distance_to(Vector2(home)), 10.0, "%s clear of %s" % [entry["id"], spawn["id"]])


func test_each_is_its_kind_grown_with_a_move_and_a_drop_of_its_own() -> void:
	for entry in _board():
		var kind := Bestiary.monster(entry["monsterId"])
		assert_false(kind.is_empty(), "%s is a %s" % [entry["id"], entry["monsterId"]])
		assert_gt(int(entry["maxHp"]), int(kind["maxHp"]) * 3, "%s outlasts three of its kind" % entry["id"])
		assert_gt(int(entry["attack"]), int(kind["attack"]), "%s hits harder" % entry["id"])
		assert_has(MOVES, String(entry["move"]["move"]), "%s's move is known" % entry["id"])
		var drop := Catalog.item(entry["drop"])
		assert_true(drop.has("slot"), "%s drops gear" % entry["id"])
		assert_string_contains(String(drop["description"]), "Hunted, never sold")
		assert_ne(ItemIcons.source(entry["drop"]), "", "%s's drop has an icon" % entry["id"])
	var moves := _board().map(func(entry: Dictionary) -> String: return entry["move"]["move"])
	assert_eq(moves.size(), 5)
	for move: String in moves:
		assert_eq(moves.count(move), 1, "%s is one monster's own" % move)


func test_the_board_posts_them_as_floors_are_cleared() -> void:
	assert_eq(Hunts.notices([], []), [] as Array[Dictionary])
	assert_eq(Hunts.next_notice([])["id"], "greymaw")
	assert_eq(Hunts.notices([1, 2], []).map(func(entry: Dictionary) -> String: return entry["id"]), ["greymaw"])
	var deep := range(1, 10)
	assert_eq(Hunts.notices(deep, []).size(), 4)
	assert_eq(Hunts.next_notice(deep)["id"], "gulp")
	# Past the mountain, the next is the Deep Hunt's first (PIX-219).
	assert_eq(Hunts.next_notice(range(1, 16))["id"], "grimshade")
	# The slain go to the bottom of the board, and out of their lairs.
	var board := Hunts.notices(deep, ["greymaw"]).map(func(entry: Dictionary) -> String: return entry["id"])
	assert_eq(board, ["drowned_knight", "cinderjaw", "mossback", "greymaw"])
	var out := Hunts.living_on("overworld", deep, ["greymaw"]).map(func(entry: Dictionary) -> String: return entry["id"])
	assert_eq(out, ["drowned_knight", "cinderjaw"])
	assert_eq(Hunts.status(Hunts.named("gulp"), deep, []), "")


func test_a_named_monster_fights_as_an_elite_of_its_kind_with_its_own_numbers() -> void:
	var fighter := Hunts.fighter("greymaw")
	assert_eq(fighter["id"], "wolf", "the wolf's sprite and family")
	assert_eq(fighter["named"], "greymaw")
	assert_eq(fighter["name"], "Old Greymaw")
	assert_true(fighter["elite"])
	assert_eq(fighter["hp"], fighter["maxHp"])
	assert_eq(fighter["maxHp"], int(Hunts.named("greymaw")["maxHp"]))
	assert_eq(Bestiary.family_of(fighter["id"]), "beasts")
	# Its own level sets the XP a strong hero still earns.
	assert_eq(Bestiary.xp_for(fighter, 5), int(fighter["xp"]))


func test_the_kill_pays_the_bounty_and_the_drop_and_the_town_hears() -> void:
	var gold: int = state.pack.gold
	var gear: int = state.pack.gear.size()
	var lines: Array[String] = state.defeat_monster(Hunts.fighter("greymaw"), "forest", "", 1)
	var entry := Hunts.named("greymaw")
	assert_gte(state.pack.gold, gold + int(entry["bounty"]) + int(entry["gold"]))
	assert_true(state.pack.gear.any(func(piece: Dictionary) -> bool: return piece["itemId"] == "greymaw_hood"))
	assert_gt(state.pack.gear.size(), gear)
	assert_true(lines.any(func(line: String) -> bool: return line.contains("bounty on Old Greymaw")))
	assert_eq(state.progression.hunted, ["greymaw"] as Array[String])
	assert_has(state.reveals, "hunt:greymaw")
	assert_eq(state.last_deed, {"kind": "hunt", "beast": "Old Greymaw"})
	var bram := {"id": "villager_bram", "mapId": "town"}
	assert_string_contains(Npcs.reaction(bram, state.last_deed), "Old Greymaw")
	# Never paid twice.
	var after: int = state.pack.gold
	state._hunted("greymaw")
	assert_eq(state.pack.gold, after)


func test_the_slain_are_kept_in_the_save_and_only_once_there_are_any() -> void:
	var progress := ProgressionState.new()
	var bare := {}
	progress.write_into(bare)
	assert_false(bare.has("hunted"), "saves from before stay byte for byte")
	progress.hunted.append("cinderjaw")
	var written := {}
	progress.write_into(written)
	assert_eq(written["hunted"], ["cinderjaw"])
	var back := ProgressionState.from_dict(written)
	assert_eq(back.hunted, ["cinderjaw"] as Array[String])
