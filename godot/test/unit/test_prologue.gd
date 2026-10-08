extends GutTest
## The Night of Ash (PIX-152): a new hero arrives on the road with the letter,
## and the night moves on only through its own steps - the scavenger, the
## gate, Bram, Sela, Maren - before the dawn starts the game proper.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior", 0, true)


func test_a_new_hero_arrives_on_the_road_at_night_with_the_letter() -> void:
	assert_eq(state.progression.prologue, Prologue.SCAVENGER)
	assert_eq(state.world.map_id, "overworld")
	assert_eq(state.world.cell, Vector2i(48, 34))
	assert_true(DayNight.is_night(state.world.steps))
	assert_eq(state.pack.items.get("chancellors_letter", 0), 1)
	assert_true(Catalog.item("chancellors_letter").get("quest", false), "not for sale")
	assert_eq(Prologue.objective(Prologue.SCAVENGER), "Something is feeding at the road - drive it off (Space to strike)")


func test_the_night_moves_only_through_its_steps() -> void:
	var dawns := [0]
	state.prologue_dawn.connect(func() -> void: dawns[0] += 1)
	state.finish_dialogue("elder")
	assert_eq(state.progression.prologue, Prologue.SCAVENGER, "Maren waits her turn")
	assert_string_contains(state.prologue_pouch(), "health potion")
	assert_eq(state.progression.prologue, Prologue.GATE)
	state.prologue_reached_town()
	assert_eq(state.progression.prologue, Prologue.BRAM)
	state.finish_dialogue("villager_bram")
	assert_eq(state.progression.prologue, Prologue.SELA)
	state.hero.hp = 3
	state.finish_dialogue("innkeeper")
	assert_eq(state.hero.hp, state.hero.stats["maxHp"], "Sela's bandages")
	assert_false(state.progression.quests.has("slime_trouble"), "no errands on the night of the fire")
	assert_eq(state.progression.prologue, Prologue.MAREN)
	state.finish_dialogue("elder")
	assert_eq(dawns[0], 1, "the letter in her hands: dawn")
	assert_false(state.pack.items.has("chancellors_letter"))
	state.finish_prologue()
	assert_eq(state.progression.prologue, Prologue.DONE)
	assert_false(DayNight.is_night(state.world.steps), "morning")


func test_the_night_is_saved_only_while_it_runs() -> void:
	var saved := {}
	state.progression.write_into(saved)
	assert_eq(saved["prologue"], Prologue.SCAVENGER)
	state.progression.prologue = Prologue.DONE
	var after := {}
	state.progression.write_into(after)
	assert_false(after.has("prologue"), "a hero past it saves as before")


func test_only_the_survivors_are_about_and_they_say_the_nights_lines() -> void:
	var ids := Prologue.survivors().map(func(npc: Dictionary) -> String: return npc["id"])
	assert_eq(ids, ["elder", "villager_bram", "innkeeper"])
	var town := MapData.load_by_id("town")
	for npc: Dictionary in Prologue.survivors():
		assert_true(town.is_walkable(Vector2i(npc["x"], npc["y"])), "%s stands on open ground" % npc["id"])
		assert_false(npc.has("stall"), "no trading tonight")
