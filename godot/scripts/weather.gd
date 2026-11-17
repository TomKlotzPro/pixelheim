class_name Weather
## areas: field
## Each region's air and the sky's weather (PIX-224). The Ash shimmers with
## heat and drifting embers, the Frostgate snows and frosts the edges of the
## view, the Mire and the marshes roll with low fog, salt spray blows off
## the Saltmere coast; and now and then a shower crosses the open land -
## drops, splashes, a darker light and its own sound. Each air has a colour
## mood too, quieter at night. Showers come from the world's own clock (the
## steps walked), so they need no saving and fall the same way every time.
## Some showers are thunderstorms (PIX-491): heavier rain, a darker sky, a
## harder wind, lightning and the thunder after it; and any rain leaves the
## ground wet and its puddles full, drying after, all read off the same
## clock. Pure: the Atmosphere and Storm nodes do the per-frame work.

## A region's air: region -> air. The woods have theirs too (PIX-225: the
## leaves falling, a deeper green).
## Blackiron's mines and the mountain road breathe the Ash's air too, its
## embers and its ash drifting (PIX-308).
const AIRS := {
	"ash": "ash", "mines": "ash", "road": "ash", "frost": "frost", "mire": "mire", "marsh": "mire", "coast": "coast",
	"forest": "woods", "deepwood": "woods",
}
## Every air; the first four are the ones the air's pass draws.
const KINDS := ["ash", "frost", "mire", "coast", "woods"]
const DRAWN := ["ash", "frost", "mire", "coast"]
## Each air's colour mood: a tint, its saturation and its contrast. The open
## land keeps Shade's colours.
const MOODS := {
	"": [Color(1, 1, 1), 1.0, 1.0],
	"ash": [Color(1.0, 0.93, 0.86), 0.86, 1.05],
	"frost": [Color(0.93, 0.97, 1.0), 0.9, 1.02],
	"mire": [Color(0.94, 1.0, 0.93), 0.8, 0.96],
	"coast": [Color(0.98, 1.0, 1.0), 1.06, 1.02],
	"woods": [Color(0.96, 1.0, 0.95), 1.04, 1.03],
}
## The airs no rain falls through: the Ash's heat, the Frostgate's snow,
## the Mire's fog.
const DRY_AIRS := ["ash", "frost", "mire"]
## The night takes some colour from everything.
const NIGHT_SATURATION := 0.82
## How many days in a hundred bring a shower; how long one lasts and how
## long it takes to come and go, as shares of the day so they keep its pace
## (PIX-246: a twelfth to three sixteenths of it, a forty-eighth to build).
const RAIN_CHANCE := 40
const SHOWER_MIN := DayNight.DAY_CYCLE_STEPS / 12.0
const SHOWER_MAX := DayNight.DAY_CYCLE_STEPS * 3.0 / 16.0
const SHOWER_RAMP := DayNight.DAY_CYCLE_STEPS / 48.0
## Rain darkens and cools the light.
const RAIN_LIGHT := Color(0.72, 0.76, 0.85)
## How many showers in a hundred are thunderstorms (PIX-491): never a day
## more of rain than before, a storm is one of the showers there were.
const STORM_CHANCE := 35
## A storm's clouds darken the rain's light this much again, and its wind
## blows this much harder (the trees' lean, the grass's ripples).
const STORM_LIGHT := Color(0.72, 0.76, 0.86)
const STORM_WIND := 0.9
## The ground is wet as soon as it rains and dries over an hour of the
## day once the rain has gone; the puddles fill over the first part of a
## shower (fuller under a storm) and take half as long again to dry.
const DRY_STEPS := DayNight.DAY_CYCLE_STEPS / 24.0
const PUDDLE_FILL := DayNight.DAY_CYCLE_STEPS / 24.0
const PUDDLE_DRY := DayNight.DAY_CYCLE_STEPS / 16.0
const SHOWER_PUDDLES := 0.6
## Lightning: the seconds between two strikes, and never more than
## FLASH_CAP flashes in any FLASH_WINDOW seconds, whatever asks (safety:
## a strike's flicker counts, a strike the harness forces too).
const STRIKE_GAP := Vector2(5.0, 16.0)
const FLASH_CAP := 3
const FLASH_WINDOW := 5.0
## A flash: full for its first frames, gone after FLASH_S; a strike that
## flickers flashes again FLICKER_S on. The soft one (Flashes off, or
## Reduce motion) swells and fades over SOFT_S, to SOFT_LIGHT at most.
const FLASH_HOLD := 0.05
const FLASH_S := 0.32
const FLICKER_S := 0.14
const SOFT_S := 1.8
const SOFT_LIGHT := 0.3
## Thunder: a strike nearer than THUNDER_NEAR cracks, a farther one
## rumbles; the farthest is heard this many seconds after its flash.
const THUNDER_NEAR := 0.35
const THUNDER_FAR_S := 4.5


## The air at `cell`: its region's ("" for the open land), read cell by
## cell, for inside a lit lamp's ring the Ash's heat and embers fade over
## the healed ground (PIX-323, Lamps), and a grave-moss lamp's thins the
## Mirefen's fog (PIX-324, Lamps.clears).
static func air_at(map: MapData, cell: Vector2i) -> String:
	if map == null or not Lights.under_sky(map):
		return ""
	var air: String = AIRS.get(map.regions.get(cell, ""), "")
	if air != "" and Lamps.clears(air, cell, Lamps.now(map.id)):
		return ""
	return air


## How hard it rains at `steps`, 0..1: a shower on some days, coming and
## going.
static func rain_at(steps: float) -> float:
	return _falling(steps, false)


## How hard a thunderstorm blows at `steps`, 0..1 (PIX-491): the rain of a
## shower that is one, nothing under any other.
static func storm_at(steps: float) -> float:
	return _falling(steps, true)


static func _falling(steps: float, storms_only: bool) -> float:
	var day := floori(steps / DayNight.DAY_CYCLE_STEPS)
	var most := 0.0
	# Yesterday's shower may run on past midnight.
	for d: int in [day - 1, day]:
		var shower := _shower(d)
		if shower.is_empty() or (storms_only and not storms(d)):
			continue
		var into: float = steps - shower[0]
		var length: float = shower[1]
		if into > 0.0 and into < length:
			most = maxf(most, minf(1.0, minf(into, length - into) / SHOWER_RAMP))
	return most


## Day `day`'s shower: [the step it starts, how long it lasts], or [].
static func _shower(day: int) -> Array:
	var h := absi(hash(day * 7919 + 104729))
	if h % 100 >= RAIN_CHANCE:
		return []
	var start := (day + (h >> 7) % 1000 / 1000.0) * DayNight.DAY_CYCLE_STEPS
	return [start, lerpf(SHOWER_MIN, SHOWER_MAX, (h >> 17) % 1000 / 1000.0)]


## Whether day `day`'s shower is a thunderstorm (PIX-491): on its own
## throw of the day's dice, so the showers fall when they always did.
static func storms(day: int) -> bool:
	return not _shower(day).is_empty() and absi(hash(day * 6151 + 31337)) % 100 < STORM_CHANCE


## Where the harness stands to see a thunderstorm at its height, from
## `steps` on: the heart of the first one that pours in full day, or with
## `night` the first night whose hour (the harness's `night`: NIGHT_HOUR
## of its day) lies in one, its puddles full.
static func next_storm(steps: float, night: bool) -> float:
	var day := floori(steps / DayNight.DAY_CYCLE_STEPS)
	for d in range(day, day + 4000):
		if night:
			var at := (d + NIGHT_HOUR) * DayNight.DAY_CYCLE_STEPS
			if at >= steps and storm_at(at) >= 1.0 and puddles_at(at) >= 1.0:
				return at
			continue
		var shower := _shower(d)
		if shower.is_empty() or not storms(d):
			continue
		var heart := float(shower[0]) + float(shower[1]) / 2.0
		var hour := fposmod(heart, float(DayNight.DAY_CYCLE_STEPS)) / DayNight.DAY_CYCLE_STEPS
		if heart >= steps and hour > 0.08 and hour < 0.42:
			return heart
	return steps


## The hour the harness's `night` stands at, as a share of its day.
const NIGHT_HOUR := 0.7


## How wet the ground is at `steps`, 0..1 (PIX-491): wet as the rain comes
## on, and dry DRY_STEPS (an hour of the day) after the shower has gone.
static func wet_at(steps: float) -> float:
	return _left(steps, SHOWER_RAMP, DRY_STEPS, false)


## How full the puddles are at `steps`, 0..1 (PIX-491): gathering through
## a shower's first part, fuller under a storm, then drying slowly.
static func puddles_at(steps: float) -> float:
	return _left(steps, PUDDLE_FILL, PUDDLE_DRY, true)


## What the rain has left at `steps`: rising over `fill` steps of a shower,
## falling to nothing over `dry` steps once it ends; `by_kind` leaves less
## after a shower than after a storm.
static func _left(steps: float, fill: float, dry: float, by_kind: bool) -> float:
	var day := floori(steps / DayNight.DAY_CYCLE_STEPS)
	var most := 0.0
	for d: int in [day - 1, day]:
		var shower := _shower(d)
		if shower.is_empty():
			continue
		var into: float = steps - shower[0]
		var length: float = shower[1]
		if into <= 0.0 or into >= length + dry:
			continue
		var full := SHOWER_PUDDLES if by_kind and not storms(d) else 1.0
		var risen := full * minf(1.0, minf(into, length) / fill)
		most = maxf(most, risen * (1.0 - maxf(0.0, into - length) / dry))
	return most


## The storm's `n`th strike (PIX-491), on its own throw: {"gap": the
## seconds after the one before, "far": 0 overhead to 1 at the horizon,
## "flashes": 1, or 2 when it flickers, "from": the way its light falls,
## in radians off straight down the screen}. The same list every storm.
static func strike(n: int) -> Dictionary:
	var h := absi(hash(n * 9973 + 7717))
	return {
		"gap": lerpf(STRIKE_GAP.x, STRIKE_GAP.y, (h % 1000) / 1000.0),
		"far": ((h >> 10) % 1000) / 1000.0,
		"flashes": 2 if (h >> 20) % 5 < 2 else 1,
		"from": lerpf(-1.1, 1.1, ((h >> 23) % 100) / 100.0),
	}


## Whether one more flash may be shown at `now`, `shown` being the seconds
## the last ones began at: never more than FLASH_CAP in any FLASH_WINDOW.
static func may_flash(shown: Array, now: float) -> bool:
	return shown.filter(func(at: float) -> bool: return now - at < FLASH_WINDOW).size() < FLASH_CAP


## How bright a flash is `t` seconds after it began, 0..1: white for its
## first frames, then falling fast; `soft`, a slow swell to SOFT_LIGHT and
## back, never a strobe.
static func flash_light(t: float, soft: bool) -> float:
	if t < 0.0:
		return 0.0
	if soft:
		return SOFT_LIGHT * sin(PI * t / SOFT_S) if t < SOFT_S else 0.0
	if t < FLASH_HOLD:
		return 1.0
	var left := 1.0 - (t - FLASH_HOLD) / (FLASH_S - FLASH_HOLD)
	return left * left if left > 0.0 else 0.0


## How long after its flash a strike `far` off is heard, in seconds.
static func thunder_delay(far: float) -> float:
	return clampf(far, 0.0, 1.0) * THUNDER_FAR_S


## The middle of the first shower from `steps` on (where to stand to see it).
static func next_shower(steps: float) -> float:
	var day := floori(steps / DayNight.DAY_CYCLE_STEPS)
	for d in range(day, day + 60):
		var shower := _shower(d)
		if not shower.is_empty() and float(shower[0]) + float(shower[1]) / 2.0 >= steps:
			return float(shower[0]) + float(shower[1]) / 2.0
	return steps


## Whether rain falls on `map` where the air is `air`: under the sky, but
## not on the Ash's heat, the Frostgate's snow or the Mire's fog, nor on the
## village the night it burns or the night it holds (PIX-253 step 9).
static func rains_in(map: MapData, air: String) -> bool:
	if map == null or not Lights.under_sky(map) or air in DRY_AIRS:
		return false
	return map.id != "town" or village_rains()


## Whether it may rain on the village: not the night it burns, nor the
## night it holds (PIX-253 step 9); its houses' roofs hear it (PIX-414).
static func village_rains() -> bool:
	return GameState.progression.prologue == Prologue.DONE and GameState.progression.bells == Bells.NONE


## Whether `map` is a village house whose roof hears the village's weather
## (PIX-414): its rain, and a storm's thunder and flashes at its windows
## (PIX-491).
static func under_roof(map: MapData) -> bool:
	return map != null and map.id.begins_with("town_") and village_rains()


## The colour mood of `weights` (air -> 0..1) at darkness `dark`: [tint,
## saturation, contrast].
static func mood(weights: Dictionary, dark: float) -> Array:
	var tint := Color(1, 1, 1)
	var saturation := 1.0
	var contrast := 1.0
	for air: String in weights:
		var w: float = weights[air]
		var of: Array = MOODS.get(air, MOODS[""])
		tint = tint.lerp(tint * (of[0] as Color), w)
		saturation = lerpf(saturation, saturation * float(of[1]), w)
		contrast = lerpf(contrast, contrast * float(of[2]), w)
	saturation *= lerpf(1.0, NIGHT_SATURATION, dark)
	return [tint, saturation, contrast]
