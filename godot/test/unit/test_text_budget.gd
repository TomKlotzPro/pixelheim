extends GutTest
## Too much text at once after a fight (PIX-334, Tom: « trop d'infos qui pop
## d'un coup sur l'écran en texte »): an area shows a few things at a time,
## the rest wait their turn, the same thing again folds into one, and what
## can wait does until the fight is over. Nothing is lost.


func test_an_area_shows_its_room_and_the_rest_wait_their_turn() -> void:
	var log := TextBudget.new(2)
	for line: String in ["The pack is scattered.", "A wolf howls.", "Greymaw has seen you."]:
		log.add(line)
	assert_eq(log.next(false)["text"], "The pack is scattered.")
	assert_eq(log.next(false)["text"], "A wolf howls.")
	assert_eq(log.next(false), {}, "two at a time")
	log.gone(log.showing[0])
	assert_eq(log.next(false)["text"], "Greymaw has seen you.", "its turn once one has gone: nothing lost")


func test_what_can_wait_waits_out_the_fight() -> void:
	var log := TextBudget.new(4)
	log.add("Slime Trouble: 1/3.", true)
	log.add("Greymaw has seen you.")
	assert_eq(log.next(true)["text"], "Greymaw has seen you.", "what matters now goes first")
	assert_eq(log.next(true), {}, "a quest's count waits while the fight is on")
	assert_eq(log.next(false)["text"], "Slime Trouble: 1/3.", "and shows once it's over")


func test_the_same_line_again_folds_into_one() -> void:
	var log := TextBudget.new(4)
	var first := log.add("The wolf is afflicted by Poison!")
	assert_true(is_same(log.add("The wolf is afflicted by Poison!"), first), "one entry")
	assert_eq([first["text"], first["count"]], ["The wolf is afflicted by Poison!", 2], "counted, not stacked")
	log.next(false)
	log.add("The wolf is afflicted by Poison!")
	assert_eq(first["count"], 3, "folds into the one showing too")
	assert_eq(log.waiting.size(), 0)


func test_a_count_takes_the_newest_and_a_plus_adds_up() -> void:
	assert_eq(TextBudget.fold("+3 gold", "+3 gold"), "+6 gold")
	var log := TextBudget.new(4)
	for i in 4:
		log.add("+3 gold")
	assert_eq(log.waiting[0]["text"], "+12 gold", "four of them: +12, the ticket's own")
	assert_eq(TextBudget.fold("Slime Trouble: 1/3.", "Slime Trouble: 2/3."), "Slime Trouble: 2/3.", "a quest's count: the newest")
	assert_eq(
		TextBudget.fold("Level up: you reached level 2. +3 stat points.", "Level up: you reached level 3. +3 stat points."),
		"Level up: you reached level 3. +6 stat points.", "two levels in a fight: once, at the higher, the points added")
	assert_ne(TextBudget.shape_of("The wolf howls."), TextBudget.shape_of("The bear howls."), "other words are another line")
	var edge := "Boss slayer: +10% damage for 10 minutes."
	assert_eq(TextBudget.fold(edge, edge), edge, "an edge that starts over doesn't add up")
	var tranchant := "Tueur de boss : +10 % de dégâts pendant 10 minutes."
	assert_eq(TextBudget.fold(tranchant, tranchant), tranchant, "nor in French")


func test_a_line_that_cant_wait_folded_into_one_that_can_no_longer_waits() -> void:
	var log := TextBudget.new(4)
	log.add("Slime Trouble: 1/3.", true)
	log.add("Slime Trouble: 2/3.")
	assert_eq(log.next(true)["text"], "Slime Trouble: 2/3.")


## The field's rule (PIX-340): a word over the world steps up just clear of
## a tag (and of the one over it), never back down, and past its most it
## shows anyway.
func test_a_word_rises_just_clear_of_a_tag() -> void:
	var tag := Rect2(0, 0, 30, 10)
	var number := Rect2(5, 6, 10, 8)
	assert_eq(TextBudget.rise([tag] as Array[Rect2], number, 1.0), 15.0, "its foot a pixel over the tag")
	var above := Rect2(0, -12, 30, 10)
	assert_eq(TextBudget.rise([tag, above] as Array[Rect2], number, 1.0), 27.0, "and over the word over it")
	assert_eq(TextBudget.rise([] as Array[Rect2], number, 1.0), 0.0, "nothing there: where it is")
	assert_eq(TextBudget.rise([] as Array[Rect2], number, 1.0, 4.0), 4.0, "never back down")
	var wall := Rect2(0, -100, 30, 120)
	assert_eq(TextBudget.rise([wall] as Array[Rect2], number, 1.0, 0.0, 36.0), 36.0, "no room: as high as it may, still shown")
