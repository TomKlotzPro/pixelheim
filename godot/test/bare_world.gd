extends World
## A world with nothing of the world built (PIX-499): what a test hands to
## whatever holds a `World`, now that the type says so. Nothing is loaded,
## drawn or stepped; a test sets the pieces its subject reads (`map`,
## `player`, `hud`, `fx`...) and overrides what it calls. A stand-in extends
## it by its path: `class StandIn extends "res://test/bare_world.gd"`.


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _unhandled_input(_event: InputEvent) -> void:
	pass


## The pieces a test gave it and stood nowhere in the tree go with it: they
## are nodes now, where a stand-in's own were often RefCounted.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for piece: String in ["camera_rig", "fx", "messages", "soundscape", "folk", "interaction", "neighbours", "foes", "delve", "stage", "night", "hud", "lights", "atmosphere", "storm", "player"]:
		var node: Variant = get(piece)
		if is_instance_valid(node) and (node as Node).get_parent() == null and not (node as Node).is_queued_for_deletion():
			(node as Node).free()
		set(piece, null)
