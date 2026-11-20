class_name DayNight
## areas: field night
## The day/night wheel: one deterministic clock turned by steps walked, its
## hours, when night falls and where the sun stands. The light by the hour
## is Lights.DAY_LIGHT's.

## A step walked is a minute: a day is 1440 steps (PIX-246; it was 480, two
## minutes of walking, and a day went by too fast). Time stands still while
## the hero does.
const DAY_CYCLE_STEPS := 1440
## The cycle starts in the morning: its first step is six o'clock.
const MORNING_MINUTE := 360

## The sun over the open air (PIX-449): up from the night's end (0.92 of the
## cycle, about five) to its start (0.58, about eight in the evening), so
## the scenery's shadows go as the lamps come on; highest halfway, at noon.
const SUNRISE := -0.08
const SUNSET := 0.58
## Every shadow falls this way, east and a little south, all day: Shade
## lights his art from the upper left, and the ruins' and walls' shadows
## fall south and east (RuinArt).
const SHADOW_WAY := Vector2(0.94, 0.34)
## How far a shadow reaches for each pixel of what casts it, with the sun at
## its height, and at most with the sun low.
const SHADOW_NOON := 0.35
const SHADOW_LONGEST := 1.5
## A shadow's strength is the sun's height to this power: full at noon,
## fainter as the sun goes down.
const SHADOW_FADE := 0.6


## Whether it's dark enough for lamps and windows (PIX-149): from dusk's end
## to dawn.
static func is_night(steps: float) -> bool:
	var t := fposmod(steps, float(DAY_CYCLE_STEPS)) / DAY_CYCLE_STEPS
	return t >= 0.58 and t < 0.92


## The evening before it (PIX-159): the hour the town gathers on the square.
static func is_dusk(steps: float) -> bool:
	var t := fposmod(steps, float(DAY_CYCLE_STEPS)) / DAY_CYCLE_STEPS
	return t >= 0.47 and t < 0.58


## The evening's windows (PIX-526): each lights at its own minute between
## these shares of the day (18:15 to 19:45), one by one before the street
## lamps, which light with the night (is_night, 19:55).
const WINDOWS_FIRST := 12.25 / 24.0
const WINDOWS_LAST := 13.75 / 24.0


## Whether the window on `cell` is lit already in the evening before the
## night (PIX-526): through the dusk from its own minute on, each window at
## its own; never by day, and the night's own lighting is is_night's.
static func lit_before_night(steps: float, cell: Vector2i) -> bool:
	if not is_dusk(steps):
		return false
	var t := fposmod(steps, float(DAY_CYCLE_STEPS)) / DAY_CYCLE_STEPS
	return t >= lerpf(WINDOWS_FIRST, WINDOWS_LAST, float(absi(hash(cell)) % 1000) / 1000.0)


## The clock's hour and minute at `steps` (PIX-246): the cycle's start is
## six in the morning, dusk about seven in the evening, dawn about five.
static func clock(steps: float) -> Vector2i:
	var minute := (floori(fposmod(steps, float(DAY_CYCLE_STEPS)) * 1440.0 / DAY_CYCLE_STEPS) + MORNING_MINUTE) % 1440
	return Vector2i(minute / 60, minute % 60)


## The minute of the day at `steps`, 0 at midnight (PIX-252): what the
## clock reads, as one number.
static func minute_of(steps: float) -> int:
	var time := clock(steps)
	return time.x * 60 + time.y


## Whether the clock's `minute` of the day falls in the night (is_night),
## read back to the steps that show it: a step is a minute, and the
## cycle's first step is six in the morning.
static func night_at(minute: int) -> bool:
	return is_night(float(minute - MORNING_MINUTE))


## The next morning's first step after `steps`: where a night's sleep wakes
## the hero (PIX-246).
static func next_morning(steps: float) -> float:
	return (floorf(steps / DAY_CYCLE_STEPS) + 1.0) * DAY_CYCLE_STEPS


## The sun at `steps` for the scenery's shadows (PIX-449): where a shadow
## reaches for each pixel of height (x, y, always SHADOW_WAY) and how strong
## it is (z, 0..1); none between sunset and sunrise.
static func sun(steps: float) -> Vector3:
	var t := fposmod(steps, float(DAY_CYCLE_STEPS)) / DAY_CYCLE_STEPS
	if t >= 1.0 + SUNRISE:
		t -= 1.0
	var up := (t - SUNRISE) / (SUNSET - SUNRISE)
	if up <= 0.0 or up >= 1.0:
		return Vector3.ZERO
	var height := sin(PI * up)
	var cast := SHADOW_WAY.normalized() * minf(SHADOW_NOON / height, SHADOW_LONGEST)
	return Vector3(cast.x, cast.y, pow(height, SHADOW_FADE))
