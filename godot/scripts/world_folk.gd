class_name Folk
extends Node
## The villagers (Solid Ground, PIX-260: moved out of world.gd as it was):
## who stands on a map, drawn again when a recruit settles or the town
## grows; who stands beside the hero; and the village's hours (PIX-149).
## They stand on the world's y-sorted actors layer, in the "npcs" group.

var world: Node


## Villagers who live on this map now: tier-gated townsfolk and recruits.
func spawn_for(data: MapData) -> void:
	var settlers := GameState.settlement.settlers
	var folk := Npcs.on_map(data.id, GameState.settlement.town_tier, settlers, Town.done_projects(GameState.settlement), Relics.gate_open(GameState.progression), GameState.progression.deepest, Letters.tin_waits(GameState.progression))
	# On the night of the fire only the survivors are about (PIX-152).
	if GameState.progression.prologue != Prologue.DONE and data.id == "town":
		folk = Prologue.survivors()
	# On the Night of Bells everyone is out at their job (PIX-253 step 9).
	var bells: bool = GameState.progression.bells != Bells.NONE and data.id == "town"
	if bells:
		folk = Bells.folk(settlers, GameState.settlement.town_tier)
	# A festival day's barker runs the ring toss on the square (PIX-159).
	if data.id == "town" and GameState.holdings.festival_on() and GameState.progression.prologue == Prologue.DONE and not bells:
		var barker: Dictionary = Npcs._data()["festivalBarker"].duplicate()
		barker.merge({"x": int(Town.festival("barker")["x"]), "y": int(Town.festival("barker")["y"])})
		folk.append(barker)
	for npc: Dictionary in folk:
		var villager := preload("res://scripts/npc.gd").new()
		villager.world = world
		villager.data = npc
		villager.add_to_group("decor")
		villager.add_to_group("npcs")
		world.actors.add_child(villager)


## The folk of a map walked into over a line (One Reach, PIX-269): where
## the hour puts them, each in sight `coming` into it (fading in) - two
## frames on, as making them is a few milliseconds the crossing's own frame
## can do without.
var _coming := 0
var _come: Callable


func come_in(coming: Callable) -> void:
	_come = coming
	_coming = 2


func _process(_delta: float) -> void:
	if _coming <= 0:
		return
	_coming -= 1
	if _coming > 0 or world.map == null:
		return
	spawn_for(world.map)
	keep_hours(true)
	for villager: Node in get_tree().get_nodes_in_group("npcs"):
		_come.call(villager)


## A recruit settled or the town grew: redraw who stands on this map.
func respawn() -> void:
	for villager in get_tree().get_nodes_in_group("npcs"):
		villager.queue_free()
	spawn_for(world.map)


## The villager beside the hero, faced side first: {npc, side} or {}.
func beside() -> Dictionary:
	var occupied := {}
	for villager in get_tree().get_nodes_in_group("npcs"):
		if not villager.away:
			occupied[villager.cell] = villager.data
	return Npcs.beside(occupied, world.player_cell, Vector2i(world.player.facing))


## The village's hours (PIX-149): lamps and windows lit at night, and the
## folk who wander - villagers, builders, children, the cat and the dog - go
## home after dark and come back in the morning, never vanishing in view.
## On arriving, everyone is simply where the hour puts them.
func keep_hours(arriving := false) -> void:
	var night := DayNight.is_night(GameState.world.steps)
	world.view.set_night(night)
	var map: MapData = world.map
	var rig: CameraRig = world.camera_rig
	var tile: float = world.TILE
	# At dusk, and all day on a festival, the town's folk walk to the square
	# (PIX-159); each takes a spot of its own.
	var gathering: bool = map.id == "town" and not night and GameState.progression.prologue == Prologue.DONE \
		and (DayNight.is_dusk(GameState.world.steps) or GameState.holdings.festival_on())
	var spots := Town.gathering_spots(map) if gathering else ([] as Array[Vector2i])
	var taken := {}
	for villager in get_tree().get_nodes_in_group("npcs"):
		if villager.is_queued_for_deletion():
			continue
		var id := String(villager.data["id"])
		if not villager.data.get("wander", false) and not id.begins_with("worker_"):
			continue
		var home_seen := rig.in_view(MapView.center(villager.home), tile)
		if villager.away != night and (arriving or (not rig.in_view(villager.position, tile) and (night or not home_seen))):
			villager.set_away(night)
		if villager.away or id.begins_with("worker_") or not villager.data.get("wander", false):
			continue
		if gathering and villager.gather_at == villager.NOWHERE and taken.size() < spots.size():
			var index := Npcs.id_hash(id) % spots.size()
			while taken.has(index):
				index = (index + 1) % spots.size()
			taken[index] = true
			villager.gather_at = spots[index]
			if arriving or (not rig.in_view(villager.position, tile) and not rig.in_view(MapView.center(spots[index]), tile)):
				villager.place_at(spots[index])
		elif gathering and villager.gather_at != villager.NOWHERE:
			taken[spots.find(villager.gather_at)] = true
		elif not gathering and villager.gather_at != villager.NOWHERE and not rig.in_view(villager.position, tile) and not home_seen:
			# The gathering's over by day (a night skipped at the inn): home.
			villager.set_away(false)
