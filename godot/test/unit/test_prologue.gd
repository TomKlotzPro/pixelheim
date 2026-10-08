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
	assert_eq(Prologue.objective(Prologue.SCAVENGER), "Drive off what's feeding at the road (J to strike)", "the key as bound (J by default)")


func test_the_night_moves_only_through_its_steps() -> void:
	var dawns := [0]
	state.prologue_dawn.connect(func() -> void: dawns[0] += 1)
	state.finish_dialogue("elder")
	assert_eq(state.progression.prologue, Prologue.SCAVENGER, "Maren waits her turn")
	assert_string_contains(state.prologue_pouch(), "health potion")
	assert_eq(state.progression.prologue, Prologue.GATE)
	state.prologue_reached_town()
	assert_eq(state.progression.prologue, Prologue.HOUNDS, "PIX-197: hounds inside the gate")
	assert_string_contains(state.prologue_wave_cleared(), "Upper Street")
	assert_eq(state.progression.prologue, Prologue.BRAM)
	state.finish_dialogue("villager_bram")
	assert_eq(state.progression.prologue, Prologue.SELA)
	state.hero.hp = 3
	state.finish_dialogue("innkeeper")
	assert_eq(state.hero.hp, state.hero.stats["maxHp"], "Sela's bandages")
	assert_false(state.progression.quests.has("slime_trouble"), "no errands on the night of the fire")
	assert_eq(state.progression.prologue, Prologue.CAP, "and a cap to wear")
	var cap: Dictionary = state.pack.gear.filter(func(g: Dictionary) -> bool: return g["itemId"] == "leather_cap")[0]
	state.equip(cap["uid"])
	assert_eq(state.progression.prologue, Prologue.FIRES, "worn: on to the fires")
	for ruin in Prologue.fires_needed():
		assert_ne(state.prologue_douse(ruin), "")
		assert_eq(state.prologue_douse(ruin), "", "a fire goes out once")
	assert_eq(state.progression.prologue, Prologue.EMBERS)
	assert_string_contains(state.prologue_wave_cleared(), "Maren")
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


## PIX-197: the dawn is played on the square, each line said by someone who
## is there (or told), Fafnyr's shadow on his name, and everyone has a place.
func test_the_dawn_is_said_by_those_on_the_square() -> void:
	var beats := Prologue.dawn()
	assert_gt(beats.size(), 3)
	assert_eq(String(beats[0]["who"]), "", "it opens on the telling, while the fires go out")
	var places := Prologue.dawn_places()
	var shadows := 0
	for beat: Dictionary in beats:
		var who := String(beat["who"])
		assert_true(who == "" or places.has(who), "%s stands on the square" % who)
		if beat.get("shadow", false):
			shadows += 1
			assert_string_contains(String(beat["line"]), "Fafnyr")
	assert_eq(shadows, 1, "his shadow passes once")
	var map := MapData.load_by_id("town")
	var seen := {}
	for who: String in places:
		var cell: Vector2i = places[who]
		assert_true(map.is_walkable(cell), "%s's place at %s" % [who, cell])
		assert_false(seen.has(cell), "one each")
		seen[cell] = true
	assert_false(seen.has(Town.square() + Vector2i(0, 2)), "the hero's place is free")
	assert_false(String(Prologue.data()["dayCard"]["title"]).is_empty())


## PIX-197: the night teaches the game, one thing a beat, in order.
func test_the_night_teaches_every_control_in_order() -> void:
	assert_eq(Prologue.ORDER[0], Prologue.SCAVENGER)
	assert_eq(Prologue.ORDER[-1], Prologue.MAREN)
	assert_eq(Prologue.next(Prologue.MAREN), Prologue.DONE)
	var taught := ""
	for step: int in Prologue.ORDER:
		var text := String(Quests._data()["prologue"]["steps"][step - 1]["text"])
		assert_false(text.is_empty(), "beat %d has a line" % step)
		taught += text
	for action: String in ["attack", "dodge", "interact", "inventory", "skill_1"]:
		assert_string_contains(taught, "{key:%s}" % action, "the night teaches %s" % action)
	assert_eq(Prologue.objective(Prologue.FIRES, 1), "Carry water from the well to the burning homes (1/3)")
	for step: int in [Prologue.HOUNDS, Prologue.EMBERS]:
		var wave := Prologue.wave(step)
		var town := MapData.load_by_id("town")
		for at: Array in wave["cells"]:
			assert_true(town.is_walkable(Vector2i(int(at[0]), int(at[1]))), "a %s stands on open ground" % wave["name"])
		var foe := Bestiary.spawn(wave["monsterId"], wave["elite"], int(wave["level"]) - int(Bestiary.monster(wave["monsterId"])["level"]))
		assert_eq(int(foe["level"]), int(wave["level"]), "%s at a first night's level" % wave["name"])


func test_the_fires_put_out_are_kept() -> void:
	state.progression.prologue = Prologue.FIRES
	state.prologue_douse(2)
	var saved := {}
	state.progression.write_into(saved)
	assert_eq(saved["prologueDoused"], [2])
	assert_eq(ProgressionState.from_dict(saved).prologue_doused, [2] as Array[int])
