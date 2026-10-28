extends Feature
## areas: town night
## The town's farm animals in the harness (PIX-387): their map layer
## (FarmAnimals, the herd as Herd lives it) and the report's animals=, its
## row beside this script and its flows in tools/flows.d/farm_animals.txt.


func layers() -> Dictionary[String, MapLayer]:
	return {"farm_animals": FarmAnimals.new()}


## An animal the hero stands facing steps aside (Herd.shoo, PIX-389).
func every_second(world: Node) -> void:
	var herd: Variant = _herd(world.view)
	if is_instance_valid(herd):
		herd.shoo(world.player_cell, world.player_cell + Vector2i(world.player.facing.round()))


## The town's herd, or null.
static func _herd(view: MapView) -> Variant:
	return view.get_meta("herd") if view != null and view.has_meta("herd") else null


# --- The report's fields, by name ---------------------------------------------

func field_animals(report: HarnessReport) -> String:
	var herd: Variant = _herd(report.world.view)
	return herd.describe() if is_instance_valid(herd) else ""
