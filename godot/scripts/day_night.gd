class_name DayNight
## The day/night wheel, ported verbatim from src/render/dayNight.ts:
## one deterministic clock turned by steps walked, interpolating sky-tint
## stops. Applied as a full-screen overlay color.

const DAY_CYCLE_STEPS := 480

## [position in cycle 0..1, overlay color]
const SKY_STOPS := [
	[0.00, Color(0, 0, 0, 0.0)],  # day
	[0.45, Color(0, 0, 0, 0.0)],
	[0.55, Color(1.0, 122 / 255.0, 50 / 255.0, 0.13)],  # dusk
	[0.65, Color(10 / 255.0, 16 / 255.0, 48 / 255.0, 0.36)],  # night
	[0.85, Color(10 / 255.0, 16 / 255.0, 48 / 255.0, 0.36)],
	[0.93, Color(1.0, 190 / 255.0, 110 / 255.0, 0.1)],  # dawn
	[1.00, Color(0, 0, 0, 0.0)],
]


## Whether it's dark enough for lamps and windows (PIX-149): from dusk's end
## to dawn.
static func is_night(steps: float) -> bool:
	var t := fposmod(steps, float(DAY_CYCLE_STEPS)) / DAY_CYCLE_STEPS
	return t >= 0.58 and t < 0.92


static func sky_at(steps: float) -> Color:
	var t := fposmod(steps, float(DAY_CYCLE_STEPS)) / DAY_CYCLE_STEPS
	var i := 0
	while i < SKY_STOPS.size() - 2 and SKY_STOPS[i + 1][0] < t:
		i += 1
	var from: Array = SKY_STOPS[i]
	var to: Array = SKY_STOPS[i + 1]
	var span: float = to[0] - from[0]
	var k: float = (t - from[0]) / span if span > 0 else 0.0
	return (from[1] as Color).lerp(to[1], k)
