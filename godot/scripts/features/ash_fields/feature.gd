extends Feature
## areas: travel field night quest +overworld*
## The Ash Fields' burnt farmsteads in the harness (PIX-397, step 2): their
## map layer (AshRuins: charred frames, fallen fences, dead orchards,
## scorched carts, mending on healed ground) and the report's ashruins=, its
## row beside this script and its flows in tools/flows.d/ash_fields.txt.
## E at a stead's door searches its ash (PIX-448): the keepsake it kept
## (Quests.keepsakes), glinting there till found, and the report's keepsakes=.
## Once it's home and the lamp's ground nearby has healed, E there says one
## line on the plate (PIX-466, Quests.remembered).


func layers() -> Dictionary[String, MapLayer]:
	return {"ash_ruins": AshRuins.new()}


## The prompt over a stead's door while its keepsake waits there, or once
## the stead has its line to say.
func prompt_at(world: Node, cell: Vector2i) -> Variant:
	if world.map.id != AshRuins.MAP or (Quests.keepsake_at(world.map.id, cell, GameState.progression.quests).is_empty() and _remembered(cell) == ""):
		return null
	return Rect2(Vector2(cell * MapView.TILE), Vector2.ONE * MapView.TILE)


## E at the door: the keepsake out of the ash, rising over it, and whose it
## is; later, the stead's line.
func interact(world: Node, cell: Vector2i) -> bool:
	if world.map.id != AshRuins.MAP:
		return false
	var quest := Quests.keepsake_at(world.map.id, cell, GameState.progression.quests)
	if quest.is_empty():
		var said := _remembered(cell)
		world.messages.flash(said)
		return said != ""
	var gains := GameState.questing.salvage(quest)
	AshRuins.take_keepsake(world.view, cell)
	Sound.play("pickup")
	var whose := Npcs.by_id(quest["objective"]["to"], [])
	world.messages.flash(Text.t("In the ash: %s. Carry it home to %s.") % [Catalog.item_name(quest["objective"]["itemId"]), whose.get("name", "")])
	world.fx.show_gains(gains, MapView.center(cell) + WorldFx.OVER_THING)
	return true


## What the stead at `cell` says once its keepsake is home and its lamp's
## ground has healed (PIX-466, Quests.remembered), "" before. The lamps are
## asked only at a door whose keepsake was found.
func _remembered(cell: Vector2i) -> String:
	var quest := Quests.keepsake_of(AshRuins.MAP, cell)
	if not GameState.progression.quests.has(quest.get("id", "")):
		return ""
	return Quests.remembered(quest, GameState.progression.quests, Lamps.now(AshRuins.MAP))


# --- The report's fields, by name ---------------------------------------------

func field_ashruins(report: HarnessReport) -> String:
	return AshRuins.describe(report.world.view)


## The keepsakes found and carried home, once any is found, and on the Ash
## how many still lie at their doors: found 1 home 0 lying 4.
func field_keepsakes(report: HarnessReport) -> String:
	var found := 0
	var home := 0
	for quest: Dictionary in Quests.keepsakes():
		var entry: Dictionary = GameState.progression.quests.get(quest["id"], {})
		found += 0 if entry.is_empty() else 1
		home += 1 if entry.get("done", false) else 0
	if found == 0:
		return ""
	var said := "found %d home %d" % [found, home]
	var view: MapView = report.world.view
	return said if view == null or not view.has_meta("keepsakes") else "%s lying %d" % [said, view.get_meta("keepsakes").size()]
