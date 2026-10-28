extends Feature
## areas: travel night screen +mountain_road*
## The lookout on the mountain road in the harness (PIX-363): its spyglass
## (Lookout, a map layer) and the report's lookout=, its row beside this
## script and its flows in tools/flows.d/lookout.txt; E at it and its
## prompt (`interact`, `prompt_at`); the view is LookoutScreen.


func layers() -> Dictionary[String, MapLayer]:
	return {"lookout": Lookout.new()}


## The prompt over the spyglass, as tall as it's drawn.
func prompt_at(world: Node, cell: Vector2i) -> Variant:
	if not Lookout.at(world.map.id, cell):
		return null
	return Rect2(Vector2(cell * MapView.TILE), Vector2.ONE * MapView.TILE).grow_side(SIDE_TOP, Lookout.PIECE.size() - MapView.TILE)


func interact(world: Node, cell: Vector2i) -> bool:
	return Lookout.use(world, cell)


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
