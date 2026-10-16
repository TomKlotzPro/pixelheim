class_name SlotCard
## What a hero's card on the Saves screen says (PIX-302), from the slot's
## summary (`SaveSlots.summary`, read off the save's card): who they are,
## where they stand and how far into the story, how long they've played and
## when they were last saved. No gold: the chapter and the hours say more.
## Pure, so the tests read the lines without a screen.
##
##     Bryn                                                  Playing
##     Ranger, level 13
##     Saltmere · Chapter 3: The Letter to Blackiron
##     4 h 12 min played · saved just now

## Played this long and more, the hours alone ("31 h"): the minutes no
## longer tell anything.
const HOURS_ALONE := 10


## "Ranger, level 13"
static func who(summary: Dictionary) -> String:
	var role: String = Catalog.role(summary["roleId"]).get("name", summary["roleId"])
	return Text.t("%s, level %d") % [role, summary["level"]]


## "Saltmere · Chapter 3: The Letter to Blackiron"
static func where(summary: Dictionary) -> String:
	return "%s · %s" % [Catalog.place_name(summary["mapId"]), chapter(summary["chapter"])]


## A chapter as the card names it: the Night of Ash before the first (0),
## "After the story" past the last.
static func chapter(number: int) -> String:
	if number <= 0:
		return Text.t("The Night of Ash")
	if number > MainQuest.chapters().size():
		return Text.t("After the story")
	return Text.t("Chapter %d: %s") % [number, MainQuest.title_of(number)]


## "4 h 12 min played · saved just now"
static func when(summary: Dictionary, now: int) -> String:
	return "%s · %s" % [played(summary["playSeconds"]), Text.t("saved %s") % ago(summary["savedAt"], now)]


## "4 h 12 min played", "31 h played", "Just begun" under a minute.
static func played(seconds: int) -> String:
	if seconds < 60:
		return Text.t("Just begun")
	return Text.t("%s played") % duration(seconds)


## "12 min", "4 h 12 min", "4 h", "31 h".
static func duration(seconds: int) -> String:
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	if hours >= HOURS_ALONE or (hours > 0 and minutes == 0):
		return Text.t("%d h") % hours
	if hours > 0:
		return Text.t("%d h %d min") % [hours, minutes]
	return Text.t("%d min") % minutes


## How long ago a save was written, `now` the clock's seconds: "just now",
## "5 min ago", "yesterday"... A save with no time, or one from ahead of
## the clock, is just now.
static func ago(saved_at: int, now: int) -> String:
	var seconds := now - saved_at
	if saved_at <= 0 or seconds < 60:
		return Text.t("just now")
	if seconds < 3600:
		return Text.t("%d min ago") % (seconds / 60)
	if seconds < 86400:
		var hours := seconds / 3600
		return Text.t("1 hour ago") if hours == 1 else Text.t("%d hours ago") % hours
	var days := seconds / 86400
	return Text.t("yesterday") if days == 1 else Text.t("%d days ago") % days


## The pause menu's line under its title (PIX-302 step 4): the last save,
## `seconds` ago by the game's clock. "Saved just now", "Saved 12 s ago",
## "Saved 3 min ago", "Saved 2 h ago".
static func saved_ago(seconds: int) -> String:
	if seconds < 2:
		return Text.t("Saved just now")
	if seconds < 60:
		return Text.t("Saved %d s ago") % seconds
	if seconds < 3600:
		return Text.t("Saved %d min ago") % (seconds / 60)
	return Text.t("Saved %d h ago") % (seconds / 3600)


## What Delete asks first (PIX-302): the hero by name, class and level and
## their hours, so a slip of the finger is caught.
## "Delete Hrafna? Warrior, level 18. 31 h played."
static func asking(summary: Dictionary, in_hand: bool) -> String:
	var question := Text.t("Delete %s, the hero you're playing?") if in_hand else Text.t("Delete %s?")
	return "%s %s. %s." % [question % summary["name"], who(summary), played(summary["playSeconds"])]
