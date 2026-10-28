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
## feature's own `field_<name>(report)`, a step its flags name its own
## `step_<name>(h)`, given the harness (harness.gd). Its clock, its prompt
## and E are hooks the core calls for every feature in their order
## (`every_second`, `prompt_at`, `interact`; PIX-369): Lantern Night and the
## lookout each took a direct call in a shared file before.

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


## Each second of play, after the core's own once-a-second work (world.gd's
## watch).
func every_second(_world: Node) -> void:
	pass


## The pixels what E meets facing `cell` is drawn in, for the prompt to
## stand over, or null when it's none of this feature's
## (Interaction._prompt_target, after the core's own).
func prompt_at(_world: Node, _cell: Vector2i) -> Variant:
	return null


## E facing `cell`: true when this feature took it (Interaction.interact,
## after the core's own things on a cell, before the folk beside the hero:
## the lookout's spyglass took E over a villager standing by).
func interact(_world: Node, _cell: Vector2i) -> bool:
	return false
