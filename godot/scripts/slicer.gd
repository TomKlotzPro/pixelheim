class_name Slicer
extends RefCounted
## Work cut into slices a frame (One Reach, PIX-269, step 5): drawing the map
## beside the hero, taking it down again, working the Reach's ground out
## ahead, each a list of small units run in order, as many a frame as fit a
## budget of milliseconds measured by the clock - not a count of nodes, as a
## tree costs more than a tuft of grass and the browser more than the
## desktop. PR #338 measured the browser: a region drawn beside the hero is
## 11 to 20 ms of work and the Ashenreach 41, so at 3 ms a frame the slower
## browser frame stays near 6.5 ms of its 16.7.
## A unit runs only if the longest a unit of its kind has taken so far still
## fits what's left of the frame's budget; a kind not yet timed runs only
## first in a frame, where the budget is all its own. So once each kind has
## been timed a frame never goes over, unless one unit alone is bigger than
## the budget: that one runs alone, or the work would never end.
## Or `counted`: a budget of so many units a frame, whatever they take - the
## same units every frame on any machine (a harness run, stepped, lives the
## same frames however fast it's drawn: PIX-276).
## Pure but for the clock, which a test swaps for its own.

## A unit: {"kind": String, "run": Callable}.
var _units: Array[Dictionary] = []
var _next := 0
## kind -> the longest a unit of it has taken, in ms: this slicer's own, or
## shared by several (learn_from), each timing the kinds for the others.
var _longest := {}
## kind -> all its units have taken so far, ms (what a drawing cost, part by
## part).
var totals := {}
## The clock, in ms: Time's by default, a test's own.
var clock: Callable = func() -> float: return Time.get_ticks_usec() / 1000.0
## What the last run spent, in ms (in units when `counted`), and how many
## units it ran.
var spent := 0.0
var ran := 0
var counted := false


## Shares `known` (kind -> longest ms) with other slicers.
func learn_from(known: Dictionary) -> void:
	_longest = known


## Adds a unit of work: `run` called once, when its turn comes.
func add(kind: String, run: Callable) -> void:
	_units.append({"kind": kind, "run": run})


## Adds `count` units of `kind`, the i-th calling `run` with i: a layer laid
## a band of rows at a time.
func add_each(kind: String, count: int, run: Callable) -> void:
	for i in count:
		add(kind, run.bind(i))


## Whether every unit has run.
func done() -> bool:
	return _next >= _units.size()


## Drops every unit not yet run (work given up). Units often hold the slicer
## that runs them (a unit adds the next ones), so letting them go is what
## lets it all be freed.
func cancel() -> void:
	_units.clear()
	_next = 0


## How many units are left.
func left() -> int:
	return _units.size() - _next


## Runs units in order while they fit `budget` ms (see above); what was
## spent is in `spent`, how many ran in `ran`. `fresh`: the frame's budget is
## all this run's (else another run had some of it first, and even this
## run's first unit must fit). Returns whether all are done.
func run(budget: float, fresh := true) -> bool:
	spent = 0.0
	ran = 0
	if counted:
		while _next < _units.size() and ran < int(budget):
			_run_next()
			ran += 1
		spent = ran
		return done()
	var started: float = clock.call()
	while _next < _units.size():
		var kind: String = _units[_next]["kind"]
		var known := _longest.has(kind)
		var first := ran == 0 and fresh
		if not first and (not known or spent + float(_longest[kind]) > budget):
			break
		_run_next()
		ran += 1
		spent = clock.call() - started
		if spent >= budget:
			break
	return done()


## Runs everything left at once (a map built in one go).
func finish() -> void:
	while _next < _units.size():
		_run_next()


func _run_next() -> void:
	var unit: Dictionary = _units[_next]
	var kind: String = unit["kind"]
	var before: float = clock.call()
	(unit["run"] as Callable).call()
	var took: float = clock.call() - before
	_longest[kind] = maxf(float(_longest.get(kind, 0.0)), took)
	totals[kind] = float(totals.get(kind, 0.0)) + took
	_next += 1
	# All done: the units go (see cancel).
	if _next >= _units.size():
		cancel()


## The longest a unit of `kind` has taken so far, ms (0 when not yet seen).
func longest(kind: String) -> float:
	return float(_longest.get(kind, 0.0))
