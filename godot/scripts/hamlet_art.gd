class_name HamletArt
## areas: town travel field +blackiron* +saltmere* +greyhold* +frostgate* +mountain_road*
## What the settlements beyond Pixelheim are dressed in that Shade's sheets
## don't draw (PIX-313), and the story's last set pieces (PIX-312): kegs and
## crates at the Puny folk's scale (Shade's barrel stood as tall as the
## villager beside it), woodpiles, coal and ore, a quenching tub, Saltmere's
## boats, drying nets, creels and fish rack, a washing line, a vegetable
## bed, a miner's lantern by a door, Morvax's forge stack and the light
## under his door, and the Kings' Vault's black iron door in its carved
## surround, shut and open; and Pixelheim's post box (PIX-320), empty or
## with the day's post in it, and the post house behind it (PIX-325). Pixelheim's
## yards take its window boxes and the City's bunting (PIX-382, Yards), and
## its market Mabel's stalls cleared for the pack's wares, a handcart and a
## crate of fish (PIX-382 step 4). Drawn here in code in Shade's palette (his
## outline, his woods, irons and greys), at 1x on his 16 px grid, so they
## sit beside his art as his. Our own, so CC0 like the rest of the
## repository: they draw the same with or without the paid pack. Pictures
## are rows of characters, one a pixel, keyed in INKS; a piece's foot is its
## bottom row.

const TILE := 16
## Shade's palette, a character a colour: o his outline; woods dark to
## light (1-6); irons and greys (k i l h j); snow (y s S); a net's tarred
## twine (t T); cork and cloth (r R e, u U, b B); the dark of a doorway
## (n N); leaves (f F v) and carrots (c C); coal (z Z); flame and gold
## (a Y q Q); slate (g G) and water (w W); sea glass (m M, PIX-324: the
## coast's shallows' greens).
const INKS := {
	"o": Color("2e2036"), "1": Color("4a3132"), "2": Color("644227"), "3": Color("79542d"), "4": Color("a1753f"),
	"5": Color("c18f4f"), "6": Color("d6a555"), "k": Color("2d2d2d"), "i": Color("484849"), "l": Color("6f6f70"),
	"h": Color("9a9b9e"), "j": Color("b5b7bb"), "y": Color("ffffff"), "s": Color("d7e3ec"), "S": Color("a9bfd0"),
	"t": Color("1f3d46"), "T": Color("3a6466"), "r": Color("d5773b"), "R": Color("c0463b"), "e": Color("8f2d2d"),
	"u": Color("4f6d96"), "U": Color("7d9bc4"), "n": Color("141318"), "N": Color("26252b"), "b": Color("b3aa8f"),
	"B": Color("e8e2cc"), "f": Color("2f5a3a"), "F": Color("4c8a4e"), "v": Color("7bb35a"), "c": Color("8a4a32"),
	"C": Color("e0884a"), "z": Color("1d1b22"), "Z": Color("3b3944"), "a": Color("f8ac34"), "Y": Color("fbe08a"),
	"q": Color("fff4c0"), "Q": Color("e8b84a"), "g": Color("4d587a"), "G": Color("5e769e"), "w": Color("596b7a"),
	"W": Color("8ea6b8"), "m": Color("3e9e94"), "M": Color("8fd8c8"),
}
## A glint's beats over the Vault's gold once its door stands open: most
## beats dark, then a star that opens and closes.
const GLINT_BEATS := 14
const GLINT_FPS := 7.0
## Where on the open door the glints catch, in its pixels, in turn.
const GLINT_AT := [Vector2i(8, 12), Vector2i(6, 11), Vector2i(10, 13)]
## The light under Morvax's door, in three beats of his fire.
const DOOR_GLOW_FPS := 6.0
const DOOR_GLOW := [Color(1.0, 0.62, 0.25, 0.85), Color(1.0, 0.7, 0.32, 0.7), Color(1.0, 0.56, 0.2, 0.9)]
## A washing line's cloths, pegged along it in turn: [width, height, cloth
## ink, its shade].
const CLOTHS := [[5, 6, "B", "b"], [3, 4, "u", "g"], [7, 7, "B", "b"], [4, 5, "R", "e"], [2, 4, "U", "u"]]
## How far a washing line sags in its middle, in pixels, and how high its
## ends are tied above the bottom of its cells.
const LINE_SAG := 3
const LINE_HIGH := 13
## A boat afloat rises and settles a pixel on the swell, this many times a
## second; its frames have this much room either side for the ripples at
## its waterline (this far up from its keel), and it rides this far down
## in its cells.
const AFLOAT_FPS := 1.2
const AFLOAT_PAD := 2
const WATERLINE := 4
const AFLOAT_SINK := 2
## Where the smoke leaves Morvax's forge stack and where a miner's
## lantern's glass hangs, from its cell's top left.
const STACK_MOUTH := Vector2(8, 2)
const LANTERN_GLASS := Vector2(8, 9)

const PIECES := {
	## A keg at the Puny folk's scale (PIX-313: Shade's barrel stood as tall as a
	## villager): staves, two iron hoops, its lid. 16x16, foot on the bottom row.
	"keg": [
		"................",
		"................",
		"................",
		"................",
		"................",
		".....oooooo.....",
		"....o344443o....",
		"....o455554o....",
		"....okiiiiko....",
		"....o344443o....",
		"....o345543o....",
		"....o344443o....",
		"....okiiiiko....",
		"....o234432o....",
		".....o2332o.....",
		"......oooo......",
	],
	## A crate at their scale: planks, a brace across, darker sides.
	"box": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"...oooooooooo...",
		"..o5555555554o..",
		"..oooooooooooo..",
		"..o5o4444445o3o.",
		"..o4o54444o4o3o.",
		"..o4o445o444o3o.",
		"..o4o4o5444o4o..",
		"..o4o5444444o3o.",
		"..o3o2222222o2o.",
		"..oooooooooooo..",
	],
	## Logs stacked against a wall: their cut ends, rings in them.
	"woodpile": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"......oooo......",
		".....o5665o.....",
		"...ooo6c36ooo...",
		"..o5665o56o5665o",
		"..o6c36oooo6c36o",
		"oooo56ooo5o5665o",
		"o5665o5665o6c36o",
		"o6c36o6c36oo56oo",
		"oo56ooo56oo2222o",
		".oooooooooooooo.",
	],
	## The same under the Frostgate's snow.
	"woodpile_snow": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"......ssss......",
		".....oyyyyo.....",
		"....oyyyyyyo....",
		"...oyy6c36yyoo..",
		"..oyyyyo56oyyyyo",
		"..o6c36oooo6c36o",
		"oyyyy6ooosyyyyyo",
		"o5665o5665o6c36o",
		"o6c36o6c36oo56oo",
		"oo56ooo56oo2222o",
		".oooooooooooooo.",
	],
	## A tub of water for quenching hot iron.
	"tub": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"...oooooooooo...",
		"..o4555555554o..",
		"..o5wwWWwwww5o..",
		"..o4wwwwWWww4o..",
		"..okiiiiiiiiko..",
		"..o3444444443o..",
		"..o2333333332o..",
		"...o22222222o...",
		"....oooooooo....",
	],
	## A crate of coal, and one of charcoal sacks.
	"coal": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"......oo.oo.....",
		"....ooZzoZzo....",
		"...oZzzZzzZzo...",
		"..oooooooooooo..",
		"..o5444444443o..",
		"..o4ooooooo23o..",
		"..o4444444443o..",
		"..o4ooooooo23o..",
		"..o3222222221o..",
		"..oooooooooooo..",
	],
	## Iron ore heaped by the miners' door: grey rock, rust in it.
	"ore": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		".......ooo......",
		"......ohhlo.....",
		"....ooljrlloo...",
		"...ohjllloCrlo..",
		"..ohlrClhjlllo..",
		"..olllliilrClio.",
		".oilCrliiillliio",
		".oiiiiiiiiiiiio.",
		"..oooooooooooo..",
	],
	## An ore cart on a stub of rail.
	"cart": [
		"................",
		"................",
		"................",
		".....oooooo.....",
		"...ooljrlCloo...",
		"..olhjlrClhjlo..",
		".ooooooooooooooo",
		".okhhhhhhhhhhhko",
		"..okllllllllko..",
		"..okiillliiiko..",
		"...okkkkkkkko...",
		"..oZzo....oZzo..",
		".o3ozo3333ozo3o.",
		".o3333333333333o",
		"..o.o..o..o..o..",
		"................",
	],
	## Lobster pots stacked on the sand: woven cages, a rope's eye on top.
	"creels": [
		"................",
		"................",
		"................",
		"................",
		".......oo.......",
		"......o5co......",
		".....oooooo.....",
		"....o5o5o5oo....",
		"....o4o4o43o....",
		"....oooooooo....",
		"..oooooooooooo..",
		"..o5o5o5o5o5co..",
		"..o4o4o4o4o43o..",
		"..o4o4o4o4o43o..",
		"..o3o3o3o3o32o..",
		"..oooooooooooo..",
	],
	## Fish drying on a rack: two posts, a pole, four fish hung by the tail.
	"fish_rack": [
		"................",
		"................",
		".oo..........oo.",
		".o5oooooooooo5o.",
		".o4o4444444443o.",
		".o4ooooooooooo4.",
		".o4o.o..o..o.o4.",
		".o4ojojojojo.o4.",
		".o4ojhjojhjo.o4.",
		".o4ohWhohWho.o4.",
		".o4ohWhohWho.o4.",
		".o4ohWhohWho.o4.",
		".o4ohhhohhho.o4.",
		".o4o.oho.oho.o4.",
		".o4o..o...o..o4.",
		".o3o.........o3.",
		".o3o.........o3.",
		".o3o.........o3.",
		".o2o.........o2.",
		".ooo.........ooo",
	],
	## Nets drying on a rack: three posts and a rail, the net sagging between
	## them, its cork floats along the top.
	"nets": [
		"................................",
		"................................",
		".oo............oo............oo.",
		".o5oooooooooooo5ooooooooooooo5o.",
		".o4o4444444444o4o44444444444o4o.",
		".o4ooroooorooo.4ooroooorooooo4o.",
		".o4TtTtTtTtTtTo4TtTtTtTtTtTtTo4o",
		".o4tTtTtTtTtTto4tTtTtTtTtTtTto4o",
		".o4TtTtTtTtTtTo4TtTtTtTtTtTtTo4o",
		".o4otTtTtTtTtoo4otTtTtTtTtTtoo4o",
		".o4ooTtTtTtTo.o4.oTtTtTtTtTo.o4o",
		".o4o.otTtTtoo.o4.ootTtTtTtoo.o4o",
		".o4o..ooTtoo..o4..oooTtTtoo..o4o",
		".o4o....oo....o4.....oooo....o4o",
		".o3o..........o3o............o3o",
		".o3o..........o3o............o3o",
		".o3o..........o3o............o3o",
		".o2o..........o2o............o2o",
		".ooo..........ooo............ooo",
	],
	## A rowing boat, bow to the east: its strakes, its thwarts, a pair of oars
	## shipped along it. 32x16, its keel on the bottom rows.
	"boat": [
		"................................",
		"................................",
		"................................",
		"................................",
		".......oooooooooooooooooo.......",
		"....ooo566666666666666665ooo....",
		"..oo5662222222222222222222665oo.",
		".o5621111o4o11111111o4o111112665",
		"o5621111o445o1111111o45o1111126o",
		"o4621111o4o11111111o4o111111264o",
		".o45622222222222222222222226543o",
		"..o3445555555555555555555544433o",
		"...oo33444444444444444444433oo..",
		".....oo2222222222222222222oo....",
		".......ooooooooooooooooooo......",
		"................................",
	],
	## A lantern on an iron bracket by a door, its glass cold by day.
	"lantern": [
		"................",
		"................",
		"..oooooo........",
		"..okiiikoo......",
		"..oooookiko.....",
		"........oko.....",
		".......o4o......",
		"......o464o.....",
		".....okkkkko....",
		".....okhgGko....",
		".....okgggko....",
		".....okggako....",
		".....okkkkko....",
		"......o464o.....",
		".......ooo......",
		"................",
	],
	## Its glass lit at night (the only part the dark doesn't touch).
	"lantern_lit": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		".......Yqa......",
		".......aYa......",
		".......aaa......",
		"................",
		"................",
		"................",
		"................",
	],
	## A window box (PIX-382, Pixelheim's yards): a planter of planks hung
	## under a window's sill, its flowers over the glass's foot and spilling
	## over its edges; red here, the others by WINDOW_TINTS. On the wall, so
	## it blocks nothing.
	"window_box": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"...e.....e...e..",
		"..eRe.F.eRe.eRe.",
		"..RrRFvFRrRFRrR.",
		".FvRFfvFvRFvFRvF",
		".oooooooooooooo.",
		".o665666656665o.",
		".o444344443444o.",
		".o332333323332o.",
		"..oooooooooooo..",
	],
	## A vegetable bed in a fenced yard: dark tilled earth, rows of cabbages
	## and carrot tops.
	"garden": [
		"................",
		"................",
		"..2.2..2...2.2..",
		".2121212121212..",
		".21fF1fF1fF1f12.",
		"..1FvF1FvF1Fv1..",
		".2111111111111..",
		"..21v1v1v1v1v12.",
		".212C1C1C1C1C1..",
		"..21111111111112",
		".21fF1fF1fF1f12.",
		"..1FvF1FvF1Fv1..",
		".2111111111111..",
		"..2121212121212.",
		"...2..2.2..2....",
		"................",
	],
	## A handcart come up to Pixelheim's market (PIX-382 step 4): its bed of
	## planks on one wheel, its shafts resting on the ground; empty, the
	## pack's wares laid on it (Yards' `on`). 32x16, foot on the bottom row.
	"handcart": [
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"..oooooooooooooooooooo..........",
		"..o3333333333333333332o.........",
		"..o2222222222222222222o.........",
		"..oooooooooooooooooooooo........",
		"..o6666o66666666o666665oooooooo.",
		"..o4444o4oooo444o444443o5555556o",
		"..o3333oo2552oo3o33333oooooooooo",
		"..ooooo2o2oo2o2ooooooo.......o..",
		"......o5o2552o5o.............o..",
		"......oo2o22o2oo.............o..",
		".......ooo22ooo.................",
	],
	## A crate of the coast's catch (PIX-382 step 4), the one ware the pack
	## doesn't draw: silver fish laid head to tail in a wooden crate.
	"fish_crate": [
		"................",
		"................",
		"................",
		"..oooooooooooo..",
		".o666666666665o.",
		".o5oooooooooo4o.",
		".o5o2jjjjh2l24o.",
		".o5ojkWjjhll24o.",
		".o5o2hhhhl2l24o.",
		".o5o2l2hjjjj24o.",
		".o5o2llhjjWkj4o.",
		".o5o2l2lhhhh24o.",
		".o5oooooooooo4o.",
		".o444444444443o.",
		".o3o.......o3o..",
		".ooo.......ooo..",
	],
	## The Kings' Vault's door (PIX-312): two leaves of black iron studded and
	## banded, a ring on each, in a doorway cut in the rock, a carved step.
	"vault_door": [
		"....oooooooo....",
		"..oollhhhhlloo..",
		".olhhoooooohhlo.",
		".olhokkkkkkohlo.",
		"olhokzZkkZzkohlo",
		"olhokhzkkzhkohlo",
		"olhokzZkkZzkohlo",
		"olhokiiiiiikohlo",
		"olhokzZkkZzkohlo",
		"olhokzjkkjzkohlo",
		"olhokzZkkZzkohlo",
		"olhokiiiiiikohlo",
		"olhokzZkkZzkohlo",
		"olhokhzkkzhkohlo",
		"ohjjjjjjjjjjjjho",
		"oooooooooooooooo",
	],
	## Open: the leaves swung in against the jambs, the dark beyond, the hoard's
	## gold catching what light comes in.
	"vault_door_open": [
		"....oooooooo....",
		"..oollhhhhlloo..",
		".olhhoooooohhlo.",
		".olhokinnnikohlo",
		"olhokznnnnzkohlo",
		"olhokznnnnzkohlo",
		"olhokinnnnikohlo",
		"olhokznnnnzkohlo",
		"olhokzNnnNzkohlo",
		"olhokzNNNNzkohlo",
		"olhokiNNNNikohlo",
		"olhokzN6QNzkohlo",
		"olhokz6QaQzkohlo",
		"olhokiQa6aikohlo",
		"ohjjjjjjjjjjjjho",
		"oooooooooooooooo",
	],
	## The carved lintel over it: the old kings' crown cut in the rock.
	"vault_lintel": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		".....o.oo.o.....",
		"....oQoQQoQo....",
		"....oQQaaQQo....",
		"....oQQQQQQo....",
		"...oooooooooo...",
		"..olhhhhhhhhlo..",
		".olhjjjjjjjjhlo.",
		"olhhllllllllhhlo",
		"olhlhhhhhhhhlhlo",
	],
	## Morvax's forge stack (PIX-312): a broad chimney of soot-black stone, its
	## mouth glowing, taller than a cottage's.
	"forge_stack": [
		"................",
		"...oooooooooo...",
		"..ozzzzzzzzzzo..",
		"..oZnnnnnnnnZo..",
		"..olhhhhhhhhlo..",
		"...oZlZlZlZlo...",
		"...olZlZlZlZo...",
		"...oZliZlZilo...",
		"...olZlZiZlZo...",
		"...oZlZlZlZlo...",
		"...olZiZlZlZo...",
		"...oZlZlZiZlo...",
		"..oolZlZlZlZoo..",
		".olhlhlhlhlhlhlo",
		".oiiiiiiiiiiiiio",
		"..oooooooooooo..",
	],
	## Saltmere's fish stall by the jetty road: a striped awning on two poles
	## over a plank counter on trestles, the morning's catch laid out on it and
	## a basket of it beside.
	"fish_stall": [
		"................................",
		"................................",
		"...oooooooooooooooooooooooooo...",
		"..oBBuuBBuuBBuuBBuuBBuuBBuuBBo..",
		".oBBuuBBuuBBuuBBuuBBuuBBuuBBuuo.",
		".obbgubbgubbgubbgubbgubbgubbgbo.",
		"..ooBoooBoooBoooBoooBoooBoooBo..",
		"...o4o...................o4o....",
		"...o4o...................o4o....",
		"...o4o...................o4o....",
		"...o4o...................o4o....",
		"..oo4oooooooooooooooooooooo4oo..",
		"..o5ohjhoo5ojhjhoo5ohjho5o5o55o.",
		"..o4ohWhho4ohWhhhoo4hWho4o4o44o.",
		"..oooooooooooooooooooooooooooooo",
		"..o3333333333333333333333333333o",
		"..oooooooooooooooooooooooooooooo",
		"...o2o.....................o2o..",
		"...o2o.....................o2o..",
		"...ooo.....................ooo..",
	],
	## The fire's glow in the forge stack's mouth, over it: untouched by the
	## dark, so it shows red at night.
	"forge_mouth": [
		"................",
		"................",
		"................",
		"...CaaYaaYaaC...",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	## A net hung to dry on a fisher's wall, its corks along the top.
	"wall_net": [
		"................",
		"..oo........oo..",
		"..o4oooooooo4o..",
		"...orTrTrTrTo...",
		"...oTtTtTtTto...",
		"...otTtTtTtTo...",
		"...oTtTtTtTto...",
		"....oTtTtTtTo...",
		"....otTtTtTo....",
		".....oTtTtTo....",
		".....otTtTo.....",
		"......oTtTo.....",
		"......otTo......",
		".......oo.......",
		"................",
		"................",
	],
	## Pixelheim's post box on the square (PIX-320): a slate-roofed box on a
	## post, its slot under the eave and an envelope's back on its front.
	## 16x26, foot on the bottom row.
	"post_box": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"......oooo......",
		"....ooGGGGoo....",
		"..ooGGGGGGGgoo..",
		".oGGGGGGGGggggo.",
		".oooooooooooooo.",
		"..o5444444443o..",
		"..o4kkkkkkkk3o..",
		"..o4knnnnnnk3o..",
		"..o4kkkkkkkk3o..",
		"..o44bBBBBb43o..",
		"..o44BbBBbB43o..",
		"..o44BBbbBB43o..",
		"..o44BbBBbB43o..",
		"..o44bBBBBb43o..",
		"..o3333333332o..",
		"..oooooooooooo..",
		"......o42o......",
		"......o32o......",
		".....oo32oo.....",
		"....o233332o....",
		"....oooooooo....",
	],
	## The same with the day's post in it: a letter sealed in red poking out
	## of the slot, and the red pennant up on the roof.
	"post_box_full": [
		"........o.......",
		"........kooo....",
		"........kRRRo...",
		"........kRReo...",
		"........kooo....",
		"......ookoo.....",
		"....ooGGkGoo....",
		"..ooGGGGGGGgoo..",
		".oGGGGGGGGggggo.",
		".oooooooooooooo.",
		"..o5444444443o..",
		"..o4kkBBkkkk3o..",
		"..o4knBBBRnk3o..",
		"..o4kkkkkkkk3o..",
		"..o44bBBBBb43o..",
		"..o44BbBBbB43o..",
		"..o44BBbbBB43o..",
		"..o44BbBBbB43o..",
		"..o44bBBBBb43o..",
		"..o3333333332o..",
		"..oooooooooooo..",
		"......o42o......",
		"......o32o......",
		".....oo32oo.....",
		"....o233332o....",
		"....oooooooo....",
	],
	## The post house behind the box (PIX-325): a slate-roofed timber house
	## two cells wide, Pip's loft on its ridge (two holes, a dove at one,
	## another on the perch and one on the ridge: the rest are off seeing
	## the Reach), a window, the door under Wren's horseshoe, an envelope
	## sign on its bracket. 32x44, foot on the bottom row.
	"post_house": [
		"................................",
		"...............oo...............",
		"..............oGGo..............",
		".............oGGGgo.............",
		"............oGGGGggo............",
		"...........oGGGGGgggo...........",
		"..........oooooooooooo..........",
		"........oo.o54444443o...........",
		".......oyyoo4nn44yn3o...........",
		"......oyyyoo4nn44nn3o..oo.......",
		".....a22222o44444443o.oyyo......",
		"...........oooooooooo.oyyyo.....",
		"...oooooooooooooooooooooooooo...",
		"..oGGGGGGGGGGGGGGGGGGGGGGGGGGo..",
		"..oGGGGGGGGGGGGGGGGGGGGGGGGGGo..",
		".oggggggggggggggggggggggggggggo.",
		".oGGGGGGGGGGGGGGGGGGGGGGGGGGGGo.",
		".oGGGGGGGGGGGGGGGGGGGGGGGGGGGGo.",
		"oggggggggggggggggggggggggggggggo",
		"oGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGo",
		"oGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGo",
		"oggggggggggggggggggggggggggggggo",
		"oooooooooooooooooooooooooooooooo",
		".o2222222222222222222222222222o.",
		".o4bbbbbbbbbbbbbbbbbbbbbbbbbb3o.",
		".o4BBBBBBBBBBBBBBBBBBBBkkkkkk3o.",
		".o4BBoooooBBBBBBBBBBBBBBkBBkB3o.",
		".o4BBouUuoBBBBBBBhBBhBBoooooo3o.",
		".o4BBoUuuoBBBBBBBhBBhBBobBBbo3o.",
		".o4BBouUuoBBBBBBBBhhBBBoBbbBo3o.",
		".o4BBoooooBBBBBBooooooBoBRBBo3o.",
		".o4BB33333BBBBBBo3443oBoooooo3o.",
		".o4BBBBBBBBBBBBBo3443oBBBBBBB3o.",
		".o4BBBBBBBBBBBBBo3443oBBBBBBB3o.",
		".o42222222222222o3443o22222223o.",
		".o4BBBBBBBBBBBBBo344QoBBBBBBB3o.",
		".o4BBBBBBBBBBBBBo3443oBBBBBBB3o.",
		".o4BBBBBBBBBBBBBo3443oBBBBBBB3o.",
		".o4BBBBBBBBBBBBBo3443oBBBBBBB3o.",
		".o4BBBBBBBBBBBBBo3443oBBBBBBB3o.",
		".o4BBBBBBBBBBBBBo3443oBBBBBBB3o.",
		".ollllllllllllllo3443ollllllllo.",
		".oiiiiiiiiiiiiiio3443oiiiiiiiio.",
		".oooooooooooooooooooooooooooooo.",
	],
}


static var _textures := {}
static var _lines := {}
static var _bunting := {}
static var _afloat := {}
static var _glint: SpriteFrames
static var _door_glow: SpriteFrames


## The window box's flowers in the town's other colours (PIX-382): its
## reds swapped, blossom, shade and highlight.
const WINDOW_TINTS := {
	"window_box_gold": {"R": "Y", "e": "a", "r": "q"},
	"window_box_white": {"R": "B", "e": "b", "r": "y"},
	"window_box_blue": {"R": "U", "e": "u", "r": "s"},
}
## The bunting strung across the City's square (PIX-382): its pennants'
## [ink, shade] in turn, a lantern in place of every LANTERN_EVERY-th, and
## how far its rope sags at most.
const PENNANTS := [["R", "e"], ["Y", "a"], ["U", "u"], ["B", "b"]]
const LANTERN_EVERY := 5
const BUNTING_SAG := 7


## Pixelheim's market stalls (PIX-382 step 4): Mabel's (HubArt) with their
## counters cleared of her small heaps, so the pack's wares lie on them
## (Yards' `on`), and one with its awning in green: [whose, inks swapped].
const STALLS := {
	"stall_red": ["market_stall", {}],
	"stall_blue": ["market_stall_blue", {}],
	"stall_green": ["market_stall", {"R": "F", "e": "f"}],
}
## Where on Mabel's stall her heaps lie: between the poles, over the counter.
const STALL_HEAPS := Rect2i(6, 14, 20, 4)


## Piece `name`'s rows: ours, what the hubs grow (HubArt, PIX-324), or
## what the Post's roads put up (RouteArt: the town's benches, PIX-382).
static func rows_of(name: String) -> Array:
	if STALLS.has(name):
		var swap: Dictionary = STALLS[name][1]
		var rows := rows_of(STALLS[name][0])
		var out := []
		for y in rows.size():
			var row := ""
			for x in String(rows[y]).length():
				var ink := String(rows[y])[x]
				row += "." if STALL_HEAPS.has_point(Vector2i(x, y)) else String(swap.get(ink, ink))
			out.append(row)
		return out
	if WINDOW_TINTS.has(name):
		var swap: Dictionary = WINDOW_TINTS[name]
		return PIECES["window_box"].map(func(row: String) -> String:
			var out := ""
			for ink in row:
				out += String(swap.get(ink, ink))
			return out)
	if PIECES.has(name):
		return PIECES[name]
	return HubArt.PIECES[name] if HubArt.PIECES.has(name) else RouteArt.PIECES[name]


## Piece `name` drawn (a "." clear), as an image.
static func picture(name: String) -> Image:
	var rows := rows_of(name)
	var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if row[x] != ".":
				image.set_pixel(x, y, INKS[row[x]])
	return image


## Piece `name` as a texture, drawn once a session.
static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = ImageTexture.create_from_image(picture(name))
	return _textures[name]


## How big piece `name` is, in pixels.
static func size(name: String) -> Vector2i:
	var rows := rows_of(name)
	return Vector2i(String(rows[0]).length(), rows.size())


## How many cells across piece `name` stands.
static func cells_wide(name: String) -> int:
	return ceili(size(name).x / float(TILE))


## What burns in a lit piece at night (PIX-324: the lighthouse's lantern,
## the lodge's windows, the stall's lantern): its flame's and its sea
## glass's pixels alone, a step brighter, drawn over it unshaded.
const SHINE := {"a": "Y", "Y": "q", "q": "q", "m": "a", "M": "Y"}


static func shine(name: String) -> Texture2D:
	var key := "shine:" + name
	if not _textures.has(key):
		var rows := rows_of(name)
		var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			var row := String(rows[y])
			for x in row.length():
				if SHINE.has(row[x]):
					image.set_pixel(x, y, INKS[SHINE[row[x]]])
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


## Where a lit piece's light stands, in its pixels: the middle of what
## burns in it.
static func shine_at(name: String) -> Vector2:
	var image := (shine(name) as ImageTexture).get_image()
	return Rect2(image.get_used_rect()).get_center()


## A washing line strung `cells` cells across (between two walls, PIX-313):
## its rope sagging in the middle and the week's wash pegged along it.
static func washing(cells: int) -> Texture2D:
	if not _lines.has(cells):
		var width := cells * TILE
		var image := Image.create(width, TILE, false, Image.FORMAT_RGBA8)
		var high := TILE - LINE_HIGH
		var line: Array[int] = []
		for x in width:
			var t := x / float(maxi(1, width - 1))
			line.append(high + roundi(LINE_SAG * 4.0 * t * (1.0 - t)))
			image.set_pixel(x, line[x], INKS["3"])
		var x := 3
		var turn := cells
		while x < width - 3:
			var cloth: Array = CLOTHS[turn % CLOTHS.size()]
			var w: int = cloth[0]
			var h: int = cloth[1]
			if x + w >= width - 2:
				break
			var top: int = line[x + w / 2] + 1
			for dy in h:
				for dx in w:
					var ink: String = cloth[2]
					if dx == 0 or dx == w - 1 or dy == h - 1:
						ink = "o"
					elif dx == w - 2 or dy == h - 2:
						ink = cloth[3]
					image.set_pixel(x + dx, top + dy, INKS[ink])
			# A peg at each top corner.
			image.set_pixel(x, top - 1, INKS["4"])
			image.set_pixel(x + w - 1, top - 1, INKS["4"])
			x += w + 2 + turn % 2
			turn += 1
		_lines[cells] = ImageTexture.create_from_image(image)
	return _lines[cells]


## The bunting over the City's square (PIX-382): a rope tied under the
## lanterns of two lamps `cells` + 1 cells apart (it starts at the left
## lamp's middle, half a cell before its first cell), sagging between, a
## pennant in the town's colours every few pixels and a small lantern in
## place of every LANTERN_EVERY-th. By day ("day"), what burns in its
## lanterns at night ("lit", drawn over it unshaded) and each lantern's
## middle ("lights"). Two cells tall, its foot the bottom of its row.
static func bunting(cells: int) -> Dictionary:
	if not _bunting.has(cells):
		var width := (cells + 1) * TILE
		var day := Image.create(width, TILE * 2, false, Image.FORMAT_RGBA8)
		var lit := Image.create(width, TILE * 2, false, Image.FORMAT_RGBA8)
		var lights: Array[Vector2] = []
		var sag := mini(BUNTING_SAG, 2 + cells / 3)
		var rope: Array[int] = []
		for x in width:
			var t := x / float(width - 1)
			# Tied a pixel above its row, where a lamp's post meets its lantern.
			rope.append(TILE - 1 + roundi(sag * 4.0 * t * (1.0 - t)))
			day.set_pixel(x, rope[x], INKS["3"])
		var x := 4
		var turn := 0
		while x + 5 < width - 3:
			var top: int = rope[x + 2] + 1
			if turn % LANTERN_EVERY == LANTERN_EVERY - 1:
				# A lantern on its hook: cap, glass, foot.
				day.set_pixel(x + 2, top, INKS["o"])
				for dy in [1, 2]:
					day.set_pixel(x + 1, top + dy, INKS["o"])
					day.set_pixel(x + 2, top + dy, INKS["Q"])
					day.set_pixel(x + 3, top + dy, INKS["o"])
					lit.set_pixel(x + 2, top + dy, INKS["q"])
				day.set_pixel(x + 2, top + 3, INKS["o"])
				lights.append(Vector2(x + 2.5, top + 2.0))
			else:
				var pennant: Array = PENNANTS[turn % PENNANTS.size()]
				for dy in 3:
					for dx in range(dy, 5 - dy):
						day.set_pixel(x + dx, top + dy, INKS[pennant[1] if dy == 2 or dx == 4 - dy else pennant[0]])
			x += 6
			turn += 1
		_bunting[cells] = {"day": ImageTexture.create_from_image(day), "lit": ImageTexture.create_from_image(lit), "lights": lights}
	return _bunting[cells]


## Boat `name` afloat (Saltmere's at the jetty, PIX-313): two beats, riding
## a pixel higher then lower on the swell, the water lapping white at its
## bow and stern, AFLOAT_PAD clear either side.
static func afloat(name: String) -> SpriteFrames:
	if not _afloat.has(name):
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", AFLOAT_FPS)
		var hull := picture(name)
		var size := hull.get_size()
		var foam := Color(INKS["y"], 0.8)
		var lap := Color(INKS["s"], 0.6)
		for beat in 2:
			var image := Image.create(size.x + AFLOAT_PAD * 2, size.y + 1, false, Image.FORMAT_RGBA8)
			image.blend_rect(hull, Rect2i(Vector2i.ZERO, size), Vector2i(AFLOAT_PAD, beat))
			var water := size.y - WATERLINE + beat
			for side: int in [0, 1]:
				var x := 0 if side == 0 else size.x + AFLOAT_PAD * 2 - 2
				image.set_pixel(x + beat, water, foam)
				image.set_pixel(x + 1 - beat, water + 1, lap)
			frames.add_frame("default", ImageTexture.create_from_image(image))
		_afloat[name] = frames
	return _afloat[name]


## The glint over the open Vault's gold: GLINT_BEATS beats, a small star
## opening and closing over the last few, at each of GLINT_AT in turn.
static func glint() -> SpriteFrames:
	if _glint == null:
		_glint = SpriteFrames.new()
		_glint.set_animation_speed("default", GLINT_FPS)
		var cross := [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		var star := [[], [Vector2i.ZERO], cross, cross + [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]]
		var steps := [1, 2, 3, 2, 1]
		for spot: Vector2i in GLINT_AT:
			for beat in GLINT_BEATS:
				var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
				var lit := beat - (GLINT_BEATS - steps.size())
				for point: Vector2i in star[steps[lit] if lit >= 0 else 0]:
					var at: Vector2i = spot + point
					if Rect2i(0, 0, TILE, TILE).has_point(at):
						image.set_pixel(at.x, at.y, INKS["q"] if point == Vector2i.ZERO else INKS["Y"])
				_glint.add_frame("default", ImageTexture.create_from_image(image))
	return _glint


## The light under Morvax's door (PIX-312): the gap under it and its
## keyhole lit by the fire inside (Shade's door's), and a warm wash on the
## threshold below, flickering through DOOR_GLOW's beats. 16x24: the door's
## cell and the top half of the cell before it.
static func door_glow() -> SpriteFrames:
	if _door_glow == null:
		_door_glow = SpriteFrames.new()
		_door_glow.set_animation_speed("default", DOOR_GLOW_FPS)
		for beat: Color in DOOR_GLOW:
			var image := Image.create(TILE, TILE + TILE / 2, false, Image.FORMAT_RGBA8)
			for at: Vector2i in [Vector2i(11, 8), Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9)]:
				image.set_pixel(at.x, at.y, beat)
			# The gap under the door, and the light along its jambs.
			for x in range(1, 15):
				image.set_pixel(x, 13, beat)
			for y in range(6, 13):
				var seam := Color(beat, beat.a * 0.55)
				image.set_pixel(0, y, seam)
				image.set_pixel(15, y, seam)
			for y in range(14, TILE + TILE / 2):
				var fade := 1.0 - (y - 13) / float(TILE / 2 + 3)
				for x in range(1, 15):
					var middle := clampf((1.0 - absf(x - 7.5) / 8.0) * 1.6, 0.0, 1.0)
					var tint := beat
					tint.a = beat.a * 0.7 * fade * fade * middle
					if tint.a > 0.02:
						image.set_pixel(x, y, tint)
			_door_glow.add_frame("default", ImageTexture.create_from_image(image))
	return _door_glow
