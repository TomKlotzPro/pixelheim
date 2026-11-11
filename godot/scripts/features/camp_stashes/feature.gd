extends Feature
## areas: field combat travel +overworld* +deepwood* +mirefen*
## The camps' stashes in the harness (PIX-453): their map layer
## (CampStashes), out each second as the packs fall and come back, E and
## its prompt at a shut one (opened as the core opens a chest), the
## report's stashes= and the step `stash`, their rows beside this script and
## their flows in tools/flows.d/camp_stashes.txt.


## After the core's chest.
func flags_after() -> String:
	return "chest"


func layers() -> Dictionary[String, MapLayer]:
	return {"camp_stashes": CampStashes.new()}


func every_second(world: Node) -> void:
	CampStashes.refresh(world.view, world.player_cell)


func prompt_at(world: Node, cell: Vector2i) -> Variant:
	if CampStashes.shut_at(world.view, cell).is_empty():
		return null
	return Rect2(Vector2(cell * MapView.TILE), Vector2.ONE * MapView.TILE)


func interact(world: Node, cell: Vector2i) -> bool:
	var stash := CampStashes.shut_at(world.view, cell)
	if stash.is_empty():
		return false
	world.interaction.open_chest(stash)
	return true


## `stash` (after clear): the hero beside the first stash out on the map,
## facing it, E pressed, as a player opens it.
func step_stash(h: Node) -> void:
	var world: Node = h.world
	CampStashes.refresh(world.view, world.player_cell)
	var cells: Dictionary = world.view.get_meta(CampStashes.META, {})
	for spawn_id: String in cells:
		var cell: Vector2i = cells[spawn_id]
		if CampStashes.shut_at(world.view, cell).is_empty():
			continue
		for side: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			var stand := cell + side
			if world.map.is_walkable(stand) and not world.map.covered.has(stand):
				world.player.position = MapView.center(stand)
				world.player_cell = stand
				world.camera_rig.cut()
				world.player.face(Vector2(-side))
				world.interaction.interact()
				await h.get_tree().create_timer(0.3).timeout
				return


# --- The report's fields, by name ---------------------------------------------

func field_stashes(report: HarnessReport) -> String:
	return CampStashes.describe(report.world.view)
