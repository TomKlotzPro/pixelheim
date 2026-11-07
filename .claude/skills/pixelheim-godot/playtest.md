# Playtest: an agent plays the real game (play.py)

`godot/tools/play.py` (PIX-423) lets an agent play the web build the way a player does, from Bash, one command at a time. It runs in headless Chrome with the sound off, so nothing opens on Tom's screen. Each session has a fresh Chrome profile that `stop` deletes, so its saves go with it and Tom's saves are never touched. The rules of a playtest (what to report, the proof it needs) are in the `pixelheim-playtest` skill.

## Setup, once per worktree

1. Copy the private art in from the main checkout (`godot/assets/puny/{medieval,shade,gegx,animals}`, `godot/assets/audio/paid`). It is git-ignored: never commit it, `godot/export/` or a screenshot.
2. `godot --headless --audio-driver Dummy --path godot --import`, then `mkdir -p godot/export/web && godot --headless --path godot --export-release Web export/web/index.html` (a fresh worktree has no `godot/export/web`, and the export won't make it). Export again after any change to the game.
3. Playwright for Python in a venv in your scratch folder: `python3 -m venv <scratch>/pw && <scratch>/pw/bin/pip install playwright==1.56.0`. Run play.py with that python. It drives the installed Google Chrome, so there is no browser to download.

## Commands

```
play.py start [--port N] [--dir D] [--lang fr] [--role mage --level 10] [--map overworld --at 93,33] [--flags "..."]
play.py keys [--port N] "right:1.2, e, esc"
play.py look [--port N] [--out D]
play.py stop [--port N]
```

- `start` opens the game and prints the first `look`. With no option it is a plain launch: the title, then New Game and hero creation, as a new player sees it (`--lang fr`: the browser in French). `--role`, `--level`, `--map` and `--at` start a harness run's throwaway hero with those presets instead (`scripts/harness_flags.txt`). That run skips the title and the Night of Ash, and starts in the Hamlet by day. `--flags` adds any other harness flags, steps too (`fight --foe orc`). With `fight`, play.py always adds `hurt`: the foe's hits hurt the hero, who can dodge and fall (the harness's hero is untouchable otherwise). It refuses `kill`, which swings by itself for up to five minutes of play, through your own keys: fight with your keys instead. `start` prints its first `look` once the presets' steps are done and the camera has settled. The session listens on port 8642, or on the next free port, which `start` prints. When sessions start at the same moment, give each its own `--port` (two can find the same port free, and the second then fails, saying so). Pass `--port` to every later command when several sessions run. `--dir` is the session's folder: its screenshots, `daemon.log` and Chrome profile. Without it, the folder is a new temp folder.
- `keys` presses keys, separated by commas. Each key is a Godot key name: `e`, `esc`, `enter`, `space`, `tab`, `shift`, `up`, `right`, `1`..`6`, `i`, `m`, `j`, `pgup`, `pgdn`. `name:1.5` holds the key for 1.5 s, and a key with no time is tapped. `up+left:0.5` holds both keys together, and `wait:2` presses nothing for 2 s. A one-letter key also types its letter, so `R,o,b,i,n` types a name in hero creation. The keys go through the game's input actions as the keyboard's would, rebinding included. `keys` prints the state after the last key.
- `look` saves a screenshot (`look-NNN.png` in the session's folder, or in `--out`) and prints JSON: `shot`, `map`, `cell`, `hp`/`maxHp`, `mana`/`maxMana`, `level`, `gold`, `hour`, `night`, `paused` (the game's own pause), `open` (the screens open, in the order they opened), `text` (the words on the top screen: a conversation, a menu, a card), `hud` (the HUD's words: the message plate, a hint, a door's nameplate, the battle log), `quest` (the line after "Next"), `tracked`, `foes` (within 12 cells: name, id, level, hp/maxHp, cell, mode), `seconds` (the game's clock), and `errors` (the page's console errors and warnings since the last look, each line once with its count).
- `stop` closes Chrome and the daemon and deletes the profile. Always stop, even after a failure. A session left alone for 30 minutes stops by itself.

## Turn by turn

The game runs only during a command. Between commands the page gives the engine no frames, so the clock, timers, tweens and the game's own pause menu stay exactly as they were, however long you think. The run is stepped (`--fixed-fps 60`): one frame is 1/60 s of game time, however slowly Chrome draws it, so `right:1` walks one second of the game. Check the clock with `seconds`: it only moves during `keys`.

On the web build `GameState.boot` reads the browser's saves, which are empty in a fresh profile, so a plain launch is always a new player's.

## How it works

`start` runs `play.py serve` in the background. The daemon serves `godot/export/web` as `web_perf.py` does, opens it with Playwright and answers on its port. Before the page loads, it sets `window.pixelheimArgs` (the game's command line: `play`, plus `--screenshot` and the presets) and a shim on `requestAnimationFrame` that holds the engine's next frame while `window.pixelheimPlay.frozen` is true. `world.gd` adds `scripts/play_bridge.gd` to the root when it sees `play` on the web. The bridge takes `pixelheimPlay.command` (the steps as JSON), presses and holds the keys for their physics ticks, then writes `pixelheimPlay.state` and sets `frozen`. Under `--screenshot`, `play` makes `harness.gd` stop after its steps, with no report, shot or quit, and the bridge holds its first answer until those steps are done and the maps beside the hero are stitched (`Harness.stepping`). Every answer carries the daemon's `pid`: `start` checks it is its own daemon's, and `stop` waits for it to go. The bridge's tests are in `test/unit/test_play_bridge.gd`, and the key parsing's tests are in `tools/test_play.py`.

## Known

- The camera keeps inside the maps drawn. Where no map lies beyond the edge (a dungeon, a house, the Reach's rim), the hero stands off centre near it, as designed. On the Reach the maps beside are drawn a moment after the hero arrives, and the camera eases out to them: `start`'s first look waits for that (it once showed the hero held at the map's edge).
