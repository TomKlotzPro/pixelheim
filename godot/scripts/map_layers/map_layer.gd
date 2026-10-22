class_name MapLayer
extends RefCounted
## areas: town rooms travel +town-age*
## One kind of what MapView draws, in a script of its own (PIX-359): its
## units in the plan and in the drawing, by the kinds `planning` and
## `building` always gave them (Slicer), and how it changes with the hour.
## A layer keeps nothing itself: what it plans and draws goes on the view
## (`view`), which the world and the harness read. MapView keeps the order
## the units run in, the roots (`under`, `actors`), what the art covers
## (`data.covered`) and what each part took (`took`).

const TILE := MapView.TILE


## Adds this layer's units to the plan (MapView.planning, where its kind
## stands in the order).
func plan(_view: MapView, _slices: Slicer) -> void:
	pass


## Adds this layer's units to the drawing (MapView.building, where its kind
## stands in the order).
func build(_view: MapView, _slices: Slicer) -> void:
	pass


## Lit from dusk's end to dawn, cold by day (MapView.set_night).
func set_night(_view: MapView, _night: bool) -> void:
	pass
