---
name: pixelheim-godot
description: Pixelheim, a Godot 4.7 game (godot/) - the rules every change needs (authorship, paid art, quiet runs, saves, how to verify and finish), how a feature plugs in, and topic pages read on demand (saves, verify, UI, art, world, story, perf, release). Use whenever editing anything under godot/ or scripts/fetch-private-art.sh, cutting a release, or verifying Godot work.
---

# Pixelheim in Godot

Pixelheim is a Godot 4.7 game (`godot/`), live at the GitHub Pages root and as a desktop app. It began as a React/Pixi web game, removed in v0.75; its code is only in git history, and nothing talks to it, exports from it or checks against it.

**This page holds what every change needs. The topic pages beside it (`.claude/skills/pixelheim-godot/<topic>.md`) hold the rest: read the ones your change touches before you edit.** If the skill you loaded disagrees with your worktree's copy, the worktree's wins (`check.sh quick` warns when the main checkout's is stale). When a page and the code disagree, the code wins: fix the page in your PR.

## Rules every change needs

- **Tom is the sole author**: no `Co-Authored-By` trailer and no "Generated with" footer, in commits or PR descriptions.
- **Never commit paid art**: Shade's Medieval Age pack and his paid icon packs live only in the private `TomKlotzPro/pixelheim-assets` repo, installed git-ignored into `godot/assets/puny/medieval/` and `godot/assets/puny/shade/` by `scripts/fetch-private-art.sh`. No PNG, sample map or anything cut from them goes in git, and the game must run on Shade's CC0 art alone (`cc0`). See `art.md`.
- **Quiet runs**: everything headless with `--audio-driver Dummy` (`check.sh` and `flows.sh --quiet` do it); a window only when the thing measured needs one (`perf.md`), and screenshots rare. **Never pass `--slot`**: it writes real saves. Use fixture slots (`--slots`, `--load`).
- **Saves**: everything that persists lives in `GameState` and changes through its methods. A field with an empty default for every save needs no version change; anything else bumps `SaveCodec.VERSION` with **no migration until the beta** (old heroes may stop loading: say so in the release note). See `saves.md`.
- **Data and rules**: maps and tables in `godot/assets/` are the source, edited where they live; rules are pure static classes tested by GUT; a new rule for the data goes in a test. See `world.md`.
- **Code**: typed GDScript, tabs, `##` doc comments that explain *why*. A script's first `##` paragraph starts with one sentence saying what it is: that sentence is its line in godot/README.md's Layout (`python3 godot/tools/layout.py`). Pure modules get `class_name`; the autoload script (`scripts/state/game_state.gd`, autoload `GameState`) must not. Nodes are built in code (`scenes/main.tscn` is the only scene). Signals up, calls down.
- **Time and dice**: time anything in play by `GameClock`, never `Time.get_ticks_msec()`; draw from the global `randf()`/`randi()` or a seeded `RandomNumberGenerator`. Flows are stepped and must give the same report every run (`verify.md`).
- **Screens and keys**: every menu, page and conversation extends `Screen`; take keys in `_unhandled_input`/`_command`, never by polling `Input` for a key a screen can take; the look is `UiStyle`'s alone (one pixel font, never below 2x). See `ui.md`.
- **Tweens** are bound to the node they animate (`node.create_tween()`): a looping one left on a freed node freezes the web build.
- **The desktop canvas is linear light**: a shader doing colour maths over the world includes `shaders/linear.gdshaderinc` (`art.md`).
- **No backward compatibility until the beta**: legacy paths can go; don't add migrations.
- macOS has no `timeout`; don't wrap commands in it.

## How a feature plugs in today

A feature that shows in the world and is checked by a flow touches, besides its own files:

1. **Rules**: a pure class in `scripts/state/<name>.gd` and `test/unit/test_<name>.gd`; data in `assets/data/*.json` with a test keeping it whole.
2. **Save**: a field in its state section and `SaveCodec.to_file`/`from_file` only if it can't be worked out from what's saved (`saves.md`).
3. **Drawing**: a unit in `MapView`'s `planning`/`building` (`map_view.gd`), its pieces in its own `*_art.gd`; its blockers in `MapData.covered` (`art.md`, `world.md`).
4. **Wiring**: `world.gd` or the `world_*.gd` piece it belongs to (E in `world_interaction.gd`, foes in `world_foes.gd`, the story in `world_stage.gd`).
5. **Harness flag**: a row in `HarnessFlags.TABLE` (`harness_flags.gd`), read through `HarnessFlags.given()`: a preset before the first map in `world._ready`, a step in `harness.gd`'s `_run_test_harness`.
6. **Report field**: a row in `HarnessReport.TABLE` and its `field_<name>()` in `harness_report.gd`, in place by name.
7. **Flow**: lines in `godot/tools/flows.txt` under a comment with the ticket, ending on their tags.
8. **Look book shot**: a key of `Lookbook.SHOTS` in `lookbook.gd`, by name, with its area.
9. **AREAS**: the new script's line in `godot/tools/check.sh`'s `AREAS`, so `quick` picks its flows.
10. **Strings**: `python3 godot/tools/i18n.py`, then their French in `godot/locale/fr.po`.
11. **Docs**: the root README's feature list when a player sees it; `python3 godot/tools/layout.py` for a new script; this skill's topic page when a rule changed.
12. **Release note**: the main session's (`release.md`).

Steps 5-9 append to shared registries: add your rows beside their kind, never edit another's (`verify.md`).

## How to verify

`godot/tools/check.sh quick` before every PR (under a minute, headless: the checks, GUT, the boots and the flows the diff could break; `--plan` shows what it would run). CI runs the rest on the PR: GUT, the export, every map booted, every flow headless and windowed in four shares, the look book. A flow that timed out under load: run it alone (`godot/tools/flows.sh --quiet <name>`) before believing it. Details in `verify.md`.

## How to finish

1. `godot --headless --audio-driver Dummy --path godot --import`, then `bash godot/tools/check.sh quick`.
2. Merge `origin/main`. In a conflict: `flows.txt` merges by union (a flow both sides changed comes out twice: keep one); the catalogue: take both sides, rerun `i18n.py`; godot/README.md's Layout: rerun `layout.py`.
3. Commit on a `tomklotz/pix-NNN-<slug>` branch in the repo's style: `feat:`, `fix:`, `chore:`, `docs:`, `test:` or `ci:`, a lower-case summary, `(PIX-NNN)`, then ` - ` and what changed and why.
4. Push, open a PR against `main` (what changed, why, what was tested), and watch CI to green.
5. Never bump the version or run `release.py` in a feature branch: the main session cuts releases and merges.

## Topics

- `saves.md`: GameState's sections, the v5 format, codes, slots and backups, the quill, the Saves screen, fixture slots, where a save wakes.
- `verify.md`: check.sh and its areas, CI's jobs, the harness and its flags, flows, report fields, look book shots, strings, determinism.
- `ui.md`: Screen (and the HUD put aside), UiStyle, type, lists that fit, the HUD and marks, TextBudget, the loading screen, input, sound.
- `art.md`: paid art and icons, houses, rooms, props, settlements, dungeon looks, characters and walks, the ground, linear light, shaders, fire, collision, the camera.
- `world.md`: data and its tests, world.gd's pieces, the Reach's plane and streaming, scene changes, gates, dungeon floors and ways out, the Kings' Vault, the Post, routes, lamps, hubs and the post house.
- `story.md`: cutscenes, the Night of Ash, the letters, the Night of Bells, Coming Home, settlers home, the regions' chapters, foes that stand down, pacing.
- `perf.md`: frame, map entry, save, boot, GUT and CI numbers, and which tools need a window.
- `release.md`: `release.py`, French house style, the changelog.
