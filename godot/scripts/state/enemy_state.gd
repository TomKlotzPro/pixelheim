class_name EnemyState
## areas: combat field
## What a foe is doing, one state at a time, and which state may follow
## which (PIX-501). Pure: enemy.gd holds the state and does each one's entry
## and exit work (Enemy.enter); its brains ask it by name (begin_cast,
## fall_to_pile, run_off...) and never write it. A change this table doesn't
## know is a bug: the enemy refuses it and says so. Its fall is no state of
## these: `dying` ends them all (a foe that stands down goes IDLE first).

enum {
	## At home: wandering, asleep or at its meal, watching for the hero.
	IDLE,
	## The hero is seen: the "!" and the hop before the charge.
	ALERT,
	## On the hunt: at the hero or its place in the ring, biting, shooting.
	CHASE,
	## Standing still while a move is told or a trick plays (PIX-150).
	CAST,
	## A skeleton's bones, waiting to rise (PIX-489).
	PILE,
	## Walking home, deaf to the hero on the way (PIX-142).
	HOMEWARD,
	## Running from the hero (PIX-251; a goblin with their gold, PIX-489).
	FLEE,
}

## Each state's name, as the harness's report and tools/play.py's
## `foes[].mode` say it (PIX-485): never change one.
const NAMES: Array[String] = ["idle", "alert", "chase", "cast", "pile", "homeward", "flee"]

## From each state, the states that may follow it and what brings each on.
const NEXT := {
	IDLE: [
		ALERT,  # the hero is seen
		FLEE,  # seen, and far too strong
		CHASE,  # struck
		PILE,  # felled where it stood
	],
	ALERT: [
		ALERT,  # seen again: the wind-up starts over
		CHASE,  # the wind-up done, or struck
		PILE,
		IDLE,  # it stands down
	],
	CHASE: [
		CAST,  # a move told, a trick begun
		FLEE,  # a goblin runs with the gold
		HOMEWARD,  # the chase given up
		PILE,
		IDLE,  # it stands down
	],
	CAST: [
		CHASE,  # the move done, or a stun broke it
		PILE,
		IDLE,  # it stands down
	],
	PILE: [
		CHASE,  # it rises
	],
	HOMEWARD: [
		IDLE,  # home
		ALERT,  # called to a fight on its way
		CHASE,  # struck
		PILE,
	],
	FLEE: [
		ALERT,  # cornered, it turns
		CHASE,  # struck, or a goblin turning back
		HOMEWARD,  # far enough: it calms down
		PILE,
		IDLE,  # it stands down
	],
}


## Whether a foe in `from` may go to `to`.
static func allowed(from: int, to: int) -> bool:
	return to in NEXT.get(from, [])


## `state`'s name ("chase"), "" for none.
static func name_of(state: int) -> String:
	return NAMES[state] if state >= 0 and state < NAMES.size() else ""


## The state called `name`, -1 for none.
static func named(name: String) -> int:
	return NAMES.find(name)


## Whether a foe in `state` is in a fight: chasing or telling a move, where
## a blow leaves it as it is (PIX-451) and it takes a place in the ring.
static func fighting(state: int) -> bool:
	return state == CHASE or state == CAST
