extends Feature
## areas: travel field night +overworld*
## The Reach's wayside lanterns in the harness (PIX-397, step 4): their map
## layer (Waysides: a lamp at each fork of the Post's roads and at the
## bridge, lit at night) and the report's waysides=, its row beside this
## script and its flows in tools/flows.d/waysides.txt.


func layers() -> Dictionary[String, MapLayer]:
	return {"waysides": Waysides.new()}


# --- The report's fields, by name ---------------------------------------------

func field_waysides(report: HarnessReport) -> String:
	return Waysides.describe(report.world.view)
