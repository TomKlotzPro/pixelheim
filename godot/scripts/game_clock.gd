class_name GameClock
## The game's own clock (PIX-276): the time the world has lived, counted in
## its physics ticks, sixty a second. Every "how long since" in play reads it
## (a foe's grace on arrival, a message's time up, the place's card, a
## second press to confirm, a sound not played twice at once, a lamp's
## flicker), never the machine's clock.
##
## In play the two keep pace: Godot ticks physics as the wall clock goes.
## They part where it matters: a harness run is stepped (`--fixed-fps 60`,
## tools/flows.sh), each frame a sixtieth of a second however long the
## machine took to draw it, so a run headless on a fast core and the same
## run in a slow software-rendered window live the same seconds; read off
## the machine's clock, the place's card and a foe's grace ran out after a
## different number of steps on every run, and the flows that read them
## failed now and then under load. A frame the machine can't keep up with
## (a map loading, a tab in the background) costs the world no time either.
## Hit stop (Engine.time_scale) doesn't slow it: ticks keep their pace.
##
## Measuring the machine itself (what a frame or a load costs: PerfProbe,
## MapView.timed, the harness's `reentry`) still reads Time.

## Seconds since the engine started, a tick at a time.
static func seconds() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)


## The same in whole milliseconds.
static func msec() -> int:
	return Engine.get_physics_frames() * 1000 / Engine.physics_ticks_per_second
