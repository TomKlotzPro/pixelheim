class_name Foes
extends Node
## The world's foes (Solid Ground, PIX-260: moved out of world.gd as they
## were): packs at their homes and back when their time is up, the named
## monsters in their lairs, the mimic in its chest; when a monster may notice
## the hero, and the fight's clock that keeps the battle music on; a monster
## fallen (the web's victory, a pack scattered, a floor's foes counted down)
## and a boss's fall. Monsters stand on the world's y-sorted actors layer, in
## the "mobs" group.

var world: Node
## Monsters at each of the web's visible spawn points: a small pack of the
## species that lives there, so the real-time fight has bodies to swing at.
const PACK_SIZE := 3
## Fight music holds this long after the last hunter gives up.
const COMBAT_LINGER_S := 3.0
## A boss's fall (PIX-210): how long the music keeps quiet, and how slow the
## world runs as it falls.
const BOSS_HUSH_S := 3.5
const BOSS_SLOW := 0.25
const BOSS_SLOW_S := 0.8
var kills := 0
## spawn id -> monsters of its pack still standing
var pack_alive := {}
## When the hero last arrived somewhere: a moment's grace before anything
## notices them (Packs graceSeconds).
var arrived_at := -100.0
## When something last hunted the hero, and whether a boss did.
var hunted_at := -100.0
var hunted_by_boss := false
var noticed_at := -100.0
## Foes still standing on the dungeon floor the hero walks (0 when cleared).
var floor_foes := 0


## Packs at their homes (the spawns): the species its region and position
## decide, an elite roll each. A pack the slain ledger keeps down stays away;
## one whose time is up comes home only where the hero can't see it appear
## (PIX-142), now or on a later look (revive).
func spawn_for(data: MapData) -> void:
	pack_alive = {}
	for spawn: Dictionary in Bestiary.spawns_on(data.id):
		if spawn["id"] in GameState.world.slain:
			continue
		_spawn_pack(data, spawn)
	spawn_lairs()
	revive()


## One monster of `species` at `cell`, at home there unless `home` says where
## its pack lives; wild ones pay the reduced wild rewards.
func spawn_enemy(species: String, cell: Vector2i, region := "", spawn_id := "", elite := false, wild := true, home := Vector2i(-1, -1), lift := 0) -> Node:
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = world
	var fighter := Bestiary.spawn(species, elite, lift)
	enemy.fighter = Bestiary.wild(fighter, region) if wild else fighter
	enemy.region = region
	enemy.spawn_id = spawn_id
	enemy.position = MapView.center(cell)
	enemy.home = MapView.center(home if home != Vector2i(-1, -1) else cell)
	enemy.add_to_group("mobs")
	world.actors.add_child(enemy)
	return enemy


## The named monsters the board has posted, each in its lair on this map
## unless already out (PIX-156).
func spawn_lairs() -> void:
	if world.map.floor_level > 0:
		return
	var out := []
	for enemy in get_tree().get_nodes_in_group("mobs"):
		if not enemy.is_queued_for_deletion():
			out.append(enemy.fighter.get("named", ""))
	for entry in Hunts.living_on(world.map.id, GameState.board_floors(), GameState.progression.hunted):
		if entry["id"] not in out:
			spawn_named(entry["id"])


## A named monster in its lair (PIX-156), or at `cell` (the harness): never
## a pack, never respawned once dead; a chase it gives up ends with it home
## and whole again.
func spawn_named(named_id: String, cell := Vector2i(-1, -1)) -> Node:
	var at := Hunts.lair(Hunts.named(named_id)) if cell == Vector2i(-1, -1) else cell
	var enemy := preload("res://scripts/enemy.gd").new()
	enemy.world = world
	enemy.fighter = Hunts.fighter(named_id)
	enemy.region = world.map.region_at(at)
	enemy.position = MapView.center(at)
	enemy.home = MapView.center(at)
	enemy.add_to_group("mobs")
	world.actors.add_child(enemy)
	return enemy


## Cleared packs whose time is up, back at homes out of view.
func revive() -> void:
	if world.map.floor_level > 0:
		return
	for spawn: Dictionary in Bestiary.spawns_on(world.map.id):
		if not Packs.is_due(GameState.world, spawn["id"]):
			continue
		var home := MapView.center(Vector2i(spawn["x"], spawn["y"]))
		if world.camera_rig.in_view(home, 2 * MapView.TILE):
			continue
		GameState.revive_pack(spawn["id"])
		_spawn_pack(world.map, spawn)


## One pack around its home: up to PACK_SIZE on open cells of its region.
func _spawn_pack(data: MapData, spawn: Dictionary) -> void:
	var home := Vector2i(spawn["x"], spawn["y"])
	var region := data.region_at(home)
	var elite_chance := float(Bestiary.region(region)["eliteChance"])
	var cells: Array[Vector2i] = [home]
	for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = home + offset
		if cells.size() < PACK_SIZE and data.is_walkable(cell) and data.region_at(cell) != "" and not data.portals.has(cell):
			cells.append(cell)
	# A spawn may name its size: one captain, not three (PIX-165).
	cells.resize(mini(cells.size(), int(spawn.get("size", PACK_SIZE))))
	for i in cells.size():
		# The pack's leader is the spawn's kind; the rest the region's mix (PIX-191).
		var kind := Bestiary.pack_species(spawn, region, i, cells[i])
		spawn_enemy(kind, cells[i], region, spawn["id"], GameState.roll.call() < elite_chance, true, home)
	pack_alive[spawn["id"]] = cells.size()


## A mimic's chest shudders before it bites (PIX-142): a beat to step back,
## then it bursts out beside the chest, nearest the hero, already hunting.
func mimic_wakes(sprite: Sprite2D, chest: Dictionary) -> void:
	var visit: MapView = world.view
	var rest := sprite.position
	var shudder := sprite.create_tween()
	for i in 7:
		shudder.tween_property(sprite, "position:x", rest.x + (1.0 if i % 2 == 0 else -1.0), 0.07)
	shudder.tween_property(sprite, "position:x", rest.x, 0.07)
	await shudder.finished
	if world.view != visit:
		return
	sprite.texture = MapView.treasure_texture(chest, true)
	Sound.play("chest")
	var at := Vector2i(int(chest["x"]), int(chest["y"]))
	var ambush := Vector2i(-1, -1)
	for step: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i(-1, 1), Vector2i(1, 1)]:
		var cell := at + step
		if not world.map.is_walkable(cell) or cell == world.player_cell:
			continue
		if ambush.x < 0 or cell.distance_to(world.player_cell) < ambush.distance_to(world.player_cell):
			ambush = cell
	if ambush.x < 0:
		ambush = world.player_cell + Vector2i.RIGHT
	var mimic := spawn_enemy("mimic", ambush, world.map.region_at(ambush), "", false, true)
	world.fx.appear(mimic)
	mimic.notice()


## Whether a monster may notice the hero now (PIX-142): not in the moment
## after an arrival, only close by, only where the player can see it (on
## screen, above the dock) and only with nothing solid between them.
func can_notice(enemy: Node) -> bool:
	if Time.get_ticks_msec() / 1000.0 - arrived_at < float(Packs.rules()["graceSeconds"]):
		return false
	var at: Vector2 = enemy.global_position
	if enemy.feeding and at.distance_to(world.player.global_position) > MapView.TILE * 1.5:
		return false
	if not Packs.within_notice(at, world.player.global_position) or not world.camera_rig.in_view(at):
		return false
	return Packs.can_see(world.map, Vector2i((at / MapView.TILE).floor()), Vector2i((world.player.position / MapView.TILE).floor()))


## Something has seen the hero: a growl (SFX.bump), not more than once a beat.
func on_enemy_noticed(enemy: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	world.hint("dodge")
	# A named monster or a boss roars (PIX-158, PIX-210); anything else bumps.
	if fights_like_boss(enemy):
		Sound.play("roar")
	elif now - noticed_at > 1.5:
		Sound.play("bump")
	noticed_at = now
	hunted_at = now
	hunted_by_boss = hunted_by_boss or fights_like_boss(enemy)
	if enemy.fighter.has("named"):
		world.messages.log_lines([Hunts.named(enemy.fighter["named"])["seen"]])


## A boss or a named monster (PIX-156): the boss's music plays.
func fights_like_boss(enemy: Node) -> bool:
	return Bestiary.is_boss(enemy.fighter["id"]) or enemy.fighter.has("named")


## A fight is on: something has hunted the hero in the last few seconds.
func in_fight() -> bool:
	return Time.get_ticks_msec() / 1000.0 - hunted_at < COMBAT_LINGER_S


## A monster fell: the web's victory pays out, and the last of a spawn's pack
## clears that spawn until the hero leaves the map.
func on_enemy_died(enemy: Node) -> void:
	kills += 1
	var cleared := ""
	if enemy.spawn_id != "":
		pack_alive[enemy.spawn_id] = pack_alive.get(enemy.spawn_id, 1) - 1
		if pack_alive[enemy.spawn_id] <= 0:
			cleared = enemy.spawn_id
	var floor_level := Bestiary.wild_drop_floor(enemy.region, enemy.fighter) if enemy.region != "" else 1
	if world.map.floor_level > 0:
		floor_level = Dungeons.drop_floor(world.map.floor_level)
	var gear_before := GameState.pack.gear.size()
	world.messages.log_lines(GameState.defeat_monster(enemy.fighter, enemy.region, cleared, floor_level, world.map.floor_level))
	world.fx.show_loot(GameState.pack.gear.slice(gear_before), enemy.global_position)
	if enemy.has_meta("prologue"):
		world.messages.flash(GameState.prologue_pouch())
	# The last of a wave of the night's foes: on to the next beat.
	if enemy.has_meta("prologue_wave"):
		var left := get_tree().get_nodes_in_group("mobs").filter(func(mob: Node) -> bool:
			return mob != enemy and mob.has_meta("prologue_wave") and not mob.dying)
		if left.is_empty():
			world.messages.flash(GameState.prologue_wave_cleared())
	if enemy.fighter.has("named"):
		Sound.play("bounty")
	if GameState.pack.gear.size() > gear_before:
		Sound.play("drop")
	if cleared != "":
		world.messages.log_lines([Text.t("The pack is scattered. Another comes once you've walked a good way, or after a night's rest.")])
	# The dead a boss summons aren't the floor's own foes (PIX-150).
	if world.map.floor_level > 0 and floor_foes > 0 and not enemy.is_in_group("summoned"):
		floor_foes -= 1
		if floor_foes == 0:
			world.delve.floor_cleared(Vector2i((enemy.position / MapView.TILE).floor()))


## A boss falls (PIX-210): the world slows a moment, shakes and flashes
## white, and the music cuts so the victory sting rings out alone (the
## floor's clearing plays it; a boss with foes still about plays its own).
func boss_fell() -> void:
	Sound.stop_music()
	world.soundscape.hush(BOSS_HUSH_S)
	hunted_by_boss = false
	if world.map.floor_level == 0 or floor_foes > 0:
		Sound.play("victory")
	world.camera_rig.shake(8.0, 0.6)
	if GameState.settings.reduce_motion:
		return
	world.camera_rig.hit_stop(BOSS_SLOW_S, BOSS_SLOW)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.75)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = -world.hud_root.offset
	flash.size = Touch.view_size(world)
	world.hud_root.add_child(flash)
	var fade := flash.create_tween().set_ignore_time_scale(true)
	fade.tween_property(flash, "color:a", 0.0, 0.45)
	fade.tween_callback(flash.queue_free)
