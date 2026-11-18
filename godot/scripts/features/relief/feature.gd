extends Feature
## areas: town field night dungeon rooms
## Light relief in the harness (PIX-528): `--relief` and the report's
## relief=, their rows beside this script and their flows in
## tools/flows.d/relief.txt. The look is the shaders'
## (shaders/relief.gdshaderinc); the plain pieces' material is Relief's.


## After `large`, as a player's setting is.
func flags_after() -> String:
	return "large"


## `--relief on|off`: Light relief forced, whatever the player's setting, so
## pictures and flows read the same on any machine (a harness run never
## writes the setting).
func before_first_map(flags: HarnessFlags) -> void:
	if flags.has("--relief"):
		GameState.settings.relief = flags.value("--relief") == "on"


func field_relief(report: HarnessReport) -> String:
	var view: MapView = report.world.view
	if view == null or view.under == null:
		return ""
	return "%s pieces %d" % ["on" if GameState.settings.relief else "off", Relief.worn(view.under) + Relief.worn(view.stand)]
