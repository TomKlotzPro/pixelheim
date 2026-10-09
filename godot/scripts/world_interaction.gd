class_name Interaction
extends Node
## What E does in the world (Solid Ground, PIX-260: moved out of world.gd as
## it was), in the web's INTERACT order: the well's water on the Night of
## Ash, a faced chest, the house's door and fixtures, a fishing spot, the
## square's boards, then the villager beside the hero (a keeper's counter, a
## stall, the bank, or a talk). What the hero steps on is picked up (ground
## treasure, patches), and the prompt floats over whatever E would meet.
## The screens it opens, and the prompt, stand on the world as before.

var world: Node
## A bucket of the well's water in hand, on the Night of Ash (PIX-197).
var prologue_bucket := false
## What floats over a faced villager, chest or fishing spot: the interact
## key as a keycap (PIX-193), or "!" on a phone, which has its Use button.
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
	if not chest.is_empty() and chest["look"] == "chest" and not GameState.is_opened(chest):
		_open_chest(chest)
		return
	if world.map.id == "town" and faced == Town.house_door():
		if Town.ashes_tent(Town.done_projects(GameState.settlement)).x >= 0:
			world.messages.flash("Only cinders where the house stood. The board on the square can change that.")
		elif GameState.owns_house():
			world.enter_house()
		elif GameState.pack.gold >= int(Town._data()["houseDeedCost"]) and not _asked_twice("deed"):
			# A big buy asks first (PIX-179).
			world.messages.flash(Controls.say(Text.t("The deed costs %d gold. {key:interact} again to sign it.") % int(Town._data()["houseDeedCost"])))
		else:
			world.messages.flash(GameState.buy_house())
		return
	if world.map.id == "town_house" and _house_interact(faced):
		return
	# A fishing spot facing the water: cast (PIX-165).
	if _fishing_here():
		Sound.play("drop")
		world.messages.flash(GameState.fish(Gathering.fishing_spot_at(world.map.id, world.player_cell)["id"]))
		return
	# The projects board on the square opens the village's ledger (PIX-145);
	# what it built, the town shows off as it closes (PIX-147).
	if world.map.id == "town" and faced == Town.project_board():
		var ledger := preload("res://scripts/town_hall_screen.gd").new()
		ledger.tree_exited.connect(world.after_board)
		world.add_child(ledger)
		return
	# Beside it, the bounties on the named monsters (PIX-156).
	if world.map.id == "town" and faced == Town.bounty_board():
		world.add_child(preload("res://scripts/bounty_screen.gd").new())
		return
	var beside: Dictionary = world.folk.beside()
	if not beside.is_empty():
		world.player.face(Vector2(beside["side"]))
		# Keepers trade instead of chatting: anyone in a shop opens its counter
		# (unless they have a quest to offer or take back: then they talk, and
		# the next word opens the counter), a settled Mirelle her bank (her
		# arc's asks first, PIX-157). The
		# mayor talks, then opens the projects ledger (see talk).
		var quest_word := Quests.awaits_word(beside["npc"]["id"], GameState.progression.quests, GameState.pack.items, GameState.quest_open)
		var at_stall: bool = world.map.id == "town" and beside["npc"].has("stall") and beside["npc"]["mapId"] == "town"
		# A trader out in the Reach (PIX-176) sells from their own pack.
		var trader: String = beside["npc"].get("shop", "")
		if trader != "" and not quest_word:
			_open_stall(trader)
		elif at_stall and not quest_word:
			# A keeper on the burnt square (PIX-146): Sela's tent takes a
			# guest for the night, the others trade from their stalls.
			if beside["npc"]["id"] == "innkeeper":
				world.messages.flash(GameState.rest_at_inn())
				world.dream()
			else:
				_open_stall(Economy.shop_at(String(Npcs.by_id(beside["npc"]["id"], []).get("mapId", ""))))
		elif GameState.active_shop() != "" and not quest_word:
			_open_shop()
		elif beside["npc"]["id"] == "settler_mirelle" and GameState.is_settled("settler_mirelle") and not quest_word:
			world.add_child(preload("res://scripts/bank_screen.gd").new())
			world.hint("bank")
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
	var text := GameState.place_furniture(item_id, cell, _tile_in_hand(cell))
	if text != "":
		world.messages.flash(text)
	world.view.furnish()


func _asked_twice(key: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if _asked.has(key) and now - float(_asked[key]) < 6.0:
		_asked.erase(key)
		return true
	_asked[key] = now
	return false


## The house's fixtures and furniture; true when E meant one of them.
func _house_interact(cell: Vector2i) -> bool:
	# The workbench is a big buy: it asks first (PIX-179).
	var cost := int(Town._data()["workbenchCost"])
	if _tile_in_hand(cell) == "shelf" and GameState.furniture_at(cell).is_empty() and not GameState.settlement.house.get("workbench", false) \
			and GameState.pack.gold >= cost and not _asked_twice("workbench"):
		world.messages.flash(Controls.say(Text.t("A workbench for this shelf: %d gold. It counts as a trade level more when you craft at home. {key:interact} again to buy it.") % cost))
		return true
	var result := GameState.house_interact(cell, _tile_in_hand(cell))
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


## On a fishing spot, facing the water (PIX-165).
func _fishing_here() -> bool:
	if Gathering.fishing_spot_at(world.map.id, world.player_cell).is_empty():
		return false
	return world.map.tile_at(facing_cell()) in PunyTerrain.WATERS


func _open_shop() -> void:
	world.add_child(preload("res://scripts/shop_screen.gd").new())


## A stall's counter: the shop as if in its building, until the screen closes.
func _open_stall(shop_id: String) -> void:
	GameState.stall_shop = shop_id
	var screen := preload("res://scripts/shop_screen.gd").new()
	screen.tree_exited.connect(func() -> void: GameState.stall_shop = "")
	world.add_child(screen)


func talk(npc: Dictionary) -> void:
	var box := preload("res://scripts/dialogue_box.gd").new()
	# On the night of the fire the survivors say only the night's lines.
	if GameState.progression.prologue != Prologue.DONE:
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
			world.messages.flash(GameState.choose(asking["id"], asking["choice"]["options"][index]["id"]))
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
	var offer := GameState.quest_on_offer(npc["id"])
	if not offer.is_empty() and String(offer.get("accepted", "")) != "":
		npc = npc.duplicate()
		npc["lines"] = npc["lines"] + [offer["accepted"]]
	box.npc = npc
	world.add_child(box)


func _open_chest(chest: Dictionary) -> void:
	var result := GameState.open_chest(chest)
	world.messages.flash(result["message"])
	if not result["opened"]:
		return
	var sprite: Sprite2D = world.view.chest_sprites[chest["id"]]
	if result["mimic"]:
		world.foes.mimic_wakes(sprite, chest)
		return
	sprite.texture = MapView.treasure_texture(chest, true)
	Sound.play("chest")


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
		world.messages.flash(GameState.prologue_douse(i))
		if GameState.progression.prologue == Prologue.EMBERS:
			world.prologue_wave.call_deferred()
		return true
	return false


## The hero stepped onto `cell`: ground treasure there is picked up, and a
## patch is gathered.
func step_on(cell: Vector2i) -> void:
	_collect_ground_treasure(cell)
	_gather_at(cell)


## A patch underfoot is picked (PIX-143).
func _gather_at(cell: Vector2i) -> void:
	var patch: Dictionary = world.view.patches.get(cell, {})
	if patch.is_empty():
		return
	var lines := GameState.gather(patch["id"], patch["item"])
	if lines.is_empty():
		return
	Sound.play("drop")
	world.messages.log_lines(lines)
	world.view.refresh_patches()


func _collect_ground_treasure(cell: Vector2i) -> void:
	var chest := _chest_at(cell)
	if chest.is_empty() or chest["look"] == "chest" or GameState.is_opened(chest):
		return
	var result := GameState.open_chest(chest)
	world.messages.flash(result["message"])
	if result["opened"]:
		world.view.chest_sprites[chest["id"]].queue_free()
		world.view.chest_sprites.erase(chest["id"])


## The one interaction-prompt rule (interactionPrompt.ts): a villager beside
## the hero wins, then a faced unopened chest; the "!" floats over their head.
func update_prompt() -> void:
	var beside: Dictionary = world.folk.beside()
	if not beside.is_empty():
		_show_prompt(world.player_cell + Vector2i(beside["side"]), -18)
		return
	var chest := _chest_at(facing_cell())
	var show: bool = (
		not chest.is_empty() and chest["look"] == "chest" and not GameState.is_opened(chest)
	) or _fishing_here()
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
	var bob := roundf(sin(Time.get_ticks_msec() / 260.0)) if not GameState.settings.reduce_motion else 0.0
	var size := prompt_label.size
	prompt_label.position = Vector2(cell * MapView.TILE) + Vector2(roundf((MapView.TILE - size.x) / 2.0), rise - size.y + 16 + bob)


func _interact_key() -> String:
	return Controls.key_label(Controls.key_for("interact", GameState.settings.bindings))
