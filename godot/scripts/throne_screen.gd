extends "res://scripts/ledger_screen.gd"
## Morvax beaten at his throne (PIX-157): the hero decides how it ends.
## Destroy him, or - knowing Maren's story of the five and holding Liane's
## last page - lay him to rest. There is no walking away from it: Esc does
## nothing here. The world plays the chosen ending (`on_choice`).

## Called with "destroy" or "rest" once the hero has chosen.
var on_choice := Callable()


func _open() -> void:
	super._open()
	# Gold means nothing at the throne.
	purse.visible = false


func _title() -> String:
	return "The Throne Below"


func _intro() -> String:
	return "Morvax is beaten. What happens to him now is up to you."


func _footer() -> String:
	return Text.t("{key:move_up}/{key:move_down}  choose      {key:interact}  %s") % Text.t("decide")


func _closes_on(_event: InputEvent) -> bool:
	return false


func _info() -> String:
	var lines: Array[String] = [
		Text.t("Morvax the Deathless kneels on the steps of his throne. The dead around him have stopped moving. His crown has slipped over one eye."),
		"",
		Text.t("\"Finish it, courier,\" he says. \"Everyone else did.\""),
	]
	if _knows():
		lines.append_array(["", Text.t("Liane's last page is in your pack, and you know the names of the five who climbed. You could give him those instead of the blade.")])
	lines.append_array(["", String(rows[selected].get("detail", ""))])
	return "\n".join(lines)


func _rows() -> Array[Dictionary]:
	return [
		{
			"label": "Destroy him",
			"note": "",
			"enabled": true,
			"detail": Text.t("Break the Deathless. The dark takes what is left, and nothing of him comes back."),
			"action": _decide.bind("destroy"),
		},
		{
			"label": "Lay him to rest",
			"note": "" if _knows() else "?",
			"enabled": _knows(),
			"detail": Text.t("Read him Liane's words, say their names, and let him go.") if _knows()
				else Text.t("You don't know him well enough. Maren's story of the five, and the last page of Liane's journal, would tell you how."),
			"why": "You don't know him well enough. Maren's story of the five, and the last page of Liane's journal, would tell you how.",
			"action": _decide.bind("rest"),
		},
	]


func _knows() -> bool:
	return Story.can_lay_to_rest(GameState.progression.cleared_levels, GameState.progression.story_seen)


func _decide(choice: String) -> String:
	close()
	if on_choice.is_valid():
		on_choice.call_deferred(choice)
	return ""
