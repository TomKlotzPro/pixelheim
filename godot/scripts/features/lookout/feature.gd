extends Feature
## areas: travel night screen +mountain_road*
## The lookout on the mountain road in the harness (PIX-363): its spyglass
## (Lookout, a map layer) and the report's lookout=, its row beside this
## script and its flows in tools/flows.d/lookout.txt. E at it is
## world_interaction.gd's (a feature has no hook for E or the prompt yet);
## the view is LookoutScreen.


func layers() -> Dictionary[String, MapLayer]:
	return {"lookout": Lookout.new()}


# --- The report's fields, by name ---------------------------------------------

func field_lookout(report: HarnessReport) -> String:
	for node in report.world.get_children():
		if node is LookoutScreen:
			var panorama: LookoutScreen.Panorama = node.panorama
			var shown := PackedStringArray()
			for lamp: Dictionary in panorama.lamps:
				shown.append("%s:%s" % [lamp["place"], lamp["kind"]])
			shown.sort()
			return "%s/%d" % [",".join(shown) if not shown.is_empty() else "dark", panorama.healed.size()]
	return ""
