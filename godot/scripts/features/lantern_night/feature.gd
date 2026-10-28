extends Feature
## areas: travel field night story +overworld*
## Lantern Night in the harness (PIX-362): `--lantern` and its preset, and
## the report's lantern=, their rows beside this script and their flows in
## tools/flows.d/lantern_night.txt; the lamps' hold until Fafnyr's pass
## (LanternLayer). The rules are LanternNight's, the moment LanternPass's,
## watched each second (`every_second`) and by `--lantern fly`'s step
## (`step_lantern`).


## After the lamps' `--lit`.
func flags_after() -> String:
	return "--lit"


## `--lantern wait|fly`: the story ended ("Come home.") and the clock on
## the morning of the first Lantern Night, before the first map is drawn.
func before_first_map(flags: HarnessFlags) -> void:
	if flags.has("--lantern"):
		GameState.mark_seen("ending_home")
		GameState.world.steps = LanternNight.NIGHT * DayNight.DAY_CYCLE_STEPS


func layers() -> Dictionary[String, MapLayer]:
	return {"lantern_night": LanternLayer.new()}


## Lantern Night's festival, and Fafnyr's pass over the Reach.
func every_second(world: Node) -> void:
	LanternPass.watch(world)


## `--lantern fly`: Fafnyr's pass, as the world's next second would play it
## on Lantern Night after dark; --keys esc skips it, --wait lets it play out.
## A second of the night first, so its light has settled before the world
## holds still for him, as in play.
func step_lantern(h: Node) -> void:
	await h.get_tree().create_timer(1.0).timeout
	LanternPass.watch(h.world)
	await h.get_tree().create_timer(0.3).timeout


# --- The report's fields, by name ---------------------------------------------

func field_lantern(report: HarnessReport) -> String:
	var day := Gathering.day_of(GameState.world.steps)
	if report.world.map == null or report.world.map.id != Routes.MAP or not LanternNight.tonight(GameState.progression, GameState.settlement, day):
		return ""
	return "flown" if LanternNight.flown(GameState.settlement, day) else "waiting"
