class_name Delve
extends Node
## The dungeon floors (Solid Ground, PIX-260: moved out of world.gd as they
## were): down to a floor and its foes, up the stairs to the gate, the
## floor's clearing (its hoard, the way up, the Deep Hunt's hole, the
## throne), and how hard the hero's skills strike on a warded depth. The
## floor's foes are Foes' to count (floor_foes).

var world: Node


## Down to a dungeon floor (DungeonFloor): its foes one per room, the
## guardian last. The save still holds the gate the hero entered by.
func enter_floor(level: int) -> void:
	var plan := DungeonFloor.plan(level)
	world.map = plan["map"]
	world.enter_map(world.map, world.map.spawn)
	var foes: Foes = world.foes
	foes.floor_foes = plan["foes"].size()
	# A depth of the Deep Hunt already cleared pays its foes a share (PIX-180).
	var replay := Dungeons.is_deep(level) and Dungeons.depth_of(level) <= GameState.progression.deepest
	# The mountain's foes wear their floor's name (PIX-188): a Cellar Slime.
	var epithet := Dungeons.epithet(level)
	var twist := Dungeons.modifier(level)
	var rules: Dictionary = Bestiary._data()["deepHunt"]
	for foe: Dictionary in plan["foes"]:
		var spawned := foes.spawn_enemy(foe["id"], foe["cell"], "", "", foe["elite"], false, Vector2i(-1, -1), foe["lift"])
		# A twisted depth (PIX-216): its foes quicker, or their bites venomous.
		match String(twist.get("id", "")):
			"swift":
				spawned.pace = float(rules["swiftPace"])
			"venom":
				var venom: Dictionary = rules["venom"]
				spawned.fighter["inflicts"] = {"kind": venom["kind"], "chance": venom["chance"], "turns": venom["turns"], "power": maxi(2, roundi(int(spawned.fighter["attack"]) * float(venom["attackShare"])))}
		if String(foe.get("name", "")) != "":
			# A warden goes by its own name (PIX-216).
			spawned.fighter["name"] = Text.t(foe["name"])
		elif epithet != "" and int(foe["lift"]) > 0:
			# Named, not positional: French puts the epithet after (PIX-196).
			var titled := Text.t("{epithet} {name}").format({"epithet": Text.t(epithet), "name": Bestiary.monster(foe["id"])["name"]})
			spawned.fighter["name"] = Text.t("Elite %s") % titled if foe["elite"] else titled
		if replay:
			spawned.fighter["gold"] = roundi(int(spawned.fighter["gold"]) * float(Bestiary._data()["deepHunt"]["replayGoldShare"]))
	# A Deep Hunt named monster takes its depth's stair (PIX-219).
	if Dungeons.is_deep(level):
		var hunted := Hunts.deep_guardian(Dungeons.depth_of(level), GameState.questing.board_floors(), GameState.progression.hunted)
		if not hunted.is_empty():
			var guardian: Dictionary = plan["foes"][-1]
			for mob in get_tree().get_nodes_in_group("mobs"):
				if mob.position == MapView.center(guardian["cell"]):
					mob.remove_from_group("mobs")
					mob.queue_free()
			foes.spawn_named(hunted["id"], guardian["cell"])
	# Somewhere else in the first hall each day (PIX-250).
	var patch := Gathering.floor_patch(plan["patch_ground"], level, Gathering.day_of(GameState.world.steps))
	world.view.add_patch(patch, Gathering.floor_spot_id(level), Gathering.floor_material(level))
	var floor_def := Dungeons.floor_def(level)
	world.messages.log_lines([String(floor_def["name"]) if Dungeons.is_deep(level) else Text.t("Floor %d: %s") % [level, floor_def["name"]], String(floor_def["description"])])
	if not twist.is_empty():
		world.messages.log_lines([Text.t("%s: %s") % [Text.t(twist["name"]), Text.t(twist["line"])]])
	# A boss's floor: its intro, the first time only (PIX-32).
	world.stage.play_story(Cutscene.moment("boss:%s" % Dungeons.boss_of(level)["monsterId"]))


## Up the stairs, back to the gate the save remembers.
func leave_floor() -> void:
	world.map = world.load_map(GameState.world.map_id)
	world.enter_map(world.map, Vector2i(GameState.world.cell))


## The floor's last foe fell: its hoard on a first clear, and a way up where
## the guardian stood, so the hero needn't walk the halls back.
func floor_cleared(at: Vector2i) -> void:
	var map: MapData = world.map
	var deep := Dungeons.is_deep(map.floor_level)
	var result := GameState.spoils.clear_deep(map.floor_level) if deep else GameState.spoils.clear_floor(map.floor_level)
	Sound.play("victory")
	world.messages.log_lines(result["lines"])
	# The hoard and the way down's XP rise where the last foe fell, with what
	# it paid (PIX-245).
	world.fx.show_gains(result["gains"], MapView.center(at) + WorldFx.OVER_FOE)
	var stairs := at
	if not map.is_walkable(stairs) or map.portals.has(stairs):
		stairs = world.player_cell
	map.grid[stairs] = "cave"
	map.portals[stairs] = {"kind": "gate"}
	PunyDungeon.sheet().place(world.view.dungeon_objects, stairs, PunyDungeon.STAIRS)
	# The Deep Hunt (PIX-161) goes on: a hole into the dark beside the way up.
	if deep or Dungeons.is_final(map.floor_level):
		for side: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var down := stairs + side
			if map.is_walkable(down) and not map.portals.has(down):
				map.grid[down] = "cave"
				map.portals[down] = {"kind": "deeper"}
				PunyDungeon.sheet().place(world.view.dungeon_objects, down, PunyDungeon.VOID)
				break
	if result["victory"] and Story.ending_of(GameState.progression.story_seen) == "":
		# Morvax kneels: the hero decides how it ends (PIX-157).
		var throne := preload("res://scripts/throne_screen.gd").new()
		throne.on_choice = world.stage.play_ending
		world.add_child(throne)
	elif result["first"]:
		world.stage.play_story(Cutscene.moment("cleared:%d" % map.floor_level))


## How hard the hero's skills strike on this floor (PIX-216): less on a
## warded depth of the Deep Hunt.
func skill_ward() -> float:
	if world.map != null and Dungeons.modifier(world.map.floor_level).get("id", "") == "warded":
		return float(Bestiary._data()["deepHunt"]["wardedSkills"])
	return 1.0
