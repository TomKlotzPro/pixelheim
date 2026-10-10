class_name Interaction
extends Node
## What E does in the world (Solid Ground, PIX-260: moved out of world.gd as
## it was), in the web's INTERACT order: the well's water on the Night of
## Ash, a faced chest, a letter's answer waiting to be read and a dungeon's
## set piece's words (PIX-255), the house's door and fixtures, a trade's
## station (a
## forge, an anvil, a cauldron: PIX-234), the stairs down to a cellar
## (PIX-256), a fishing spot, the square's boards, then the villager beside
## the hero (a keeper's counter, a stall, the bank, or a talk). What the
## hero steps on is picked up (ground treasure, patches), and the prompt
## floats over whatever E would meet. The screens it opens, and the prompt,
## stand on the world as before.

var world: Node
## A bucket of the well's water in hand, on the Night of Ash (PIX-197).
var prologue_bucket := false
## What floats over a faced villager, chest, station or fishing spot: the
## interact key as a keycap (PIX-193), or "!" on a phone, which has its Use
## button.
var prompt_label: Control
## A big buy asked twice (PIX-179): true when this is the second E on the
## same thing within a few seconds, else it remembers this one.
var _asked := {}


## The prompt, hidden until there's something to meet.
func build_prompt() -> void:
	if Touch.enabled():
		var mark := Label.new()
		mark.text = "!"
		mark.add_theme_font_size_override("font_size", 10)
		mark.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		mark.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12))
		mark.add_theme_constant_override("outline_size", 3)
		prompt_label = mark
	else:
		prompt_label = UiStyle.world_keycap(_interact_key())
	prompt_label.visible = false
	prompt_label.z_index = 50
	# Words in the world stay readable at night (PIX-221).
	Lights.unshade(prompt_label)
	world.add_child(prompt_label)


func _chest_at(cell: Vector2i) -> Dictionary:
	for chest: Dictionary in Interactables.chests_on(world.map.id):
		if int(chest["x"]) == cell.x and int(chest["y"]) == cell.y:
			return chest
	return {}


func facing_cell() -> Vector2i:
	return world.player_cell + Vector2i(world.player.facing)


## E in the web's INTERACT order: a faced chest, the house door, the house's
## fixtures, then the villager beside the hero (turning to face them).
func interact() -> void:
	var faced := facing_cell()
	if world.map.id == "town" and GameState.progression.prologue == Prologue.FIRES and _carry_water(faced):
		return
	var chest := _chest_at(faced)
	if not chest.is_empty() and chest["look"] == "chest" and not GameState.spoils.is_opened(chest):
		_open_chest(chest)
		return
	# A letter's answer that waits where it was written (PIX-255: Captain
	# Hale's order book, on his table).
	var reading := Letters.reading_at(world.map.id, faced)
	if not reading.is_empty():
		read(reading)
		return
	# What a region dungeon's set piece says, faced (PIX-255: the wreck).
	if world.map.notes.has(faced):
		world.messages.flash(String(world.map.notes[faced]))
		return
	if world.map.id == "town" and faced == Town.house_door():
		if Town.ashes_tent(Town.done_projects(GameState.settlement)).x >= 0:
			world.messages.flash("Only cinders where the house stood. The board on the square can change that.")
		elif GameState.household.owns_house():
			world.enter_house()
		elif GameState.pack.gold >= int(Town._data()["houseDeedCost"]) and not _asked_twice("deed"):
			# A big buy asks first (PIX-179).
			world.messages.flash(Controls.say(Text.t("The deed costs %d gold. {key:interact} again to sign it.") % int(Town._data()["houseDeedCost"])))
		else:
			world.messages.flash(GameState.household.buy_house())
		return
	if world.map.id == "town_house" and _house_interact(faced):
		return
	# A bed at the inn: a night's sleep for coin (PIX-246).
	if world.map.id == "town_inn" and _tile_in_hand(faced) == "bed":
		_sleep_at_inn()
		return
	if _station(faced):
		return
	# The stairs down to the cellar (PIX-256) ask whether to go.
	var map: MapData = world.map
	if Ways.goes_down(map, faced):
		ask_down(faced)
		return
	# A fishing spot facing the water: cast (PIX-165). The catch rises out of
	# the water faced (PIX-245).
	if _fishing_here():
		Sound.play("drop")
		var cast := GameState.spoils.fish(Gathering.fishing_spot_at(world.map.id, world.player_cell)["id"])
		world.messages.flash(cast["message"])
		world.messages.log_lines(cast["lines"])
		world.fx.show_gains(cast["gains"], MapView.center(faced) + WorldFx.OVER_THING)
		return
	# The projects board on the square opens the village's ledger (PIX-145);
	# what it built, the town shows off as it closes (PIX-147).
	if world.map.id == "town" and faced == Town.project_board():
		var ledger := preload("res://scripts/town_hall_screen.gd").new()
		ledger.tree_exited.connect(world.stage.after_board)
		world.add_child(ledger)
		return
	# Beside it, the bounties on the named monsters (PIX-156).
	if world.map.id == "town" and faced == Town.bounty_board():
		world.add_child(preload("res://scripts/bounty_screen.gd").new())
		return
	# A gate the story keeps shut says again what opens it (PIX-254).
	var gate := _gate_at(faced)
	if not gate.is_empty():
		_say_gate(gate)
		return
	var beside: Dictionary = world.folk.beside()
	if not beside.is_empty():
		world.player.face(Vector2(beside["side"]))
		# Keepers trade instead of chatting: anyone in a shop opens its counter
		# (unless they have a quest to offer or take back: then they talk, and
		# the next word opens the counter), a settled Mirelle her bank (her
		# arc's asks first, PIX-157). The
		# mayor talks, then opens the projects ledger (see talk).
		var quest_word := Quests.awaits_word(beside["npc"]["id"], GameState.progression.quests, GameState.pack.items, GameState.questing.quest_open)
		var at_stall: bool = world.map.id == "town" and beside["npc"].has("stall") and beside["npc"]["mapId"] == "town"
		# A trader out in the Reach (PIX-176) sells from their own pack.
		var trader: String = beside["npc"].get("shop", "")
		if trader != "" and not quest_word:
			_open_stall(trader)
		elif at_stall and not quest_word:
			# A keeper on the burnt square (PIX-146): Sela's tent takes a
			# guest for the night, the others trade from their stalls.
			if beside["npc"]["id"] == "innkeeper":
				_sleep_at_inn()
			else:
				_open_stall(Economy.shop_at(String(Npcs.by_id(beside["npc"]["id"], []).get("mapId", ""))))
		elif GameState.trade.active_shop() != "" and not quest_word:
			_open_shop()
		elif beside["npc"]["id"] == "settler_mirelle" and GameState.holdings.is_settled("settler_mirelle") and not quest_word:
			world.add_child(preload("res://scripts/bank_screen.gd").new())
			world.hud.hint("bank")
		else:
			talk(beside["npc"])
		return


## What the hero's hands meet on a cell: the furniture drawn over it (a
## bed's foot is the bed: E rests there, nothing can be set on it), else the
## web's tile.
func _tile_in_hand(cell: Vector2i) -> String:
	return world.view.buildings.get("over", {}).get(cell, world.map.tile_at(cell))


## Furniture from the pack onto the floor tile the hero faces (PLACE_FURNITURE).
func place_from_pack(item_id: String) -> void:
	var cell := facing_cell()
	var text := GameState.household.place_furniture(item_id, cell, _tile_in_hand(cell))
	if text != "":
		world.messages.flash(text)
	world.view.furnish()


func _asked_twice(key: String) -> bool:
	var now := GameClock.seconds()
	if _asked.has(key) and now - float(_asked[key]) < 6.0:
		_asked.erase(key)
		return true
	_asked[key] = now
	return false


## The house's fixtures and furniture; true when E meant one of them.
func _house_interact(cell: Vector2i) -> bool:
	# Your own bed: a night's sleep, till morning (PIX-246).
	if _tile_in_hand(cell) == "bed" and GameState.household.furniture_at(cell).is_empty():
		world.sleep_through(func() -> void:
			world.messages.flash(GameState.household.house_interact(cell, "bed")["text"]))
		return true
	# The workbench is a big buy: it asks first (PIX-179).
	var cost := int(Town._data()["workbenchCost"])
	if _tile_in_hand(cell) == "shelf" and GameState.household.furniture_at(cell).is_empty() and not GameState.settlement.house.get("workbench", false) \
			and GameState.pack.gold >= cost and not _asked_twice("workbench"):
		world.messages.flash(Controls.say(Text.t("A workbench for this shelf: %d gold. It counts as a trade level more when you craft at home. {key:interact} again to buy it.") % cost))
		return true
	var result := GameState.household.house_interact(cell, _tile_in_hand(cell))
	if result.is_empty():
		return false
	if result.has("text"):
		world.messages.flash(result["text"])
	if result.has("panel"):
		var screen := preload("res://scripts/home_screen.gd").new()
		screen.mode = result["panel"]
		screen.cell = cell
		screen.on_placed = world.view.furnish
		world.add_child(screen)
	world.view.furnish()
	return true


## A station faced (PIX-234: E at them was silent, and nothing in the room
## said crafting is at the counter): a forge, an anvil or a cauldron opens
## its keeper's counter on the Craft tab, that trade's recipes; the inn's
## hearth, which cooks nothing a hero can, says where the stew is brewed.
## True when E meant one.
func _station(cell: Vector2i) -> bool:
	match _station_at(cell):
		"":
			return false
		"hearth":
			world.messages.flash(Text.t("Sela's stew simmers over the fire. Hunter's Stew is brewed at Vex's cauldron, behind the BREWS door."))
		_:
			_open_shop("Craft")
	return true


## A letter's answer read where it was written (PIX-255, chapter 4: Captain
## Hale's order book, the last page he wrote). Shut until its letter is
## delivered; the first time, its page in a conversation, kept in the story
## ledger as it closes (a main quest step); a short word after.
func read(reading: Dictionary) -> void:
	var lines := Letters.reading_lines(reading, GameState.progression)
	if not Letters.reads_now(reading, GameState.progression):
		world.messages.flash(String(lines[0]))
		return
	var scene_id := String(reading["sceneId"])
	GameState.dialogue_closed.connect(func(_who: String) -> void: GameState.mark_seen(scene_id), CONNECT_ONE_SHOT)
	var box := preload("res://scripts/dialogue_box.gd").new()
	box.npc = {"id": scene_id, "name": String(reading["name"]), "lines": lines}
	world.add_child(box)
	Sound.play_ui("page")


## The stairs down from a room to the cellar under it (PIX-256: a house
## opened straight onto a dungeon): where they go, asked as a question with
## no face; going down takes them, staying (or Esc) leaves the hero at the
## top.
func ask_down(cell: Vector2i) -> void:
	var map: MapData = world.map
	var question := Ways.going_down(map, cell)
	var target: Dictionary = map.portals[cell]
	var box := preload("res://scripts/dialogue_box.gd").new()
	box.npc = {"id": question["id"], "name": question["name"], "lines": question["lines"]}
	box.choices = question["choices"]
	box.on_choice = func(index: int) -> void:
		if index == 0:
			world.use_portal(target)
	world.add_child(box)


## A night at the inn (PIX-246): in one of its beds, or in Sela's tent before
## it's rebuilt. With the coin, the screen goes dark, the night passes and
## Morvax may speak in a dream (PIX-154); without it, Sela says the price.
func _sleep_at_inn() -> void:
	if GameState.pack.gold < Town.rest_cost_for(GameState.town_tier()):
		world.messages.flash(GameState.upkeep.rest_at_inn())
		return
	world.sleep_through(func() -> void:
		world.messages.flash(GameState.upkeep.rest_at_inn())
		world.stage.dream())


## A bed E can sleep in (PIX-246): the inn's, or your own.
func _bed_at(cell: Vector2i) -> bool:
	return world.map.id in ["town_inn", "town_house"] and _tile_in_hand(cell) == "bed"


## What a cell is to E as a station: its trade ("smithing", "alchemy"),
## "hearth" for the inn's, else "". Read through the furniture drawn over
## it, so the forge's right half is the forge too.
func _station_at(cell: Vector2i) -> String:
	var tile := _tile_in_hand(cell)
	if world.map.id == "town_inn" and tile == "hearth":
		return "hearth"
	return Economy.station_job(world.map.id, tile)


## On a fishing spot, facing the water (PIX-165).
func _fishing_here() -> bool:
	if Gathering.fishing_spot_at(world.map.id, world.player_cell).is_empty():
		return false
	return world.map.tile_at(facing_cell()) in PunyTerrain.WATERS


## The keeper's counter, on `tab` when named (a station opens "Craft").
func _open_shop(tab := "") -> void:
	var screen := preload("res://scripts/shop_screen.gd").new()
	screen.start_tab = tab
	world.add_child(screen)


## A stall's counter: the shop as if in its building, until the screen closes.
func _open_stall(shop_id: String) -> void:
	GameState.trade.stall_shop = shop_id
	var screen := preload("res://scripts/shop_screen.gd").new()
	screen.tree_exited.connect(func() -> void: GameState.trade.stall_shop = "")
	world.add_child(screen)


func talk(npc: Dictionary) -> void:
	var box := preload("res://scripts/dialogue_box.gd").new()
	# On the night of the fire the survivors say only the night's lines.
	if GameState.progression.prologue != Prologue.DONE:
		box.npc = npc
		world.add_child(box)
		return
	# The first word with Maren after the night is her tin (PIX-253): dug
	# out of her hearth together while her house is ash, a short word for a
	# hero who comes to her later. Closing it gives the letters (Questing).
	if npc["id"] == "elder" and Letters.tin_waits(GameState.progression):
		npc = npc.duplicate()
		npc["lines"] = Letters.tin_lines(Town.done_projects(GameState.settlement))
		box.npc = npc
		world.add_child(box)
		return
	# A letter carried to them (PIX-253): their answer, and as it closes the
	# letter is theirs.
	var letter := GameState.questing.letter_for(npc["id"])
	if not letter.is_empty():
		npc = npc.duplicate()
		npc["lines"] = letter["answer"]
		box.npc = npc
		world.add_child(box)
		return
	# Maren tells what the hero's floors have earned, once each (PIX-153).
	if npc["id"] == "elder":
		var told := Story.elder_story(GameState.progression.cleared_levels, GameState.progression.story_seen, GameState.progression.hunted)
		if not told.is_empty():
			npc = npc.duplicate()
			npc["lines"] = told["lines"]
			GameState.dialogue_closed.connect(func(_who: String) -> void: GameState.mark_seen(told["id"]), CONNECT_ONE_SHOT)
			box.npc = npc
			world.add_child(box)
			return
	# A quest that ends in a choice asks it now (PIX-192): its question, an
	# answer for each key; leaving without one keeps it waiting.
	var asking := Quests.pending_choice(npc["id"], GameState.progression.quests, GameState.pack.items)
	if not asking.is_empty():
		npc = npc.duplicate()
		npc["lines"] = asking["choice"]["prompt"]
		box.choices = asking["choice"]["options"].map(func(option: Dictionary) -> String: return option["label"])
		box.on_choice = func(index: int) -> void:
			world.messages.flash(GameState.questing.choose(asking["id"], asking["choice"]["options"][index]["id"]))
		box.npc = npc
		world.add_child(box)
		return
	# A choice made stays with the one who asked it (PIX-192).
	var remembered := Quests.after_choice(npc["id"], GameState.progression.quests)
	if remembered != "":
		npc = npc.duplicate()
		npc["lines"] = [remembered] + npc["lines"]
	# Townsfolk talk about the hero's latest deed first (PIX-149).
	var reaction := Npcs.reaction(npc, GameState.last_deed)
	if reaction != "":
		npc = npc.duplicate()
		npc["lines"] = [reaction] + npc["lines"]
	# And about the letters going out (PIX-253: Bram's crew and the road).
	var news := Letters.news_for(npc["id"], GameState.progression)
	if news != "":
		npc = npc.duplicate()
		npc["lines"] = [news] + npc["lines"]
	# The elder and the mayor always know what comes next (PIX-144).
	if npc["id"] in ["elder", "mayor"]:
		var next := MainQuest.hint(GameState.progression, GameState.settlement, npc["id"])
		if next != "":
			npc = npc.duplicate()
			npc["lines"] = npc["lines"] + [next]
	# The festival's barker has his say, then the ring toss (PIX-159).
	if npc["id"] == "festival_barker":
		GameState.dialogue_closed.connect(func(_who: String) -> void:
			world.add_child(preload("res://scripts/ring_toss_screen.gd").new()), CONNECT_ONE_SHOT)
	# The mayor has his say, then opens the projects ledger (PIX-145).
	if npc["id"] == "mayor":
		GameState.dialogue_closed.connect(func(_who: String) -> void:
			world.add_child(preload("res://scripts/town_hall_screen.gd").new()), CONNECT_ONE_SHOT)
	# The giver asks it themselves before it's taken (PIX-202).
	var offer := GameState.questing.quest_on_offer(npc["id"])
	if not offer.is_empty() and String(offer.get("accepted", "")) != "":
		npc = npc.duplicate()
		npc["lines"] = npc["lines"] + [offer["accepted"]]
	box.npc = npc
	world.add_child(box)


func _open_chest(chest: Dictionary) -> void:
	var result := GameState.spoils.open_chest(chest)
	world.messages.flash(result["message"])
	if not result["opened"]:
		return
	var sprite: Sprite2D = world.view.chest_sprites[chest["id"]]
	if result["mimic"]:
		world.foes.mimic_wakes(sprite, chest)
		return
	sprite.texture = MapView.treasure_texture(chest, true)
	Sound.play("chest")
	# What it held rises out of it (PIX-245).
	world.fx.show_gains(result["gains"], MapView.center(Vector2i(int(chest["x"]), int(chest["y"]))) + WorldFx.OVER_THING)


## The fires beat (PIX-197): the well fills a bucket; a burning home's
## frame, faced with one, puts that fire out. True when the cell was either.
func _carry_water(faced: Vector2i) -> bool:
	var fires: Dictionary = Prologue.data()["fires"]
	if world.map.tile_at(faced) == "well":
		prologue_bucket = true
		Sound.play("drop")
		world.messages.flash(String(fires["well"]))
		return true
	var ruins := Town.ruins(Town.done_projects(GameState.settlement))
	for i in ruins.size():
		var rect: Rect2i = ruins[i]["rect"]
		if not rect.has_point(faced) or i in GameState.progression.prologue_doused:
			continue
		if not prologue_bucket:
			world.messages.flash(String(fires["empty"]))
			return true
		prologue_bucket = false
		world.view.douse_ruin(i)
		Sound.play("heal")
		world.messages.flash(GameState.questing.prologue_douse(i))
		if GameState.progression.prologue == Prologue.EMBERS:
			world.stage.prologue_wave.call_deferred()
		return true
	return false


## The hero stepped onto `cell`: ground treasure there is picked up, a
## patch is gathered, and a gate the story keeps shut says what opens it.
func step_on(cell: Vector2i) -> void:
	_collect_ground_treasure(cell)
	_gather_at(cell)
	_near_gate(cell)


## The gate that spoke last, while the hero is still near it, and the last
## one that spoke on this run (the harness reports it).
var _gate_near := ""
var gate_said := ""


## Walking up to a gate still shut (PIX-254): its line, once, until the hero
## has gone a few steps away from it.
func _near_gate(cell: Vector2i) -> void:
	var beside := ""
	var still_near := false
	for gate: Dictionary in world.view.gates:
		var off := 1 << 20
		for at: Vector2i in Gates.cells_of(gate):
			off = mini(off, maxi(absi(at.x - cell.x), absi(at.y - cell.y)))
		if off <= 1 and beside == "":
			beside = gate["id"]
		if gate["id"] == _gate_near and off < 4:
			still_near = true
	if not still_near:
		_gate_near = ""
	if beside != "" and beside != _gate_near:
		_gate_near = beside
		_say_gate(Gates.by_id(beside))


## A shut gate's line, on the message plate.
func _say_gate(gate: Dictionary) -> void:
	gate_said = gate["id"]
	world.messages.flash(Gates.line(gate, GameState.progression, GameState.settlement))


## The shut gate on `cell` of this visit, or {}.
func _gate_at(cell: Vector2i) -> Dictionary:
	for gate: Dictionary in world.view.gates:
		if cell in Gates.cells_of(gate):
			return gate
	return {}


## A patch underfoot is picked (PIX-143); what it gave rises over the hero
## standing in it (PIX-245).
func _gather_at(cell: Vector2i) -> void:
	var patch: Dictionary = world.view.patches.get(cell, {})
	if patch.is_empty():
		return
	var picked := GameState.spoils.gather(patch["id"], patch["item"])
	if Gains.is_empty(picked["gains"]):
		return
	Sound.play("drop")
	world.messages.log_lines(picked["lines"])
	world.fx.show_gains(picked["gains"], MapView.center(cell) + WorldFx.OVER_HERO)
	world.view.refresh_patches()


## Treasure underfoot (a glint on the road, herbs): picked up, and what it
## was rises over the hero (PIX-245).
func _collect_ground_treasure(cell: Vector2i) -> void:
	var chest := _chest_at(cell)
	if chest.is_empty() or chest["look"] == "chest" or GameState.spoils.is_opened(chest):
		return
	var result := GameState.spoils.open_chest(chest)
	world.messages.flash(result["message"])
	if result["opened"]:
		world.view.chest_sprites[chest["id"]].queue_free()
		world.view.chest_sprites.erase(chest["id"])
		world.fx.show_gains(result["gains"], MapView.center(cell) + WorldFx.OVER_HERO)


## The one interaction-prompt rule (interactionPrompt.ts): a villager beside
## the hero wins, then a faced unopened chest, a station (PIX-234), the
## water from a fishing spot, a bed or the stairs down (PIX-256); the "!"
## floats over their head.
func update_prompt() -> void:
	var beside: Dictionary = world.folk.beside()
	if not beside.is_empty():
		_show_prompt(world.player_cell + Vector2i(beside["side"]), -18)
		return
	var chest := _chest_at(facing_cell())
	var map: MapData = world.map
	var show: bool = (
		not chest.is_empty() and chest["look"] == "chest" and not GameState.spoils.is_opened(chest)
	) or _fishing_here() or _station_at(facing_cell()) != "" or _bed_at(facing_cell()) or Ways.goes_down(map, facing_cell()) or map.notes.has(facing_cell()) \
			or not Letters.reading_at(map.id, facing_cell()).is_empty()
	if show:
		_show_prompt(facing_cell(), -12)
	else:
		prompt_label.visible = false


## The prompt over `cell`, its bottom `rise` pixels above the cell's top,
## bobbing a pixel; the key read fresh (it may have been rebound).
func _show_prompt(cell: Vector2i, rise: int) -> void:
	if prompt_label is Keycap and not prompt_label.visible:
		(prompt_label as Keycap).show_key(_interact_key())
		prompt_label.reset_size()
	prompt_label.visible = true
	var bob := roundf(sin(GameClock.msec() / 260.0)) if not GameState.settings.reduce_motion else 0.0
	var size := prompt_label.size
	prompt_label.position = Vector2(cell * MapView.TILE) + Vector2(roundf((MapView.TILE - size.x) / 2.0), rise - size.y + 16 + bob)


func _interact_key() -> String:
	return Controls.key_label(Controls.key_for("interact", GameState.settings.bindings))
