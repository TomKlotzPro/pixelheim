class_name Tricks
## areas: combat field screen
## A common foe's one trick (PIX-489), by its kind, so every fight reads
## differently: the slime splits, the dire wolf bites and runs, the goblin
## snatches gold, the skeleton rises once from its bones, the ghost fades,
## the crab guards with its shell. Pure, over combat.json's "tricks"
## numbers; trick_brain.gd, riding on the enemy, does the moving and the
## drawing. An elite has its kind's trick besides its family's move; a boss
## or a named monster never, nor a slime's small halves.

const TILE := 16.0
## How far round the hero a circling wolf's next step leads, in radians.
const CIRCLE_STEP := 0.5


## `fighter`'s trick, {} for one without.
static func of(fighter: Dictionary) -> Dictionary:
	if fighter.get("small", false) or Bestiary.fights_like_boss(fighter):
		return {}
	return Bestiary.trick(String(fighter["id"]))


## The Bestiary's line for a kind's trick, "" for a kind without.
static func says(monster_id: String) -> String:
	return String(Bestiary.trick(monster_id).get("says", ""))


## One of the small ones `fighter` bursts into (split): a share of its
## health, its bite and its pay, never an elite, and never splitting again.
static func small(fighter: Dictionary, trick: Dictionary) -> Dictionary:
	var half := fighter.duplicate(true)
	half["small"] = true
	half["elite"] = false
	half["name"] = Text.t("Small %s") % String(Bestiary.monster(fighter["id"])["name"])
	half["maxHp"] = maxi(1, roundi(int(fighter["maxHp"]) * float(trick["hp"])))
	half["hp"] = half["maxHp"]
	half["attack"] = maxi(1, roundi(int(fighter["attack"]) * float(trick["attack"])))
	half["xp"] = maxi(1, roundi(int(fighter["xp"]) * float(trick["xp"])))
	half["gold"] = maxi(1, roundi(int(fighter["gold"]) * float(trick["gold"])))
	return half


## The coins a snatch takes from `gold` carried by a foe of `level`: its
## share, never more than `perLevel` a level, a coin at least while there
## is one.
static func snatched(gold: int, level: int, trick: Dictionary) -> int:
	if gold <= 0:
		return 0
	return clampi(roundi(gold * float(trick["share"])), 1, mini(gold, int(trick["perLevel"]) * level))


## What a slain snatcher gives for the `taken` coins: them and half again.
static func given_back(taken: int, trick: Dictionary) -> int:
	return ceili(taken * float(trick["back"]))


## The health a pile of bones stands up with (rise).
static func risen(max_hp: int, trick: Dictionary) -> int:
	return maxi(1, roundi(max_hp * float(trick["hp"])))


## Whether a foe struck at `struck_at` (game seconds, oldest first, this
## blow's last) fades now: `hits` of them within `within` seconds, and
## `every` seconds since it last came back (`faded_at`).
static func fades(struck_at: Array, faded_at: float, trick: Dictionary) -> bool:
	var hits := int(trick["hits"])
	if struck_at.size() < hits:
		return false
	var now := float(struck_at[-1])
	return now - float(struck_at[-hits]) <= float(trick["within"]) and now - faded_at >= float(trick["every"])


## Whether a blow from `to_blow` away meets the shell: within the trick's
## arc about `front`, the way the claws were raised.
static func in_front(front: Vector2, to_blow: Vector2, trick: Dictionary) -> bool:
	if front == Vector2.ZERO or to_blow == Vector2.ZERO:
		return true
	return absf(front.angle_to(to_blow)) <= deg_to_rad(float(trick["arc"])) / 2.0


## What a blow of `damage` does to a raised shell: its `front` share from
## the front (1 at least), whole from the side or the back.
static func shelled(damage: int, front: Vector2, to_blow: Vector2, trick: Dictionary) -> int:
	return maxi(1, roundi(damage * float(trick["front"]))) if in_front(front, to_blow, trick) else damage


## Where a wolf out of the fight's reach stands (hitrun): its place in the
## ring round the hero (`ring_spot`, Vector2.INF alone) pushed out to the
## circle, or alone a step further round them (`turn`: 1 or -1), so it
## circles.
static func circle_spot(hero: Vector2, at: Vector2, ring_spot: Vector2, turn: float, trick: Dictionary) -> Vector2:
	var radius := float(trick["circle"]) * TILE
	if ring_spot != Vector2.INF and ring_spot.distance_to(hero) >= 1.0:
		return hero + (ring_spot - hero).normalized() * radius
	var out := (at - hero).normalized() if at != hero else Vector2.RIGHT
	return hero + out.rotated(CIRCLE_STEP * turn) * radius


## Whether a wolf may dart now (a pack takes turns): nobody else's turn
## (`taken`), and the breath after the last one over (`free_at`).
static func may_dart(taken: bool, now: float, free_at: float) -> bool:
	return not taken and now >= free_at


## Where a faded ghost may come back, `reach` from the hero, best first:
## behind them (the far side from where it stood, `from`), then either side,
## then where it came from.
static func beside(hero: Vector2, from: Vector2, reach: float) -> Array[Vector2]:
	var away := (hero - from).normalized() if hero != from else Vector2.RIGHT
	var spots: Array[Vector2] = []
	for turn: float in [0.0, PI / 2.0, -PI / 2.0, PI]:
		spots.append(hero + away.rotated(turn) * reach)
	return spots
