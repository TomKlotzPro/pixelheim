extends Screen
## A chapter card (PIX-253 step 2, v2 §5: "Main quests stand out"): when a
## chapter of the main story opens, its number and title over the world in
## the style of the dawn's "Day one" - "Chapter 3" in gold, "The Letter to
## Blackiron" under it in the title's type - a breath held, and the world
## again. Shown once each (MainQuest.card_due; Stage waits for the world to
## be free). The world holds still meanwhile; E or Esc lets it go sooner.
## With Reduce motion the words fade in where they stand, nothing slides.

## How long the card stays in full view, and fades in and out.
const HOLD_SECONDS := 2.4
const FADE_SECONDS := 0.6
## How far the title rises as it comes in (none with Reduce motion).
const RISE_PX := 12.0
## How dark the world goes behind the card, and the night's line round its
## words (as the town's tour has round its captions).
const DIM := 0.7
const OUTLINE := 8
## Between the number and the title.
const GAP := 14.0
## The title's type, a multiple of the logo face's 8 px, the largest that
## fits across the screen: the dawn's "Pixelheim" stands at 6.
const TITLE_SCALES := [4, 3]
const TITLE_ROOM := 1160.0

## The chapter, from 1.
var number := 1
var _black: ColorRect
var _number: Label
var _title: Label
var _flow: Tween
## Where the title stands once it has come in.
var _title_y := 0.0
## Reduce motion, as the card opened.
var _still := false
## How far the title rose coming in: RISE_PX, or 0 with Reduce motion.
var rose := 0.0


func _open() -> void:
	layer = 6
	_still = GameState.settings.reduce_motion
	_black = dim(0.0)
	_number = _line(UiStyle.heading(Text.t("Chapter %d") % number, 27, UiStyle.GOLD))
	var title := MainQuest.title_of(number)
	_title = _line(UiStyle.heading(title, 54, UiStyle.CREAM))
	_title.add_theme_font_override("font", UiStyle.logo_font())
	_title.add_theme_font_size_override("font_size", UiStyle.LOGO_PX * title_scale(title))
	Sound.play("learn")
	_come_in.call_deferred()


## A line of the card, centred across the screen, outlined in the night so it
## reads on any ground (the dim is light in the desktop's linear light),
## unseen until it comes in; placed once it has its own face's size
## (_come_in).
func _line(label: Label) -> Label:
	label.add_theme_color_override("font_outline_color", UiStyle.NIGHT)
	label.add_theme_constant_override("outline_size", OUTLINE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	add_child(label)
	return label


## The title's type for `title`: the largest of TITLE_SCALES whose line fits
## (the logo face is 8 px a letter, every letter as wide).
static func title_scale(title: String) -> int:
	for scale: int in TITLE_SCALES:
		if title.length() * UiStyle.LOGO_PX * scale <= TITLE_ROOM:
			return scale
	return TITLE_SCALES[-1]


## The card comes in, once the box has placed its lines: the world dims, the
## number shows, the title rises into place under it (or, with Reduce
## motion, simply shows); held; then it all goes, and the world runs again.
func _come_in() -> void:
	if not is_inside_tree():
		return
	# The two lines stacked about the screen's middle, a little above it as
	# the day card stands.
	var high := _number.get_combined_minimum_size().y
	var tall := _title.get_combined_minimum_size().y
	var top := roundf(330.0 - (high + GAP + tall) / 2.0)
	for label: Label in [_number, _title]:
		label.size = Vector2(1280, 0)
	_number.position = Vector2(0, top)
	_title_y = top + high + GAP
	_title.position = Vector2(0, _title_y)
	var still := _still
	if not still:
		rose = RISE_PX
		_title.position.y = _title_y + RISE_PX
	_flow = create_tween()
	_flow.tween_property(_black, "color:a", DIM, FADE_SECONDS)
	_flow.parallel().tween_property(_number, "modulate:a", 1.0, FADE_SECONDS)
	_flow.parallel().tween_property(_title, "modulate:a", 1.0, FADE_SECONDS).set_delay(0.0 if still else 0.25)
	if not still:
		_flow.parallel().tween_property(_title, "position:y", _title_y, FADE_SECONDS).set_delay(0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flow.tween_interval(HOLD_SECONDS)
	_flow.tween_property(_black, "color:a", 0.0, FADE_SECONDS)
	_flow.parallel().tween_property(_number, "modulate:a", 0.0, FADE_SECONDS)
	_flow.parallel().tween_property(_title, "modulate:a", 0.0, FADE_SECONDS)
	_flow.tween_callback(close)


## Its own entrance: no easing in over it.
func _eases_in() -> bool:
	return false


## A card is read, not worked: a phone's tap moves it on like E.
func _wants_tap_bar() -> bool:
	return false


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		return close
	return Callable()


## How far the title has risen into place, in pixels still to go: 0 once it
## stands (and always, with Reduce motion).
func rise_left() -> float:
	return _title.position.y - _title_y if _title != null else 0.0


func close() -> void:
	if _flow != null:
		_flow.kill()
	super.close()
