extends Feature
## areas: town field dungeon night
## The hero's hand lantern in the harness (PIX-530): `handlantern` and its
## preset, the report's handlight= and the hint at the first nightfall that
## Odo sells one, their rows beside this script and their flows in
## tools/flows.d/hand_lantern.txt. The rule is Lights.carried, the light the
## LightRig's (`_tend_lantern`), the lantern in hand the Player's.


## After `shadows`, the other light a run turns on.
func flags_after() -> String:
	return "shadows"


## `handlantern`: the Tin Lantern in the pack before the hero is made, so it
## burns from the first frame.
func before_first_map(flags: HarnessFlags) -> void:
	if flags.has("handlantern"):
		GameState.pack.add_item(Lights.HAND_LANTERN)


## The first night under the sky with none carried, once the story has
## begun (never on the Night of Ash, never in a cave): Odo sells them.
func every_second(world: World) -> void:
	if world.lights.dark > 0.5 and Lights.under_sky(world.map) and GameState.progression.prologue == Prologue.DONE and not Lights.carried(GameState.pack.items):
		world.hud.hint("lantern")


func field_handlight(report: HarnessReport) -> String:
	var lantern: PointLight2D = report.world.lights.lantern if report.world.lights != null else null
	if not is_instance_valid(lantern) or not Lights.carried(GameState.pack.items):
		return ""
	return "lantern %d %s" % [roundi(lantern.texture_scale * Lights.TEXTURE_PX / 2.0), "lit" if lantern.visible else "dark"]
