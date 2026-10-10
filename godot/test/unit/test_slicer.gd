extends GutTest
## Work a few units a frame (One Reach, PIX-269, step 5): a map drawn beside
## the hero is built in slices of at most 3 ms a frame by the clock. Here the
## clock is the test's own, each unit costing what its kind does, so a run
## is counted unit by unit.

## A unit's cost by kind, ms: small and big, as a map's are.
const COSTS := {"tuft": 0.1, "tree": 0.4, "row": 0.9, "plan": 2.6}
const BUDGET := 3.0

var _now := 0.0


func _slicer() -> Slicer:
	var slices := Slicer.new()
	slices.clock = func() -> float: return _now
	return slices


## A unit of `kind` that moves the clock on by its cost and notes it ran.
func _unit(kind: String, ran: Array) -> Callable:
	return func() -> void:
		_now += COSTS[kind]
		ran.append(kind)


func test_a_frame_never_spends_more_than_its_budget() -> void:
	var slices := _slicer()
	var ran: Array = []
	var kinds := ["plan", "row", "row", "tree", "tuft", "tuft", "plan", "row"]
	for i in 300:
		slices.add(kinds[i % kinds.size()], _unit(kinds[i % kinds.size()], ran))
	var frames := 0
	while not slices.run(BUDGET):
		assert_lte(slices.spent, BUDGET + 0.0001, "frame %d spent %.2f ms" % [frames, slices.spent])
		assert_gt(slices.ran, 0, "every frame gets something done")
		frames += 1
	assert_lte(slices.spent, BUDGET + 0.0001, "the last frame too")
	assert_eq(ran.size(), 300, "every unit ran, once")
	for i in ran.size():
		if ran[i] != kinds[i % kinds.size()]:
			assert_eq(ran[i], kinds[i % kinds.size()], "in order")
			return
	# Work worth 300 units' cost over frames of at most 3 ms.
	var total := 0.0
	for i in 300:
		total += COSTS[kinds[i % kinds.size()]]
	assert_gte(frames + 1, ceili(total / BUDGET), "no frame took more than its share")


func test_a_kind_not_yet_timed_runs_first_in_a_frame() -> void:
	var slices := _slicer()
	var ran: Array = []
	slices.add("tuft", _unit("tuft", ran))
	slices.add("plan", _unit("plan", ran))
	slices.run(BUDGET)
	assert_eq(ran, ["tuft"], "an untimed plan waits for a frame of its own")
	slices.run(BUDGET)
	assert_eq(ran, ["tuft", "plan"])


func test_a_unit_bigger_than_the_budget_runs_alone() -> void:
	var slices := _slicer()
	var huge := func() -> void: _now += 7.0
	slices.add("huge", huge)
	slices.add("huge", huge)
	assert_false(slices.run(BUDGET))
	assert_eq(slices.ran, 1, "one, alone: the work still ends")
	assert_true(slices.run(BUDGET))
	assert_eq(slices.ran, 1)


func test_a_run_after_another_in_the_frame_starts_only_what_fits() -> void:
	var learned := {}
	var first := _slicer()
	first.learn_from(learned)
	var ran: Array = []
	first.add("row", _unit("row", ran))
	first.run(BUDGET)
	var second := _slicer()
	second.learn_from(learned)
	second.add("row", _unit("row", ran))
	second.add("plan", _unit("plan", ran))
	second.run(0.5, false)
	assert_eq(second.ran, 0, "a known row doesn't fit half a millisecond left")
	second.run(2.0, false)
	assert_eq(second.ran, 1, "it fits two, and the plan, untimed, waits for a frame of its own")


func test_a_unit_may_add_the_next_ones() -> void:
	var slices := _slicer()
	var ran: Array = []
	slices.add("plan", func() -> void:
		ran.append("load")
		slices.add_each("row", 3, func(i: int) -> void: ran.append("row %d" % i)))
	slices.add("tuft", func() -> void: ran.append("tuft"))
	slices.finish()
	assert_eq(ran, ["load", "tuft", "row 0", "row 1", "row 2"], "added after what was there")
	assert_true(slices.done())
	assert_eq(slices.left(), 0, "and let go once run")


func test_given_up_work_is_let_go() -> void:
	var slices := _slicer()
	var ran: Array = []
	slices.add_each("tuft", 5, func(_i: int) -> void: ran.append(1))
	slices.cancel()
	assert_true(slices.done())
	slices.finish()
	assert_eq(ran.size(), 0)


func test_counted_it_runs_so_many_units_a_frame_whatever_they_take() -> void:
	var slices := _slicer()
	slices.counted = true
	var ran: Array = []
	for i in 10:
		slices.add("plan" if i % 3 == 0 else "tuft", _unit("plan" if i % 3 == 0 else "tuft", ran))
	assert_false(slices.run(4))
	assert_eq(ran.size(), 4, "four units, the plans among them, on any machine")
	assert_eq(slices.spent, 4.0, "counted in units")
	slices.run(4)
	assert_true(slices.run(4))
	assert_eq(ran.size(), 10)

