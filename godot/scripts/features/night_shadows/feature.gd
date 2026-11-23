extends Feature
## areas: town field dungeon night
## The lamps' shadows in the harness (PIX-490): the layer
## that lays the occluders (NightShadowsLayer) and the report's
## nightshadows=, its row beside this script and its flows in
## tools/flows.d/night_shadows.txt. The rules are NightShadows'
## (scripts/state/night_shadows.gd); the LightRig picks the lights.


func layers() -> Dictionary[String, MapLayer]:
	return {"night_shadows": NightShadowsLayer.new()}


func field_nightshadows(report: HarnessReport) -> String:
	var world := report.world
	var laid := NightShadowsLayer.laid(world.view)
	if laid.is_empty():
		return ""
	return "lights %d of %d lamps %d feet %d walls %d" % [world.lights.casting.size(), NightShadows.LAMPS, world.lights.candidates, laid["feet"], laid["walls"]]
