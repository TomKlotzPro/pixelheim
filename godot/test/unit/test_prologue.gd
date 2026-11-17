extends GutTest
## The Night of Ash (PIX-152): a new hero arrives on the road with the letter,
## and the night moves on only through its own steps - the scavenger, the
## gate, Bram, Sela, Maren - before the dawn starts the game proper.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior", true)


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
	state.questing.finish_dialogue("elder")
	assert_eq(state.progression.prologue, Prologue.SCAVENGER, "Maren waits her turn")
	assert_string_contains(state.questing.prologue_pouch(), "health potion")
	assert_eq(state.progression.prologue, Prologue.GATE)
	state.questing.prologue_reached_town()
	assert_eq(state.progression.prologue, Prologue.HOUNDS, "PIX-197: hounds inside the gate")
	assert_string_contains(state.questing.prologue_wave_cleared(), "Upper Street")
	assert_eq(state.progression.prologue, Prologue.BRAM)
	state.questing.finish_dialogue("villager_bram")
	assert_eq(state.progression.prologue, Prologue.SELA)
	state.hero.hp = 3
	state.questing.finish_dialogue("innkeeper")
	assert_eq(state.hero.hp, state.hero.stats["maxHp"], "Sela's bandages")
	assert_false(state.progression.quests.has("slime_trouble"), "no errands on the night of the fire")
	assert_eq(state.progression.prologue, Prologue.CAP, "and a cap to wear")
	var cap: Dictionary = state.pack.gear.filter(func(g: Dictionary) -> bool: return g["itemId"] == "leather_cap")[0]
	state.upkeep.equip(cap["uid"])
	assert_eq(state.progression.prologue, Prologue.FIRES, "worn: on to the fires")
	for ruin in Prologue.fires_needed():
		assert_ne(state.questing.prologue_douse(ruin), "")
		assert_eq(state.questing.prologue_douse(ruin), "", "a fire goes out once")
	assert_eq(state.progression.prologue, Prologue.EMBERS)
	assert_string_contains(state.questing.prologue_wave_cleared(), "Maren")
	assert_eq(state.progression.prologue, Prologue.MAREN)
	state.questing.finish_dialogue("elder")
	assert_eq(dawns[0], 1, "the letter in her hands: dawn")
	assert_false(state.pack.items.has("chancellors_letter"))
	state.questing.finish_prologue()
	assert_eq(state.progression.prologue, Prologue.DONE)
	assert_false(DayNight.is_night(state.world.steps), "morning")


## PIX-344: beat 7 waits for head gear and is saved waiting, so Sela's cap
## dropped or sold left the night stuck for good. It stays while the night
## runs; a hero who lost it before gets another from her; the night still
## runs to its dawn, and after it the cap is a cap like any other.
func test_selas_cap_stays_until_the_night_is_over() -> void:
	state.progression.prologue = Prologue.SELA
	state.questing.finish_dialogue("innkeeper")
	assert_eq(state.progression.prologue, Prologue.CAP)
	var cap := _cap()
	assert_false(state.upkeep.drop_gear(cap["uid"]), "never dropped")
	state.world.map_id = "town_smith"
	assert_eq(state.trade.sell_gear(cap["uid"]), 0, "nor sold")
	assert_eq(_caps(), 1)
	# A save from before: the cap gone at beat 7.
	state.pack.gear.erase(cap)
	state.questing.finish_dialogue("villager_bram")
	assert_eq(_caps(), 0, "Bram has none to give")
	state.questing.finish_dialogue("innkeeper")
	assert_eq(state.progression.prologue, Prologue.CAP, "her word doesn't move the night on")
	assert_eq(_caps(), 1, "Sela finds another")
	state.questing.finish_dialogue("innkeeper")
	assert_eq(_caps(), 1, "one is enough")
	state.upkeep.equip(_cap()["uid"])
	assert_eq(state.progression.prologue, Prologue.FIRES, "worn: on to the fires")
	for ruin in Prologue.fires_needed():
		state.questing.prologue_douse(ruin)
	state.questing.prologue_wave_cleared()
	state.questing.finish_dialogue("elder")
	state.questing.finish_prologue()
	assert_eq(state.progression.prologue, Prologue.DONE, "the night finishes")
	state.upkeep.unequip("head")
	assert_true(state.upkeep.drop_gear(_cap()["uid"]), "a cap like any other by day")


func _cap() -> Dictionary:
	var caps: Array = state.pack.gear.filter(func(piece: Dictionary) -> bool: return piece["itemId"] == "leather_cap")
	return caps[0] if not caps.is_empty() else {}


func _caps() -> int:
	return state.pack.gear.filter(func(piece: Dictionary) -> bool: return piece["itemId"] == "leather_cap").size()


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
	state.questing.prologue_douse(2)
	var saved := {}
	state.progression.write_into(saved)
	assert_eq(saved["prologueDoused"], [2])
	assert_eq(ProgressionState.from_dict(saved).prologue_doused, [2] as Array[int])


## PIX-460: the well and each burning home took E from one cell and one
## facing, and a newcomer spent fifteen tries on them: beside one, on any
## side, is enough, the faced side first. PIX-461: a full bucket leads to the
## nearest fire, and the line says it's in hand.
func test_the_water_is_met_from_beside_and_a_full_bucket_leads_to_a_fire() -> void:
	# Shade's well, two wide with its roof two tall over it, and two homes.
	var well := Rect2i(4, 2, 2, 3)
	var homes: Array[Dictionary] = [{"rect": Rect2i(10, 4, 4, 3)}, {"rect": Rect2i(15, 4, 3, 3)}]
	assert_eq(Prologue.water_beside(Vector2i(5, 5), Vector2i.UP, well, homes, []), {"cell": Vector2i(5, 4), "ruin": -1}, "under the roof's right half")
	assert_eq(Prologue.water_beside(Vector2i(6, 3), Vector2i.DOWN, well, homes, []), {"cell": Vector2i(5, 3), "ruin": -1}, "beside the roof, facing away")
	assert_eq(Prologue.water_beside(Vector2i(14, 5), Vector2i.RIGHT, well, homes, []), {"cell": Vector2i(15, 5), "ruin": 1}, "between two homes, the faced one")
	assert_eq(Prologue.water_beside(Vector2i(14, 5), Vector2i.RIGHT, well, homes, [1]), {"cell": Vector2i(13, 5), "ruin": 0}, "one put out takes no more")
	assert_eq(Prologue.water_beside(Vector2i(12, 8), Vector2i.UP, well, homes, []), {}, "a step off, nothing")
	assert_eq(Prologue.nearest_fire(Vector2i(20, 5), homes, []), Vector2i(17, 5), "the nearest home, at its nearest cell")
	assert_eq(Prologue.nearest_fire(Vector2i(20, 5), homes, [1]), Vector2i(13, 5), "the next once that one is out")
	assert_eq(Prologue.nearest_fire(Vector2i(20, 5), homes, [0, 1]), Prologue.well(), "the well once none burns")
	assert_eq(Prologue.objective(Prologue.FIRES, 1, false, true), "Pour the bucket on a burning home (1/3)")
	assert_eq(Prologue.objective(Prologue.EMBERS, 3, false, true), Prologue.objective(Prologue.EMBERS, 3), "only the carrying beat has a bucket")


## PIX-426: the line above the dock said Upper Street while the map's goal,
## the journal and Maren's gold "!" sent a newcomer to her, who played her
## letter scene again and again and never found the caller. At every step of
## the night every guide points at the one place the step is done: the
## lead (the line above the dock, the journal's top, the map's goal and the
## arrow all read it), the journal's main story row, and the marks (no quest
## is offered that night; the survivor the step waits on wears the gold "!").
func test_every_guide_points_where_the_nights_step_is_done() -> void:
	var people := {Prologue.BRAM: "villager_bram", Prologue.SELA: "innkeeper", Prologue.MAREN: "elder"}
	var town := MapData.load_by_id("town")
	# Something followed from the journal doesn't take the night's lead.
	state.progression.tracked = "greymaw"
	for step: int in Prologue.ORDER:
		state.progression.prologue = step
		var goal := Prologue.goal(step)
		var line := Prologue.objective(step, state.progression.prologue_doused.size())
		var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
		assert_eq([lead["map_id"], lead["cell"], lead["who"]], [goal["map_id"], goal["cell"], goal["who"]], "beat %d: the lead is its goal" % step)
		assert_eq(lead["step"], line, "beat %d: and says the line above the dock" % step)
		assert_true(Bearing.tells_story(lead), "beat %d: the gold arrow" % step)
		assert_eq(Bearing.behind(lead, state.progression, state.settlement, state.pack.items), {}, "beat %d: no story behind it" % step)
		var row: Dictionary = Journal.rows(state.progression, state.settlement, state.pack.items)[0]
		assert_eq([row["id"], row["title"], row["line"]], [Journal.STORY, "The Night of Ash", line], "beat %d: the journal's row" % step)
		assert_eq(row["lead"], lead, "beat %d: leads where the line does" % step)
		var healer: Dictionary = Journal.rows(state.progression, state.settlement, state.pack.items, {}, true)[0]
		assert_eq(healer["line"], Prologue.objective(step, state.progression.prologue_doused.size(), true), "beat %d: a healer's row says a healer's line, as above the dock" % step)
		assert_eq(goal["who"], people.get(step, ""), "beat %d: who it waits on" % step)
		for survivor: Dictionary in Prologue.survivors():
			assert_eq(Quests.mark_for(survivor["id"], state.progression.quests, state.pack.items, state.questing.quest_open), "", "beat %d: %s offers nothing" % [step, survivor["id"]])
		var cell: Vector2i = goal["cell"]
		match step:
			Prologue.SCAVENGER:
				assert_eq([goal["map_id"], cell], ["overworld", Vector2i(48, 37)], "the thing on the road")
			Prologue.GATE:
				var road := MapData.load_by_id("overworld")
				assert_eq(String(road.portals.get(cell, {}).get("mapId", "")), "town", "the way in")
			Prologue.FIRES:
				assert_eq(town.grid.get(cell, ""), "well", "the well")
			Prologue.CAP:
				assert_eq([goal["map_id"], cell], ["", Bearing.NOWHERE], "worn anywhere")
			_:
				assert_eq(goal["map_id"], "town")
				assert_true(town.is_walkable(cell), "beat %d: on open ground" % step)
	state.progression.prologue = Prologue.DONE
	state.progression.tracked = ""
	assert_eq(Bearing.active(state.progression, state.settlement, state.pack.items)["step"], MainQuest.next_step(state.progression, state.settlement)["text"], "dawn: the story's own step again")
	assert_eq(Quests.mark_for("elder", state.progression.quests, state.pack.items, state.questing.quest_open), "offer", "and her relics to offer")


## PIX-426: a survivor whose turn it isn't sends the hero on without naming
## where; their scene is their own step's. Maren never takes the letter early.
func test_a_survivor_plays_their_scene_only_on_their_step() -> void:
	var said := {}
	for survivor: Dictionary in Prologue.survivors():
		said[survivor["id"]] = survivor
	var letter := "(You hand her the letter.) Vellmar's seal. I wrote to them three times."
	assert_true(letter in Prologue.lines_of(said["elder"], Prologue.MAREN), "her scene on her step")
	for step: int in Prologue.ORDER:
		if step != Prologue.MAREN:
			assert_false(letter in Prologue.lines_of(said["elder"], step), "beat %d: not before it" % step)
	var freed: Array = said["villager_bram"]["prologue"]["lines"]
	assert_eq(Prologue.lines_of(said["villager_bram"], Prologue.BRAM), freed)
	assert_ne(Prologue.lines_of(said["villager_bram"], Prologue.HOUNDS), freed, "still pinned")
	assert_ne(Prologue.lines_of(said["villager_bram"], Prologue.MAREN), freed, "no beam lifted twice")
	assert_ne(Prologue.lines_of(said["innkeeper"], Prologue.BRAM), Prologue.lines_of(said["innkeeper"], Prologue.FIRES), "before and after")
	for id: String in said:
		for step: int in Prologue.ORDER:
			if Prologue.step_of(id) == step:
				continue
			for line: String in Prologue.lines_of(said[id], step):
				for place: String in ["shrine", "square", "Upper Street", "well"]:
					assert_false(place in line, "%s at beat %d names no place: %s" % [id, step, line])
	var wanderer := {"id": "mayor", "lines": ["Hello."]}
	assert_eq(Prologue.lines_of(wanderer, Prologue.BRAM), ["Hello."], "anyone else says their own")


## PIX-506: the hounds' line asked for a roll and the embers' for a skill,
## and each waited for its wave to die: 36 rolls went unanswered. The beat
## is done by the first of what it teaches, and still by the wave's fall.
func test_a_waves_beat_is_done_by_what_it_teaches() -> void:
	assert_eq(Prologue.teaches(Prologue.HOUNDS), "dodge")
	assert_eq(Prologue.teaches(Prologue.EMBERS), "skill")
	for step: int in Prologue.ORDER + [Prologue.DONE]:
		assert_eq(Prologue.teaches(step) != "", not Prologue.wave(step).is_empty(), "only a wave's beat teaches: %d" % step)
		if Prologue.teaches(step) != "":
			# The line names the key of what finishes it, and its answer the place the next beat is done.
			var key := "{key:%s}" % ("skill_1" if Prologue.teaches(step) == "skill" else Prologue.teaches(step))
			assert_string_contains(String(Prologue.data()["steps"][step - 1]["text"]), key)
			assert_eq(String(Prologue.wave(step)["taught"]).get_slice(". ", 1), String(Prologue.wave(step)["cleared"]).get_slice(". ", 1), "where to next, as its fall says")
	state.progression.prologue = Prologue.HOUNDS
	assert_eq(state.questing.prologue_did("skill"), "", "a skill is not the hounds' lesson")
	assert_eq(state.questing.prologue_did(""), "")
	assert_eq(state.progression.prologue, Prologue.HOUNDS)
	assert_string_contains(state.questing.prologue_did("dodge"), "Upper Street")
	assert_eq(state.progression.prologue, Prologue.BRAM, "the first roll, both hounds standing")
	assert_eq(state.questing.prologue_did("dodge"), "", "once")
	assert_eq(state.questing.prologue_wave_cleared(), "", "the hounds falling later move nothing")
	assert_eq(state.progression.prologue, Prologue.BRAM)
	state.progression.prologue = Prologue.EMBERS
	assert_eq(state.questing.prologue_did("dodge"), "", "a roll is not the embers' lesson")
	assert_string_contains(state.questing.prologue_did("skill"), "Maren")
	assert_eq(state.progression.prologue, Prologue.MAREN, "the first skill cast at them")
	# Never rolled, never cast: the wave down still moves the night on.
	state.progression.prologue = Prologue.HOUNDS
	assert_string_contains(state.questing.prologue_wave_cleared(), "Upper Street")
	assert_eq(state.progression.prologue, Prologue.BRAM)


## PIX-507: the line that names the fight's key faded as every fight's does.
func test_the_nights_line_stays_through_its_fights() -> void:
	for step: int in Prologue.ORDER:
		assert_true(Prologue.line_stays(step), "beat %d" % step)
	assert_false(Prologue.line_stays(Prologue.DONE), "after the night a fight fades it, as before (PIX-144)")


## PIX-508: "Open your pack (I) and drink a potion (E)" opened the pack on
## the sword in hand, and E took it off mid-fight.
func test_the_pack_opens_on_the_potion_for_a_hero_hurt_that_night() -> void:
	assert_true(Prologue.hurt(Prologue.HOUNDS, 18, 42))
	assert_false(Prologue.hurt(Prologue.HOUNDS, 21, 42), "half or more: no hint, the pack as it opens")
	assert_false(Prologue.hurt(Prologue.HOUNDS, 0, 42), "fallen")
	assert_false(Prologue.hurt(Prologue.DONE, 5, 42), "the night's hint only")
	state.pack.add_item("potion_hp")
	var rows: Array = state.pack.listing("all")
	assert_eq(rows[0]["kind"], "gear", "the pack opens on the gear in hand")
	var at := Prologue.potion_row(rows)
	assert_eq(String(rows[at]["item_id"]), "potion_hp", "the row E drinks")
	state.pack.add_item("bread")
	rows = state.pack.listing("all", "name")
	assert_eq(String(rows[Prologue.potion_row(rows)]["item_id"]), "potion_hp", "the potion before food, however the pack is sorted")
	state.pack.items.erase("potion_hp")
	rows = state.pack.listing("all")
	assert_eq(String(Catalog.item(rows[Prologue.potion_row(rows)]["item_id"])["category"]), "food", "no potion: what else mends")
	for item_id: String in state.pack.items.keys():
		if Catalog.item(item_id).has("restoreHp"):
			state.pack.items.erase(item_id)
	assert_eq(Prologue.potion_row(state.pack.listing("all")), -1, "nothing that mends: the pack as it opens")


## PIX-505: the prompt stood over the roof, three cells from a hero below
## the well, and under the rim, on bare ground, for one facing down at it.
func test_the_wells_prompt_sits_on_its_roof() -> void:
	var size := Vector2(12, 14)
	# Shade's well: two cells wide, its roof two tall over the rim.
	var well := Rect2(Vector2(34, 29) * MapView.TILE, Vector2(2, 3) * MapView.TILE)
	var roof := Rect2(well.position, Vector2(2, 2) * MapView.TILE)
	for at: Array in [[Vector2i(35, 31), false], [Vector2i(35, 29), true], [Vector2i(34, 30), false]]:
		var spot := Interaction.well_spot(well, at[0], size, at[1])
		assert_true(roof.encloses(Rect2(spot, size).grow(1.0)), "on the roof, its bob too, facing %s" % [at[0]])
		assert_eq(Rect2(spot, size).get_center().x, well.get_center().x, "in its middle")
	# Without the pack the well is its one cell: the prompt as anything's.
	var small := Rect2(Vector2(34, 31) * MapView.TILE, Vector2.ONE * MapView.TILE)
	for below: bool in [false, true]:
		assert_eq(Interaction.well_spot(small, Vector2i(34, 31), size, below), Interaction.prompt_spot(small, Vector2i(34, 31), size, below))


## PIX-506: the hounds, rolled past, give up the chase and stand at the gate
## through the rest of the night. They are not the embers' wave: the embers'
## fall finishes their beat, and a skill cast with only hounds up does not.
func test_a_wave_counts_only_its_own_beats_foes() -> void:
	var mobs: Array[Node] = []
	for step: int in [Prologue.HOUNDS, Prologue.HOUNDS, Prologue.EMBERS, Prologue.EMBERS]:
		var foe: Node = autofree(Node.new())
		foe.set_meta("prologue_wave", step)
		mobs.append(foe)
	mobs.append(autofree(Node.new()))
	assert_eq(Stage.wave_left(mobs, Prologue.EMBERS), mobs.slice(2, 4), "the embers alone, no hound, no wild foe")
	assert_eq(Stage.wave_left(mobs, Prologue.EMBERS, mobs[3]), [mobs[2]], "but the one falling")
	mobs.remove_at(2)
	assert_eq(Stage.wave_left(mobs, Prologue.EMBERS, mobs[2]), [], "the last ember down, both hounds standing: the wave is down")
	assert_eq(Stage.wave_left(mobs.slice(0, 2), Prologue.EMBERS), [], "only hounds up: no ember's wave for a skill to answer")
	assert_eq(Stage.wave_left(mobs, Prologue.DONE), [], "nothing untagged is a wave, the night done")
