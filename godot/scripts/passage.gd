class_name Passage
## areas: all
## How the hero comes to a place (PIX-500): the five ways `world.go` takes
## and what each one does where it arrives. Until then a map was entered one
## way (world.gd's enter_map) whatever had happened, so a town drawn again
## round the hero - back from the board, a hub grown by the post, Lantern
## Night's stalls going up - did all a door does: its sound, every foe
## freed and made anew, the hero's ailments gone, a save, the camera cut.
## DOOR dissolves the old place into the new one, DARK goes through the
## dark (under the ground, a way down), CUT builds at once (a story's place,
## waking at the inn), SEAMLESS is the Reach's hand-over at a line, and
## REDRAW draws the hero's own map again in place.
## Pure: the world reads `does` at each thing a door did, and
## test_passage.gd holds every way to its row.

enum { DOOR, DARK, CUT, SEAMLESS, REDRAW }

## Each way's name, for a test's or a report's words.
const NAMES: Array[String] = ["door", "dark", "cut", "seamless", "redraw"]

## What arriving may do, each a thing a door does:
## SOUND, the door's sound;
## FOES, the foes of the place left go and the new place's come, the hunt
## and a boss's bar with them;
## AILMENTS, the hero's ailments end;
## PLACED, the hero is stood on the arrival cell and the camera cuts there;
## SAVE, the game is saved;
## NAME, the place says its name (a card, when it is due);
## ARRIVAL, the story hears the hero has come (the nights set out, a
## dungeon's floor said, the dodge taught);
## NEWS, what was built since is shown (the town's reveals, a hub's tour);
## FADE, the place comes in from the dark;
## HUSH, the way hushes the web's music itself before the build (PIX-417).
const SOUND := &"sound"
const FOES := &"foes"
const AILMENTS := &"ailments"
const PLACED := &"placed"
const SAVE := &"save"
const NAME := &"name"
const ARRIVAL := &"arrival"
const NEWS := &"news"
const FADE := &"fade"
const HUSH := &"hush"
const EFFECTS: Array[StringName] = [SOUND, FOES, AILMENTS, PLACED, SAVE, NAME, ARRIVAL, NEWS, FADE, HUSH]

## What each way does. A door's dissolve is its own way in, so it has no
## fade from the dark; a cut and a redraw have no hush of their own: off a
## door the caller waits on `world.hushed_build` first (PIX-420), a story's
## never dropped, a redraw's dropped while a change of place is under way.
## A redraw keeps the hero where they stand, so it stands them somewhere
## only when their cell was built over (the map's spawn, as a door would).
const DOES := {
	DOOR: [SOUND, FOES, AILMENTS, PLACED, SAVE, NAME, ARRIVAL, NEWS, HUSH],
	DARK: [SOUND, FOES, AILMENTS, PLACED, SAVE, NAME, ARRIVAL, NEWS, FADE, HUSH],
	CUT: [SOUND, FOES, AILMENTS, PLACED, SAVE, NAME, ARRIVAL, NEWS, FADE],
	SEAMLESS: [FOES, SAVE, NAME, ARRIVAL],
	REDRAW: [NEWS, FADE],
}


## Whether coming `how` does `effect`.
static func does(how: int, effect: StringName) -> bool:
	return effect in DOES[how]


## The way through a door from `from` to `to`: the dark going under the
## ground (Ways.goes_under), a dissolve every other way.
static func through(from: MapData, to: MapData) -> int:
	return DARK if Ways.goes_under(from, to) else DOOR
