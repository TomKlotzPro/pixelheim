extends Feature
## areas: field night +mirefen*
## The Mirefen alive in the harness (PIX-401): its map layer (MireDressing:
## dead trees, reed beds, boardwalks, stilt huts, wisps at night) and the
## report's mire=, its row beside this script and its flows in
## tools/flows.d/mirefen.txt.


func layers() -> Dictionary[String, MapLayer]:
	return {"mire": MireDressing.new()}


# --- The report's fields, by name ---------------------------------------------

func field_mire(report: HarnessReport) -> String:
	return MireDressing.describe(report.world.view)
