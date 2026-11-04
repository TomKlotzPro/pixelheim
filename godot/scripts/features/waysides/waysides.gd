class_name Waysides
extends MapLayer
## areas: travel field night +overworld*
## Wayside lanterns on the Reach's main roads (PIX-397, step 4; the v0.307
## world audit: « at night the Reach is unlit beyond the town »): a lamp at
## each fork the Post's roads part at and at the bridge's north end, where
## a traveller after dark wants to see which way to turn. The town's street
## lamp (LampArt, drawn in code, so the same without the pack), lit with the
## town's at night, a light of its own each, far enough apart to keep
## within the night's light budget (test_night_light). Not at the gate's
## corner, which the town's lamps and the farmland's (Farmland) light, and
## none where a waystation's ember lamp burns already (Routes): each stands
## at least LAMP_APART cells off every waystation's lamp, and off the cell
## under each fork's signpost (it would hide it, as the City's farmland
## lamp once did; test_waysides). Each blocks its cell, never a road nor a
## way (Hamlet.fits), and stands every day: a day's patch dealt under one
## is left out, as under the Post's pieces (MapView._plan_routes).

const MAP := "overworld"
## Each lantern by where it stands: the bridge, or a fork's id (post.json's
## forks), beside the road a cell along from the turn's inside corner (the
## road's dirt fills that corner, PIX-404: a lamp there stood in the road)
## and a cell clear of the fork's signpost.
const LANTERNS := {
	"bridge": Vector2i(50, 27),
	"saltmere_fork": Vector2i(14, 34),
	"river_fork": Vector2i(50, 21),
	"greyhold_fork": Vector2i(52, 16),
	"mountain_fork": Vector2i(46, 12),
}
## How far (cells, either way) a lantern keeps from a waystation's lamp.
const LAMP_APART := 6


## The lanterns that stand on `map`, by where: {where: cell}, each fitting
## open ground (Hamlet.fits) with `kept` left clear.
static func plan_on(map: MapData, kept: Dictionary) -> Dictionary:
	var out := {}
	if map.id != MAP:
		return out
	var blocks: Array[Vector2i] = []
	for where: String in LANTERNS:
		var cell: Vector2i = LANTERNS[where]
		var cells: Array[Vector2i] = [cell]
		if Hamlet.fits(map, cells, kept, blocks):
			out[where] = cell
			blocks.append(cell)
	return out


# --- The layer ------------------------------------------------------------------

func plan(view: MapView, slices: Slicer) -> void:
	if view.data.id != MAP:
		return
	slices.add("plan_waysides", func() -> void:
		var kept := Hamlet.kept_on(view.data, {})
		kept[view.arrival] = true
		var lanterns := plan_on(view.data, kept)
		for cell: Vector2i in lanterns.values():
			view.data.covered[cell] = true
			view.bare[cell] = true
			view.patches.erase(cell)
		view.set_meta("waysides", lanterns))


func build(view: MapView, slices: Slicer) -> void:
	if not view.has_meta("waysides"):
		return
	slices.add("decor_waysides", func() -> void:
		var first := view.lamps.size()
		for cell: Vector2i in view.get_meta("waysides").values():
			PropsLayer.add_puny_prop(view, PunyProps.plan({cell: "lamp"})["props"][0])
		# Lit and put out with the town's (PropsLayer); kept to report.
		view.set_meta("wayside_lamps", view.lamps.slice(first)))


## What the harness reports (waysides=): where each lantern stands, and how
## many burn: bridge,greyhold_fork,mountain_fork,river_fork,saltmere_fork lit 5.
static func describe(view: MapView) -> String:
	if view == null or not view.has_meta("waysides"):
		return ""
	var names: Array = view.get_meta("waysides").keys()
	names.sort()
	var lit: int = view.get_meta("wayside_lamps", []).filter(func(lamp: Dictionary) -> bool:
		return is_instance_valid(lamp["flame"]) and lamp["flame"].visible).size()
	return "%s lit %d" % [",".join(names), lit]
