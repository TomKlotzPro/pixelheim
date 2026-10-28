class_name LanternNight
## areas: travel field night story +overworld*
## Lantern Night's rules (PIX-362, the Post's step 7b): once the story is
## over, the last night of every Reach year is a festival of its own, and
## that night the freed Fafnyr lights every lamp on the Reach in one pass.
## The game counts only days and Maren's weeks, and a day is some six
## minutes of walking: a year of real length would never come round, so a
## Reach year is four of her weeks (YEAR), and Lantern Night its last night,
## the lamps lit for the new one. It brings the town its festival day
## (SettlementState.festival, as an age's does) with the night's own marks:
## `lantern`, its day, and `flown`, once Fafnyr's pass is over. Until then
## the lamps wait dark for him (LanternLayer). Pure: the world plays it
## (LanternPass).

## Days in a Reach year: four weeks.
const YEAR := 28
## Lantern Night is the year's last day (its night belongs to it until six).
const NIGHT := YEAR - 1


## Whether day `day` is Lantern Night: the story over (as the Dragon Post
## needs, Post.dragon_open) and the year's last day.
static func tonight(progression: ProgressionState, settlement: SettlementState, day: int) -> bool:
	return posmod(day, YEAR) == NIGHT and Post.dragon_open(progression, settlement)


## Whether Fafnyr's pass is over on day `day`.
static func flown(settlement: SettlementState, day: int) -> bool:
	return int(settlement.festival.get("lantern", -1)) == day and settlement.festival.get("flown", false)


## Whether the Reach's lamps wait dark for him on day `day`.
static func waits(progression: ProgressionState, settlement: SettlementState, day: int) -> bool:
	return tonight(progression, settlement, day) and not flown(settlement, day)


## Whether Lantern Night's festival is still to begin on day `day`.
static func begins(progression: ProgressionState, settlement: SettlementState, day: int) -> bool:
	return tonight(progression, settlement, day) and int(settlement.festival.get("lantern", -1)) != day


## The town's festival for Lantern Night `day`, as an age's (Holdings.
## start_festival) but until the next morning: stalls, the ring toss (its
## prize by the town's `age`), everyone on the square.
static func begin(settlement: SettlementState, day: int, age: int) -> void:
	settlement.festival = {"until": (day + 1) * DayNight.DAY_CYCLE_STEPS, "age": age, "won": false, "lantern": day}


## Fafnyr's pass over on day `day`: once a Lantern Night.
static func fly(settlement: SettlementState, day: int, age: int) -> void:
	if int(settlement.festival.get("lantern", -1)) != day:
		begin(settlement, day, age)
	settlement.festival["flown"] = true


## The lamps' places in the order his pass lights them: west to east, as he
## flies (Routes.lamps).
static func order(lamps: Array[Dictionary]) -> Array[String]:
	var sorted := lamps.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2i(a["cell"]) < Vector2i(b["cell"]))
	var out: Array[String] = []
	for lamp: Dictionary in sorted:
		out.append(String(lamp["place"]))
	return out
