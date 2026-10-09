class_name Weather
## Each region's air and the sky's weather (PIX-224). The Ash shimmers with
## heat and drifting embers, the Frostgate snows and frosts the edges of the
## view, the Mire and the marshes roll with low fog, salt spray blows off
## the Saltmere coast; and now and then a shower crosses the open land -
## drops, splashes, a darker light and its own sound. Each air has a colour
## mood too, quieter at night. Showers come from the world's own clock (the
## steps walked), so they need no saving and fall the same way every time.
## Pure: the Atmosphere node does the per-frame work.

## A region's air: region -> air. The woods have theirs too (PIX-225: the
## leaves falling, a deeper green).
const AIRS := {"ash": "ash", "frost": "frost", "mire": "mire", "marsh": "mire", "coast": "coast", "forest": "woods", "deepwood": "woods"}
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


## The air of the region `cell` lies in ("" for the open land).
static func air_at(map: MapData, cell: Vector2i) -> String:
	if map == null or not Lights.under_sky(map):
		return ""
	return AIRS.get(map.regions.get(cell, ""), "")


## How hard it rains at `steps`, 0..1: a shower on some days, coming and
## going.
static func rain_at(steps: float) -> float:
	var day := floori(steps / DayNight.DAY_CYCLE_STEPS)
	var most := 0.0
	# Yesterday's shower may run on past midnight.
	for d in [day - 1, day]:
		var shower := _shower(d)
		if shower.is_empty():
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
## village the night it burns.
static func rains_in(map: MapData, air: String) -> bool:
	if map == null or not Lights.under_sky(map) or air in ["ash", "frost", "mire"]:
		return false
	return not (map.id == "town" and GameState.progression.prologue != Prologue.DONE)


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
