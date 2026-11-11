extends Feature
## areas: travel field night quest +overworld*
## The Ash Fields' burnt farmsteads in the harness (PIX-397, step 2): their
## map layer (AshRuins: charred frames, fallen fences, dead orchards,
## scorched carts, mending on healed ground) and the report's ashruins=, its
## row beside this script and its flows in tools/flows.d/ash_fields.txt.
## E at a stead's door searches its ash (PIX-448): the keepsake it kept
## (Quests.keepsakes), and the report's keepsakes=.


func layers() -> Dictionary[String, MapLayer]:
	return {"ash_ruins": AshRuins.new()}


## The prompt over a stead's door while its keepsake waits there.
func prompt_at(world: Node, cell: Vector2i) -> Variant:
	if world.map.id != AshRuins.MAP or Quests.keepsake_at(world.map.id, cell, GameState.progression.quests).is_empty():
		return null
	return Rect2(Vector2(cell * MapView.TILE), Vector2.ONE * MapView.TILE)


## E at the door: the keepsake out of the ash, rising over it, and whose it is.
func interact(world: Node, cell: Vector2i) -> bool:
	if world.map.id != AshRuins.MAP:
		return false
	var quest := Quests.keepsake_at(world.map.id, cell, GameState.progression.quests)
	if quest.is_empty():
		return false
	var gains := GameState.questing.salvage(quest)
	Sound.play("pickup")
	var whose := Npcs.by_id(quest["objective"]["to"], [])
	world.messages.flash(Text.t("In the ash: %s. Carry it home to %s.") % [Catalog.item_name(quest["objective"]["itemId"]), whose.get("name", "")])
	world.fx.show_gains(gains, MapView.center(cell) + WorldFx.OVER_THING)
	return true


# --- The report's fields, by name ---------------------------------------------

func field_ashruins(report: HarnessReport) -> String:
	return AshRuins.describe(report.world.view)


## The keepsakes found and carried home, once any is found: found 1 home 0.
func field_keepsakes(_report: HarnessReport) -> String:
	var found := 0
	var home := 0
	for quest: Dictionary in Quests.keepsakes():
		var entry: Dictionary = GameState.progression.quests.get(quest["id"], {})
		found += 0 if entry.is_empty() else 1
		home += 1 if entry.get("done", false) else 0
	return "" if found == 0 else "found %d home %d" % [found, home]
