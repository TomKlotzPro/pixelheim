extends GutTest
## After the story (PIX-257, the main story's step 11): the Deep Hunt is
## retired and the Kings' Vault takes its place. Five floors under the
## summit, laid from seeds, reached through a door of black iron on the
## mountain road that opens once the dragon is freed (or at once for a hero
## who slew him on the old mountain); each floor harder than the one above,
## a guardian on each, the very best gear in its chests and forged into its
## drops. Old saves keep what the Deep Hunt gave them and wake safe; nothing
## in the world points at the old floors or the Hunt any more.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const FLOORS := ["vault_1", "vault_2", "vault_3", "vault_4", "vault_5"]
const GUARDIANS := ["hollowmother", "grimshade", "bone_abbot", "ironheart", "hollow_king"]
const DOOR := Vector2i(12, 2)
const OLD_DEEP := "res://test/fixtures/old_deep.json"

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


## Every cell a walk from `from` reaches on open ground, through no way on.
func _walked(map: MapData, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		for step: Vector2i in STEPS:
			var next := here + step
			if not seen.has(next) and Ways.open_ground(map, next):
				seen[next] = true
				queue.append(next)
	return seen


func _beside(walked: Dictionary, cell: Vector2i) -> bool:
	return STEPS.any(func(step: Vector2i) -> bool: return walked.has(cell + step))


# ---- The floors ---------------------------------------------------------------------

func test_the_vault_is_five_planned_floors_top_down() -> void:
	assert_eq(Depths.floors("vault").map(func(entry: Dictionary) -> String: return entry["mapId"]), FLOORS)
	for i in FLOORS.size():
		assert_eq(Depths.number(FLOORS[i]), i + 1)
		assert_true(Depths.is_planned(FLOORS[i]), "%s is laid from a seed" % FLOORS[i])
		var map := MapData.load_by_id(FLOORS[i])
		assert_eq(map.style, "cave")
		assert_eq(map.region_at(map.spawn), "vault", "%s is the Vault's" % FLOORS[i])
		assert_eq(Depths.root(FLOORS[i]), "vault_1")
	assert_eq(Depths.dungeon("vault")["name"], "The Kings' Vault")
	assert_eq(Depths.wind("vault_3"), "deepwind", "the deeper wind")


func test_every_floor_is_reached_from_the_door_down_the_stairs() -> void:
	var road := MapData.load_by_id("mountain_road")
	var door: Dictionary = road.portals[DOOR]
	assert_eq([door["mapId"], door["barred"]], ["vault_1", "vault"], "the door under the summit, barred")
	assert_eq(Ways.kind_of(road, DOOR), "gate")
	assert_true(Ways.on(road).any(func(way: Dictionary) -> bool: return way["at"] == DOOR and way["rock"]), "drawn as a gate in the rock")
	assert_true(_beside(_walked(road, road.spawn), DOOR), "walked to up the road")
	var map := MapData.load_by_id(door["mapId"])
	var at := Vector2i(int(door["x"]), int(door["y"]))
	assert_eq(at, map.spawn, "it opens at the foot of the first floor's stair")
	for depth in FLOORS.size():
		assert_eq(map.id, FLOORS[depth])
		var walked := _walked(map, at)
		var guardian := Hunts.named(GUARDIANS[depth])
		assert_eq(guardian["mapId"], map.id, "%s keeps %s" % [GUARDIANS[depth], map.id])
		assert_true(walked.has(Hunts.lair(guardian)), "%s's lair is walked to" % GUARDIANS[depth])
		var find := Depths.find_cell(map.id)
		assert_true(_beside(walked, find), "%s: its find is walked to" % map.id)
		var down: Dictionary = Depths.stairs(map.id).get("down", {})
		if down.is_empty():
			var cut: Dictionary = Depths.shortcut_on(map.id)
			assert_true(_beside(walked, cut["cell"]), "the bottom: its shortcut is walked to")
			break
		assert_true(_beside(walked, down["cell"]), "%s: its stair down is walked to" % map.id)
		var target: Dictionary = map.portals[down["cell"]]
		map = MapData.load_by_id(target["mapId"])
		at = Vector2i(int(target["x"]), int(target["y"]))
	assert_eq(map.id, "vault_5", "all five floors")


func test_the_stairs_go_both_ways_and_the_first_leads_out() -> void:
	for i in FLOORS.size() - 1:
		var upper := MapData.load_by_id(FLOORS[i])
		var lower := MapData.load_by_id(FLOORS[i + 1])
		var down: Dictionary = Depths.stairs(upper.id)["down"]
		var up: Dictionary = Depths.stairs(lower.id)["up"]
		assert_eq(upper.tile_at(down["cell"]), "stairwell")
		assert_eq(lower.tile_at(up["cell"]), "cave")
		assert_eq(upper.portals[down["cell"]], {"kind": "map", "mapId": lower.id, "x": up["arrive"].x, "y": up["arrive"].y})
		assert_eq(lower.portals[up["cell"]], {"kind": "map", "mapId": upper.id, "x": down["arrive"].x, "y": down["arrive"].y})
		assert_true(Ways.goes_under(upper, lower))
	var first := MapData.load_by_id("vault_1")
	var stairs: Vector2i = Depths.plan("vault_1")["stairs"]
	assert_eq(first.tile_at(stairs), "cave")
	assert_eq(first.portals[stairs], {"kind": "map", "mapId": "mountain_road", "x": 12, "y": 3}, "the first floor's stair leads back out of the door")
	assert_true(MapData.load_by_id("mountain_road").is_walkable(Vector2i(12, 3)), "onto the road below it")


func test_each_floor_is_harder_and_forges_deeper() -> void:
	for i in range(1, FLOORS.size()):
		assert_gt(Depths.foe_level(FLOORS[i]), Depths.foe_level(FLOORS[i - 1]), "%s's packs are stronger" % FLOORS[i])
		assert_gte(Depths.forged(FLOORS[i]), Depths.forged(FLOORS[i - 1]))
		assert_gt(int(Hunts.named(GUARDIANS[i])["level"]), int(Hunts.named(GUARDIANS[i - 1])["level"]), "%s stands above %s" % [GUARDIANS[i], GUARDIANS[i - 1]])
	assert_gte(Depths.foe_level("vault_1"), 15.0, "the first floor's foes from 15")
	assert_eq(Depths.boss("vault"), "hollow_king")
	for spawn: Dictionary in Bestiary.spawns_on("vault_3"):
		assert_has(["boneknight", "shade", "mimic", "imp"], spawn["species"], "the old foes of the mountain's deep floors")


## The very best gear lives here (PIX-257): the Obsidian Blade, the Old
## King's Crown, the kings' own mail and the deep-forged pieces.
func test_the_best_gear_is_in_the_vault() -> void:
	var finds := {}
	for chest: Dictionary in Interactables._data()["chests"]:
		if String(chest["mapId"]).begins_with("vault_"):
			finds[chest["mapId"]] = chest
	for floor_id: String in FLOORS:
		assert_true(finds.has(floor_id), "%s has a find" % floor_id)
		assert_eq(String(Depths.floor_of(floor_id)["find"]), String(finds[floor_id]["id"]))
	assert_eq(finds["vault_2"]["loot"]["itemId"], "obsidian_blade")
	assert_eq(finds["vault_3"]["loot"]["itemId"], "runic_armor")
	assert_eq(int(finds["vault_3"]["loot"]["forged"]), 2, "forged as deep as its floor")
	assert_eq(Hunts.named("hollow_king")["drop"], "lich_crown")
	assert_eq(Catalog.item_name("lich_crown"), "Old King's Crown")
	state.spoils.hunted("hollow_king")
	assert_eq(int(state.pack.items.get("lich_crown", 0)), 1, "the Hollow King leaves his crown")
	# A guardian's gear comes epic and forged as deep as its floor.
	state.spoils.hunted("grimshade")
	var cloak: Dictionary = state.pack.gear[-1]
	assert_eq([cloak["itemId"], cloak["rarity"], int(cloak["deep"])], ["shadow_cloak", "epic", Depths.forged("vault_2")])


## Each region's bottom floor keeps its best pieces (PIX-257: the old
## mountain's floor hoards moved there).
func test_each_regions_bottom_floor_keeps_its_best_pieces() -> void:
	var hoards := {"seacave_grotto": "duelists_ring", "shafts_blackseam": "wyrm_visor", "cellars_hall": "moon_pendant", "icecave_glass": "dragonbane"}
	for map_id: String in hoards:
		var chests: Array = Interactables._data()["chests"].filter(func(chest: Dictionary) -> bool: return chest["mapId"] == map_id and chest.get("loot", {}).get("itemId", "") == hoards[map_id])
		assert_eq(chests.size(), 1, "%s keeps %s" % [map_id, hoards[map_id]])
		var map := MapData.load_by_id(map_id)
		var at := Vector2i(int(chests[0]["x"]), int(chests[0]["y"]))
		assert_true(map.is_walkable(at) or map.tile_at(at) == map.tile_at(map.spawn), "%s's hoard stands on its floor" % map_id)
		assert_true(_beside(_walked(map, map.spawn), at), "%s's hoard is walked to" % map_id)
		assert_eq(Depths.floor_of(map_id)["number"], Depths.count(Depths.floor_of(map_id)["dungeon"]), "%s is its dungeon's bottom" % map_id)


# ---- The door -----------------------------------------------------------------------

func test_the_door_waits_for_the_dragon_freed() -> void:
	var door: Dictionary = MapData.load_by_id("mountain_road").portals[DOOR]
	assert_false(Vault.door_open(state.progression, state.settlement), "shut to a new hero")
	assert_true(Ways.barred(door, state.progression, state.settlement))
	assert_string_contains(Ways.barred_line(door), "corners")
	# Even Maren's promise, which opens the mountain's gate, doesn't open it.
	state.mark_seen("maren_confession")
	assert_true(Relics.gate_open(state.progression))
	assert_true(Ways.barred(door, state.progression, state.settlement), "the mountain's gate open, the Vault's still shut")
	# The dragon freed: the Night of Bells told (the chapter done), its
	# condition as MainQuest reads a step's.
	var opens: Dictionary = Vault.dungeon()["opens"]
	assert_eq([opens["kind"], int(opens["chapter"])], ["chapterDone", 7])
	assert_eq(MainQuest.title_of(7), "The Night of Bells")
	# The collar off at dawn (PIX-253 step 9): Fafnyr is free, and the door opens.
	state.mark_seen(Bells.collar_id())
	assert_true(Vault.door_open(state.progression, state.settlement), "the dragon freed")
	assert_false(Ways.barred(door, state.progression, state.settlement))
	assert_eq(Vault.first_word(door, state.progression), Vault.FIRST_WORD, "and he shows the hoard himself")


func test_a_hero_who_slew_fafnyr_finds_it_open() -> void:
	var door: Dictionary = MapData.load_by_id("mountain_road").portals[DOOR]
	for level: int in [10, 15]:
		var progression := ProgressionState.new()
		progression.cleared_levels.append(level)
		assert_true(Vault.door_open(progression, state.settlement), "floor %d cleared on the old mountain" % level)
		assert_false(Ways.barred(door, progression, state.settlement))
		assert_eq(Vault.first_word(door, progression), Vault.QUIET_WORD, "no dragon to show the hoard: the door alone")
		progression.story_seen.append(Vault.QUIET_WORD)
		assert_eq(Vault.first_word(door, progression), "", "once")


func test_a_whole_chapter_told_is_done() -> void:
	var settlement := SettlementState.new()
	assert_false(MainQuest.chapter_done(1, state.progression, settlement))
	state.mark_seen("maren_tin")
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	assert_true(MainQuest.chapter_done(1, state.progression, settlement), "its errands aside, chapter 1's steps met")
	assert_false(MainQuest.chapter_done(7, state.progression, settlement), "the Night of Bells not held yet")
	state.mark_seen(Bells.collar_id())
	assert_true(MainQuest.chapter_done(7, state.progression, settlement), "the collar off: the night is told")
	assert_false(MainQuest.chapter_done(8, state.progression, settlement), "Coming Home isn't written yet")


func test_fafnyr_shows_the_hoard_he_hated() -> void:
	var door: Dictionary = MapData.load_by_id("mountain_road").portals[DOOR]
	assert_eq(Vault.first_word(door, state.progression), Vault.FIRST_WORD)
	assert_eq(Vault.first_word({"kind": "map", "mapId": "morvax_forge", "x": 8, "y": 8}, state.progression), "", "no other door says it")
	var scene: Array = Cutscene.scenes()[Vault.FIRST_WORD]
	var said: Array = scene.filter(func(step: Dictionary) -> bool: return step["kind"] == "caption").map(func(step: Dictionary) -> String: return step["text"])
	assert_true(said.any(func(line: String) -> bool: return line.contains("It's all corners.")), "Take it. It's all corners.")
	assert_true(scene.any(func(step: Dictionary) -> bool: return step["kind"] == "actor" and String(step["sheet"]).contains("Dragon")), "Fafnyr himself")
	assert_false(Cutscene.scenes()[Vault.QUIET_WORD].any(func(step: Dictionary) -> bool: return step["kind"] == "actor"), "no dragon for one who slew him")


# ---- Old saves ----------------------------------------------------------------------

## A hero saved deep in the Hunt (PIX-257): the save stood by the
## Undermountain's old cave, filled in now, so they wake in town, their
## gear, crystals, crown and medal as they were, the Vault open to them.
func test_a_hero_from_the_deep_hunt_wakes_safe_with_what_it_gave() -> void:
	var raw := FileAccess.get_file_as_string(OLD_DEEP)
	state.apply(WebImport.parse_any(raw))
	assert_eq(state.progression.deepest, 12, "the depth kept, unread")
	var woke := Depths.waking(state.world.map_id, state.world.cell)
	assert_eq(woke["mapId"], "town", "by the filled-in cave: home to town")
	var blade: Dictionary = state.pack.gear_by_uid(state.pack.equipped["weapon"])
	assert_eq(int(blade["deep"]), 2)
	assert_string_starts_with(InventoryState.gear_name(blade), "Abyssal ", "a deep piece keeps its name")
	assert_eq(HeroRules.gear_damage(blade), int(Catalog.item("obsidian_blade")["damage"]) + int(blade["bonus"]) + int(blade["deepBonus"]), "and its bonus")
	assert_eq(int(InventoryState.shown_affixes(blade)["strength"]), 5, "and what Hilda quenched into it")
	assert_gt(Economy.quench_cost(blade), 0, "Hilda still quenches it")
	assert_eq(Town.trophy_stat_delta("deep_crystal_5"), {"endurance": 2}, "the crystals still stand on the shelf")
	assert_eq(Town.trophy_stat_delta("lich_crown").size(), 5, "the crown still lends every stat")
	assert_has(Deeds.shown(state.progression).map(func(deed: Dictionary) -> String: return deed["id"]), "deep_10", "the medal earned stays in the journal")
	assert_true(Vault.door_open(state.progression, state.settlement), "past Morvax: the Vault's door stands open")
	# And it all goes back into the save as it came.
	var saved: Dictionary = state.to_dict()
	assert_eq(int(saved["deepHunt"]), 12)
	assert_eq(saved["deeds"], ["deep_10"])


# ---- Nothing points at what left ------------------------------------------------------

func test_nothing_leads_to_the_old_floors_or_the_deep_hunt() -> void:
	var combat := Bestiary._data()
	for key: String in ["levels", "dungeons", "deepHunt", "namedDeep", "floorPools", "clearXpPerFloor"]:
		assert_false(combat.has(key), "combat.json's %s left with the old floors" % key)
	for map_path: String in DirAccess.get_files_at("res://assets/maps"):
		if not map_path.ends_with(".json") or map_path == "interactables.json":
			continue
		var map := MapData.load_by_id(map_path.get_basename())
		for cell: Vector2i in map.portals:
			assert_eq(String(map.portals[cell].get("kind", "")), "map", "%s %s: every way leads to a map" % [map.id, cell])
	for waypoint: Dictionary in Interactables._data()["waypoints"]:
		assert_false(String(waypoint.get("name", "")).contains("Undermountain"), String(waypoint["id"]))
	var hints := FileAccess.get_file_as_string("res://assets/data/hints.json")
	for word: String in ["Deep Hunt", "Undermountain", "depth"]:
		assert_false(hints.contains(word), "no hint names %s" % word)
	for deed: Dictionary in Deeds.in_play():
		assert_ne(String(deed["kind"]), "deepest", "%s asks for no depth" % deed["id"])
	for entry: Dictionary in Hunts.all():
		assert_false(entry.has("deepDepth"), "%s waits on no depth" % entry["id"])
		assert_ne(String(entry["mapId"]), "deep")
	assert_false(Cutscene.scenes().has("descent"), "the stair down after the dragon left with it")
