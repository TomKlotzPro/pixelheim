extends GutTest
## Nothing bought or taken by accident (PIX-486): the E that ends a talk,
## pressed again or held, does nothing for a moment, at a counter or in the
## world; and a talk left with Esc takes no quest.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const DialogueBox := preload("res://scripts/dialogue_box.gd")
const ShopScreen := preload("res://scripts/shop_screen.gd")
const BankScreen := preload("res://scripts/bank_screen.gd")
const QUEST := "herbs_for_vex"
const VEX := "alchemist_vex"


## A counter: E buys.
class Counter:
	extends Screen
	var bought := 0

	func _command(event: InputEvent) -> Callable:
		if event.is_action_pressed("interact"):
			return func() -> void: bought += 1
		return Callable()


func after_each() -> void:
	Screen._quiet_until = 0
	get_tree().paused = false


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _counter() -> Counter:
	var screen := Counter.new()
	add_child_autofree(screen)
	return screen


func _talk() -> Node:
	var box := DialogueBox.new()
	box.npc = {"id": "nobody", "name": "Nobody", "lines": ["One.", "Two."]}
	add_child_autofree(box)
	return box


func _past_the_moment() -> void:
	for tick in roundi(Screen.SETTLE * Engine.physics_ticks_per_second) + 1:
		await get_tree().physics_frame


# ---- the E that ends a talk ------------------------------------------------------

func test_e_pressed_on_after_a_talk_does_not_buy() -> void:
	var box := _talk()
	box._unhandled_input(_press(&"interact"))
	box._unhandled_input(_press(&"interact"))
	assert_true(box.is_queued_for_deletion(), "the pages turn at once, and the last E ends it")
	assert_true(Screen.hushed(_press(&"interact")), "the world's E opens no counter yet")
	var counter := _counter()
	for press in 5:
		counter._unhandled_input(_press(&"interact"))
	assert_eq(counter.bought, 0, "E pressed over and over buys nothing")
	await _past_the_moment()
	counter._unhandled_input(_press(&"interact"))
	assert_eq(counter.bought, 1, "a press after a pause is meant")


func test_a_fresh_e_just_after_the_talks_end_does_not_buy() -> void:
	_talk().close()
	var counter := _counter()
	counter._unhandled_input(_press(&"interact"))
	assert_eq(counter.bought, 0, "a press, not an echo, inside the moment")


# ---- E at a reading pace ---------------------------------------------------------

func test_the_counter_opens_with_no_row_chosen() -> void:
	var kept_stall: String = GameState.trade.stall_shop
	var kept_gold: int = GameState.pack.gold
	var kept_items: Dictionary = GameState.pack.items.duplicate()
	GameState.trade.stall_shop = Economy.shop_at("town_shop")
	GameState.pack.gold = 30
	var counter: Screen = ShopScreen.new()
	add_child_autofree(counter)
	assert_true(counter.resting)
	# Every press past the moment: a reader's pace, one E a second.
	counter._unhandled_input(_press(&"interact"))
	assert_false(counter.resting, "the first E chooses the first row")
	assert_eq(counter.selected, 0)
	assert_eq(GameState.pack.gold, 30, "and buys nothing")
	counter._unhandled_input(_press(&"interact"))
	assert_lt(GameState.pack.gold, 30, "E on a row chosen buys")
	GameState.trade.stall_shop = kept_stall
	GameState.pack.gold = kept_gold
	GameState.pack.items = kept_items


func test_up_or_down_first_chooses_the_first_row() -> void:
	var kept_stall: String = GameState.trade.stall_shop
	GameState.trade.stall_shop = Economy.shop_at("town_shop")
	var counter: Screen = ShopScreen.new()
	add_child_autofree(counter)
	counter._unhandled_input(_press(&"move_down"))
	assert_false(counter.resting)
	assert_eq(counter.selected, 0, "chosen, not passed over")
	counter._unhandled_input(_press(&"move_down"))
	assert_eq(counter.selected, 1)
	GameState.trade.stall_shop = kept_stall


func test_a_ledger_opens_with_no_row_chosen() -> void:
	var kept: int = GameState.pack.gold
	GameState.pack.gold = 100
	var bank: Screen = BankScreen.new()
	add_child_autofree(bank)
	bank._unhandled_input(_press(&"interact"))
	assert_eq(GameState.pack.gold, 100, "the first E only chooses")
	assert_false(bank.resting)
	GameState.pack.gold = kept


func test_esc_and_the_arrows_are_never_held_back() -> void:
	Screen.hush()
	assert_false(Screen.hushed(_press(&"ui_cancel")))
	assert_false(Screen.hushed(_press(&"move_down")))
	var counter := _counter()
	counter._unhandled_input(_press(&"ui_cancel"))
	assert_true(counter.is_queued_for_deletion(), "Esc closes it at once")


# ---- a talk left with Esc --------------------------------------------------------

func test_a_talk_left_on_its_first_line_takes_no_quest() -> void:
	var state: Node = autofree(GameStateScript.new())
	var said: Array[String] = []
	state.message.connect(func(text: String) -> void: said.append(text))
	state.questing.finish_dialogue(VEX, false)
	assert_false(state.progression.quests.has(QUEST), "left with Esc: not taken")
	assert_eq(said, [] as Array[String], "and nothing said of it")
	assert_true(Quests.awaits_word(VEX, state.progression.quests, state.pack.items, state.questing.quest_open), "she still asks")
	state.questing.finish_dialogue(VEX)
	assert_eq(state.progression.quests[QUEST], {"progress": 0, "done": false}, "heard to the end: taken")


func test_a_talk_left_still_hands_in_what_is_ready() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.questing.finish_dialogue(VEX)
	state.progression.quests[QUEST]["progress"] = 1
	state.questing.finish_dialogue(VEX, false)
	assert_true(state.progression.quests[QUEST]["done"], "the hero came to hand it in")


func test_the_box_says_whether_it_was_heard_out() -> void:
	var quests: Dictionary = GameState.progression.quests
	var before := quests.duplicate(true)
	var box := DialogueBox.new()
	box.npc = {"id": VEX, "name": "Alchemist Vex", "lines": ["One.", "Two.", "Three."]}
	add_child_autofree(box)
	box._unhandled_input(_press(&"ui_cancel"))
	assert_true(box.is_queued_for_deletion(), "Esc leaves on line 1 of 3")
	assert_eq(quests, before, "and takes nothing")


func test_marens_tin_left_with_esc_stays_shut() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.progression.prologue = Prologue.DONE
	assert_true(Letters.tin_waits(state.progression), "the tin waits")
	var said: Array[String] = []
	state.message.connect(func(text: String) -> void: said.append(text))
	state.questing.finish_dialogue("elder", false)
	assert_true(Letters.tin_waits(state.progression), "left with Esc: still shut")
	assert_eq(state.progression.quests, {}, "no letter, no ask taken")
	assert_eq(said, [] as Array[String])
	state.questing.finish_dialogue("elder")
	assert_false(Letters.tin_waits(state.progression), "heard to the end: opened")
	assert_false(state.progression.quests.is_empty())
