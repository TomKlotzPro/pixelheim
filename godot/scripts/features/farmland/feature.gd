extends Feature
## areas: travel field night +overworld*
## The farmland round the town on the Reach in the harness (PIX-397): the
## report's farmland=, its row beside this script and its flows in
## tools/flows.d/farmland.txt. The plan is Farmland's, laid by MapView with
## the settlements' dressing (Hamlet.plan's `grown`) and drawn by its layer;
## the pastures' animals are FarmAnimals'.


# --- The report's fields, by name ---------------------------------------------

func field_farmland(report: HarnessReport) -> String:
	var world := report.world
	if world.map == null or world.map.id != Farmland.MAP or world.view == null:
		return ""
	var pieces: Array = world.view.hamlet["pieces"]
	return "" if pieces.is_empty() else Farmland.describe(pieces)
