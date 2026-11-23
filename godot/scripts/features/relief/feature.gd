extends Feature
## areas: town field night dungeon rooms
## Light relief in the harness (PIX-528): `--relief` and the report's
## relief=, and the lights' rim's `--rim` and rim= (PIX-531), their rows
## beside this script and their flows in tools/flows.d/relief.txt. The look
## is the shaders' (shaders/relief.gdshaderinc); the plain pieces' material
## is Relief's.


## After `large`, as a player's setting is.
func flags_after() -> String:
	return "large"


## `--relief on|off`: Light relief forced, whatever the player's setting, so
## pictures and flows read the same on any machine (a harness run never
## writes the setting).
func before_first_map(flags: HarnessFlags) -> void:
	if flags.has("--relief"):
		GameState.settings.relief = flags.value("--relief") == "on"
	# `--rim off` (PIX-531): the lights' rim held back, for a picture to set
	# beside one with it; a static, so put back for the next flow in a batch.
	LightRig.rim_on = flags.value("--rim") != "off"


func field_relief(report: HarnessReport) -> String:
	var view: MapView = report.world.view
	if view == null or view.under == null:
		return ""
	return "%s pieces %d" % ["on" if GameState.settings.relief else "off", Relief.worn(view.under) + Relief.worn(view.stand)]


func field_rim(report: HarnessReport) -> String:
	if report.world.lights == null:
		return ""
	return "%s %.2f" % ["on" if LightRig.rim_on else "off", LightRig.rim_strength(report.world.lights.dark)]
