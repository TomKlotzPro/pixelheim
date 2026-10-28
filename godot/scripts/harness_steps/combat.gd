extends RefCounted
## areas: all
## The harness's fighting steps (PIX-357): the hero's level, gear and wounds,
## a foe fought, cast at or felled, the fall, the mimic, a flight.
##
## Each `step_<name>()` is the step a flag names in scripts/harness_flags.txt
## (`flag | takes | does | step | order`); harness.gd runs the steps of the
## flags it was given in their order, awaiting each.

## The harness (harness.gd): its tree, its key presses and what's open.
var h: Node
var world: Node
var flags: HarnessFlags
## The report line's fields; a value known only part-way through is noted
## as it's known.
var report: HarnessReport

## How long `kill` swings at most, in the game's seconds (PIX-379: a level-1
## hero's swings fell the Hollow King in about 222).
const KILL_SECONDS := 300.0


func step_clear() -> void:
	# Fell every foe on the map at once (a floor of the Kings' Vault, PIX-257).
	for foe in h.get_tree().get_nodes_in_group("mobs"):
		foe.take_hit(99999, foe.global_position + Vector2.LEFT)
	await h.get_tree().create_timer(0.6).timeout


## `--wear iron_helm,iron_armor`: gear put on the hero (drawn on them, PIX-129).
func step_wear() -> void:
	for item_id: String in flags.list("--wear"):
		var piece := InventoryState.create_gear(item_id)
		GameState.pack.gear.append(piece)
		GameState.upkeep.equip(piece["uid"])


## `wounded` (PIX-322): a quarter of the hero's health left, for a bench
## to mend.
func step_wounded() -> void:
	GameState.upkeep.hurt(int(GameState.hero.stats["maxHp"]) - maxi(1, int(GameState.hero.stats["maxHp"]) / 4))
	world.player.heal()


func step_mimic() -> void:
	# Pair with `--map mirefen`: open the mire's mimic chest; `--wait`
	# catches its shudder (under 0.6 s) or the ambush after.
	world.player.position = MapView.center(Vector2i(42, 13))
	world.camera_rig.cut()
	world.player_cell = Vector2i(42, 13)
	world.player.invulnerable = true
	world.player.face(Vector2.UP)
	world.interaction.interact()


## A blow no hero survives: the fall, then waking at the inn; after the
## fight when there's one (PIX-288: felled mid-fight).
func step_die() -> void:
	if not flags.has("fight"):
		await _die()


func step_cast() -> void:
	# A foe two steps away, then the first skill: the strike, the flash, the log.
	world.player.invulnerable = true
	world.foes.spawn_enemy("orc", world.player_cell + Vector2i(2, 0), world.map.region_at(world.player_cell + Vector2i(2, 0)))
	world.player.face(Vector2.RIGHT)
	await h.get_tree().create_timer(0.2).timeout
	world.player.cast(0)
	await h.get_tree().create_timer(0.15).timeout


func step_fight() -> void:
	# `--foe <species>` picks the opponent (default orc); `hurt` lets it bite.
	var foe := flags.value("--foe", "orc")
	world.player.invulnerable = not flags.has("hurt")
	# `--foe-distance N` stands it N cells off (an elite's opener from range).
	var foe_distance := int(flags.value("--foe-distance", "2"))
	# A named monster's id (`--foe greymaw`) brings it out of its lair (PIX-156):
	# the one in its lair on this map when it's here (PIX-255: no twin
	# beside it in the shot).
	var opponent: Node = null
	var at: Vector2i = world.player_cell + Vector2i(foe_distance, 0)
	# `--foe-at x,y` (PIX-288): on that cell instead (a boss across water).
	if flags.has("--foe-at"):
		var spot := flags.list("--foe-at")
		at = Vector2i(int(spot[0]), int(spot[1]))
	if not Hunts.named(foe).is_empty():
		for mob in h.get_tree().get_nodes_in_group("mobs"):
			if not mob.dying and mob.fighter.get("named", "") == foe:
				opponent = mob
		if opponent != null:
			opponent.position = MapView.center(at)
			opponent.home = opponent.position
			opponent.reset_physics_interpolation()
		else:
			opponent = world.foes.spawn_named(foe, at)
	else:
		# The map's region where it stands (PIX-379): its loot, its shards.
		opponent = world.foes.spawn_enemy(foe, at, world.map.region_at(at), "", flags.has("elite"))
	world.player.face(Vector2.RIGHT)
	# `pack` (PIX-340): the rest of its pack round it, all on the hunt.
	var pack: Array[Node] = [opponent]
	if flags.has("pack"):
		for i in Foes.PACK_SIZE - 1:
			pack.append(world.foes.spawn_enemy(foe, at + [Vector2i.DOWN, Vector2i.UP][i % 2], world.map.region_at(at)))
		for member in pack:
			member.notice()
	# `--foe-left S` (PIX-288): the fight already on, the foe hunting the
	# hero with its bar up, then a blow down to that share of its health,
	# its ghost still easing as the swings that follow land.
	if flags.has("--foe-left"):
		opponent.notice()
		await h.get_tree().create_timer(0.3).timeout
		var left := maxi(1, roundi(int(opponent.fighter["maxHp"]) * float(flags.value("--foe-left"))))
		opponent.take_hit(maxi(0, int(opponent.fighter["hp"]) - left), opponent.global_position + Vector2.LEFT)
	# `--foe-ail poison`: afflicted, sure to take, its next tick as strong
	# as the health it has left (PIX-288: a boss an ailment finishes).
	if flags.has("--foe-ail"):
		var ailment := {"kind": flags.value("--foe-ail"), "chance": 1.0, "turns": 3, "power": int(opponent.fighter["hp"])}
		opponent.ailments.inflict(ailment, func() -> float: return 0.0)
	if flags.has("slay"):
		# Felled outright: what its death pays (a named one's bounty); a
		# blow as big as its health, so the number over it reads true.
		await h.get_tree().create_timer(0.2).timeout
		opponent.guarding = false
		opponent.take_hit(int(opponent.fighter["hp"]), opponent.global_position + Vector2.LEFT)
		await _hear_out(opponent)
	# `kill` swings until the foe (its pack) drops, KILL_SECONDS at most
	# (PIX-379); plain `fight` swings once a foe and is caught mid-swing.
	var swings := pack.size()
	var kills_before: int = world.foes.kills
	var since := GameClock.seconds()
	var i := 0
	while flags.has("kill") or i < swings:
		# A pack's: at the nearest of it still standing. A Variant, as a
		# freed foe can't be passed as a Node to be checked (PIX-372).
		var standing := pack.filter(func(member: Variant) -> bool: return is_instance_valid(member) and not member.dying)
		if flags.has("pack") and not standing.is_empty():
			var hero: Vector2 = world.player.global_position
			standing.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_to(hero) < b.global_position.distance_to(hero))
			world.player.face(standing[0].global_position - hero)
		world.player.attack()
		i += 1
		if flags.has("kill") or i < swings:
			await h.get_tree().create_timer(0.45).timeout
		# Down when it fell or stood down, not when something else did
		# (PIX-379: a bone knight beside the Bone Abbot).
		if pack.all(func(member: Variant) -> bool: return not is_instance_valid(member) or member.dying) or GameClock.seconds() - since > KILL_SECONDS:
			break
		# The wins rising while some of the pack still stand (PIX-343:
		# at each kill, not held to the fight's end).
		if world.foes.kills > kills_before and report.noted("rising") == "":
			report.note("rising", str(world.fx.rising_now()))
	if flags.has("kill"):
		await _hear_out(opponent)
	await h.get_tree().create_timer(0.4 if flags.has("kill") else 0.1).timeout
	if flags.has("die"):
		await _die()


## Every run's: a fifth of a second where a fight would be (a fight's own
## waits stand in for it).
func step_breath() -> void:
	if not flags.has("fight"):
		await h.get_tree().create_timer(0.2).timeout


func step_flee() -> void:
	# Run for the way out mid-fight (PIX-232): whatever hunts the hero
	# has seen them, then the map's first portal is taken.
	for mob in h.get_tree().get_nodes_in_group("mobs"):
		if not mob.hunting and not mob.dying:
			mob.notice()
	world.use_portal(world.map.portals.values()[0])
	await h.get_tree().create_timer(0.5).timeout


## One that stands down rather than falls (PIX-255) has its say: the run
## waits for its words, which --keys then read through. A Variant: the
## foe may be freed (PIX-372).
func _hear_out(foe: Variant) -> void:
	var waited := 0.0
	while is_instance_valid(foe) and foe.stood_down and waited < 3.0 and not world.get_children().any(func(node: Node) -> bool:
			return node.get_script() == preload("res://scripts/dialogue_box.gd")):
		await h.get_tree().create_timer(0.1).timeout
		waited += 0.1


## A blow no hero survives: the fall, then waking at the inn.
func _die() -> void:
	world.player.take_hit(99999, world.player.global_position + Vector2.LEFT)
	await h.get_tree().create_timer(1.8).timeout
