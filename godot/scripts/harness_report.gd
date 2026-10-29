class_name HarnessReport
extends RefCounted
## areas: all
## The screenshot harness's report line (PIX-273): `screenshot saved;
## map=town cell=(40, 33) hp=... gate=bridge`, every field declared once in
## the table (harness_report.txt) and written by its own function below. Each branch used to add its
## field to the end of one long print in harness.gd, so any two at once
## conflicted there, and a flow anchored on the line's end (`packs=...$`)
## broke when another field came after it. Now a field is a row and a
## function, the line joins them in the table's order, and the flows
## (tools/flows.txt) match fields by name, never by where they stand.
##
## A new field: a row in harness_report.txt in its place by name (after the
## head), and its function `field_<name>()` in the same place among the
## functions, returning its text, or "" when this run has none (the line
## leaves it out); a feature's field is a row in its own folder's
## harness_report.txt and its `field_<name>(report)` in its feature.gd
## (Feature, PIX-361). A value the run knows only part-way (the clock as the hero wakes)
## is `note`d by the harness then, and its function reads it back with
## `noted`. test_harness_report keeps it so: no field twice, the head first
## and the rest by name, each with its function in the table's order,
## harness.gd writing no field itself, and every field a flow expects here.

## Every field, a line each (PIX-356: a row a branch adds merges by union,
## where a table in this script made catch-up merges conflict):
## `field | says`, in the order the line shows them. The head (every run's)
## first; then the rest by name.
const TABLE_FILE := "res://scripts/harness_report.txt"
## How many of the table's first rows are the head every run shows.
const HEAD := 10

## TABLE_FILE's rows, read once (`table()`).
static var _table: Array[Dictionary] = []

var harness: Node
var world: Node
var flags: HarnessFlags
## What the run noted part-way, by field.
var _noted := {}


func _init(run: Node, given: HarnessFlags) -> void:
	harness = run
	world = run.world
	flags = given


## Every field's row, in TABLE_FILE's order, each feature's (PIX-361) among
## the rest by name.
static func table() -> Array[Dictionary]:
	if _table.is_empty():
		var columns: PackedStringArray = ["field", "says"]
		var rows := HarnessFlags.read_rows(TABLE_FILE, columns)
		for feature in Features.all():
			rows.append_array(Features.rows(feature, "harness_report.txt", columns))
		var rest := rows.slice(HEAD)
		rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["field"]) < String(b["field"]))
		_table = rows.slice(0, HEAD)
		_table.append_array(rest)
	return _table


## The report line: every field this run has, in the table's order (a
## feature's from its own `field_<name>(report)`).
func line() -> String:
	var texts := {}
	for row: Dictionary in table():
		var function := "field_" + String(row["field"])
		texts[row["field"]] = String(row["feature"].call(function, self) if row.has("feature") else call(function))
	return joined(texts)


## `screenshot saved; ` and each field with text, as `name=text`, in the
## table's order (a field the table doesn't hold is never shown).
static func joined(texts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for row: Dictionary in table():
		var text: String = texts.get(row["field"], "")
		if text != "":
			parts.append("%s=%s" % [row["field"], text])
	return "screenshot saved; " + " ".join(parts)


## Whether the table holds `field`.
static func has(field: String) -> bool:
	return table().any(func(row: Dictionary) -> bool: return row["field"] == field)


## A field's value the run knows part-way through (the clock as the hero
## wakes, the counter's tab as it opens), for the line at the end.
func note(field: String, text: String) -> void:
	assert(has(field), "%s is not a field in scripts/harness_report.txt" % field)
	_noted[field] = text


func noted(field: String) -> String:
	return _noted.get(field, "")


## The menus and conversations still open over the world, by script name.
func screens() -> PackedStringArray:
	var out: PackedStringArray = []
	for node in world.get_children():
		if node is CanvasLayer and node.get_script() != null:
			var path: String = node.get_script().resource_path
			if path.ends_with("_screen.gd") or path.ends_with("dialogue_box.gd"):
				out.append(path.get_file().get_basename())
	return out


## The open map screen, or null.
func _map_screen() -> Node:
	for node in world.get_children():
		if node.has_method("destination_id"):
			return node
	return null


## The chapter card up, or null.
func _chapter_card() -> Node:
	for node in world.get_children():
		if node.has_method("rise_left"):
			return node
	return null


## The journal on its Letters page, or null.
func _letters_page() -> Node:
	for node in world.get_children():
		if node.get_script() == preload("res://scripts/journal_screen.gd") and node.tab == "letters":
			return node
	return null


## Maren's letters once any is out (PIX-253).
## Maren's letters taken: the four, and the fifth once she's given it.
func _letters() -> Array:
	var all: Array = Letters.all()
	all.append(Letters.fifth_quest())
	return all.filter(func(quest: Dictionary) -> bool: return GameState.progression.quests.has(quest["id"]))


# --- The head ----------------------------------------------------------------

func field_map() -> String:
	return world.map.id


func field_cell() -> String:
	return str(world.player_cell)


func field_hp() -> String:
	return str(world.player.hp)


func field_gold() -> String:
	return str(GameState.pack.gold)


func field_save() -> String:
	return "%s%s" % [GameState.world.map_id, GameState.world.cell]


func field_draws() -> String:
	return str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))


func field_paused() -> String:
	return str(world.get_tree().paused)


func field_open() -> String:
	var open := screens()
	return ",".join(open) if not open.is_empty() else "none"


func field_night() -> String:
	return str(GameState.progression.prologue)


func field_mobs() -> String:
	return str(world.get_tree().get_nodes_in_group("mobs").filter(func(mob: Node) -> bool: return not mob.dying).size())


# --- The rest, by name -------------------------------------------------------

func field_ascension() -> String:
	if not flags.has("rankup"):
		return ""
	var screen: Node = harness._ascension()
	return screen.phase if screen != null else "closed"


func field_backsteps() -> String:
	return noted("backsteps")


func field_bank() -> String:
	if world.view == null or Streets.areas(world.map.id).is_empty():
		return ""
	return str(Streets.on_water(world.map.grid, world.view.streets).size())


func field_barred() -> String:
	return world.barred_said


func field_bells() -> String:
	if GameState.progression.bells != Bells.NONE:
		return Bells.beat_name(GameState.progression.bells)
	return "done" if Bells.over(GameState.progression) else ""


func field_beside() -> String:
	if not flags.has("seamless"):
		return ""
	var ids: Array = world.neighbours.drawn.keys()
	ids.sort()
	return ",".join(ids) if not ids.is_empty() else "none"


func field_book() -> String:
	var pieces: Array = world.view.buildings.get("art", {}).values() + world.view.buildings.get("objects", {}).values()
	var books := pieces.filter(func(name: Variant) -> bool: return name is String and "_book" in name)
	if books.is_empty():
		return ""
	return "shut" if books.any(func(name: String) -> bool: return "shut_book" in name) else "open"


func field_boss() -> String:
	var out: PackedStringArray = []
	for enemy in world.get_tree().get_nodes_in_group("mobs"):
		if not enemy.dying and not enemy.is_queued_for_deletion() and Bestiary.fights_like_boss(enemy.fighter):
			var share: int = world.hud.boss_bar.percent(float(enemy.fighter["hp"]) / maxi(1, int(enemy.fighter["maxHp"])))
			out.append("%s:%s:%d%%" % [enemy.fighter.get("named", enemy.fighter["id"]), enemy.mode, share])
	return ",".join(out)


func field_bossbar() -> String:
	var bar: Node = world.hud.boss_bar
	if bar.showing():
		return bar.reading()
	return "none" if flags.has("fight") or not Depths.shortcut_on(world.map.id).is_empty() else ""


func field_burning() -> String:
	if GameState.progression.bells != Bells.EMBERS:
		return ""
	return str(Bells.roofs().size() - world.night.doused.size())


func field_card() -> String:
	var card: Variant = world.hud.place_card
	return (card as PanelContainer).get_child(0).get_child(0).text if is_instance_valid(card) else ""


func field_cards() -> String:
	if not flags.has("--slots"):
		return ""
	var kinds: PackedStringArray = []
	for slot in range(1, SaveSlots.SLOT_COUNT + 1):
		var summary := GameState.slots.summary(slot)
		kinds.append("backup" if summary.get("backup", false) else String(summary["kind"]))
	return ",".join(kinds)


func field_change() -> String:
	if not flags.has("fades"):
		return ""
	var change: String = world.scene_change
	return change if change != "" else "none"


func field_chapter() -> String:
	var card := _chapter_card()
	return str(card.number) if card != null and not card.continued else ""


func field_clock() -> String:
	return noted("clock")


func field_continued() -> String:
	var card := _chapter_card()
	return str(card.number) if card != null and card.continued else ""


func field_cpu() -> String:
	return noted("cpu")


func field_creation() -> String:
	for node in world.get_children():
		if node.get_script() == preload("res://scripts/create_screen.gd"):
			return "%s skill %d/%d" % [node._role(), node.skill_index + 1, node.skill_chips.size()]
	return ""


func field_credits() -> String:
	for node in world.get_children():
		if node is Cutscene and not node.finished and node.roll_end != "":
			return node.roll_end
	return ""


func field_dark() -> String:
	if not flags.has("fades"):
		return ""
	return str(world.hud.root.get_children().filter(func(node: Node) -> bool: return node.has_meta("fade") and node.color.a > 0.5).size())


func field_day() -> String:
	return str(Gathering.day_of(GameState.world.steps)) if flags.has("--day") else ""


func field_decor() -> String:
	if world.view == null or not PunyTerrain.is_outdoor(world.map.grid):
		return ""
	return str(world.view.field.size())


func field_delivered() -> String:
	var letters := _letters()
	if letters.is_empty():
		return ""
	return str(letters.filter(func(quest: Dictionary) -> bool: return GameState.progression.quests[quest["id"]]["done"]).size())


func field_dest() -> String:
	var screen := _map_screen()
	if screen == null:
		return ""
	var chosen: String = screen.destination_id()
	return chosen if chosen != "" else "none"


func field_detail() -> String:
	if world.view == null or not PunyTerrain.is_outdoor(world.map.grid) or not world.view.has_ground_layers():
		return ""
	return str(world.view.detail_layer.get_used_cells().size())


func field_dockmenu() -> String:
	var dock: Control = world.hud.dock
	if not dock.menu.visible:
		return ""
	var lines: PackedStringArray = []
	for at in dock.menu_lines.size():
		var row: Dictionary = dock.menu_lines[at]
		if (row["line"] as Control).visible:
			lines.append("[%s]" % row["id"] if at == dock.menu_focus else String(row["id"]))
	var menu: Rect2 = dock.menu.get_global_rect()
	# Clear of the "Next" line too (PIX-388: it hid the line's end).
	var fits: bool = Rect2(0, 0, 1280, 720).encloses(menu) and menu.end.y <= dock.words_top()
	return "%s %s" % [",".join(lines), "fits" if fits else "off"]


func field_dressed() -> String:
	if world.view == null or String(world.view.dressing.get("look", "")) == "":
		return ""
	var counts: Dictionary = world.view.dressing["counts"]
	var kinds: Array = counts.keys()
	kinds.sort()
	var parts: PackedStringArray = []
	for kind: String in kinds:
		parts.append("%s%d" % [kind, counts[kind]])
	var look := String(world.view.dressing["look"])
	return look if parts.is_empty() else "%s:%s" % [look, ",".join(parts)]


func field_ending() -> String:
	return Story.ending_of(GameState.progression.story_seen)


func field_entrance() -> String:
	if world.view == null:
		return ""
	var looks: PackedStringArray = []
	for entrance: Dictionary in world.view.entrances:
		looks.append(entrance["look"])
	for _stair: Vector2i in EntranceArt.frosted_stairs(world.map):
		looks.append("ice_stair")
	return ",".join(looks)


func field_feats() -> String:
	return ",".join(GameState.progression.deeds)


func field_fell() -> String:
	return str(world.foes.bosses_fallen) if world.foes.bosses_fallen > 0 else ""


func field_fires() -> String:
	if world.view == null:
		return ""
	var houses := 0
	var drawn := {"flames": 0, "smoke": 0, "sparks": 0, "coals": 0}
	for fire: Dictionary in world.view.fires:
		if fire.get("out", false):
			continue
		houses += 1
		for node: Node in fire["nodes"]:
			if is_instance_valid(node) and node.has_meta("fire"):
				drawn[node.get_meta("fire")] += 1
	if houses == 0:
		return ""
	return "houses %d flames %d smoke %d sparks %d coals %d" % [houses, drawn["flames"], drawn["smoke"], drawn["sparks"], drawn["coals"]]


func field_firstnight() -> String:
	for node in world.get_children():
		if node.get_script() == preload("res://scripts/create_screen.gd"):
			return "play" if node.play_night else "skip"
	return ""


func field_fled() -> String:
	return str(world.foes.fled) if world.foes.fled > 0 else ""


func field_floats() -> String:
	return Gains.summary(world.fx.floated) if not Gains.is_empty(world.fx.floated) else ""


func field_floor() -> String:
	if Depths.number(world.map.id) <= 0:
		return ""
	var entry := Depths.floor_of(world.map.id)
	return "%d/%d" % [int(entry["number"]), Depths.count(entry["dungeon"])]


func field_frames() -> String:
	return noted("frames")


func field_free() -> String:
	return str(GameState.free_slot()) if flags.has("launch") else ""


func field_gate() -> String:
	return world.interaction.gate_said


func field_hamlet() -> String:
	if world.view == null or String(world.view.hamlet.get("look", "")) == "":
		return ""
	return "%s:%s" % [world.view.hamlet["look"], _counted(world.view.hamlet["pieces"])]


## A dressing's pieces counted by how each stands, in its name's order:
## line1,moored2,stand4.
static func _counted(pieces: Array) -> String:
	var kinds := {}
	for piece: Dictionary in pieces:
		kinds[piece["kind"]] = int(kinds.get(piece["kind"], 0)) + 1
	var names: Array = kinds.keys()
	names.sort()
	return ",".join(names.map(func(kind: String) -> String: return "%s%d" % [kind, kinds[kind]]))


func field_hero() -> String:
	if not flags.has("--role") and not flags.has("--level"):
		return ""
	var hero := GameState.hero
	var stats := ["strength", "intelligence", "dexterity", "endurance"].map(func(stat: String) -> String: return str(hero.stats[stat]))
	return "%s:%d:%d/%d:%s:skills%d:%s" % [hero.role_id, hero.level, int(hero.stats["maxHp"]), int(hero.stats["maxMp"]), ",".join(stats), hero.skill_nodes.size(), GameState.pack.worn_items().get("weapon", "none")]


func field_hint() -> String:
	var hud: Hud = world.hud
	if is_instance_valid(hud.hint_card) and not hud.hint_card.is_queued_for_deletion():
		# Held unseen under a title card (PIX-345).
		return ("" if hud.hint_card.visible else "held:") + String(hud.hint_card.get_meta("id", ""))
	var held := hud.hint_held()
	return "held:" + held if held != "" else ""


func field_home() -> String:
	var homecomers: Array = Npcs.recruits().filter(func(recruit: Dictionary) -> bool:
		return recruit.has("comesHome") and GameState.holdings.is_settled(recruit["id"]))
	if homecomers.is_empty():
		return ""
	return ",".join(homecomers.map(func(recruit: Dictionary) -> String: return String(recruit["id"]).get_slice("_", 1)))


func field_hour() -> String:
	var hud: Hud = world.hud
	if hud.clock_plate == null or not world.get_children().any(func(node: Node) -> bool: return node.get_script() == preload("res://scripts/dawn_screen.gd")):
		return ""
	return "%s %s" % [hud._clock_text.text, "moon" if hud._clock_dial.night else "sun"]


func field_houses() -> String:
	if world.map == null or world.map.id != "town":
		return ""
	return "%d:%d" % [GameState.town_tier(), PunyTown.houses(world.map.grid).size()]


func field_hub() -> String:
	if world.map == null or world.view == null or Hubs.steps(world.map.id).is_empty():
		return ""
	var grown: Array = Hubs.dressing(world.map.id, GameState.post).map(func(entry: Dictionary) -> Vector2i: return entry["cell"])
	var standing: PackedStringArray = []
	for piece: Dictionary in world.view.hamlet["pieces"]:
		if piece["cell"] in grown:
			standing.append(String(piece["art"]))
	var step := Hubs.step(GameState.post, world.map.id)
	return "%s:%d:%s" % [world.map.id, step, "+".join(standing)] if not standing.is_empty() else "%s:%d" % [world.map.id, step]


func field_hudclash() -> String:
	var hud: Hud = world.hud
	var messages: Messages = world.messages
	var shown: Array = []
	if hud.card_up():
		shown.append(["card", hud._card.get_global_rect()])
	if is_instance_valid(hud.hint_card) and hud.hint_card.visible and not hud.hint_card.is_queued_for_deletion():
		shown.append(["hint", hud.hint_card.get_global_rect()])
	for rect: Rect2 in world.fx.shown():
		shown.append(["float", hud.to_screen(rect)])
	for chip: Control in messages.log_box.get_children():
		shown.append(["log", chip.get_global_rect()])
	if hud.arrow != null and hud.arrow.visible:
		var art: Texture2D = Marks.arrow(hud.arrow.way, hud.arrow.main)
		shown.append(["arrow", Rect2(hud.arrow.position - Marks.arrow_middle(), art.get_size())])
	if shown.is_empty():
		return ""
	if hud.boss_bar.showing():
		shown.append(["bar", hud.boss_bar.plate.get_global_rect()])
	# The objective's line gives way to a message where it stands.
	if messages.message_box.modulate.a > 0.0:
		shown.append(["plate", messages.message_box.get_global_rect()])
	elif hud.objective_box.modulate.a > 0.0:
		shown.append(["next", hud.objective_box.get_global_rect()])
	shown.append(["hero", hud.hero_on_screen()])
	var clashes: PackedStringArray = []
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			var pair: Array = [shown[i][0], shown[j][0]]
			# The hero counts under a card or a hint, the plates the HUD
			# places: the rest stands where it stands, the hero wherever the
			# camera has them at a map's edge.
			if pair.has("hero") and not (pair.has("card") or pair.has("hint")):
				continue
			pair.sort()
			var said := "%s/%s" % pair
			if (shown[i][1] as Rect2).intersects(shown[j][1]) and not clashes.has(said):
				clashes.append(said)
	return ",".join(clashes) if not clashes.is_empty() else "none"


func field_jobs() -> String:
	if GameState.progression.bells == Bells.NONE:
		return ""
	var kinds: Array[String] = world.night.acted.duplicate()
	kinds.sort()
	return ",".join(kinds) if not kinds.is_empty() else "none"


func field_jumps() -> String:
	return noted("jumps")


func field_lamplight() -> String:
	var view: MapView = world.view
	if view == null:
		return ""
	# A room always says (without the paid pack it has none of them).
	var room := PunyInterior.is_room(world.map.id)
	if not room and view.lamps.is_empty() and view.panes.is_empty() and view.flames.is_empty() and view.beams.is_empty():
		return ""
	var lit := view.lamps.filter(func(lamp: Dictionary) -> bool: return is_instance_valid(lamp["flame"]) and lamp["flame"].visible).size()
	var shown := func(nodes: Array) -> int:
		return nodes.filter(func(node: Node) -> bool: return is_instance_valid(node) and (node as CanvasItem).visible).size()
	return "posts %d/%d panes %d flames %d beams %d" % [lit, view.lamps.size(), shown.call(view.panes), shown.call(view.flames), shown.call(view.beams)]


func field_letters() -> String:
	var letters := _letters()
	if letters.is_empty():
		return ""
	return str(letters.filter(func(quest: Dictionary) -> bool: return int(GameState.pack.items.get(quest["objective"]["itemId"], 0)) > 0).size())


func field_lit() -> String:
	return str(world.night.lit.size()) if GameState.progression.bells != Bells.NONE else ""


func field_logged() -> String:
	return str(world.messages.logged) if not Gains.is_empty(world.fx.floated) else ""


func field_mapped() -> String:
	var screen := _map_screen()
	if screen == null:
		return ""
	var roads: Array[String] = screen.painting.mapped()
	return ",".join(roads) if not roads.is_empty() else "none"


func field_maps() -> String:
	var screen := _map_screen()
	return str(screen.painting.sheets.size()) if screen != null else ""


func field_morvax() -> String:
	var villager: Node = harness._villager(Homecoming.MORVAX)
	if villager == null:
		return ""
	return "%s%s" % [villager.cell, " bench" if villager.data.get("bench", false) else ""]


func field_motes() -> String:
	if not flags.has("rankup"):
		return ""
	var screen: Node = harness._ascension()
	var flying := 0
	if screen != null:
		for node in screen.find_children("*", "CPUParticles2D", true, false):
			if (node as CPUParticles2D).emitting:
				flying += 1
	return str(flying)


func field_music() -> String:
	return str(Sound.track) if world.foes.fled > 0 else ""


func field_next() -> String:
	if GameState.progression.prologue != Prologue.DONE:
		return ""
	return String(MainQuest.next_step(GameState.progression, GameState.settlement).get("id", ""))


func field_overflow() -> String:
	return noted("overflow")


func field_packs() -> String:
	if Bestiary.spawns_on(world.map.id).is_empty():
		return ""
	var packs: PackedStringArray = world.foes.standing_report(world.map.region_at(world.player_cell))
	return ",".join(packs) if not packs.is_empty() else "none"


func field_page() -> String:
	var screen := _map_screen()
	return String(screen.page_id()) if screen != null else ""


func field_patches() -> String:
	if not flags.has("--day"):
		return ""
	var cells: Array = world.view.patches.keys().filter(func(cell: Vector2i) -> bool:
		return Gathering.is_ready(GameState.world, world.view.patches[cell]["id"]))
	cells.sort()
	return ";".join(cells.map(func(cell: Vector2i) -> String: return "%d,%d" % [cell.x, cell.y])) if not cells.is_empty() else "none"


func field_pauseline() -> String:
	for node in world.get_children():
		if node is Screen and node.get("saved_line") is Label and node.saved_line.visible:
			return node.saved_line.text
	return ""


func field_plate() -> String:
	var messages: Messages = world.messages
	if messages.message_box.modulate.a <= 0.0:
		return ""
	return messages.message_tag.text if messages.message_tag.visible else messages.message_label.text


func field_post() -> String:
	if not GameState.posting.is_open():
		return ""
	var counts := "box:%d,bag:%d,sent:%d" % [GameState.posting.in_box().size(), GameState.post.bag.size(), GameState.post.delivered.size()]
	var screen := _map_screen()
	if screen != null:
		counts += ",marked:%d" % screen.painting.post_cells().size()
	return ("standing," + counts) if world.view.post_box != null and is_instance_valid(world.view.post_box) else counts


func field_posthouse() -> String:
	return "standing" if world.view.post_house != null and is_instance_valid(world.view.post_house) else ""


func field_quill() -> String:
	var quill: Hud.Quill = world.hud.quill
	return "%d/%d%s" % [quill.writes, GameState.saves_made, " slept" if quill.slept else ""]


func field_read() -> String:
	if _letters_page() == null:
		return ""
	return str(Letters.satchel(GameState.progression).filter(func(carried: Dictionary) -> bool: return carried["delivered"]).size())


func field_rise() -> String:
	if not flags.has("--rise"):
		return ""
	var rise: RebuildRise = harness._rise()
	return rise.phase if rise != null else ("built" if harness._rise_phase != "none" else "none")


func field_rising() -> String:
	return noted("rising")


func field_rooms() -> String:
	return noted("rooms")


func field_rose() -> String:
	var card := _chapter_card()
	return str(roundi(card.rose)) if card != null else ""


func field_routes() -> String:
	var parts: PackedStringArray = []
	var built := Routes.built(GameState.settlement)
	for place: String in Routes.carried(GameState.post):
		var part := "%s:%d" % [place, Routes.count(GameState.post, place)]
		if Routes.signed(GameState.post, place):
			part += ":signs"
		if place in built:
			part += ":built"
		elif Routes.station_offered(GameState.post, place):
			part += ":offered"
		parts.append(part)
	return ",".join(parts)


func field_saves() -> String:
	return str(world.neighbours.saves) if flags.has("seamless") else ""


func field_scene() -> String:
	for node in world.get_children():
		if node is Cutscene and not node.finished:
			return node.scene_id
	return ""


func field_scorch() -> String:
	var view: MapView = world.view
	if view == null or view.kept == null or not view.has_ground_layers():
		return ""
	var counts := {
		"burnt": view.kept.burnt.size(), "snags": view.snags.size(), "cinders": view.ember_layer.get_used_cells().size(),
		"rails": int(view.workings.get("rails", 0)), "spoil": int(view.workings.get("spoil", 0)), "standing": int(view.workings.get("standing", 0)),
	}
	if counts.values().all(func(n: int) -> bool: return n == 0):
		return ""
	var parts: PackedStringArray = []
	for kind: String in ["burnt", "snags", "cinders", "rails", "spoil", "standing"]:
		parts.append("%s%d" % [kind, counts[kind]])
	return ",".join(parts)


func field_shortcut() -> String:
	if Depths.number(world.map.id) <= 0:
		return ""
	var door := Depths.shortcut_on(world.map.id)
	if door.is_empty():
		return ""
	return "open" if world.map.portals.has(door["cell"]) else "shut"


func field_signposts() -> String:
	var forks: PackedStringArray = []
	for piece: Dictionary in world.view.routes["pieces"]:
		if piece["kind"] == "signpost":
			forks.append(String(piece["fork"]))
	return ",".join(forks)


func field_speaker() -> String:
	for node in world.get_children():
		if node.has_method("_advance"):
			return String(node.npc.get("id", ""))
	return ""


func field_stair() -> String:
	return world.delve.stair()


func field_stamps() -> String:
	if not GameState.posting.is_open() or GameState.post.stamps.is_empty():
		return ""
	var out: Array[String] = []
	for page: Dictionary in Post.book():
		if GameState.post.stamps.has(page["place"]):
			out.append(String(page["place"]))
	return ",".join(out)


func field_stood() -> String:
	return str(world.foes.stood) if world.foes.stood > 0 else ""


func field_story() -> String:
	var screen := _map_screen()
	if screen == null:
		return ""
	var story: Vector2i = screen.painting.story_cell()
	return "%d,%d" % [story.x, story.y] if story != Bearing.NOWHERE else ""


func field_street() -> String:
	var view: MapView = world.view
	if view == null or not view.has_ground_layers():
		return ""
	var cell: Vector2i = world.player_cell
	if view.streets.has(cell):
		return view.streets[cell]
	return "worn" if view.wear_layer.get_cell_source_id(cell) >= 0 else ""


func field_tab() -> String:
	return noted("tab")


func field_tags() -> String:
	return str(world.foes.most_tags) if world.foes.kills > 0 else ""


func field_tally() -> String:
	var marks: Variant = world.view.tally_marks
	return "fresh:%d" % marks.fresh if marks != null and is_instance_valid(marks) else ""


func field_titleline() -> String:
	for child in world.get_children():
		if child.get_script() != null and String(child.get_script().resource_path).ends_with("title_screen.gd"):
			return child.said
	return ""


func field_toast() -> String:
	var messages: Messages = world.messages
	var hud: Hud = world.hud
	var chips: Array = messages.log_box.get_children().filter(func(chip: Node) -> bool: return not chip.is_queued_for_deletion())
	if chips.is_empty():
		return ""
	var wrong: PackedStringArray = []
	var lines := 0
	for chip: Control in chips:
		var rect := chip.get_global_rect()
		lines += (chip.get_child(0) as Label).get_line_count()
		if not Rect2(0, 0, 1280, 720).encloses(rect):
			wrong.append("off")
		if hud.objective_box.modulate.a > 0.0 and rect.intersects(hud.objective_box.get_global_rect()):
			wrong.append("tracker")
		if rect.end.y > hud.dock.top():
			wrong.append("dock")
	if messages.message_box.modulate.a > 0.0:
		wrong.append("plate")
	if hud.arrow != null and hud.arrow.get_index() > messages.log_box.get_index():
		wrong.append("arrow")
	return "%d box, %d line, %s" % [chips.size(), lines, "fits" if wrong.is_empty() else ",".join(wrong)]


func field_tone() -> String:
	if world.view == null or not PunyTerrain.is_outdoor(world.map.grid) or world.view.kept == null:
		return ""
	return PunyTerrain.tone_at(world.view.kept.tint_image, world.player_cell)


func field_top() -> String:
	var shown: Array[CanvasLayer] = []
	_screens_in(world, shown)
	if shown.size() < 2:
		return ""
	var most := -1000
	for layer in shown:
		most = maxi(most, layer.layer)
	var names: PackedStringArray = []
	for layer in shown:
		if layer.layer == most:
			names.append(layer.get_script().resource_path.get_file().get_basename())
	return "=".join(names)


## Every screen shown under `node`, those opened over another screen included.
func _screens_in(node: Node, out: Array[CanvasLayer]) -> void:
	for child in node.get_children():
		if child is CanvasLayer and child.get_script() != null and child.visible and String(child.get_script().resource_path).ends_with("_screen.gd"):
			out.append(child)
		_screens_in(child, out)


func field_torches() -> String:
	if world.view == null or world.map.style != "cave":
		return ""
	var torches: Array[Vector2i] = world.view.wall_torches
	var loose := torches.filter(func(cell: Vector2i) -> bool: return not PunyDungeon.on_face(world.map.grid, cell)).size()
	return str(torches.size()) + (" %d loose" % loose if loose > 0 else "")


func field_tour() -> String:
	for node in world.get_children():
		if node is Screen and node.get_script() != null and String(node.get_script().resource_path).ends_with("reveal_screen.gd"):
			return node.caption.text
	return ""


func field_tracked() -> String:
	var tracked := GameState.progression.tracked
	if not screens().has("journal_screen") and tracked == "":
		return ""
	return tracked if tracked != "" else "none"


func field_turns() -> String:
	return noted("turns")


func field_water() -> String:
	if world.view == null or world.view.kept == null:
		return ""
	return PunyTerrain.water_near(world.view.kept.water_image, world.player_cell, 6)


func field_wayout() -> String:
	if Depths.shortcut_on(world.map.id).is_empty():
		return ""
	var cells: PackedStringArray = []
	for cell: Vector2i in Depths.exits(world.map):
		cells.append(str(cell))
	return ";".join(cells) if not cells.is_empty() else "none"


func field_waystations() -> String:
	var view: MapView = world.view
	var parts: PackedStringArray = []
	for place: String in view.waystations:
		var ember: Variant = view.ember_lamps.get(place)
		var lit: bool = ember != null and is_instance_valid(ember) and (ember as Node2D).visible
		parts.append("%s:%s" % [place, "lit" if lit else "cold"])
	return ",".join(parts)


func field_works() -> String:
	for node in world.get_children():
		if node is Screen and node.get_script() != null and String(node.get_script().resource_path).ends_with("town_hall_screen.gd"):
			var offered: PackedStringArray = []
			for row: Dictionary in node.rows:
				if not Town.work(String(row.get("project", ""))).is_empty():
					offered.append(String(row["project"]))
			return ",".join(offered) if not offered.is_empty() else "none"
	return ""


func field_yards() -> String:
	if world.map == null or world.map.id != "town" or world.view == null or world.view.hamlet["pieces"].is_empty():
		return ""
	return "%d:%s" % [GameState.town_tier(), _counted(world.view.hamlet["pieces"])]
