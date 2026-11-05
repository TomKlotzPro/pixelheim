extends Feature
## areas: travel field night +overworld*
## The Ash Fields' burnt farmsteads in the harness (PIX-397, step 2): their
## map layer (AshRuins: charred frames, fallen fences, dead orchards,
## scorched carts, mending on healed ground) and the report's ashruins=, its
## row beside this script and its flows in tools/flows.d/ash_fields.txt.


func layers() -> Dictionary[String, MapLayer]:
	return {"ash_ruins": AshRuins.new()}


# --- The report's fields, by name ---------------------------------------------

func field_ashruins(report: HarnessReport) -> String:
	return AshRuins.describe(report.world.view)
