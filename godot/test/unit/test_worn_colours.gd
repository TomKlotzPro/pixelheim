extends GutTest
## PIX-335: what the hero wears is the colour of its icon. Tom picked a green
## Wyrm Visor in the pack and wore a blue-grey one: every worn piece (a helm's
## or armour's colourway from tools/outfits.py, the tint gloves, boots and
## shields are drawn in) keeps its icon's main hue.

## How far the worn hue may stray from the icon's, in degrees.
const TOLERANCE := 45.0
## An icon greyer than this (mean chroma) has no hue to keep: iron, steel.
const GREY := 0.08
## Nor has an icon of two colours in equal measure (the oilskins' navy and
## tan): below this agreement of its hues, it is left alone.
const MIXED := 0.5
## Icons in another colour than the piece's, for Tom to settle (PIX-335):
## the free armours sheet's olive cloaks against the violet looks, the frost
## set's brown leather and white fur against its ice.
const OTHER_ICON := ["shadow_cloak", "grave_ward", "frost_hood", "frostweave_robe", "frost_mitts", "frost_boots"]


func test_worn_gear_wears_its_icons_colour() -> void:
	var checked := 0
	for item_id: String in Catalog._data()["items"]:
		var slot: String = Catalog.item(item_id).get("slot", "")
		if slot not in ["head", "body", "hands", "feet", "offhand"] or item_id in OTHER_ICON:
			continue
		var icon := ItemIcons.texture(item_id)
		if icon == null:
			continue  # a paid icon, not installed here
		var want := _hue(_colours(icon.get_image()))
		if want["chroma"] < GREY or want["focus"] < MIXED:
			continue
		var worn := _hue(_worn(item_id, slot))
		var off := rad_to_deg(absf(angle_difference(want["hue"], worn["hue"])))
		assert_lt(off, TOLERANCE, "%s worn at hue %d, its icon at %d" % [item_id, _degrees(worn["hue"]), _degrees(want["hue"])])
		checked += 1
	assert_gt(checked, 3, "the free icons at least")


## The colours a piece puts on the hero: a helm's or armour's colourway where
## it isn't Shade's bare template (above the neck for a helm, below for
## armour, in the idle and walk frames), or the tint of the rest.
func _worn(item_id: String, slot: String) -> Array[Color]:
	if slot not in ["head", "body"]:
		return [PunyArt._tint_of(Catalog.item(item_id), Color.WHITE)]
	var table: Dictionary = PunyArt.HEADS if slot == "head" else PunyArt.BODIES
	var sheet: Image = (load(PunyArt.path(table[item_id])) as Texture2D).get_image()
	var base: Image = (load(PunyArt.path(PunyArt.BASE)) as Texture2D).get_image()
	var necks := PunyArt._neck_rows()
	var columns := base.get_width() / 32
	var out: Array[Color] = []
	for row in base.get_height() / 32:
		for column in 4:
			var neck := necks[row * columns + column]
			for y in 32:
				if (y < neck) != (slot == "head"):
					continue
				for x in 32:
					var at := Vector2i(column * 32 + x, row * 32 + y)
					var here := sheet.get_pixelv(at)
					if here.a > 0.0 and here != base.get_pixelv(at):
						out.append(here)
	return out


func _colours(image: Image) -> Array[Color]:
	var out: Array[Color] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				out.append(image.get_pixel(x, y))
	return out


## Colours' main hue (radians) weighted by chroma, so greys and the black
## outline weigh nothing; their mean chroma; and how far their hues agree
## ("focus": 1 for one hue, 0 for opposite ones).
func _hue(colours: Array[Color]) -> Dictionary:
	var sum := Vector2.ZERO
	var weight := 0.0
	for colour in colours:
		var chroma := maxf(colour.r, maxf(colour.g, colour.b)) - minf(colour.r, minf(colour.g, colour.b))
		sum += Vector2.from_angle(colour.h * TAU) * chroma
		weight += chroma
	return {"hue": sum.angle(), "chroma": weight / maxf(1.0, colours.size()), "focus": sum.length() / maxf(weight, 0.001)}


func _degrees(angle: float) -> int:
	return int(fposmod(rad_to_deg(angle), 360.0))
