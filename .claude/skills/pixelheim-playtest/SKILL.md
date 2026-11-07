---
name: pixelheim-playtest
description: Playtest Pixelheim as a player - the rules of a playtest (what a finding is, the proof it needs, how bad it is, what to ignore), the five players' briefs, how triage confirms and files findings, and the lessons kept from each run. Use when an agent plays the game through godot/tools/play.py, runs the pixelheim-playtest workflow, or triages its findings.
---

# Playtesting Pixelheim

Agents play the real game, the way a player does, and report what a player would hit: bugs, confusion and things that feel off. Pixelheim's scripted flows (`godot/tools/flows.txt`) already check what we know to look for. A playtest looks for what we don't know yet.

The game runs as the web build in a headless Chrome, driven by `godot/tools/play.py` (PIX-423). Its commands and options are in `.claude/skills/pixelheim-godot/playtest.md`. This page holds the rules of a playtest; the pages beside it hold the rest:

- `players/<id>.md`: each player's goal, where they start, their route and their checklist (`newcomer`, `fighter`, `explorer`, `french`, `menus`).
- `triage.md`: how the findings are merged, reproduced and filed in Linear.
- `lessons.md`: what each run taught, and the rule it changed. **Read it before you play**: its rules overrule this page where they disagree.

The players run on cheaper models (Sonnet, Haiku). The orchestrator and the triage run on Opus: they set these rules, confirm every finding before it reaches Linear, and change the rules after each run.

## Safety, always

- **Play only through `play.py`.** Never run godot with a window, `godot/tools/shot.sh`, `flows.sh` without `--quiet`, `lookbook.sh`, or any harness `--slot` (it writes Tom's real saves).
- **Stop your session when you are done, even when something failed** (`play.py stop`), so no Chrome or server is left behind.
- **Screenshots show paid art.** They stay in your run folder and go to Linear only. Never `git add` them, never commit anything, never edit a file in the repo.
- **Never `open` a file on Tom's screen.** Name the absolute path in your report instead.
- **Don't read the game's code while you play.** Judge what you see, as a player would. Triage may read code to point a ticket at the right place.

## How to play

Each turn is one command: `look`, then think, then `keys`. The game runs only during a command, so take the time you need between them. Pass `--port` (your session's) to every command; your brief gives it, and the python to run play.py with.

```
<python> godot/tools/play.py start --port N --dir <your folder> [your brief's start options]
<python> godot/tools/play.py keys --port N "right:1.2, e, esc"
<python> godot/tools/play.py look --port N
<python> godot/tools/play.py stop --port N
```

- **`keys`**: keys separated by commas. A key alone is tapped; `right:1.2` holds it 1.2 s of game time; `up+left:0.5` holds both; `wait:2` presses nothing for 2 s. A one-letter key also types its letter (`R,o,b,i,n` types a name), and `backspace` deletes one. `keys` prints the state after its last key, but no picture.
- **`look`**: a screenshot (read it with the Read tool) and the state: `map`, `cell`, `hp`/`maxHp`, `mana`/`maxMana`, `level`, `gold`, `hour`, `night`, `paused`, `open` (the screens open), `text` (the words on the top screen, cut near 2000 characters with a line saying how many more; a caption still typing out ends in `[still typing]`), `focus` (the words of each chosen thing, one list apiece: in the pack and at a counter the lit tab, then the chosen row, the one E would take), `hud` (the HUD's words: messages, hints, a door's nameplate), `quest` (the "Next" line), `foes` (within 12 cells, with their hp and cell), `npcs` (the villagers within 12 cells: name and cell), `doors` (the ways in and out within 12 cells: cell and the map they lead to), `seconds` (the game's clock), `errors` (console errors since the last look) and `webgl` (a count of the headless Chrome's own WebGL warnings).
- **Spend your looks.** Your brief gives a budget, about 60 to 80 looks. Look after every move that could change something: a door, a fight, a menu, a line of text. Between looks, `keys`' own state is often enough to know you moved. Don't stop before your budget while your route or checklist has items left: few findings mean keep looking, not stop. When one step holds you more than six looks, report it and go past it the way your brief says, instead of trying it again.
- **The state says where you are, the picture says how it looks.** Trust the state for map, cell, health and quest, and quote `text` and `hud` for on-screen words. Trust the screenshot for what a player sees. When the two disagree, that is a finding.
- **Walk with short holds** (0.2 to 0.5 s) near things, and longer ones to travel: `right:1` walks one second of the game. If two holds don't change `cell`, you are blocked: look at why before you push again.
- **Keep a log as you go**: the `start` line and each `keys` you sent, in order. A finding's steps come from it, and triage replays them as they are.
- **Anything in `errors` is worth a look**: an error a player never sees can still be a bug. Report it with what you were doing when it came. The headless Chrome's WebGL warnings (`WebGL: INVALID_OPERATION` on `bindBuffer` or `bufferSubData`, often dozens in the burning village) are not in `errors` but counted in `webgl`: don't report those.

### The keys

The play.py name of each key is in brackets.

| Action | Keys |
|---|---|
| Move | W A S D (`w` `a` `s` `d`), or the arrows (`up` `down` `left` `right`) |
| Attack | J (`j`) or Space (`space`) |
| Dodge roll | Shift (`shift`) or L (`l`) |
| Talk, interact, confirm | E (`e`) or Enter (`enter`) |
| Skills | 1 to 6 (`1`..`6`) |
| Inventory | I (`i`) |
| World map | M (`m`) or Tab (`tab`) |
| Journal | Q (`q`) |
| Stats | C (`c`) |
| Skills screen | K (`k`) |
| Codex | B (`b`) |
| Pause menu, back | Esc (`esc`) |
| Drop, drop all | X, Z (`x`, `z`) |

In menus, W/S or the arrows choose, E or Enter confirms, and Esc goes back. A rebound key replaces the letter key; the arrows, Enter, Space and Tab always keep working.

A text field (the hero's name) types every one-letter key, `e`, `w` and `s` too: `backspace` takes a letter out, and `enter` confirms it. To talk to someone, face them first: tap the arrow toward them (`left:0.1`), then `e`.

### Where a session starts

- **No option**: a plain launch from the title, as a new player sees it. `--lang fr` sets the browser to French.
- **`--role`, `--level`, `--map`, `--at x,y`**: a throwaway hero of that role and level, standing there. It skips the title and the Night of Ash, and starts in the Hamlet by day.
- **`--flags "..."`**: more harness presets (`godot/scripts/harness_flags.txt`).
  - `night`: the night;
  - `--town-tier 0`: the village in its ashes;
  - `fight --foe orc`: a foe beside the hero. play.py makes it a real fight: the foe can hurt you;
  - `--foe-distance 3`: the foe that far off;
  - `pack`: its pack with it.

  Never pass `kill`, `slay` or `--keys`: they play the fight or the keys for you.

## What a finding is

Every finding has a **kind**:

- **bug**: the game does something wrong. A freeze, a crash, an error in `look`'s errors. A number on screen that disagrees with the state. A hero stuck on nothing, or walking through a wall, a house or water. A sprite drawn over or under the wrong thing. A seam, gap, flicker or black band in the world. Text cut off or spilling out of its frame. A key that doesn't do what its footer says. A quest step that never completes.
- **confusing**: a player wouldn't know what to do or what just happened. You spent more than three looks unsure where to go. A message that doesn't say what it means. A foe's big attack that gives no warning before it lands (no glow, band, circle or drawn bow). How long the warning lasts is Tom's call: a player that moves in steps of a few tenths of a second can't time a human's reaction.
- **polish**: it works, but it feels off. Text too long to read in a box, a moment that drags, a screen that looks unlike the others, a reward that goes unnoticed.

And a **severity**:

| | Means | Example |
|---|---|---|
| S1 | blocks play | a freeze, a crash, a hero stuck for good, lost progress |
| S2 | wrong, and a player on the main path will see it | wrong damage, a quest step that won't complete, a glitch in the village |
| S3 | wrong but minor, or off the main path | a seam in a far corner, a typo |
| S4 | a nit | one pixel off, a word that could be better |

When unsure between two, pick the lower one. Triage re-rates anyway.

## The proof a finding needs

A finding without proof is not reported.

- **A screenshot** that shows it (the path `look` gave). For something that moves, two or three in a row.
- **The state** at that moment (the JSON `look` printed, or the part that matters).
- **The steps**: the `start` options and every `keys` from the start to the moment you saw it, from your log. Triage replays exactly these.
- **For a bug, try it twice.** Say whether it happened again (`seen twice: yes/no`). If you could only guess at it, it is not a bug: report it as confusing or polish (S4 when unsure), with its screenshot. Don't leave something you saw only in your summary: triage judges a picture cheaply, and a line in a summary is lost.

## Don't report

- **Sound and music.** You can't hear; sound is Tom's to judge.
- **Speed in the headless Chrome**: frame rate, stutter and load times. Its drawing isn't a player's machine, and the turn-by-turn pause is the tool's, not the game's.
- **What the game means to do:**
  - Gold and XP numbers floating up after a kill: Tom likes them.
  - A sword, axe, hammer, dagger or fist reaches only the cell in front; a bow or a staff reaches three cells, with its shot flying (v0.322).
  - The seven skills whose blow falls from the sky (thunder, a divine sword...) are ranged.
  - On the web, a door's fade starts about 0.17 s after the key.
  - The village starts as burnt ashes for a new hero (the Night of Ash) and rebuilds over the story.
  - The day clock turns only while the hero walks (PIX-246): standing still or `wait` leaves the hour as it was, so waiting never brings the dawn.
  - A greyed button or row is one you can't use yet (no name typed, no points to spend, not enough gold). Report it only when nothing on screen says why and a player would be stuck.
- **What is already ticketed.** Triage checks Linear; you don't need to.

Do report big message boxes with too much text: Tom dislikes them.

## The report

Return your findings in the workflow's schema. Write in English, in short sentences, and quote any on-screen text exactly (the French reader quotes the French). Give each finding:

- `title`: what a player sees, in a few words ("Hero walks through the mill's wall").
- `kind`, `severity`, `where` (map, cell, open screen).
- `happened`, `expected`.
- `steps`: the start options and the keys, in order.
- `screenshots`: absolute paths. `state`: the JSON that matters. `seenTwice` for a bug.

Then say in `summary` how the session went: how far you got, what you didn't reach, and anything about the tool that slowed you down. The orchestrator reads it to improve the rules.
