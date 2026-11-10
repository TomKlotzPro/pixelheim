# Performance: what things cost, and how to measure them

Read before a change that adds work per frame, nodes to a map, lights, or time to CI. Numbers are from the PIX-329 audit (v0.263, 2026-10-21, Apple Silicon, 14 cores, Godot 4.7.1, headless, under load from other agents: trust the ratios more than the milliseconds) unless dated otherwise. Tom wants the game beautiful on a computer first: the desktop frame has room, spend it on lighting, shaders, particles and animation, not on phones or low resolutions.

## Which tools need a window

| Tool | Measures | Window? |
|---|---|---|
| `--screenshot perf` (`PerfProbe`, the perf guard) | physics, process, render per frame | **yes**: headless it prints `-`, the dummy renderer never emits `frame_pre_draw`/`frame_post_draw` |
| `--screenshot crossing` | a walk's frames over a line between maps | **yes**: headless it reports `frames 0` |
| `motion`, `line-motion` | steps back in the hero's walk, by pixels | **yes** (CI's windowed jobs walk them) |
| `lookbook.sh --perf`, `lookbook`, `film` | the GPU side: draws, shaders, lights | **yes** |
| `cpu=`, `paced=` (PIX-355, PIX-445) | each frame timed to the next once the Reach is worked out ahead, ms median/95th percentile; `paced=` the median in rounds of `PerfProbe.Pace` timed between the frames, which the `cpu-*` flows hold to budgets (below), headless only and each alone after the rest (`flows.sh`: beside other runs, or a window's software drawing, a CI frame read 4-7x its cost) | no, and never beside other runs |
| `tools/web_perf.py` (PIX-361) | the web export in headless Chrome: `cpu=`, PerfProbe's sample and the crossing's frames, read off the page (`window.pixelheimPerf`) | no (headless Chrome draws) |
| `--screenshot reentry` | entering each outdoor map, first and again; BESIDE lines part by part | no |
| `godot --headless --fixed-fps 60 --print-fps -- --screenshot --map X --wait 240` | CPU per frame (frames run back to back) | no |
| `turning`, `overflow`, `--benchmark` | the turning walk, words off the canvas, boot phases | no |

## The frame (CPU, headless, one core)

| Map | Mobs | Decor | ms per frame |
|---|---|---|---|
| overworld | 30 | 312 | 0.90-0.92 |
| overworld, night | 45 | 312 | 1.03-1.10 |
| deepwood | 12 | 1427 | 0.49-0.55 |
| mirefen | 12 | 287 + 181 (PIX-401's dead trees and reed beds) | 0.49-0.52 |
| seacave (dungeon) | 12 | – | 0.44-0.52 |
| town (day / night) | 0 | 675 | 0.25-0.38 / 0.22 |
| town_inn | 0 | – | 0.20 |

- **Mobs drove the CPU frame**: about 0.25 ms plus 0.021 ms per mob. Since PIX-360 a foe at peace (`Enemy.at_peace`: no boss) more than `REST_MARGIN` (6 cells) past the screen's edge rests, its tick skipped but for its wander's dice until the edge nears (`Enemy.rest`, asked by `Foes._process`): `cpu=` medians on 2026-10-22 went overworld 0.83 -> 0.45, night 0.95 -> 0.47, deepwood 0.48 -> 0.24, the line 0.55 -> 0.27 ms (every flow's report the same), and the `cpu-*` flows held them under 1.50, 1.00 and 1.00 ms (in paces since PIX-445, below). Decor nodes cost almost nothing per frame once drawn; lights add little CPU.
- **Streaming** (`world_neighbours.gd`) adds up to `BUDGET_MS` 3 ms a frame while the Reach's maps beside are drawn in.
- **The GPU side was not measured headless.** The 2026-10-09 baseline: about 43 draws, physics 0.7 ms on the overworld, about 2 ms of a 16.7 ms desktop frame used.
- **The CPU budgets are in paces, not ms (PIX-445).** CI's runners are several kinds of machine, steady on each but up to 2.1 times apart: on one build (2026-11-10, twelve runners, four rounds) `cpu-night` read 0.73-0.81 ms on an AMD EPYC 9V45, 0.98-1.02 on a 9V74, 1.33-1.38 on a 7763 and 1.50-1.56 on an Intel Xeon 8370C (the 8573C reads about as slow). A budget in ms failed the slowest with no change to the game (#502's `cpu-night` at 1.51, `cpu-ash` on #476 and #479, and the nightly hunt of 11-07) and let the fastest pass a frame twice as dear. `PerfProbe.Pace` times a round of a fixed piece of work (GDScript loops and engine calls, a crowd of script objects ticked, reads scattered over 4 MB) between each frame and the next, left out of the frame's time, and `paced=` is the median frame over the median round: the AMDs read within 4 % of each other, the Intels about 10 % over (night 5.75-5.83 on the AMDs, 6.37 on the 8370C; each part of the pace alone missed some machine: the Intel's tight loops ran 25 % faster than the AMDs' while its frames didn't). Each flow's budget is about the AMDs' reading and 25 %, the Intels' and 13 % (night 7.20, Ash 7.50, the Deepwood and the Mirefen 3.30, the line 3.70, the town 3.60, the fight 4.60). Proved on PIX-445's branch with a throwaway commit, 2000 more distance checks in `world._process`, five runners by five rounds: the Deepwood, the line, the town, the fight and the Mirefen, a third to a half dearer, failed all 125 readings (the ms budgets passed 84 of them, every Deepwood and Mirefen one); night and the Ash, a quarter dearer, failed 16 of 50 (every Intel's, the AMDs' at the edge; the ms budgets failed 25, only the slow machines'). Main as it is passed 175 of 175 the same way; beside it a loose ceiling in ms (2.50 and 1.50) for what slows the pace as well as the game (a Godot upgrade: then read `cpu=` by machine, the job's log names it). The laptop reads lower in paces than CI (night 5.0). Measured again whenever `Pace` changes.
- **The web build** (single-threaded wasm, Compatibility renderer) downloads 18.7 MB gzipped (wasm 10.25 MB, pck 8.37 MB) before PIX-351 took the tests out (about 1.4 MB less). Its frame is measured below.

## The web build (`tools/web_perf.py`, PIX-361)

The export (CC0 art) served as GitHub Pages serves it and opened in headless Chrome, the harness's command line handed over by the page (`window.pixelheimArgs`, read by `web/shell.html`, never from the URL), and the numbers read back off the page: `harness.gd` sets `window.pixelheimPerf` (map, `cpu`, `frames`, `perf`, the report line) on the web only. Chrome's frame rate is uncapped and the run stepped (`--fixed-fps 60`), so the frames run back to back, as headless on the desktop, but drawn. Two runs, the desktop's `cpu-night` with `perf` and `cpu-line` with `crossing`. On 2026-10-27, the laptop (its GPU), Chrome 156, three runs, ms median/95th percentile:

| Run | Web `cpu=` | Desktop headless `cpu=` (same day) |
|---|---|---|
| the overworld at night, 45 mobs | 2.70-3.10 / 3.20-3.80 | 0.49/0.90 |
| over the line into the Deepwood | 2.70-3.20 / 4.40-6.10 | 0.31/1.14 |

- The night's PerfProbe (averages): physics 0.29-0.36, process 1.08-1.19, render 1.19-1.35 ms; 81 draws, 1068 objects, 1818 nodes. The scripts (physics and process, 1.4-1.6 ms) cost about 3 times the desktop's, as assumed; the browser's drawing about as much again.
- The crossing's walk: 37 frames, the slowest 12.1-13.8 ms (the map beside handed over, streaming's 3 ms a frame): inside a 60 Hz frame, with little to spare there.
- So a web frame costs about 3 ms of 16.7 away from the lines: room to spend, on the web too. A page boots and runs in about 5 s (10 s the first time, the wasm compiled).
- Local only: on CI's GPU-less runners (WebGL drawn by SwiftShader) the page booted but didn't finish a run within 240 s (PR #419), so there is no CI job; run it on a Mac before and after a change that could slow the web build.

Run it on the laptop (Playwright for Python drives the installed Google Chrome; no browser download):

```
godot --headless --audio-driver Dummy --path godot --export-release Web export/web/index.html
python3 -m venv /tmp/pw && /tmp/pw/bin/pip install playwright==1.56.0
/tmp/pw/bin/python godot/tools/web_perf.py --out /tmp/web-perf.json
```

An export with the paid art installed measures that art too: keep its numbers, never the export.

**The music on the web** (PIX-416 review, 2026-11-05, the export with the paid pack, headless Chrome muted, two or three runs each). As samples (the web's default) each of the bundle's tracks was decoded whole on the main thread at its first play and kept as float PCM for good: the line's crossing (the Deepwood's track first heard) took 135-146 ms, the town's gate out 414-423 ms, and the page made 152-156 MB of AudioBuffers in one short walk. Streamed (`Sound`'s two music players, `PLAYBACK_TYPE_STREAM`): the crossing 13-15 ms, the gate 310-369 ms (the Reach's first visit alone), 19-24 MB of AudioBuffers (the effects' and beds' samples, the largest 4.4 MB). The cost: the single-threaded build mixes a stream on the main thread into a 2048-frame ring (`audio/driver/output_latency.web`, 50 ms), so a task longer than that holds the music with it. Steady frames never ran it dry; the gate's first visit held it some 340-400 ms, a 140 ms task (the harness's shot) about 130. A longer latency would bridge more, but the music would answer a duck or a crossfade that much late.

**A change of place on the web** (PIX-417, 2026-11-07, the export with the packs, headless Chrome with no audio output (`--disable-audio-output --mute-audio`), the worklet patched in the scratch export to count the render quanta it found its ring empty for and to keep its output's level, six runs of each walk interleaved with main's (the inn three), real time). Every map built in one frame (`enter_map`) held the music for that frame less the ring's 43 ms, at full level on both sides: the track change only begins after the build (`soundscape.refresh` at its end), and the crossfade holds its power (no dip). Since PIX-417 the hold falls in the hush, 40 dB under:

| Walk | Its long task | Music held | Level as it stopped (dBFS): main / hushed | As it came back |
|---|---|---|---|---|
| the town's gate to the Reach (dissolve, first visit) | 303-364 ms | 285-349 ms | -23.8 to -25.6 / -66.1 to -66.5 | -26.3 to -26.4 / -58.0 to -59.0 |
| a door into the town hall (dissolve) | 94-120 ms | 72-104 ms | -23.8 to -26.5 / -63.8 to -64.6 | -23.4 to -24.8 / -60.2 to -63.4 |
| Saltmere down into the sea cave (dark) | 133-169 ms | 93-131 ms | -36.5 to -38.8 (ducked by the stairs) / -76.5 to -78.7 | -36.7 to -37.7 / -72.2 to -74.0 |
| a fall on the Reach, waking at the inn | 99-129 ms | 72-99 ms | -31.4 to -31.7 / -71.3 to -71.8 | -28.3 to -28.9 / -64.2 to -66.7 |
| the line into the Deepwood (streamed) | none to 54 ms | 0-13 ms | -27.2 to -27.7 (the same) | the same |

**Maps built where no door is** (PIX-420, 2026-11-07, the same setup, five runs of each interleaved with main's): the scenes' builds and Lantern Night's held the music as a door's did, at full level, until they went through `world.hushed_build()`, and a reload of the whole world (a slot, a language, the title, a new hero) until it went through `Screen.reload_world()`. Lantern Night was measured on scratch exports whose clock started 2.5 steps before the night's day (in the harness it otherwise begins in the boot's first frame, before the music):

| Build | Its long task | Music held | Level as it stopped (dBFS): main / hushed | As it came back |
|---|---|---|---|---|
| the ending (`ending`, from the Reach to the town) | 226-277 ms (a first page 1065) | 184-237 ms (1027) | -29.3 to -29.7 / -66.1 to -66.6 | -35.8 to -37.6 / -71.1 to -73.4 |
| back from the board (`rebuilt`, the town redrawn) | 196-239 ms | 157-200 ms | -28.7 to -29.2 / -66.2 to -66.6 | -25.9 to -26.3 / -61.9 to -62.5 |
| the Night of Bells' scenes skipped, the town for the day after (main's music already fading) | 167-217 ms | 128-179 ms | -41.2 to -44.3 / -69.8 to -80.3 | -42.0 to -44.7 / -66.3 to -69.3 |
| Lantern Night begun in town (the town rebuilt round the hero) | 76-86 ms | 32-45 ms | -19.9 to -21.2 / -63.7 to -65.1 | -23.5 to -23.7 / -63.8 to -64.3 |
| a slot switch (the saves screen's E: the scene reloaded, the town built in its first frame) | 221-274 ms | 184-243 ms | -23.8 to -25.5 / -63.9 to -66.5 | -24.7 to -27.9 / -61.0 to -63.7 |

On the Night of Bells one hushed run of five had a 19 ms stall at -41.7 as the scene closed, before the hush; the Esc that starts the collar scene holds the music too (211 ms at -29.0 in one run), a scene's start, not a build. The slot switch was measured on scratch exports carrying the fixture slots (`--map town --at 40,30 --walk` four seconds `saves --slots res://test/fixtures/slots --keys e`), one reload a run; its unhushed side is this code with the `Sound.hush()` line taken out (the same wait), as main's reload, pressed by the harness's own key push, tore the harness down with the world and the web run never built it again.

The music's own level is about -23 to -34 dBFS. A hushed door or gate begins 0.15 s and a frame later on the web; the long tasks are the same. A first page in a fresh browser now and then ran far longer (the cave 1023 ms, the line 920, the door 467): a build's under the hush now, the line's not. In a fresh browser the line's frame was 66-68 ms and held the music 29 ms, at full level. The web download (90.7 MiB as files, 56.7 MiB gzipped) is mostly the bundle's music: 38.5 MiB of Ogg in the 52.5 MiB pck (gzip takes nothing off it), the engine's wasm 37.7 MiB (9.6 gzipped), the effects' and beds' takes 7.4 MiB (imported as QOA), all the rest some 6 MiB.

## Entering a map (`reentry`, ms)

| Map | First visit | Again | Drawn beside (BESIDE total) | Nodes | of which decor |
|---|---|---|---|---|---|
| overworld | 150 | 39 | 33 | 1145 | 15.2 |
| deepwood | 89 | 36 | 33 | 2293 | 25.5 |
| frostgate | 70 | 18 | 14 | 548 | 7.2 |
| greyhold | 65 | 20 | 17 | 702 | 7.8 |
| mirefen | 65 | 16 | 13.6 | 475 | 5.7 |
| blackiron | 55 | 14 | 12 | 543 | 6.0 |
| saltmere | 50 | 13 | 10 | 330 | 3.9 |
| town | 32 | 32 | 30 | 1340 | 11.7 |

Decor (one node a piece) is the largest part of drawing a map. A first visit costs 2-4 times a return (`KeptGround` keeps the worked-out ground); the town gains nothing on return. Memory kept after both rounds: +9 MB, kept ground 1.34 MB.

Most of the Deepwood's decor was not its 2142 tree sprites (about 10 ms) but working out its clumps (`Woods.look_at` and `.pieces`, about 25 ms). Since PIX-360 a map's woods are kept for the session (`KeptGround.woods`, cell by cell as they are first drawn). On 2026-10-22, nodes the same, "again" went deepwood 56 -> 26 ms, town 36 -> 26, greyhold 23 -> 17 and frostgate 21 -> 15. BESIDE went deepwood 52.7 -> 23.1 ms, town 34.9 -> 25.0, greyhold 20.1 -> 13.4 and frostgate 17.4 -> 11.6. The cost is +2.7 MB of memory kept after both rounds (+12.7 MB in all).

The town's yards (PIX-382, `Yards`, 2026-10-28, `--town-tier 4`, with the paid pack): nodes 1366 -> 1733, BESIDE 27.2 -> 30.5 ms (plan 8.8 -> 10.2, decor 9.1 -> 10.9), "again" about 30 -> 33.5 ms. The data's villager spots are worked out once a session (`Yards.kept`); the rest is `Hamlet.plan` fitting about 60 standing pieces and a node or four each.

Greyhold's walls in stone (PIX-386, `StoneWalls`, 2026-10-28, with the paid pack, three runs interleaved with main's): nodes 703 -> 704 (the ruins' tile layer), BESIDE 16.5 -> 16.9 ms (plan 3.9 -> 4.5), "again" 19.6 -> 20.5 ms; other maps' plan +0.1-0.2 ms (the scan for walls). The ruins' atlas holds 120 tiles more: about 3 ms more, once a session, on the first map with ruins or walls (the Mirefen's first visit 75 -> 79 ms).

The speakers' faces (PIX-405, 2026-11-04, headless, three runs): each dyed look is dyed (`PunyArt.dyed`, a GDScript loop over the columns it dyes: 0.7 ms a sheet) and framed once a session, as the first map it stands on loads, about 1 ms a face. The town's 18 cost 21-22 ms on CC0 art and 17-18 ms with the paid pack, on the boot's first town map; all 30 about 35 ms. PIX-409 added Pip and Nell to the town's (about 1.5 ms each, the child's cut 0.2 of it) and Teo's head and body joined as an outfit (about 2 ms). The web build's scripts run about 3 times the desktop's (above): some 60 ms there.

The town's farm animals (PIX-387, 2026-10-28, `--town-tier 4`, with the packs, two runs each): nodes 1734 -> 1759 (24 sprites and the herd), BESIDE 31.0-31.7 -> 32.6-33.2 ms (decor 10.5-11.2 -> 12.0-12.1), "again" 32.8-33.5 -> 33.9-36.3 ms. `cpu=` by the river field with every animal near the screen 0.28/0.60-0.66 -> 0.28-0.30/0.65 ms: noise. With the sty fenced (the review), the same build with and without the pack: nodes 1774 -> 1799, BESIDE 32.6-33.0 -> 33.0-33.3 ms (decor 11.2-11.3 -> 12.1-12.2); without it, nothing of the herd is planned.

The houses the ages raise and the fountain lit at night (PIX-382 step 3, 2026-10-29, with the packs): the City's town nodes 1852 -> 1763 (the woods and the orchard's trees under the new roofs went), BESIDE 32.5-33.8 -> 34.5-34.6 ms (plan 11.3-11.6 -> 12.2-12.6: the yards fit eight pieces more), "again" 34.7-35.3 -> 35.5-36.0 ms, three runs before and two after. The report's `decor=` by age, Ashes to City: 688, 675, 673 -> 652, 672 -> 639, 671 -> 564; lit windows at night (`panes`) 20, 22 -> 24, 25 -> 29, 25 -> 33 from the Hamlet, each with its light, plus the fountain's, within `test_night_light`. `cpu=` on the town at every age by day and at night, two rounds each, headless and alone: 0.20-0.28 / 0.42-0.77 ms before, 0.21-0.30 / 0.40-0.75 after (noise); `cpu-town` holds the City at night under 1.00.

The title's entrance and its richer night (PIX-392, 2026-10-29, with the packs, headless and alone, three runs each): `title cpu --wait 3` (the settled title) 0.03/0.03-0.04 -> 0.04/0.05 ms; the entrance played through (`title --title-at 8 cpu`) 0.06/0.08-0.16 ms. Building the scene (`TitleScene`'s `_ready`, once a title opens) 26 -> 28-35 ms (the near tree's picture, the shafts, the ash, the market). Windowed, the settled title draws about 110 times a frame.

The market, the trades' signs, the planters and the worn paving (PIX-382 step 4, 2026-10-29, with the packs, two runs each, headless and alone): the City's town nodes 1760 -> 1856, BESIDE 33.5-33.6 -> 36.8 ms (plan 12.2-12.5 -> 12.9-13.4, ground 7.4-7.5 -> 8.8-9.0: the worn paving's lanes, decor 11.5-11.8 -> 12.4-13.0), "again" 35.1-35.6 -> 38.0-39.5 ms. `decor=` by age, Ashes to City: 688, 675, 652 the same, the Town's 637 -> 636 and the City's 562 -> 561 (a planter's cell each); lit windows and lamps the same (no light added). `cpu=` on the town at every age by day and at night: 0.21-0.29 / 0.42-0.82 ms before, 0.21-0.29 / 0.41-0.68 after (noise). The review's round (the square worn only where its folk walk, the butcher's and the bookseller's stalls, each stall's awning drawn again over its wares; on a slower day, two runs each): nodes 1856 -> 1878, BESIDE 38.7-41.7 -> 40.4-41.9 ms (decor 13.2-14.6 -> 14.6-15.5), "again" 40.6-42.3 -> 41.6-43.3 ms; `decor=` and the night's lights the same at every age; `cpu=` 0.21-0.32 / 0.46-0.87 ms before, 0.22-0.32 / 0.46-0.92 after (noise).

The Mirefen alive (PIX-401, `MireDressing`, 2026-11-04, with the packs): PR #466's review measured nodes 477 -> 1061, BESIDE 14.5 -> 21.6 ms (plan 3.6 -> 9.5, decor 5.0 -> 6.0) and "again" about 17.5 -> 24 ms against main, almost all of it the one `plan_mire` unit (about 6 ms, twice streaming's 3 ms a frame). `lay` now rolls a cell's dice before it looks round it, so the field decor's and the water's lookups (25 cells each) are left to the third of the fen's cells the dice could grow on, and walks the grid column by column instead of sorting its keys: the same fen, cell for cell. Eight interleaved runs each, headless under heavy load (best of them): the unit 6.2-6.4 -> 3.0-3.1 ms, BESIDE's plan 10.4-11.0 -> 7.1-7.4 ms, BESIDE 24.4 -> 20.8 ms, nodes 1061 the same; "again" 27-30 -> 25-30 ms (noise). About 1 ms of what is left is `Hamlet.fits`' ring round each of the 88 trees the dice offer (no way closed). The field's own decor (`decor=`) 294 -> 287, the walks lifting it off their cells.

The farmland round the town on the Reach (PIX-397, 2026-11-04, with the packs, the City's `--town-tier 4` against the Ashes' 0, where it is one bare plot; two rounds each, and a third that agreed): the overworld's nodes 1148 -> 1505 (the table's 1145 is the Reach without it), BESIDE 35.3 -> 37.4 ms (plan +1, decor +1), first visit 148 -> 154 ms, "again" 41 -> 43 ms. `cpu=` on the Reach, the City by day and at night: 0.46-0.47 ms median before, 0.46-0.49 after (noise).

The Ash's burnt farmsteads and the Reach's wayside lanterns (PIX-397 steps 2-4, 2026-11-04, with the packs, the Hamlet's Reach, headless; at the PR's last head, four runs after against one before): the overworld's nodes 1162 -> 1665 (the steads' pieces, each standing one with its box, and five lamps), BESIDE 37.1 -> 39.0-40.5 ms (plan 6.4 -> 8.1-8.5: `plan_ash_ruins` about 1.9 ms, almost all `Hamlet.fits`' ring round each piece, and `plan_waysides` 0.1; decor 14.6 -> 16.5), first visit 45.4 -> 47.4-52.3 ms, "again" 42.1 -> 44.5-47.9 ms. The field's own decor (`decor=`) 312 -> 303, the steads' cells lifted. `cpu=` on the Reach by day and at night, headless: by Blackiron's waystation 0.49/0.80 -> 0.47-0.51/0.72-0.80 and 0.47/0.77 -> 0.48-0.51/0.69-0.73 ms, among the steads 0.70/1.16 -> 0.67-0.72/1.00-1.02 and 0.49/0.66 -> 0.50-0.56/0.81 (noise, the lanterns' flicker at most). CI's runners read the Reach at night 1.2-1.6 ms, so `cpu-ash` held it under `cpu-night`'s 1.50, not the Mirefen's 1.00; it failed four of its first 34 readings there (1.50-1.55 on slow runners, the Ash about 5 % over `cpu-night` on the same runner), so since PIX-419 it held 1.80, CI's typical 1.39 and 30 %. `cpu-night` stayed at 1.50 (98 readings from 2026-10-30 to 11-07, the slowest 1.47) until a slow runner read 1.51 on #502: both in paces since PIX-445 (above). Night lights: five more, one to each lantern, within `test_night_light` with the City's farmland lamps and every ember lamp lit. The river's meander and the roads' wandering edges are shader work alone: no node, no CPU (a pixel within a cell and a half of the Reach's river reads its column's mask a dozen times more, an edge pixel of its roads off the grass reads the road's field twice and its calm four times; the GPU's share not measured).

## Saves (a hero who has seen every cell of 29 maps)

`to_dict` 0.04 ms (4.6 ms the first time, every map packed); `SaveSlots.write` (temp, read back, decode, rename) 0.85 ms; `SaveSlots.read` 0.27 ms; `GameState.apply` 5.6 ms (the fog unpacked, once per load); a `PXH2` code 0.3 ms either way. The file is 8.8 KB, the code 1.3 KB. Nothing to do.

## Boot

A bare `--quit` and the cheapest flow both take 1.7-1.9 s: autoloads 0.37 s, the main scene 0.9 s, and loading the other 173 scripts alone 1.1 s (GDScript compiling). Booting from an exported pack of binary-token scripts was tried and was no faster. So a flow is mostly a boot: about 78% of the headless flow time on CI. Since PIX-360 the look-only flows (77 of 406) and the boot check's 88 boots run ten to a Godot (`--batch`, `verify.md`), a flow after the first about 0.2 s instead of a boot's 2: on the laptop (12 at a time, 2026-10-22) every flow headless went 114.2 -> 101.3 s, the look-only ones alone 20.5 -> 5.6 s and `flows.sh --boot` 23.8 -> 4.6 s. CI's runners, fewer cores at 4.4 s a boot, should save more (about 77 + 88 boots less 17).

## GUT

1538 tests. Locally 33-40 s after PIX-354 (was 43-62 s; `test_fit` opens every screen in its five views side by side, `test_ascension` steps its tweens, `test_ash_land` shares one `KeptGround.of` per map). Time it with `-gjunit_xml_file=<file>`. Never wait real seconds in a test: step the clock or the tweens.

## CI

Three PR runs on 2026-10-21, after PIX-350 split the windowed flows into four shares: **13.1-13.5 min** from the first job's start to the last one's end (the median was 21 min before; Tom's figure is about 11 min).

| Job | Minutes | Its slow steps |
|---|---|---|
| `godot` | 8.4-13.5 | GUT 49-75 s, boot every map 76-119 s, **flows headless 346-584 s** |
| `windowed (1)`-`(4)` | 5.6-11.0 each | flows windowed 311-627 s |
| `windowed (look)` | 4.6 | look book 245-249 s |
| `pictures` | 0.5-0.6 | |

The critical path is now the `godot` job's headless flows beside the slowest windowed share. 405 flows run twice per PR (headless and windowed); a new flow costs about 5 s headless and 15 s windowed on CI.

By 2026-11-09 (514 flows, 157 runs since 10-27, PIX-445) the `godot` job took 7.8-17.9 min (its flows 6.2-14.8), each windowed share 5.5-15.3 (its flows 5.0-13.7) and the look book 4.0-9.0: the runner's kind of machine (above) moves them about twice over. The limits are backstops for a stall, never speed checks, sized from the slowest healthy runs: the `godot` job 30 min (it had 20, 2.1 over its slowest) with its flows step stopped at 22, each windowed share 25 with its flows step stopped at 20 (so the outputs are still uploaded), and a windowed flow's watchdog 300 s (`dawn`, the burning town drawn beside three other software renderers, took 70-146 s against 150). `flows.sh` prints what each slot still runs, for how long, the load and the free memory after a minute with no result printed, so a stall names itself in the log.
