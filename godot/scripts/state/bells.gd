class_name Bells
## The Night of Bells (PIX-253 step 9, chapter 7): the dragon comes back to
## the square, and this time the village is ready. It plays the Night of
## Ash's own beats again on the town map - the lanterns lit, the embers
## driven off and the roofs doused from the well, then Fafnyr held on the
## square until the sky turns - with everyone the story brought home at a
## job: Teo's bell, Ulla's old guard on the walls, the inn a shelter, Iva's
## tent, Loras's song, Bram's cheese down Upper Street. At dawn he stands
## down, the collar comes off and he leaves a scale in the fountain.
##
## Old saves, no new field: the beat lives only while the night runs
## (ProgressionState.bells, never written), so a save made in the night plays
## it again from its start; the night's end is the collar's scene in the
## story ledger. A hero who slew Fafnyr on the old mountain skips the
## chapter (MainQuest's skipIf) and never sees it. Pure, over
## progression.json's "bells"; GameState and the world's Night act on it.

const NONE := 0
const LANTERNS := 1
const EMBERS := 2
const HOLD := 3
## Fafnyr has stood down: the dawn and the collar are playing.
const DAWN := 4
## Each beat by name (the harness reports it).
const NAMES := {LANTERNS: "lanterns", EMBERS: "embers", HOLD: "hold", DAWN: "dawn"}
## Who is out on the night by kind of job: the townsfolk's own words for
## those who only stand and talk.
const TALKING := ["watch", "lamps", "goose"]


static func data() -> Dictionary:
	return Quests._data()["bells"]


## The night's end in the story ledger: the collar opened.
static func collar_id() -> String:
	return String(data()["collar"])


static func dawn_id() -> String:
	return String(data()["dawnScene"])


## Whether this hero's night is over: Fafnyr freed, kept in the ledger.
static func over(progression: ProgressionState) -> bool:
	return collar_id() in progression.story_seen


## Whether arriving home starts the night: its first step is the story's
## next (the fifth letter delivered, the chapter not skipped) and it isn't
## running already.
static func due(progression: ProgressionState, settlement: SettlementState) -> bool:
	if progression.bells != NONE or over(progression):
		return false
	var step := MainQuest.next_step(progression, settlement)
	return not step.is_empty() and step["when"]["kind"] == "bells" and int(step["when"]["beat"]) == LANTERNS


## A main quest step of the `bells` kind is met while the night runs past
## its beat, or once the night is over.
static func step_met(when: Dictionary, progression: ProgressionState) -> bool:
	return progression.bells >= int(when["beat"]) or over(progression)


static func beat_name(beat: int) -> String:
	return String(NAMES.get(beat, ""))


## Every job of the night, in the data's order: {who, job, at, ...}.
static func all_jobs() -> Array:
	return data()["jobs"]


## The person behind a job as a villager (their sheet and name), {} when
## they don't live in Pixelheim yet: a settler not home, a townsperson the
## town hasn't grown for.
static func person(job: Dictionary, settlers: Array, town_tier: int) -> Dictionary:
	var who := String(job["who"])
	for npc: Dictionary in Npcs._data()["npcs"]:
		if npc["id"] == who:
			return npc if int(npc.get("minTownTier", 1)) <= town_tier else {}
	for recruit: Dictionary in Npcs._data()["recruits"]:
		if recruit["id"] == who:
			return Npcs.as_npc(recruit, true, town_tier) if who in settlers else {}
	return {}


## The jobs being done tonight: those whose person is out.
static func jobs(settlers: Array, town_tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for job: Dictionary in all_jobs():
		if not person(job, settlers, town_tier).is_empty():
			out.append(job)
	return out


## The first job of a kind tonight ("bell"), {} when nobody does it.
static func job(kind: String, settlers: Array, town_tier: int) -> Dictionary:
	for entry in jobs(settlers, town_tier):
		if entry["job"] == kind:
			return entry
	return {}


## A villager's job tonight, {} for one who has none.
static func job_of(npc_id: String, settlers: Array, town_tier: int) -> Dictionary:
	for entry in jobs(settlers, town_tier):
		if entry["who"] == npc_id:
			return entry
	return {}


## Who is out on the night, at their places, saying the night's lines
## (villagers for the world's Folk, as Prologue.survivors are).
static func folk(settlers: Array, town_tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in jobs(settlers, town_tier):
		var npc := person(entry, settlers, town_tier).duplicate()
		var at: Array = entry["at"]
		npc.merge({"mapId": "town", "x": int(at[0]), "y": int(at[1]), "wander": false, "lines": entry["lines"]}, true)
		npc.erase("stall")
		out.append(npc)
	return out


static func cell(at: Array) -> Vector2i:
	return Vector2i(int(at[0]), int(at[1]))


## What the night opens on: the bell, or a pot if Teo isn't home.
static func start_line(settlers: Array, town_tier: int) -> String:
	return String(data()["start"] if not job("bell", settlers, town_tier).is_empty() else data()["startQuiet"])


## What's said as the fifth lantern takes: Aske puts out the rest, or the
## village does it street by street.
static func dark_line(settlers: Array, town_tier: int) -> String:
	var lanterns: Dictionary = data()["lanterns"]
	return String(lanterns["dark"] if not job("lamps", settlers, town_tier).is_empty() else lanterns["darkQuiet"])


## The five lanterns on the square (the ending's, town.json).
static func lanterns() -> Array[Vector2i]:
	return Town.lanterns()


## The embers' wave: {monsterId, level, name, cells, come, cleared}.
static func embers() -> Dictionary:
	return data()["embers"]


static func ember_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for at: Array in embers()["cells"]:
		out.append(cell(at))
	return out


## The roofs the embers set burning, as rects of cells (corners included
## in the data, as town.json's).
static func roofs() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for corners: Array in data()["fires"]["roofs"]:
		out.append(Rect2i(int(corners[0]), int(corners[1]), int(corners[2]) - int(corners[0]) + 1, int(corners[3]) - int(corners[1]) + 1))
	return out


## The roof `faced` belongs to, -1 for none.
static func roof_at(faced: Vector2i) -> int:
	var all := roofs()
	for i in all.size():
		if all[i].has_point(faced):
			return i
	return -1


static func fafnyr_spec() -> Dictionary:
	return data()["fafnyr"]


## Fafnyr for the night: his kind lifted to the night's level, then the
## night's own numbers (he holds the square far longer than he held his
## hoard, and hits a little softer for it), the share he yields at, his
## roars over the town, and `bells` so the world knows him.
static func fafnyr() -> Dictionary:
	var spec := fafnyr_spec()
	var kind := String(spec["monsterId"])
	var fighter := Bestiary.spawn(kind, false, Bestiary.lift_to(kind, int(spec["level"])))
	fighter.merge({
		"hp": int(spec["maxHp"]), "maxHp": int(spec["maxHp"]), "attack": int(spec["attack"]),
		"defense": int(spec["defense"]), "xp": int(spec["xp"]), "gold": int(spec["gold"]),
		"level": int(spec["level"]), "yieldsAt": float(spec["yieldsAt"]), "roars": spec["roars"],
		"bells": true, "size": float(spec.get("scale", 1.0)),
	}, true)
	return fighter


## Where he lands on the square.
static func landing() -> Vector2i:
	return cell(fafnyr_spec()["at"])


## Seconds of holding the square until the sky turns.
static func dawn_seconds() -> float:
	return float(fafnyr_spec()["dawnSeconds"])


## How far from the square's heart still counts as holding it, in cells.
static func hold_radius() -> float:
	return float(fafnyr_spec()["holdRadius"])


## Whether a hero at `cell` holds the square.
static func holding(at: Vector2i) -> bool:
	return Vector2(at - Town.square()).length() <= hold_radius()


## The world's clock as the night begins: the middle of the night, now if
## it's night already, else the coming one.
static func night_start(steps: float) -> float:
	var day := float(DayNight.DAY_CYCLE_STEPS)
	var t := fposmod(steps, day) / day
	if t >= 0.65 and t < 0.85:
		return steps
	var start := floorf(steps / day) * day + 0.72 * day
	return start if start >= steps else start + day


## The clock as the square is held, `share` of the way to dawn: from where
## the night stood to the first grey of morning, the night's dark holding
## most of the way and the sky turning at the end (Lights.DAY_LIGHT).
static func sky_at(start: float, share: float) -> float:
	var day := float(DayNight.DAY_CYCLE_STEPS)
	var dawn := floorf(start / day) * day + 0.91 * day
	if dawn < start:
		dawn += day
	return lerpf(start, dawn, clampf(share, 0.0, 1.0))


## The morning after: the clock at the dawn the Night of Ash ended on.
static func morning(steps: float) -> float:
	var day := float(DayNight.DAY_CYCLE_STEPS)
	return floorf(steps / day) * day + 0.95 * day


## The line above the dock while the night runs: the beat's step and how
## far it has got.
static func objective(beat: int, lit: int, embers_left: int, burning: int, dawn_left: float) -> String:
	var steps := MainQuest.steps()
	var text := ""
	for step in steps:
		if step["when"]["kind"] == "bells" and int(step["when"]["beat"]) == beat + 1:
			text = String(step["text"])
	if text == "":
		return ""
	match beat:
		LANTERNS:
			text += " (%d/%d)" % [lit, lanterns().size()]
		EMBERS:
			text += " " + Text.t("(embers %d, fires %d)") % [embers_left, burning]
		HOLD:
			var left := ceili(maxf(0.0, dawn_left))
			text += " " + Text.t("(dawn in %d:%02d)") % [left / 60, left % 60]
	return Text.t("Next: %s") % text


## Whether Iva (or whoever heals) may heal again: `every` seconds after the
## last time.
static func heal_ready(job_entry: Dictionary, last: float, now: float) -> bool:
	return now - last >= float(job_entry.get("every", 0.0))
