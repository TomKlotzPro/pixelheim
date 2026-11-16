extends Feature
## areas: field town rooms night
## Thunderstorms in the harness (PIX-491): `storm`, `drying` and `--strike`, the
## puddles' layer (PuddlesLayer) and the report's storm=, their rows beside
## this script and their flows in tools/flows.d/storm.txt. The rules are
## Weather's (scripts/weather.gd); the Storm node (scripts/storm.gd) plays
## them frame by frame.


## After `night`, which `storm` reads.
func flags_after() -> String:
	return "night"


## `storm`: the world's clock on the first thunderstorm at its height, by
## day, or with `night` at that night's hour (where the `night` step leaves
## the clock), before the first map is drawn: the run boots into it.
## `drying`: half an hour after that day's storm has gone, the sun back
## out, the ground half dry and the puddles shrinking.
func before_first_map(flags: HarnessFlags) -> void:
	if flags.has("storm") or flags.has("drying"):
		GameState.world.steps = Weather.next_storm(GameState.world.steps, flags.has("night"))
	if flags.has("drying"):
		while Weather.rain_at(GameState.world.steps) > 0.0:
			GameState.world.steps += 1.0
		GameState.world.steps += Weather.DRY_STEPS / 2.0


func layers() -> Dictionary[String, MapLayer]:
	return {"puddles": PuddlesLayer.new()}


## `--strike now|held|<n>`: lightning strikes close by, now; `held` holds
## its flash at its brightest for the shot; a number strikes that many
## times at once, which the cap cuts to Weather.FLASH_CAP flashes.
func step_strike(h: Harness) -> void:
	var storm: Storm = h.world.storm
	var asked := String(h.flags.value("--strike"))
	for i in maxi(1, int(asked)):
		storm.strike({"gap": 0.0, "far": 0.1, "flashes": 1, "from": -0.6})
	storm.held = asked == "held"
	# The flash is on the screen with the next frame drawn.
	await h.get_tree().process_frame
	await h.get_tree().process_frame


# --- The report's fields, by name ---------------------------------------------

func field_storm(report: HarnessReport) -> String:
	var storm: Storm = report.world.storm
	if storm == null or (storm.storm <= 0.0 and storm.wet <= 0.0 and storm.puddles <= 0.0 and storm.flashes == 0):
		return ""
	return "%srain %.1f flashes %d puddles %d wet %.1f%s%s" % ["inside " if storm.inside else "", storm.storm, storm.flashes,
		roundi(storm.puddles * 100.0), storm.wet, " soft" if storm.soft and storm.flashes > 0 else "",
		" cast" if storm.bolt.visible else ""]
