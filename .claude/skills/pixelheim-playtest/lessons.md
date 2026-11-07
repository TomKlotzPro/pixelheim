# Lessons from each playtest

After each run, the orchestrator (Opus, the main session) adds what the run taught, newest first, and changes the rules it points at. **A lesson here overrules `SKILL.md` and the players' pages** until it is folded into them.

Each entry holds:
- the date, the game version, the players and their models;
- findings sent, confirmed, flaky, dropped; the issues filed;
- what each model did well or missed (for the comparison runs);
- the rule it changed, and where.

## Runs

### 2026-11-07, v0.325.0 (PIX-424, the first run)

**Players:** newcomer, fighter and explorer on Sonnet, french on Haiku, and menus on both Haiku and Sonnet (the comparison). Triage on Opus.

**Findings:** 24 sent and 17 held, which merged into 13. Triage replayed 4 bugs and confirmed all 4, with none flaky. 7 were dropped, all on judgment, and no replay failed. Filed:
- S2: PIX-426, the map, the journal and Maren's "!" send the player to Maren instead of the caller on Upper Street.
- S3: PIX-427, Esc on Saves from the pause menu also closes the pause menu.
- S3: PIX-428, E on the Language row closes Options.
- S3: PIX-429, the hero is hidden under the well's roof.
- S3: PIX-430, the hero is hidden under the west garden's canopy.
- S3: PIX-431, the ash and grass meet on a ruler-straight line. It came back after PIX-397.
- S3: PIX-432, the message reads "I opens your pack."
- S3: PIX-433, the big tip box.
- S4: PIX-434 lists the 5 nits.

| session | looks | sent | held | dropped |
|---|---|---|---|---|
| newcomer (sonnet) | 34 | 5 | 4 (PIX-426, 430, 432, 433) | 1 |
| fighter (sonnet) | 35 | 2 | 1 (PIX-429, confirmed) | 1 |
| explorer (sonnet) | 52 | 4 | 3 (PIX-431, 2 nits) | 1 |
| french (haiku) | 40 | 6 | 3 (PIX-432, 433, 1 nit) | 3 |
| menus (haiku) | 26 | 5 | 4 (PIX-427, 428, 433, 1 nit) | 1 |
| menus (sonnet) | 40 | 2 | 2 (PIX-427, 1 nit) | 0 |

**False alarms, and the rule that stops each:**
- "The day clock doesn't move while the hero stands still" (newcomer, explorer). It is by design (PIX-246). Rule: SKILL's don't-report list.
- "Gunner and bowman shots give no time to react" (fighter). Every shot showed a warning first. A player that moves in steps of a few tenths of a second can't time a human's reaction. Rule: a confusing finding means no warning at all, not a warning judged too short.
- "WebGL INVALID_OPERATION warnings" (french). They come from the headless Chrome. Rule: SKILL's errors line.
- "Stats rows grey on beige" (french) and "'Begin the adventure' greyed with no name" (menus haiku). Rule: a greyed entry is one you can't use yet.
- "The quest NPC in the Grand-Rue can't be reached" (french). The player took a wrong turn into a burning yard. Rule: the French reader reports words only, and starts its village session from a preset instead of walking through the Night of Ash.

**Stuck or wasted looks:**
- The newcomer spent about 20 looks on one step. That step was the real S2, PIX-426. It had no way past it, so it never reached the dawn. The "more than three looks" rule made it a finding, but nothing said to move on.
- The newcomer's `e` from the cutscene went into the name field, and the hero became "eTom". `backspace` didn't remove it.
- The French reader lost about 10 looks in the burning Grand-Rue.
- Menus (haiku) counted key presses without seeing which row was chosen. It turned Glow, Language and Sound by accident, and took about 40 calls to find a villager.
- Menus (sonnet) spent its first 2 looks on the title's 8-second intro. It also found that E worked only after a tap toward the NPC.
- The explorer split its looks into 12 sessions of about 4 looks each. A `--at` on a solid cell left the hero stuck.
- The fighter's `fight` preset strikes one swing before the first look. So foes start hurt, a goblin can already be dead, and `--foe-distance 3` has already closed.
- No player used its budget: they stopped between 26 and 52 of 70 looks, with route items left.

**Checklist items nobody reached:**
- newcomer: the dawn, the first quests, a quest outside the village, a fall.
- fighter: an elite's cleave, a roll through an attack, the cleric, the paladin, the necromancer.
- explorer: stairs in any dungeon, the shop, hall and alchemist doors, the Reach's rim, the sea cave.
- french: every role's description, the dawn, the village's people, a shop's goods.
- menus: the dock's Menu (it opens only with the mouse or a pad, so play.py can't reach it; the step is dropped), Fullscreen, Sell and Craft by picture, Reduce motion in play.

**Menus, Haiku against Sonnet:**
- Haiku used 26 looks and 4 of its 5 findings held. It confirmed 2 bugs, and one of them only it found: PIX-428, because it tried the Language row. It had 1 false alarm (the greyed button). It sent one finding without a screenshot (the rebind swap). Its slips came from the tool, which doesn't show which row is chosen, more than from its judgment.
- Sonnet used 40 looks and both its findings held, with no false alarm. It skipped the Language row, which its route covers, so it missed PIX-428. It saw two things and didn't send them: the rebind swap, and two message boxes stacked at once.
- **Verdict:** menus stays on Haiku. It held more findings in fewer looks, on the cheaper model.
- **The other players:**
  - french stays on Haiku but can't be judged yet. It sent no finding about the French itself, and it never reached most of the text. So the next run compares french on both models.
  - fighter stays on Sonnet, since its one held finding came from reading a picture.
  - newcomer and explorer stay on Sonnet.

**Seen but not sent (a look next run):**
- The hero's sprite half over the river near town (24,35), in menus-haiku look-021.
- Skill 2 on the warrior, ranger and rogue showed no cost and no effect.
- The "Quest accepted" plate and the "Your journal" tip shown together as two boxes.

**Tool (one play.py ticket):**
- the state shows no chosen row (`focus`);
- the state lists no people nearby (`npcs`), and no door's cell;
- the first `stop` waits 30 s and kills the session (4 times);
- `keys` printed about 340 KB with What's new open;
- the errors list carries WebGL warnings;
- `fight` swings before handing over;
- check `backspace` in the name field, and whether `text` cuts lines at about 60 characters or the text was still typing.

**Rules changed:**
- SKILL.md: don't report the clock, WebGL warnings or greyed entries; confusing means no warning at all; use the whole budget, and after six looks stuck, report and move on; text fields and talking to people; send what you saw instead of leaving it in the summary.
- players/*.md: newcomer (going past a stuck step), fighter (the swing before the first look, the elite, the roll), explorer (`--at` on open ground, the last run's gaps first), french (three sessions from presets, words only, both models), menus (no dock step, Fullscreen skipped, an 8 s wait at the title, look before you confirm, a shop session from a preset).
- triage.md: get a screenshot for a finding that has none.
- pixelheim-playtest.js: the comparison moves to french.

## Lessons in force

- Don't report the day clock standing still while the hero does (PIX-246): folded into `SKILL.md`.
- A greyed button or row is one you can't use yet, not a finding: folded into `SKILL.md`.
- Don't report the headless Chrome's WebGL warnings in `errors`: folded into `SKILL.md`.
- Confusing means a big attack with no warning at all, not a warning judged too short: folded into `SKILL.md`.
- Use the whole budget, and after six looks stuck on one step, report it and go past it: folded into `SKILL.md`.
- A text field types every one-letter key; face someone before you press E: folded into `SKILL.md`.
- Send what you saw as a finding (S4 when unsure) instead of leaving it in the summary: folded into `SKILL.md`.
- The newcomer reports a Next line, Goal and journal that disagree, and goes past a stuck step from a preset at Maren: folded into `players/newcomer.md`.
- The fighter knows the `fight` preset's first swing, fights an elite, rolls through a warning and reports a skill that shows nothing: folded into `players/fighter.md`.
- The explorer starts on open cells and begins with the places the last run didn't reach: folded into `players/explorer.md`.
- The French reader plays three sessions from presets and reports words only: folded into `players/french.md`.
- The menu tester has no dock step, skips Fullscreen, waits 8 s at the title, looks before each E and checks the shop from a preset: folded into `players/menus.md`.
- A finding with no screenshot gets one replay for its picture, else it is dropped: folded into `triage.md`.
- The comparison run moves to french, and menus stays on Haiku: folded into `.claude/workflows/pixelheim-playtest.js`.
