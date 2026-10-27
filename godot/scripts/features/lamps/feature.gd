extends Feature
## areas: travel field night +overworld*
## The lamps in the harness (PIX-323, PIX-324; PIX-361's first feature):
## `--lit` and its preset, and the report's air=, finds=, healed=, lamps= and
## visitors=, their rows beside this script and their flows in
## tools/flows.d/lamps.txt. The rules are Lamps' (scripts/state/lamps.gd).
## No map layer of its own: MapView plans the healed ground with the rest of
## the ground and RouteArt draws the lamps with their waystations. No look
## book shot either: the waystation's (the routes') shows its lamp.


## After `brew`, where `--lit` always stood in `--help`.
func flags_after() -> String:
	return "brew"


## `--lit blackiron:3` (PIX-323): that waystation's ember lamp lit three
## mornings ago (built with `--built`), its ring of healed land as far.
func before_first_map(flags: HarnessFlags) -> void:
	for spec: String in flags.list("--lit"):
		var lit := spec.split(":")
		GameState.post.lit[lit[0]] = Gathering.day_of(GameState.world.steps) - int(lit[1])


# --- The report's fields, by name ---------------------------------------------

func field_air(report: HarnessReport) -> String:
	var world := report.world
	if world.map == null or Lamps.now(world.map.id).is_empty():
		return ""
	var air: String = world.atmosphere.air
	return air if air != "" else "open"


func field_finds(report: HarnessReport) -> String:
	var world := report.world
	if world.view == null:
		return ""
	var out: PackedStringArray = []
	for cell: Vector2i in world.view.patches:
		var patch: Dictionary = world.view.patches[cell]
		if String(patch["id"]).begins_with("lamp_find_") and Gathering.is_ready(GameState.world, patch["id"]):
			out.append("%s:%s" % [String(patch["id"]).trim_prefix("lamp_find_"), patch["item"]])
	out.sort()
	return ",".join(out)


func field_healed(report: HarnessReport) -> String:
	var world := report.world
	if world.view == null or world.view.healed.is_empty():
		return ""
	var parts: PackedStringArray = []
	for stage in range(Lamps.EARTH, Lamps.SAPLINGS + 1):
		var look: String = Lamps.LOOKS[stage]
		var count: int = world.view.healed.values().count(look)
		parts.append("%s%d" % [look, count])
	return ",".join(parts)


func field_lamps(report: HarnessReport) -> String:
	var world := report.world
	if world.map == null or world.view == null:
		return ""
	var out: PackedStringArray = []
	for ring: Dictionary in Lamps.now(world.map.id):
		var ember: Variant = world.view.ember_lamps.get(ring["place"])
		var lit: bool = ember != null and is_instance_valid(ember) and (ember as Node2D).visible
		out.append("%s:%s:%d:%s" % [ring["place"], ring["kind"], ring["reach"], "lit" if lit else "cold"])
	return ",".join(out)


func field_visitors(report: HarnessReport) -> String:
	var names: PackedStringArray = []
	for npc: Node in report.world.get_tree().get_nodes_in_group("npcs"):
		if String(npc.data.get("id", "")).begins_with("lamp_visitor_"):
			names.append(String(npc.data["name"]))
	names.sort()
	return ",".join(names)
