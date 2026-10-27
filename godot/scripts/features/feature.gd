class_name Feature
extends RefCounted
## areas: all
## A feature that plugs itself in from a folder of its own (PIX-361): its
## harness flags, presets, report fields, look book shots and map layers,
## beside the core's. A feature used to add a row to each shared registry
## (the flags, the report fields, the shots, the flows), its preset to
## HarnessBoot and its layer to MapView: seven shared files. Now
## `scripts/features/<name>/` holds its `feature.gd`, extending this, and
## the rows it needs in the core's own formats beside it: harness_flags.txt,
## harness_report.txt, lookbook_shots.jsonl; its flows are
## tools/flows.d/<name>.txt. Features.all() finds every feature, and
## HarnessFlags, HarnessReport, Lookbook, MapView and HarnessBoot take the
## core's rows, then every feature's. A report field's function is the
## feature's own `field_<name>(report)`.

## Its folder, where its rows lie (Features.all sets it).
var folder := ""


## The flag its flags follow in the harness's table, so `--help` reads in a
## run's order; "" puts them at the end.
func flags_after() -> String:
	return ""


## Its presets, set before the first map is drawn, after the core's
## (HarnessBoot.before_first_map).
func before_first_map(_flags: HarnessFlags) -> void:
	pass


## Its map layers by name (MapLayer): MapView plans and draws their units
## after the core's, and sets them for the hour with the rest.
func layers() -> Dictionary[String, MapLayer]:
	return {}
