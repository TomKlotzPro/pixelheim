extends "res://scripts/ledger_screen.gd"
## areas: story
## Morvax's choice (PIX-253 step 10; the old throne's choice, PIX-157,
## re-aimed): the courier's last word. He has asked "Do they want me back?"
## and the answer is an ending (Homecoming.choices): "Come home." or "Stay
## with them.", both always open. The world plays the chosen one
## (`on_choice`). Esc steps back without a word: he waits, and the story's
## step with him.

## Called with "home" or "stay" once the courier has answered.
var on_choice := Callable()


func _open() -> void:
	super._open()
	# Gold means nothing here.
	purse.visible = false


func _title() -> String:
	return Homecoming.title()


func _intro() -> String:
	return String(Homecoming.data()["question"])


func _verb() -> String:
	return Text.t("answer")


## What an answer brings is said once one is chosen: as it opens, none is
## (PIX-486: "He takes a room at the inn" read as already decided).
func _info() -> String:
	var waiting := String(Homecoming.data()["waiting"])
	return waiting if resting else "\n\n".join([waiting, String(rows[selected].get("detail", ""))])


## An ending can't be undone: E answers nothing until up or down has chosen
## an answer, as a talk's question waits (PIX-215), where a ledger's first E
## chooses its first row.
func _command(event: InputEvent) -> Callable:
	if resting and event.is_action_pressed("interact"):
		return Callable()
	return super(event)


func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in Homecoming.choices():
		out.append({
			"label": String(entry["label"]),
			"note": "",
			"enabled": true,
			"detail": String(entry["detail"]),
			"action": _decide.bind(String(entry["id"])),
		})
	return out


func _decide(choice: String) -> String:
	close()
	if on_choice.is_valid():
		on_choice.call_deferred(choice)
	return ""
