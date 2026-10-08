class_name SettlementState
extends Resource
## The hero's stake in Pixelheim village (web GameState: house, properties,
## townTier, settlers, bardSong, investments). Town systems arrive with
## PIX-124; until then these records ride along untouched, so an imported
## web save keeps its deeds, settlers and bank ledger.

## {owned, storage, workbench?, tier?, trophies?, gardenWins?, ...}
var house := {"owned": false, "storage": {}}
var properties: Array[String] = []
var town_tier := 1
var settlers: Array[String] = []
## Village projects funded (PIX-145; saved as "projects" once there is one).
## Empty on a save from before them: Town.done_projects reads the tier.
var projects: Array[String] = []
## The festival day an age's completion brings (PIX-159): {until (steps),
## age, won}; saved only while there is one.
var festival := {}
## Additive web fields: null means absent.
var bard_song: Variant = null
var investments: Variant = null


static func from_dict(data: Dictionary) -> SettlementState:
	var town := SettlementState.new()
	town.house = data["house"].duplicate(true)
	town.properties.assign(data["properties"])
	town.town_tier = data["townTier"]
	town.settlers.assign(data["settlers"])
	town.projects.assign(data.get("projects", []))
	town.bard_song = data.get("bardSong")
	town.investments = data.get("investments")
	town.festival = data.get("festival", {}).duplicate()
	return town


func write_into(state: Dictionary) -> void:
	state["house"] = house.duplicate(true)
	state["properties"] = properties.duplicate()
	state["townTier"] = town_tier
	state["settlers"] = settlers.duplicate()
	if not projects.is_empty():
		state["projects"] = projects.duplicate()
	if bard_song != null:
		state["bardSong"] = bard_song
	if investments != null:
		state["investments"] = investments.duplicate(true)
	if not festival.is_empty():
		state["festival"] = festival.duplicate()
