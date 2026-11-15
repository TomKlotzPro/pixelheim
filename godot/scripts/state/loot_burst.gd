class_name LootBurst
extends RefCounted
## areas: combat
## What a kill's win looks like on its way to the hero (PIX-492): how many
## coins spring out of a foe for its gold, how many sparks for its XP, what
## each one carries to the float it counts up, and what a drop's rarity
## shows. Pure, no nodes: LootPop draws it, and the rule that
## matters (the coins' shares add up to the gold, the sparks' to the XP, so
## the float ends on what the kill paid) is tested without a world. The
## credit itself is Spoils', paid whole at the kill: this is only the look.

## The most coins and sparks one foe bursts into; a boss's or a named
## monster's win is a bigger burst.
const COINS := 8
const BIG_COINS := 16
const SPARKS := 5
const BIG_SPARKS := 10
## The most drops that hop out of one foe; the rest only float.
const DROPS := 4

## A coin's life in seconds: out of the foe in an arc, one bounce, a breath
## on the ground where it glints, then the sweep to the hero, each coin
## this long after the one before.
const OUT_S := 0.3
const BOUNCE_S := 0.16
const REST_S := 0.3
const FLY_S := 0.24
const STAGGER_S := 0.05
## From a burst's first coin leaving to its last, at most: a boss's sixteen
## are in as soon as a rich foe's eight.
const SWEEP_S := 0.4
## A spark rises this long over the foe before it sweeps in: the first
## lands well before the first coin, so the float is up (its XP) when the
## gold starts to count.
const RISE_S := 0.28
## A drop lies this long where it landed, its glow on it, before it goes to
## the pack; a piece with a beam a little longer.
const LIE_S := 0.9
const BEAM_S := 1.3


## How many coins a foe's `gold` springs out as: a few for a poor one, more
## for a richer one, never more than there is gold.
static func coins(gold: int, big := false) -> int:
	if gold <= 0:
		return 0
	return mini(gold, clampi(6 + gold / 8, 6, BIG_COINS) if big else clampi(2 + gold / 4, 2, COINS))


## How many sparks its `xp` rises as.
static func sparks(xp: int, big := false) -> int:
	if xp <= 0:
		return 0
	return mini(xp, clampi(4 + xp / 10, 4, BIG_SPARKS) if big else clampi(1 + xp / 6, 1, SPARKS))


## `total` shared among `count` carriers, each at least 1 when there is
## enough, the odd ones out on the last to land: they add up to `total`.
static func shares(total: int, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if count <= 0:
		return out
	out.resize(count)
	for i in count:
		out[i] = total / count + (1 if i >= count - total % count else 0)
	return out


## What a drop of `rarity` shows where it lies: nothing for a common one, a
## soft "glow" for a fine one, a "beam" of light for an epic one and
## anything rarer the game may come to have.
static func shine(rarity: String) -> String:
	return {"common": "", "fine": "glow"}.get(rarity, "beam")


## A thing `u` of the way (0 to 1) through a hop from `from` to `to` on the
## ground, `height` pixels up at the top of its arc: fast out, slowing as
## it comes down.
static func hop(from: Vector2, to: Vector2, height: float, u: float) -> Vector2:
	u = clampf(u, 0.0, 1.0)
	return from.lerp(to, 1.0 - (1.0 - u) * (1.0 - u)) - Vector2(0, height * 4.0 * u * (1.0 - u))


## A thing `u` of the way through its sweep from `from` to the hero at
## `to`: slow away, fast in, lifted a little in the middle.
static func sweep(from: Vector2, to: Vector2, u: float) -> Vector2:
	u = clampf(u, 0.0, 1.0)
	return from.lerp(to, u * u) - Vector2(0, 6.0 * sin(PI * u))
