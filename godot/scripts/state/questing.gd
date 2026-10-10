class_name Questing
extends RefCounted
## Quests, conversations and the Night of Ash (PIX-261, out of
## game_state.gd): what a giver offers and what closing a conversation
## resolves, choices, escorts and timed runs, deliveries' progress and the ask
## before spending what one needs, deeds, and each beat of the prologue. It
## holds only what is never saved (each delivery's count at the last look,
## the ask before a dip); the quests are GameState's progression, reached
## through `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one. Signals are its too.
var owner: GameStateScript


## What each accepted delivery had at the last look (PIX-206), so a pickup
## that brings one closer can say so.
var _delivered := {}
## The spend ask_before_dip last asked about, and when: the same again
## within DIP_CONFIRM_SECONDS goes ahead.
var _dip_asked := ""
var _dip_asked_at := -10.0
const DIP_CONFIRM_SECONDS := 4.0


func _init(state: GameStateScript) -> void:
	owner = state


## The quest a giver is about to offer (PIX-202): their next one not done,
## if it's untaken and open; {} otherwise. Its "accepted" line is their ask.
func quest_on_offer(giver_id: String) -> Dictionary:
	# A recruit waiting on a grown town asks nothing yet.
	var recruit := Town.recruit(giver_id)
	if not recruit.is_empty() and not owner.holdings.is_settled(giver_id) and Town.recruit_blocker(recruit, owner.town_tier()) == "tier":
		return {}
	for quest: Dictionary in Quests.for_giver(giver_id):
		var entry: Dictionary = owner.progression.quests.get(quest["id"], {})
		if entry.get("done", false):
			continue
		if entry.is_empty() and quest.get("unlessGateOpen", false) and Relics.gate_open(owner.progression):
			continue
		return quest if entry.is_empty() and quest_open(quest) else {}
	return {}


## Whether the hero's first skill mends rather than strikes (a cleric's Mend):
## the night's lines say so (PIX-205).
func first_skill_heals() -> bool:
	var skills := Skills.hero_skills(owner.hero)
	return not skills.is_empty() and skills[0]["kind"] == "heal"


## Whether a quest may be offered yet (PIX-171): its "opensAfter" is met,
## and Maren's relics aren't asked of a hero who climbed before the gate
## was barred.
func quest_open(quest: Dictionary) -> bool:
	if quest.get("unlessGateOpen", false) and Relics.gate_open(owner.progression) and not owner.progression.quests.has(quest["id"]):
		return false
	return Quests.is_open(quest, owner.progression, owner.settlement)


## The givers on a map with a word for the hero (PIX-171): a quest to offer
## or one to turn in. The map marks them.
func givers_waiting(npcs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc: Dictionary in npcs:
		if Quests.awaits_word(npc["id"], owner.progression.quests, owner.pack.items, quest_open):
			out.append(npc)
	return out


## The floors the bounty board counts (PIX-170): the hero's own, and the
## notices the relics won have earned out in the Reach.
func board_floors() -> Array:
	return Hunts.board_floors(owner.progression.cleared_levels, Relics.found(owner.progression), owner.progression.deepest)


## A conversation closed: recruits answer (resolveSettler), then the quest
## hooks (PIX-125) get their turn through dialogue_closed.
func finish_dialogue(npc_id: String) -> void:
	# On the night of the fire, talking is the night's next step (PIX-152).
	if owner.progression.prologue != Prologue.DONE:
		_prologue_talk(npc_id)
		owner.dialogue_closed.emit(npc_id)
		return
	# The first word with Maren after the night is her tin (PIX-253): the
	# letters, and nothing else asked or handed in that time. Once the four
	# keepsakes are home, her confession gives the fifth (step 8).
	var said := open_tin() if npc_id == "elder" else ""
	if said == "" and npc_id == "elder":
		said = hear_out()
	# A letter carried to this villager is theirs as the talk ends.
	if said == "":
		said = deliver(npc_id)
	if said != "":
		owner.dialogue_closed.emit(npc_id)
		owner.message.emit(said)
		return
	# Settlers first (recruiting and services ride the close), then quests;
	# a settler with an ask of their arc to make or take back (PIX-157) says
	# it after their service.
	var text := owner.holdings.resolve_settler(npc_id)
	if text == "":
		text = resolve_quests(npc_id)
	elif owner.holdings.is_settled(npc_id) and Quests.awaits_word(npc_id, owner.progression.quests, owner.pack.items, quest_open):
		text += " " + resolve_quests(npc_id)
	owner.dialogue_closed.emit(npc_id)
	if text != "":
		owner.message.emit(text)


## Closing a conversation with a giver (resolveQuests): accept their first
## untaken quest, or turn in a finished one (deliveries leave the pack), or
## say how far along it stands. "" when they give no open quest.
func resolve_quests(giver_id: String) -> String:
	var entries := owner.progression.quests
	for quest: Dictionary in Quests.for_giver(giver_id):
		var entry: Dictionary = entries.get(quest["id"], {})
		if entry.get("done", false):
			continue
		# Maren's relics are no errand for a hero who climbed before the gate
		# was barred (PIX-170): she goes on to her next ask.
		if entry.is_empty() and quest.get("unlessGateOpen", false) and Relics.gate_open(owner.progression):
			continue
		# A side quest waits for the story to reach it (PIX-171).
		if entry.is_empty() and not quest_open(quest):
			return ""
		if entry.is_empty():
			# A hunt whose quarry already fell counts at once (PIX-165).
			var asked: Dictionary = quest["objective"]
			var already: bool = asked["kind"] == "hunt" and asked["named"] in owner.progression.hunted
			var progress := int(asked["count"]) if already else 0
			# What the hero already made counts toward a crafting quest
			# (PIX-231): a potion brewed before Vex was asked.
			if asked["kind"] == "craft":
				progress = mini(int(asked["count"]), int(owner.progression.crafted.get(asked["itemId"], 0)))
				if progress >= int(asked["count"]):
					owner.noted.emit([progress_line(quest, progress)])
			entries[quest["id"]] = {"progress": progress, "done": false}
			note_deliveries(false)
			owner.save_now()
			# The giver's words were just said; the line names the task (PIX-194).
			return Text.t("Quest accepted: %s. %s") % [quest["name"], quest["brief"]] + " " + Controls.say(Text.t("It's in your journal ({key:journal})."))
		var objective: Dictionary = quest["objective"]
		# A quest that ends in a choice waits for the hero's answer (PIX-192).
		if quest.has("choice") and Quests.is_ready(quest, entries, owner.pack.items):
			return Text.t("%s: they wait on your answer.") % quest["name"]
		if Quests.is_ready(quest, entries, owner.pack.items):
			if objective["kind"] == "deliver":
				owner.pack.remove_item(objective["itemId"], int(objective["count"]))
			elif objective["kind"] == "relics":
				# They go into the mountain's gate (PIX-170).
				for item_id: String in objective["items"]:
					owner.pack.remove_item(item_id)
			entry["done"] = true
			# Handed in, it's no longer followed (PIX-239): the story leads.
			Journal.let_go(owner.progression)
			var reward: Dictionary = quest["reward"]
			owner.pack.gold += int(reward["gold"])
			var level_line := owner.spoils.earn_xp(int(reward["xp"]))
			if reward.has("itemId"):
				owner.pack.add_item(reward["itemId"])
			# A recruit's story ends with them moving to town (PIX-148).
			if quest.has("settles") and quest["settles"] not in owner.settlement.settlers:
				owner.settlement.settlers.append(quest["settles"])
				owner.last_deed = {"kind": "settler", "settler": String(Town.recruit(quest["settles"])["name"]).get_slice(" the ", 0)}
				owner.settlers_changed.emit()
			owner.pack_changed()
			owner.save_now()
			var paid: Array[String] = []
			if int(reward["gold"]) > 0:
				paid.append(Text.t("+%d gold") % reward["gold"])
			paid.append(Text.t("+%d XP") % reward["xp"])
			var done := Text.t("Quest complete: %s. %s. \u201c%s\u201d") % [quest["name"], ", ".join(paid), quest["completed"]]
			return done + ("\n" + level_line if level_line != "" else "")
		return Text.t("%s: %d/%d %s.") % [
			quest["name"], Quests.progress(quest, entries, owner.pack.items), objective["count"],
			String(objective["label"]).to_lower(),
		]
	return ""


## Maren's tin is opened (PIX-253): the letters still to deliver go in the
## satchel (the pack), their quests taken; those whose keepsake is already won stay with
## her, answered. Her own ask comes with them - the relics home, the five's
## errands in the Reach open - unless the gate stood open before it was
## barred. The tin is kept in the story ledger. Returns what the pack holds
## now, "" when the tin was found already (or the night isn't over).
func open_tin() -> String:
	if not Letters.tin_waits(owner.progression):
		return ""
	owner.mark_seen(Letters.scene_id())
	var given: Array[String] = []
	for quest: Dictionary in Letters.all():
		if owner.progression.quests.has(quest["id"]) or Letters.delivered(quest, owner.progression):
			continue
		owner.progression.quests[quest["id"]] = {"progress": 0, "done": false}
		owner.pack.add_item(quest["objective"]["itemId"])
		given.append(quest["objective"]["itemId"])
	var relics := Quests.by_id(Relics.quest_id())
	if not owner.progression.quests.has(relics["id"]) and quest_open(relics):
		owner.progression.quests[relics["id"]] = {"progress": 0, "done": false}
	owner.pack_changed()
	owner.save_now()
	var line := Letters.taken_line(given)
	# The satchel is the journal's main story (PIX-253 step 2).
	return line + " " + Controls.say(Text.t("Your satchel is in the journal ({key:journal}).")) if not given.is_empty() else line


## Maren has told it all (PIX-253 step 8): her confession, at the shrine,
## the four keepsakes home - or, for a hero who heard her old one, a word.
## The fifth letter goes in the satchel, its quest taken, with her promise
## (once: an old save may hold it from the relics' turn-in), and the
## mountain's gate opens (Relics.gate_open). Returns what the pack holds
## now, "" when she had nothing to give.
func hear_out() -> String:
	if not Letters.fifth_due(owner.progression, owner.settlement):
		return ""
	if Letters.confession_due(owner.progression, owner.settlement):
		owner.mark_seen(Letters.confession_id())
	var quest := Letters.fifth_quest()
	owner.progression.quests[quest["id"]] = {"progress": 0, "done": false}
	owner.pack.add_item(quest["objective"]["itemId"])
	if int(owner.pack.items.get(Relics.promise_id(), 0)) <= 0:
		owner.pack.add_item(Relics.promise_id())
	Journal.let_go(owner.progression)
	owner.pack_changed()
	owner.save_now()
	return String(Letters.fifth()["given"])


## The letter `npc_id` is owed now (PIX-253): a deliverTo quest taken, not
## yet handed over, its letter in the pack; {} otherwise.
func letter_for(npc_id: String) -> Dictionary:
	for quest: Dictionary in Quests.for_recipient(npc_id):
		if Quests.is_ready(quest, owner.progression.quests, owner.pack.items):
			return quest
	return {}


## The letter handed over (PIX-253): out of the pack, the quest done, its
## postage paid (the recipient paid the post, then). Returns the line to
## show, "" when `npc_id` is owed none.
func deliver(npc_id: String) -> String:
	var quest := letter_for(npc_id)
	if quest.is_empty():
		return ""
	var objective: Dictionary = quest["objective"]
	owner.pack.remove_item(objective["itemId"], int(objective["count"]))
	owner.progression.quests[quest["id"]] = {"progress": int(objective["count"]), "done": true}
	Journal.let_go(owner.progression)
	var reward: Dictionary = quest["reward"]
	owner.pack.gold += int(reward.get("gold", 0))
	var level_line := owner.spoils.earn_xp(int(reward.get("xp", 0)))
	owner.pack_changed()
	owner.save_now()
	var paid: Array[String] = []
	if int(reward.get("gold", 0)) > 0:
		paid.append(Text.t("+%d gold") % reward["gold"])
	if int(reward.get("xp", 0)) > 0:
		paid.append(Text.t("+%d XP") % reward["xp"])
	var done := Text.t("Delivered: %s.") % quest["name"]
	if not paid.is_empty():
		done = Text.t("Delivered: %s. %s.") % [quest["name"], ", ".join(paid)]
	# What comes home with the answer (PIX-254: Wenna's rope for the river
	# bridge, mended at the board), a story beat in the log.
	if quest.has("postscript"):
		owner.noted.emit([String(quest["postscript"])])
	# The keepsake already home, the family comes too (PIX-255: Wenna).
	for line: String in owner.holdings.come_home():
		done += " " + line
	return done + ("\n" + level_line if level_line != "" else "")


## The hero's answer to a quest that ends in a choice (PIX-192): the
## option's reward instead of the quest's, its words, and the choice kept
## (the giver remembers it). Returns the line to show, "" if not ready.
func choose(quest_id: String, option_id: String) -> String:
	var quest := Quests.by_id(quest_id)
	var entry: Dictionary = owner.progression.quests.get(quest_id, {})
	if not quest.has("choice") or entry.is_empty() or entry["done"] or not Quests.is_ready(quest, owner.progression.quests, owner.pack.items):
		return ""
	var option: Dictionary = {}
	for each: Dictionary in quest["choice"]["options"]:
		if each["id"] == option_id:
			option = each
	if option.is_empty():
		return ""
	if quest["objective"]["kind"] == "deliver":
		owner.pack.remove_item(quest["objective"]["itemId"], int(quest["objective"]["count"]))
	entry["done"] = true
	entry["choice"] = option_id
	Journal.let_go(owner.progression)
	var reward: Dictionary = option["reward"]
	owner.pack.gold += int(reward.get("gold", 0))
	var level_line := owner.spoils.earn_xp(int(reward.get("xp", 0)))
	if reward.has("itemId"):
		owner.pack.add_item(reward["itemId"])
	owner.pack_changed()
	owner.save_now()
	var paid: Array[String] = []
	if int(reward.get("gold", 0)) > 0:
		paid.append(Text.t("+%d gold") % reward["gold"])
	paid.append(Text.t("+%d XP") % reward.get("xp", 0))
	if reward.has("itemId"):
		paid.append(Catalog.item_name(reward["itemId"]))
	var done := Text.t("Quest complete: %s. %s. \u201c%s\u201d") % [quest["name"], ", ".join(paid), option["line"]]
	return done + ("\n" + level_line if level_line != "" else "")


## An escort under way (PIX-192): {quest, def} for a taken escort quest
## whose wagon hasn't come down yet, {} otherwise.
func escort_due() -> Dictionary:
	for quest: Dictionary in Quests.all():
		var objective: Dictionary = quest["objective"]
		var entry: Dictionary = owner.progression.quests.get(quest["id"], {})
		if objective["kind"] == "escort" and not entry.is_empty() and not entry["done"] and int(entry["progress"]) < int(objective["count"]):
			return {"quest": quest, "def": Bestiary._data()["escorts"][objective["escort"]]}
	return {}


## The wagon is down: the escort's goal is met, the giver waits.
func escort_arrived(quest_id: String) -> void:
	var entry: Dictionary = owner.progression.quests.get(quest_id, {})
	if entry.is_empty():
		return
	entry["progress"] = int(Quests.by_id(quest_id)["objective"]["count"])
	owner.save_now()


## A quest against the clock (PIX-192): {quest, left} while one runs, {}.
func timed_run() -> Dictionary:
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = owner.progression.quests.get(quest["id"], {})
		if quest.has("timed") and entry.has("left") and not entry["done"]:
			return {"quest": quest, "left": float(entry["left"])}
	return {}


## The clocks run while the world does (PIX-192): a timed quest's clock
## starts once its goods are in the pack and it's taken, stops when they
## leave it, and at nought the goods go back where they were found (their
## chest closes again). Returns {message, rearmed: chest ids}.
func tick_runs(delta: float) -> Dictionary:
	for quest: Dictionary in Quests.all():
		if not quest.has("timed"):
			continue
		var entry: Dictionary = owner.progression.quests.get(quest["id"], {})
		if entry.is_empty() or entry["done"]:
			continue
		# Its giver gone to live in Pixelheim (PIX-255: Old Pell, with the
		# ingot won), there's no racing the goods across the Reach: no clock.
		if owner.holdings.is_settled(String(quest["giver"])):
			entry.erase("left")
			continue
		var item: String = quest["objective"]["itemId"]
		var carried := int(owner.pack.items.get(item, 0)) > 0
		if not entry.has("left"):
			if carried:
				entry["left"] = float(quest["timed"]["seconds"])
				return {"message": String(quest["timed"]["start"]) % quest["timed"]["seconds"], "rearmed": []}
			continue
		if not carried:
			entry.erase("left")
			continue
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) > 0.0:
			continue
		entry.erase("left")
		owner.pack.remove_item(item, int(owner.pack.items.get(item, 0)))
		var rearmed: Array[String] = []
		for chest: Dictionary in Interactables._data()["chests"]:
			if chest.get("loot", {}).get("itemId", "") == item and chest["id"] in owner.world.opened_chests:
				owner.world.opened_chests.erase(chest["id"])
				rearmed.append(chest["id"])
		owner.pack_changed()
		owner.save_now()
		return {"message": quest["timed"]["lapse"], "rearmed": rearmed}
	return {"message": "", "rearmed": []}


## Another hero was loaded (GameState.apply): the last one's deliveries are
## no measure of this one's.
func forget_deliveries() -> void:
	_delivered.clear()


## A quest's progress for the battle log: "Reeds: 2/3.", or once it's all
## there, ready and to whom it's handed in.
func progress_line(quest: Dictionary, have: int) -> String:
	var count := int(quest["objective"]["count"])
	if have >= count:
		return Text.t("%s: ready to hand in to %s.") % [quest["name"], String(Npcs.by_id(quest["giver"], owner.settlement.settlers).get("name", quest["giver"]))]
	return "%s: %d/%d." % [quest["name"], have, count]


## Deliveries' progress as their items come and go: "Reeds: 2/3." in the
## battle log, and "ready" once all are there. `announce` false only takes
## the measure (after a load, or as a quest is taken).
func note_deliveries(announce := true) -> void:
	var lines: Array[String] = []
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = owner.progression.quests.get(quest["id"], {})
		if quest["objective"]["kind"] != "deliver" or entry.is_empty() or entry["done"]:
			_delivered.erase(quest["id"])
			continue
		var have := Quests.progress(quest, owner.progression.quests, owner.pack.items)
		var had := int(_delivered.get(quest["id"], have))
		_delivered[quest["id"]] = have
		if not announce or have <= had:
			continue
		lines.append(progress_line(quest, have))
	if not lines.is_empty():
		owner.noted.emit(lines)


## The accepted delivery that spending `costs` (item id -> count) would set
## back (PIX-206): {quest, item}, or {} when none is touched.
func delivery_dip(costs: Dictionary) -> Dictionary:
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = owner.progression.quests.get(quest["id"], {})
		var objective: Dictionary = quest["objective"]
		if objective["kind"] != "deliver" or entry.is_empty() or entry["done"] or not costs.has(objective["itemId"]):
			continue
		var have := int(owner.pack.items.get(objective["itemId"], 0))
		var count := int(objective["count"])
		if mini(count, have - int(costs[objective["itemId"]])) < mini(count, have):
			return {"quest": quest["name"], "item": Catalog.item_name(objective["itemId"])}
	return {}


## Before the board or a workbench takes what an accepted delivery needs
## (PIX-206), it asks: the first try returns the question, the same again
## within a few seconds goes ahead (""). `what` names the spend.
func ask_before_dip(what: String, costs: Dictionary) -> String:
	var dip := delivery_dip(costs)
	if dip.is_empty():
		return ""
	var now := GameClock.seconds()
	if _dip_asked == what and now - _dip_asked_at <= DIP_CONFIRM_SECONDS:
		_dip_asked = ""
		return ""
	_dip_asked = what
	_dip_asked_at = now
	return Text.t("That uses what %s needs (%s). Do it again to go ahead.") % [dip["quest"], dip["item"]]


## A deed newly done (PIX-219): kept, its medal in the pack, the log told.
func note_deeds() -> void:
	var lines: Array[String] = []
	for deed: Dictionary in Deeds.all():
		if deed["id"] in owner.progression.deeds or not Deeds.met(deed, owner.hero, owner.pack, owner.progression):
			continue
		owner.progression.deeds.append(deed["id"])
		owner.pack.add_item(deed["itemId"])
		lines.append(Text.t("A feat done: %s. The %s is yours, for the shelf at home.") % [Text.t(deed["name"]), Catalog.item_name(deed["itemId"])])
	if not lines.is_empty():
		owner.mark_dirty()
		Sound.play("learn")
		owner.noted.emit(lines)


## The Night of Ash moves on when the survivor whose turn it is has spoken:
## Bram freed, Sela's bandages (she heals), the letter in Maren's hands, and
## then the dawn (the world plays it, then calls finish_prologue).
func _prologue_talk(npc_id: String) -> void:
	if Prologue.step_of(npc_id) != owner.progression.prologue:
		return
	match owner.progression.prologue:
		Prologue.SELA:
			owner.make_whole()
			# And a cap to wear (PIX-197: the pack and worn gear, taught).
			var cap := InventoryState.create_gear(String(Prologue.data()["cap"]["itemId"]))
			owner.pack.gear.append(cap)
			owner.pack_changed()
			owner.message.emit(String(Prologue.data()["cap"]["given"]))
		Prologue.MAREN:
			owner.pack.remove_item("chancellors_letter")
			owner.pack_changed()
			owner.prologue_dawn.emit()
			return
	prologue_on()


## The scavenger at the gate fell: its pouch, and on to the village.
func prologue_pouch() -> String:
	if owner.progression.prologue != Prologue.SCAVENGER:
		return ""
	owner.pack.add_item("potion_hp")
	owner.progression.prologue = Prologue.GATE
	owner.pack_changed()
	owner.save_now()
	return Controls.say(String(Prologue.data()["pouch"]))


## Through the gate into the burning village.
func prologue_reached_town() -> void:
	if owner.progression.prologue == Prologue.GATE:
		prologue_on()


## The night's next beat (Prologue.ORDER), saved.
func prologue_on() -> void:
	owner.progression.prologue = Prologue.next(owner.progression.prologue)
	owner.save_now()


## A wave of the night's foes is down (the hounds, the embers): on, with
## the line that says where to next.
func prologue_wave_cleared() -> String:
	var wave := Prologue.wave(owner.progression.prologue)
	if wave.is_empty():
		return ""
	prologue_on()
	return String(wave["cleared"])


## A burning home put out with the well's water (PIX-197); the line to say.
func prologue_douse(ruin: int) -> String:
	if owner.progression.prologue != Prologue.FIRES or ruin in owner.progression.prologue_doused:
		return ""
	owner.progression.prologue_doused.append(ruin)
	var fires: Dictionary = Prologue.data()["fires"]
	if owner.progression.prologue_doused.size() >= Prologue.fires_needed():
		prologue_on()
		return String(fires["done"])
	owner.save_now()
	return "%s (%d/%d)" % [fires["doused"], owner.progression.prologue_doused.size(), Prologue.fires_needed()]


## Dawn: the night is over and the game proper begins.
func finish_prologue() -> void:
	owner.progression.prologue = Prologue.DONE
	owner.progression.prologue_doused.clear()
	owner.world.steps = Prologue.dawn_steps()
	owner.pack.remove_item("chancellors_letter")
	owner.pack_changed()
	owner.save_now()
