# UI art audit: what to buy and how it plugs in

Audit of v0.293.0 (2026-10-28). No game code changed.

- I took 11 screenshots in French with the paid packs installed: HUD in play, inventory, Odo's counter, the village ledger, the map, options, Sela's dialogue, Greymaw's boss bar, the title, the rank-up and the journal.
- Tom bought the GegX Pixel UI Kit during the audit. I assessed it against its real files (see "The GegX kit, against the real files") and made three mock-ups with it.
- The screenshots and mock-ups stay on the Mac and are not in git, because they show paid art.

## Top recommendations

1. **Fix the three pieces that fall outside the look, in code, whatever happens with the kit.** Tooltips (dock skill slots, inventory equipment slots) and scrollbars (shop, inventory, ledger, changelog lists) still use Godot's default grey theme, and the mouse is the OS arrow. Three theme items and a cursor in `UiStyle.setup()`, drawn like the other frames, would fix this in about half a day. The GegX kit has no tooltip, scrollbar or cursor either.
2. **Don't drop the GegX kit in as it is.** It is drawn for 1x display: every piece has 1-pixel detail, and its slots hold a 16 px icon at 1x. Our chrome, text and icons are at 2x, and Shade's world is at 3x.
   - At 2x the kit is twice too big: a 90 px slot, 90 px tall buttons, and a window frame over 40 px thick.
   - At 1x it is the right size, but its pixels are half the size of the UI's and a third of the world's.
   - On top of that, every button, tab and bar has its label baked in, there are no clean runs to stretch for 9-slicing, and its palette is not ours.

   Two ways forward:
   - **(B) Recommended first:** take its best ideas (corner brackets, bolts, a brass inner rim, slots in five colourways for rarity and focus) and draw them into `UiStyle`'s own frames at 2x. It stays one pixel size and one palette, needs no install, and takes about a day.
   - **(A) If Tom prefers the kit's look in the mock-ups:** use the **parchment** window and panel for pages and the **wood** buttons, tabs and slots, after a prep pass that erases the labels, cuts clean 9-slice pieces and remaps the colours onto UiStyle's ramps. The kit then plugs into `UiStyle` at 1x, and the code drawing stays as the fallback. This takes about 5 days.
3. **Spend future art money on the gaps players see most:**
   - **Dialogue portraits:** about 38 speakers are shown as their 16 px walking sprite blown up in a 112 px slot.
   - **Combat effects:** a blow is a white flash and a slash arc, and every skill lands as "a soft oval of light" tinted by its stat. There are no hit sparks and no spell sprites, although the Puny Skills pack gives 88 skill icons.
4. **The world map is a code job, not a purchase.** It is coloured squares on a dark field (`05-map`). Drawing it from the maps' own tiles would beat any bought frame around it.

## The pixel grid

| | Value | Where |
|---|---|---|
| Canvas | 1280x720, `canvas_items` stretch, aspect kept | `project.godot` |
| UI art | 1x art shown at `UI_SCALE` 2: one art pixel is 2x2 canvas pixels | `UiStyle.UI_SCALE` |
| World art | Shade's 16 px tiles at camera `ZOOM` 3: one art pixel is 3x3 canvas pixels | `CameraRig.ZOOM` |
| Icons | Shade's packs are 16x16 (survival 114, skills 88, jewelry 27, armour sheet 480x768 on a 16 grid). They are shown at 32x32 in the slots and lists, so 2x, the same as the UI | `ItemIcons`, `HudDock._skills` |
| Type | Pixeloid Sans 9 px at 2x (18), or 3x (27) for titles. The logo is Press Start 2P | `UiStyle.TEXT`/`BIG` |

So a UI kit must be drawn at the size of Shade's icon pixels: **1-pixel strokes at 1x, meant to be shown at 2x**. A 16x16 icon must sit in a slot whose frame is 4 art pixels or less per side. A kit drawn "hi-res" (2–3 px strokes meant for 1x display), or with anti-aliasing, would show pixels of a different size from everything else and is out. The world is at 3x and the UI at 2x on purpose: marks drawn over the world (`Marks`, the world keycap) use the world grid.

## Catalogue: every UI element drawn in code

Sizes are in canvas pixels, with art pixels in brackets. Margins are 9-slice margins in art pixels. All frames are `StyleBoxTexture`s made at runtime from `Image`s in `scripts/ui_style.gd`, scaled 2x with nearest filtering, and cached in `UiStyle._frames`.

### Frames (UiStyle)

| Element | Script, function | Size(s) | 9-slice | States | Used in |
|---|---|---|---|---|---|
| Window (parchment page in a carved wood frame, brass corner studs, grain) | `UiStyle.window(padding, fill)`, `UiStyle.page(rect)` | Art 28x28 (56). On screen from about 150x46 (nameplate) to 1116x570 (options). Shop columns 384x500, 360x500, 384x500. Ledger list 560x438. Dialogue 980x188 | 6 on every side (outline 1, wood 3, outline 1, ink 1). Centre 16x16, **tiled** | One state | Every full screen (inventory, shop, ledger, map, options, journal, saves, changelog, dawn, lookout, create, skills, ring toss), the dialogue, the dock menu, the hint card, the shop nameplate |
| Wood plate (window with `fill = WOOD`) | `UiStyle.window(8, WOOD)` | Dock about 774x110 | 6 | One state | The HUD dock |
| Card, row, slot | `UiStyle.box(fill, rim, padding)` then `_card` | Art 8x8 (16). Inventory rows 696x50. Shop rows about 334x58. Ledger rows 558x44–66. Map list 320x56. Option rows about 518x30. Journal rows about 1080x58. Equipment slots 50x50. Dock skill slots 48x48. Dialogue portrait 112x112 | 2 (1-px rim; focus has 2) | Normal (`RIM`); idle row (`CARD` at 50% alpha); focus and selected (`LAMP`, double rim); ready (`BRASS` rim, dock slot); spent (alpha 0.55); empty (`CARD` fill) | Every list and slot; also the inventory's count badges (`NIGHT`/`NIGHT`, about 24x26) and the title's NOUVEAU badge (`LAMP`/`NIGHT`) |
| Plank (button, tab) | `UiStyle.plank(lit, padding, dim)`, `UiStyle.button()`, `UiStyle.focus()` | Art 8x8 (16). Dock Menu 62x32. Tabs about 60–130x32. "Acheter le titre" about 208x36. Dialogue name tab about 210x36 | 2 | Normal; lit (hover = pressed = focus, a brass rim); dim (disabled). **No separate pressed art** | Buttons in the map, dialogue, inventory, shop, saves, create, pause and dock; tabs in the journal, shop and inventory; the dialogue's name tab |
| Plate (dark translucent bar) | `UiStyle.plate(padding_x)` | Art 6x6 (12). Objective line about 700x28. Message ≤ 860 wide. Log line ≤ 700. Clock about 102x30. Boss plate about 450x48 | 2 | One state (`NIGHT` at 82%, `WOOD_DARK` rim) | Objective ("À suivre"), messages, battle log, toast chips (`world_messages`), title card, clock, edge warning, boss bar, foe level tag, bells, run clock |
| Keycap | `UiStyle.keycap_style(pressed, small, scale)`, `keycap()`, `keys()`, `footer()`/`screen_footer()` | Art 8x12 (16x24). At least 30 or 34 wide. The world keycap is 1x on the world grid (24x36 on screen) | Left and right 2; top 2 (pressed 3); bottom 5 (pressed 3) | Up; pressed (face drops 1 px) | Every footer, the dock menu, keyed planks, the dialogue's E and Esc, the E prompt over the world (`world_interaction`) |

### Small pieces (UiStyle)

| Element | Function | Size | States | Used in |
|---|---|---|---|---|
| Coin | `UiStyle.coin()`, `purse()` | 7x7 (14) | One | Every gold sum and price |
| "More to read" arrow | `UiStyle.arrow()` | 7x5 (14x10) | Blinks (code) | Dialogue |
| Trend arrows | `UiStyle.trend(up)` | 7x5 | Up (green) and down (red) | Shop comparisons |
| Title menu pointer | `TitleScreen._marker(right)` | 4x7 (8x14) | Shown or hidden | Title menu |

### Bars (ColorRects, no stylebox)

| Bar | Script, function | Size | States |
|---|---|---|---|
| HP and EN (MP for casters) | `HudDock._bar`, `_set_bar`, `_warn_low_hp` | 144x20 since PIX-388: the kit's `bar_frame`, or a brass rim drawn without it; a dark trough, the fill, a 2-px shine, its numbers beside it | Fill and shine colours per bar (`HudDock.BARS`); a low-HP heartbeat pulse |
| XP strip | `HudDock._xp_line`, `_set_xp`, `_draw_xp`, `flash_xp` | Dock width x10 since PIX-388: outline, trough, fill and shine, a notch every tenth (in code, kit or not) | Flash on gain; its numbers under the mouse |
| Boss bar | `BossBar._ready`, `_strip`, `_process` | 420x12 inside a plate, with 2-px phase notches | Fill, a pale ghost that drains, notches, fade in and out |
| Pack weight | `InventoryScreen` (track and `weight_fill`) | 124x12 | Fill only |
| Codex progress | `CodexScreen` track | Small | Fill only |
| Foe health over the head | `Enemy` (`health_bar_back`, `health_bar`) | Bar width x2 **world** px (6 on screen) | Red, or gold for an elite |
| Escort health | `Escort` | 26x3 world px | Fill only |

### Marks over the world (`scripts/marks.gd`, letters drawn at 1x)

| Mark | Function | Size (art) | States |
|---|---|---|---|
| Talk bubble "!"/"?" | `Marks.talk`, `Npc.mark_sprite` | About 10x12, world grid | Parchment; gold for the main story; faded while under way |
| Danger burst | `Marks.alert`, `Enemy.alert_mark` | 14x14, world grid | Red for a charge; cold blue for a fright (+ the sweat drop, `Juice`) |
| Quest arrow | `Marks.arrow(way, main)` | 11x11 at `UI_SCALE` (22x22), 8 ways from two drawings | Main or side quest |
| Save quill | `Marks.quill` | 15x15 | Ink levels |

### Screens and layers without a frame

| Element | Script | Notes |
|---|---|---|
| Backdrop dim | `Screen` (`BACKDROP` at 90%) | A colour, no art needed |
| Letterbox | `Cutscene` (`BAR` 76), `RankupScreen` (`BAR` 92) | Black or colour bars. No art needed |
| Title | `TitleScreen`, `TitleScene` | Logo in Press Start 2P (gold face, a light sweep 18x140), tagline, text menu, the pointer above, NOUVEAU badge, version footer. The night village behind it is Shade's art plus code |
| Rank-up | `RankupScreen` | Shade's hero at 6x, beams, glow, motes (particles), letterbox. Rank cards are `box(CARD, LAMP/RIM, 14)` |
| Dividers | `InventoryScreen` rule (`RIM`, 2 px) | No `HSeparator` anywhere |
| Tooltips | `tooltip_text` on dock slots and equipment slots | **Godot's default theme.** Nothing in `UiStyle.setup()` styles `TooltipPanel` |
| Scrollbars | `ScrollContainer`s in the shop, inventory, ledger and changelog (map and journal hide theirs) | **Godot's default thin grey bar and grabber** (visible in `03-shop` and `02-inventory`) |
| Cursor | none | **The OS cursor.** No `set_custom_mouse_cursor` and no project cursor |
| Dialogue portrait | `DialogueBox._portrait` | The speaker's Puny sprite, scaled, on a 100x100 stage inside the 112 slot |
| Touch buttons | `Screen` (`box`) | Phone only; not in scope |

## Shopping spec for a UI kit

### Pieces

Must have:

- **Window:** a page in a frame, border ≤ 6 art px, with a 16x16 tileable centre. Also a wood variant for the dock.
- **Card, row and slot:** 1–2 px rim. States: idle, chosen, ready, spent, empty.
- **Button and tab:** about 16–17 art px tall, edges ≤ 2. States: normal, hover, pressed, disabled, selected.
- **Plate:** a dark bar for words over the world, with translucency allowed.
- **Keycap:** 8x12, with up and pressed states.
- **Bars:** frame, track and fill pieces at 5–6 art px tall, plus a 2-px line for XP. Fills in our HP, EN, MP and XP colours, or recolourable.
- **Tooltip panel.**
- **Scrollbar:** track, grabber, grabber hover and grabber pressed, 3–4 art px wide.
- **Cursor:** pointer and hand, about 12–16 art px, shown at 2x.
- **Divider.**

Nice to have:

- **Rarity frames** for slots, fine (blue) and epic (purple). Today rarity is only a text colour.
- **Toggle or checkbox and slider:** Options writes "Activé" and "70%" as text.
- **Portrait frame** for the dialogue.
- **Title-bar ribbon** for screen titles.
- **Count badge.**
- **Small icons:** coin, page arrow, trend arrows, menu pointer.

Not needed: fonts (one pixel font is a rule; a kit's font such as Pixel UI Fantasy's "Quill" stays out), backdrops and letterbox bars.

### Grid

1-px strokes drawn at 1x for 2x display, on the pixel size of Shade's 16x16 icons. Frames must be thin enough that today's layouts still fit:

- window border ≤ 6 art px (12 canvas);
- card and slot rims ≤ 2;
- plank edges ≤ 2.

A thicker kit eats content room, and the French `fit-*` flows will fail (see below). No anti-aliasing, no blur, no soft shadows.

### Palette

The kit must sit beside Shade's art and the current brass, parchment and wood look. It should be indexed with short ramps (3 tones per material) so it can be remapped onto these at install time:

| Role | Hex |
|---|---|
| Outline and dark (`NIGHT`): never pure black | `1c120a` |
| Parchment, page / card / rim / grain | `ead6a6` / `dcc391` / `a8854e` / `e0c995` |
| Wood, light / mid / dark | `b47c44` / `8c5a2e` / `5e3b1d` |
| Brass, light / mid / dark | `f6dc8a` / `d9a441` / `8a6420` |
| Ink / faded ink / focus red (`LAMP`) | `3a2414` / `7d5f3e` / `b03a1e` |
| Text on the dark: cream / dusk / gold | `f3e6c4` / `c9b48a` / `f2c14e` |
| Bars, fill / shine: HP, EN, MP, XP | `d8433f`/`ff8a80`, `5cbf4a`/`a6ea8a`, `4f7cff`/`9fc0ff`, `e8b33a`/`ffe08a` |
| Rarity: fine / epic; gain | `1f5a9a` / `6e2d8c`; `2f6b22` |

Light comes from the top left (lit top and left edges, shaded bottom and right), as in `Marks.LIGHT` and the current frames. No pure white, no gradients longer than 3 steps, and no dithering at UI scale (it reads as noise at 2x beside Shade's flat ramps).

### 9-slice, states and animation

- **Delivery:** each piece as its own PNG, or as an atlas with documented regions. A machine-readable slice file, like Pixel UI Fantasy's `slices.json`, is a plus.
- **Margins:** given in art pixels.
- **Centres:** the parchment centre must **tile** (`AXIS_STRETCH_MODE_TILE`, as today); edges tile or are flat runs; corner ornament fits inside the margin.
- **States:** state images must line up pixel for pixel (same size and margins), so swapping a state never moves the words. Pressed drops the face 1 px, as our keycaps do.
- **Animation:** optional and few frames, such as a focus shimmer or a ready-slot glint, as horizontal strips of equal frames. The code times them on `GameClock` and holds frame 0 under Reduce motion. The heartbeat, the ghost drain and the screen entrances stay tweens.

### Effects, portraits and other gaps

| Gap | Today | What to look for |
|---|---|---|
| Hit sparks | A white flash on the sprite (`Juice.flash`), the slash arc (`Juice.arc`) and the damage number | An impact star or puff, 4–6 frames, about 16x16 art on the world grid (3x), in Shade's palette |
| Spell effects | `WorldFx.skill_flash`: a soft oval of light tinted by stat (`Player.SKILL_COLORS`) | Effects per school: fire, frost, lightning, heal, buff, poison, strength or blood. 6–8 frames, 32x32 art on the world grid, 1-px pixels and no glow baked in (the LightRig adds light) |
| Level-up and pickups | LEVEL UP text, rank-up beams, ground glint (`PatchesLayer`) | Optional: a small level-up burst |
| Dialogue portraits | The walking sprite scaled on a 100x100 stage | Bust portraits of **48–50 art px square** (96–100 on screen at 2x) for about 29 villagers, 9 recruits and the named bosses. They must match Shade's Puny faces: big head and his skin and hair ramps. A generic portrait pack won't match his characters, so this may be a commission |
| World map | Coloured squares on dark | Code: draw it from each map's ground |

## The GegX kit, against the real files

Tom bought the kit on 2026-10-28. It lives in the private repo at `retro-rpg/gegx/pixel-ui-kit/`.

- **Contents:** three styles (wood 17 base pieces, stone 15, parchment 14). Six interactive pieces per style come in 4 states (normal, hover, pressed, disabled) times 5 colourways (plain, blue, green, purple, red):
  - wood: `badge_lion`, `button_narrow`, `button_wide`, `slot_a`, `slot_dark_a`, `slot_ornate`;
  - stone and parchment: `badge_round_a`, `button_narrow`, `button_wide`, `slot_small_a`, `tab_left`, `tab_right`.

  Wood's tabs (`tabs_pair`) have no states.
- **Licence:** use and modify freely; redistributing, even modified, is forbidden. So the kit and anything cut from it stay in the private repo, like Shade's packs. Credit is optional.
- **AI disclosure:** "The base pieces were AI-generated", and the states and colourways are derived by script.

Mock-ups in the scratch folder (not in git):

- `mock-1-scale.png`: today's dock slot and plank next to the kit's wood slot and button at 1x and 2x.
- `mock-2-dialogue.png`: Sela's dialogue as today, then framed by the kit's wood window and parchment window at 1x, with today's words laid back on top.
- `mock-3-dock.png`: the dock as today, then on the kit's wood panel with its slots.
- `sheet-wood.png`, `sheet-parchment.png`, `zoom-*.png`: the pieces blown up.

### Pixel size

| Piece | Size at 1x |
|---|---|
| Slots | 45x45 to 57x57, frame 9–10 px. `slot_small_b`'s inside is 27x27: room for a **16 px icon at 1x**, not our 32 px (2x) icons |
| Buttons | 92–156 x 45 |
| Tabs | 111x41 (wood: a 235x41 pair) |
| Windows | 201x151 (wood), 201x142 (parchment), 222x151 (stone) |
| Panels | 131x93 to 163x104 |
| Bars | 171–281 x 29–45 |
| Round badges | 66–73 |

None of the pieces is an integer upscale: every pixel is one art pixel, so the kit is drawn to be shown at 1x.

| Display | Result |
|---|---|
| **At 1x** (a kit pixel is a canvas pixel) | About the right size: slot 45–57 against our 48–50, button 45 tall against about 34, parchment frame 14 against our 12. But the kit's pixels are **half the UI's and a third of Shade's world pixels**. Its 1-px lines sit next to 2-px letters and Shade's 2x icons, which look chunky inside it (mock 1, second column) |
| **At 2x** (our `UI_SCALE`) | Pixels match, but everything is twice too big: slot 90, buttons 90 tall, wood window frame over 40 px (mock 1, third column) |
| Halved, to show at 2x | Its 1-px lines and studs drop out. Not viable without redrawing |

So no scale gives both the right size and our pixel size. Using it means accepting 1x chrome, which breaks `ui.md`'s rule that the chrome sits on the 2x grid.

### Palette

| Role | Kit | Ours (`ui_style.gd`) |
|---|---|---|
| Outline | Near-black `060504`, `080201` (wood); `010101`, `020203` (parchment); `040405` (stone) | `NIGHT` `1c120a`, a warm brown-black |
| Page | `f2ddb8`, `d4ab84` (wood); `e2c19a`, `e4c39b`, `e2c097`, mottled (parchment) | `WINDOW` `ead6a6`, `CARD` `dcc391`, `GRAIN` `e0c995` |
| Wood | Seven maroon-red tones: `5a2f2e`, `653633`, `734037`, `864c3a`, `945841`, `a66647`, `b2714c` | Three orange-browns: `5e3b1d`, `8c5a2e`, `b47c44` (Shade's shop signs) |
| Brass | `f6c67a`, `da9b5e`, `fceaab` | `f6dc8a`, `d9a441`, `8a6420` |
| Parchment frame | Plum: `3f2c34`, `4d3238`, `52373a` | No counterpart |
| Stone | Greys `4c5059`–`92979e`, gold `f8c36a` | Not in the game's look |

Colours per piece: wood 16–23, stone 15–22, parchment 26–33. Each parchment piece has about 7 pairs of near-identical colours (within 3/255), a speckle that Shade's flat ramps never have. The kit needs an install-time remap onto our ramps:

- **Parchment:** its speckle collapses under the remap, which helps.
- **Wood:** its seven maroon tones fold onto our three, so it loses some shading.

### Which style fits best

- **Stone:** no. It is grey.
- **Wood:** the best-made of the three: no near-duplicate colours, and 81–83% of pixels match their left-right mirror. But its window frame is heavy: 20 px plus scrollwork at the corners and halfway along the sides, which needs 9-slice margins of about 64 px.
  - In mock 2 (middle), the dialogue's keycaps and portrait run into its inner gold rim, and the tiled edges repeat the scrolls.
  - Its panels are light pages, so the dock's cream text washes out on them (mock 3).
- **Parchment:** a thin frame (14 px, corner brackets 22 px) that holds today's dialogue at 1x almost unchanged (mock 2, bottom). But its frame is plum, its page is mottled, and it is the least symmetric (52–57% mirror-equal).
- **Best fit:** parchment for windows and panels, wood for buttons, tabs and slots, with both remapped to our ramps so they read as one set.

### What maps to what (margins at 1x)

| Code element | Kit piece | 9-slice L/T/R/B | Kit states | Notes |
|---|---|---|---|---|
| `UiStyle.window()` (pages) | `parchment/base/window_large` | 24/24/24/24, centre tiled | none | The content margin grows from 12 to at least 22, so every screen loses about 10 px a side. The page must be cleaned to tile |
| Small windows: nameplate, hint card, dock menu | `parchment/base/panel_small` | 22/22/22/22 | none | |
| Dock wood plate (`window(8, WOOD)`) | **none** | | | The kit's panels are light pages; only its slots come in dark. Keep the code |
| `box()` rows and cards | none clean | | | Panels are too ornate for 50 px rows. Keep the code |
| `box()` slots: dock skills (48), equipment (50) | `wood/base/slot_a` (57x57, with its derived states) | fixed size, no stretch | normal = ready, disabled = spent, red = focus or equipped, blue = fine, purple = epic | 57 holds a 32 px icon; the 45 px slots don't. The dock's slot row grows by about 54 px |
| `plank()`, `button()` | `wood/base/button_wide`, `button_narrow` | About 14/9/14/12 (the bottom lip is thicker) | normal, hover, pressed, disabled; red colourway for the chosen one | **Labels are baked in**, even in "disabled", despite the README. **No row repeats**, so height is fixed at 45 (today about 34). Columns repeat only over 2–6 px, so the label must be erased and a clean column cut before it can stretch |
| Tabs: journal, shop, inventory | `parchment/base/tab_left`/`tab_right` (wood's `tabs_pair` has no states) | About 12/8/12/8 | 4 states x 5 colours | 41 tall against 32 today. Labels baked in |
| Boss bar | `wood/base/bar_empty` (281x29) | About 12/6/12/8, with our fill drawn inside | none | The boss plate grows to about 29 px of bar. `bar_health` and `bar_mana` carry baked numbers ("225/300", "HP 75/100") |
| Dock HP and EN bars (132x10), XP line | none | | | The kit's bars are 29–45 tall. Keep the code. **Superseded (PIX-388):** HP and EN now sit in `bar_frame` at 144x20; the XP strip stays in code, 10 px with notches |
| Rank-up or codex medallion | `badge_lion`, `badge_round_a`/`b` (66–73) | fixed | 4 states x 5 colours | Decorative only; too big for count badges |
| Dialogue portrait frame | `wood/base/slot_ornate` or `parchment/base/slot_square` | About 10 all round | | Possible, once cleaned |

**Missing from the kit:**

- keycaps;
- the dark plate over the world;
- a dark wood plate for the dock;
- tooltip, scrollbar, cursor and divider;
- checkbox, toggle and slider;
- small count badge, coin, page arrow and trend arrows;
- EN and XP fills (only HP and MP);
- any animation.

### The AI-generated art beside Shade's

- **First impression:** the wood style reads as competent pixel art: hard edges, no blur, a limited palette, readable bolts and bevels.
- **The tells, under zoom:**
  - frames that are not mirror-symmetric (wood 70–83%, parchment 52–57%; a hand-drawn frame is drawn once and mirrored);
  - wobbly inner borders and stains in random places;
  - parchment's near-duplicate colours;
  - almost no flat runs to stretch (1–6 px; none at all in parchment);
  - a README that doesn't match the files: the "label-free" disabled variants carry the label.
- **The clash with Shade:**
  - mostly the **pixel size** (above);
  - then the **palette**: near-black outlines, maroon wood and plum frames, against Shade's warm brown-black and orange wood;
  - then the **density**: Shade's Puny art is chunky and simple, and the wood window's 1-px scrollwork is busier than anything in the game.
- This would be the game's first art that is neither Shade's nor drawn in his palette in code, and the first AI-generated art. Whether that's acceptable is Tom's call. If it goes in, keep it to the chrome, never the world.

## How the GegX kit would plug in (option A, built in PIX-385)

Tom chose option A. Steps 1 to 3 are PIX-385 step 1 (PR #439); steps 4, 5 and 7 are step 2, which also gave the slots their colourways (the dock's skills by `ready`/`spent`, what's worn by its rarity, `focus` for a common piece) and put the journal's, the codex's and the dialogue's name tabs on the kit's tab. Step 6's layout retuning is step 3; step 2 retuned only what broke (the journal's text width, the hero card's columns, the pack's tab row). Step 3 shipped as PIX-388 step B: one inset (`UiStyle.INSET`, 24) and gap (`UiStyle.GAP`, 16) for every screen's pages, tabs on their page's top edge, planks 44 tall, the dialogue's portrait in the kit's slot (see ui.md).

This follows the paid-art pattern:

- the art lives in the private `pixelheim-assets` repo;
- `scripts/fetch-private-art.sh` installs it git-ignored;
- a committed JSON names what goes where, with no art in it (like `icons.json`);
- the code falls back to drawing when the art is absent or withheld (`cc0`, as `PunyTown.available()` does).

1. **Prepare the art, once, into the private repo.** The kit can't be used raw. The licence forbids redistributing even modified art, so the prepared pieces live beside it in the private repo, under `retro-rpg/gegx/pixel-ui-kit/pixelheim/`. A committed tool (no art in it; GDScript run headless, since the Mac's Python has no imaging library) writes them. For each piece the manifest names, it:
   - erases the baked label: it fills the label box from a clean column of the same piece;
   - cuts clean 9-slice edges and centre. Where no column repeats, it widens one by copying, so a stretch or tile doesn't smear the page;
   - remaps every colour onto UiStyle's ramps (outline to `NIGHT`, page to `WINDOW`/`CARD`/`GRAIN`, wood to `WOOD_*`, brass to `BRASS_*`). This also merges the parchment's near-duplicates.
2. **Install:** `fetch-private-art.sh` copies `pixelheim/` to `godot/assets/puny/gegx/`, and `godot/.gitignore` gets `/assets/puny/gegx`.
3. **Manifest:** a committed `godot/assets/puny/ui_kit.json`. For each UiStyle piece it gives the file, the 9-slice margins (at 1x, from the table above), the content margins and tile or stretch. The piece names are UiStyle's own:
   - `window` (parchment window);
   - `panel` (parchment panel);
   - `slot`, `slot_ready`, `slot_spent`, `slot_focus`, `slot_fine`, `slot_epic` (wood `slot_a` and its colourways);
   - `button`, `button_hover`, `button_pressed`, `button_dim`, `button_chosen` (wood `button_wide` and its derived states);
   - `tab`, `tab_chosen`;
   - `bar_frame` (wood `bar_empty`).
4. **`UiStyle` changes** (`scripts/ui_style.gd`):
   - **New:** `static var withheld` and `static func _kit(piece) -> StyleBoxTexture`. It loads the manifest once and builds a `StyleBoxTexture` from the installed PNG **at scale 1** (not through `_texture`, which doubles), with the manifest's margins. It returns null when the file isn't installed or `withheld` is set. `HarnessBoot`'s `cc0` sets `withheld`, as it holds back `PunyTown`.
   - **`box(fill, rim, padding)`** asks `_kit` first, by a small table from the (fill, rim, padding) pairs the 33 calls use to a piece:
     - `CARD` with padding 12 or more becomes `window`;
     - a `LAMP` rim on a 48–50 slot becomes `slot_focus`;
     - a `BRASS` rim becomes `slot_ready`;
     - and so on.

     A pair not in the table, or no kit, keeps today's drawing. Rows and cards stay in code (the kit has no clean row piece).
   - **`window(padding, fill)`** asks `_kit("window")` for the page fill only. The dock's `WOOD` plate stays in code.
   - **`plank(lit, padding, dim)`** and **`button()`** use `button_*`, with a real pressed state. **`focus()`** uses `button_chosen`.
   - **`_style()`** stays as the fallback's builder. The kit's styleboxes carry their own content margins, at least the frame, so the words never sit on the frame (mock 2's middle row is what happens otherwise).
   - **Stay as today:** `plate()`, `keycap_style()`, `coin()`, `arrow()` and `trend()`, since the kit has none of them. The same goes for the tooltip, scrollbar and cursor (recommendation 1: `setup()` gains `TooltipPanel`, `VScrollBar` and `HSeparator` theme items drawn in code, and a cursor pre-scaled to the window, since hardware cursors don't follow `canvas_items` scaling).
5. **Bars:** only the boss bar takes the kit. In `BossBar._ready`, the `NIGHT` outline `ColorRect` becomes a `Panel` with `_kit("bar_frame")`, and the fill, ghost and notches are drawn inside its content rect. The dock's bars (`HudDock._bar`, `_xp_line`), the weight and codex tracks, and `Enemy`'s and `Escort`'s world bars stay in code. (PIX-388 later put the dock's HP and EN in `bar_frame` too; its XP strip stays drawn.)
6. **Layouts:** the kit's frames are thicker than ours:
   - window content margin about 22 against 12;
   - buttons 45 tall against about 34;
   - tabs 41 against 32;
   - slots 57 against 48–50.

   The screens are laid out in canvas pixels against today's sizes, so the French `fit-*` flows and the look book must run with the kit installed, and `Layout.overflows` will point at what spills. Expect to retune `InventoryScreen.LIST`/`ROW_HEIGHT`, `ShopScreen`'s three rects, `LedgerScreen.LIST`, the journal's and options' pages, `DialogueBox.SIZE`, and `HudDock.SLOT` (the dock grows about 54 px wider).
7. **Tests:**
   - `test_ui_kit.gd`: every manifest piece's margins fit inside its texture, and every UiStyle builder returns a stylebox with the kit withheld.
   - CI's windowed jobs never fetch paid art, so they keep testing the fallback.
8. **Estimate (option A):**

   | Work | Days |
   |---|---|
   | Prep tool: labels, clean slices, remap | 1–1.5 |
   | `_kit`, manifest, `box`/`window`/`plank`/`button`/`focus`, fetch, gitignore, test | 1 |
   | Boss bar | 0.5 |
   | Layouts across about 25 screens, French fit flows and look book | 1.5–2 |

   About **5 days, or 4–5 tickets**, plus Tom's look at the result before it ships.

**Option B, recommended first, is about 1 day:**

- In `window()`, add the parchment's brass corner brackets and the wood's inner brass rim, drawn in code.
- In `plank()`, add the bolts.
- In `box()`, give the slots fine, epic, ready and focus colourways.
- Everything stays at 1x art shown at 2x, in our palette, with no install or fallback to keep. The kit stays in the private repo as reference.

## The candidate kits

| Kit | Price, licence | What it has | Grid and palette fit | Verdict |
|---|---|---|---|---|
| [Pixel UI Fantasy Free](https://godotengine.org/asset-library/asset/5492) (heyheythere) + paid six-theme pack | Free is CC BY 4.0 (credit in the ending's credits, `Cutscene._credits`). The paid pack's price and licence weren't readable | **Covers the most of the spec:** a Godot 4.3–4.7 parchment `Theme` with buttons in normal, hover, pressed and disabled states, tabs, sliders, checkboxes, tooltips, popups, scrollbars, riveted panels and windows with title bars, a divider, framed bars with HP, mana, stamina and XP fills, item slots in five rarities, a portrait frame, a nameplate, a ribbon, a cursor at 1x–4x, PNGs with `slices.json`. The paid pack adds leather, iron, gilded, elven and arcane themes and installs over the free one by file name | Panel grid not stated (icons are 16x16); palette unknown. Its "Quill" font stays out. Parchment, leather and gilded are the right family | **Best fit. Try the free one first:** it costs nothing and shows whether its strokes match 2x. Buy the paid themes only if it does |
| [GegX Pixel UI Kit](https://gegx.itch.io/pixel-ui-kit) | 3.49 EUR+; use and modify allowed, no redistribution | **Bought 2026-10-28; judged on the real files above.** 406 files: windows, panels, buttons, tabs, slots, badges and bars in wood, stone and parchment, in 4 states x 5 colourways | **Drawn for 1x** (our UI is 2x). Labels baked in, few clean 9-slice runs, a near-black, maroon and plum palette. Base pieces AI-generated | Usable only after a prep pass and at 1x (option A). Its motifs are better borrowed into UiStyle at 2x (option B) |
| [ThePixelGame 16x16 Pixel UI Pack](https://thepixelgame.itch.io/16x16-pixel-ui-pack-buttons-panels-bar-and-more) | From $1; commercial use allowed, credit welcome | Buttons (normal and **pressed only**), inventory panels, modular panel pieces, health and shield bars, possibly icons, slots and dividers. Dialogue boxes and skill-bar frames are "maybe later" | A 16x16 grid matches the icons. Palette and theme not confirmed as parchment or wood | Cheap but thin: no hover or disabled states, no tooltip, scrollbar or cursor. Only as a parts bin |
| [Parchment GUI](https://opengameart.org/content/parchment-gui) (zwonky) | CC0 | Parchment 9-patch panels (decorated and plain), a metal back panel, buttons (emerald, loop, parchment), slots, labels | 16x16 but in the **Arne16** palette, low-fi, no states documented | Reference only: the palette clashes with the brass and brown, and there's too little in it |
| Shade (merchant-shade) | none found | Search shows his Puny characters, world and editor packs, but **no UI pack** | n/a | Ask Shade or watch his page. His UI would be the only kit that needs no remap |

itch.io returned 403 to the fetch, so ThePixelGame and the paid Pixel UI Fantasy are judged from search snippets (GegX from its files). Check each one's page by eye before buying. Buying is Tom's call.

### Sources

- [GegX Pixel UI Kit](https://gegx.itch.io/pixel-ui-kit)
- [ThePixelGame 16x16 Pixel UI Pack](https://thepixelgame.itch.io/16x16-pixel-ui-pack-buttons-panels-bar-and-more), and its [release devlog](https://thepixelgame.itch.io/16x16-pixel-ui-pack-buttons-panels-bar-and-more/devlog/1119265/devlog-new-16x16-ui-pack-released)
- [Pixel UI Fantasy Free, Godot Asset Library](https://godotengine.org/asset-library/asset/5492)
- [Parchment GUI, OpenGameArt](https://opengameart.org/content/parchment-gui)
