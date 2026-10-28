extends Feature
## areas: town night
## The town's farm animals in the harness (PIX-387): their map layer
## (FarmAnimals, the herd as Herd lives it) and the report's animals=, its
## row beside this script and its flows in tools/flows.d/farm_animals.txt.


func layers() -> Dictionary[String, MapLayer]:
	return {"farm_animals": FarmAnimals.new()}


# --- The report's fields, by name ---------------------------------------------

func field_animals(report: HarnessReport) -> String:
	var view: MapView = report.world.view
	var herd: Variant = view.get_meta("herd") if view != null and view.has_meta("herd") else null
	return herd.describe() if is_instance_valid(herd) else ""
