extends "res://scripts/ledger_screen.gd"
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


func _info() -> String:
	return "\n\n".join([String(Homecoming.data()["waiting"]), String(rows[selected].get("detail", ""))])


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
