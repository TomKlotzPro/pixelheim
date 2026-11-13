# Lessons from each playtest

After each run, the orchestrator (Opus, the main session) adds what the run taught, newest first, and changes the rules it points at. **A lesson here overrules `SKILL.md` and the players' pages** until it is folded into them.

Each entry holds:
- the date, the game version, the players and their models;
- findings sent, confirmed, flaky, dropped; the issues filed;
- what each model did well or missed (for the comparison runs);
- the rule it changed, and where.

## Runs

### 2026-11-13, v0.360.0 (the third run: Fable players)

**Players:** fighter, french and menus, all three on Fable. Tom said on 2026-11-13: « utilise fable autant que tu veux ». They ran through a copy of the workflow with `args.model` (scratchpad/playtest-fable.js). There was no comparison run. Triage and replays ran on Opus. The second run (2026-11-12: newcomer and explorer on Sonnet) is the entry below.

**Findings:** 42 sent. They merged into 32 held and 4 dropped, all 4 dropped on judgment. Triage replayed 9 bugs: all 9 confirmed, none flaky, none lost. One replay found the steps one E short (Bram's hand-in) and added it. Filed:
- S3, confirmed by replay:
  - PIX-475: goblins stand 20-30 s against the village well before they come round.
  - PIX-476: HUD lines show after their moment (a burn after the foe died, "Quest accepted" after the hand-in).
  - PIX-477: with large text, the village works card runs off the screen.
  - PIX-478: Maren's « ? » sits alone on a line. The word wrap breaks at U+202F, so any French mark can be split this way.
  - PIX-479: Sela gives a « casque », and the Next line asks for a « bonnet ».
  - PIX-480: the Options footer keeps the old key after a rebind.
  - PIX-481: sixteen W push hero creation's panels off the screen.
  - PIX-482: the Skills path line is clipped mid-sentence.
  - PIX-483: with large text, a recipe card is cut and no key scrolls it.
- S3, judged from screenshots:
  - PIX-469: a foe's "Lv N" plate covers the damage floats and the hero. It came back after PIX-340.
  - PIX-470: the gunner's bullet is one pale pixel.
  - PIX-471: the message plate holds whole paragraphs. It came back after PIX-343.
  - PIX-472: a potion is used up at full health for nothing.
  - PIX-473: hero creation frames a locked skill like a choice.
  - PIX-474: Sela's slime quest says the forest, its goal says the fields.
- S4: PIX-484 lists the 17 nits.

| session | looks | sent | held | dropped |
|---|---|---|---|---|
| fighter (fable) | 69 | 8 | 8 (PIX-469, 470; 475, 476 confirmed; 4 nits) | 0 |
| french (fable) | 67 | 15 | 13 (PIX-471, 474; 477, 478, 479, 483 confirmed; 7 nits) | 2 |
| menus (fable) | 64 | 19 | 15 (PIX-471, 472, 473; 476, 480, 481, 482, 483 confirmed; 7 nits) | 2 |

**False alarms, and the rule that stops each:**
- "The dock's Menu is drawn lit after a second New Game" (menus). It was seen once: one label's colour, on a button play.py can't press. Rule: the dock is out of the menu tester's route, how it looks included.
- "Skills' F forget only says where to go, and a path is walked on one E" (menus). F names Old Hessa's shrine, and a path can be undone there. Rule: a footer key that answers by saying where to do it tells the truth. A choice that can be undone is design.
- "« x2 » beside « 2 × »" (french). A stack count and a cost line are two different things, and no house rule covers them. Rule: French typography is judged only against french.md's list and release.md's house style.
- "The journal's « À suivre » row cuts the goal" (french). A row gives way with … by design (ui.md), and the whole goal shows two rows below. Rule: a row ending in … is by design when its whole words show elsewhere on the screen. A line cut with no … (PIX-482) is a bug.
- Triage also narrowed three French findings down to their defect:
  - the spaced hyphen used as a dash is the house style in both languages (about 827 lines);
  - the codex's generic masculine is correct French;
  - two wording items are Tom's call.

**Stuck or wasted looks:**
- Every player used 64 to 69 of its 70 looks, against 26 to 52 last time, so the budget rule works. Each wrote a small wrapper that logs every command, and all 9 replays started from those logs.
- The fighter:
  - Spent about 6 looks per shooter learning its cadence (bowman about 3.15 s, gunner about 3.6 s), stepping 0.1 s at a time, because `foes[].mode` stays "chase" through a wind-up.
  - Read the hero's poison from hp ticks, since the state shows no ailments.
  - Once found the state a frame behind the picture (s1-warrior-orc look-008: the picture shows the orc dead and gold 44, the state says hp 11 and gold 30).
- The French reader:
  - Pressed E between two opening captions twice (they type for over 9 s), so the 4th caption went by unread.
  - Pressed E in a loop through Odo's talk, landed on Buy and bought things.
  - Found that `--prologue 2` to `4` start on the square, a long walk from the caller and the fires.
  - Spent 4 moves on Ana's fenced garden, then gave up.
- The menu tester lost 2 looks because `keys` answers before a fade ends (Enter on Begin, Quit to title, the language reload, a paste). A D on Language was also swallowed by the reload. `wait:0.5` after such a key fixed both.
- The French reader's script (french-fable/typo.py) checked the marks in every state's `text` and `hud` without spending looks. Worth keeping.

**Checklist items nobody reached:**
- fighter:
  - the cleave's reach, measured;
  - the ranger and the rogue against an elite;
  - skill keys 5 and 6: they hold the skills of levels 11 and 14 (combat.json skillTierLevels), so a level 5 or 10 hero has nothing there;
  - a ranged basic attack at four cells (the bowman keeps to three).
  - Covered after all: two rolls into the cleave were both clean, and loot goes into the pack when walked over.
- french: the 4th opening caption, the Night of Ash caller and the burning homes, Ana, Joss, the dog and the cat, the notice board, the bank, a level-up, a dungeon.
- menus:
  - spending stat and skill points: the `--level` hero has none left, and `--flags stats` or `skills` gives 5 and 3;
  - Hilda's Craft tab (`--map town_smith --flags shop`; triage reached it);
  - Clear warnings in a fight;
  - V paste on an empty clipboard.
  - Out by design: Fullscreen and the dock are outside the brief, and Reduce motion can't be judged from a still picture.
- newcomer and explorer didn't play this run.

**Fable against the first run's models:**

| player | 2026-11-07 | 2026-11-13, Fable |
|---|---|---|
| fighter | Sonnet: 35 looks, 2 sent, 1 held | 69 looks, 8 sent, 8 held, 2 bugs confirmed |
| french | Haiku: 40 looks, 6 sent, 3 held | 67 looks, 15 sent, 13 held, 4 bugs confirmed |
| menus | Haiku: 26 looks, 5 sent, 4 held | 64 looks, 19 sent, 15 held, 5 bugs confirmed |

- What Fable did well:
  - It used the whole budget and made its own tools.
  - Its steps were exact enough that 9 of 9 replays confirmed (one was one E short).
  - It reached what the first run never did: large text, French line breaks, footers after a rebind.
  - It was right to hold back the look-alike heroes at `--level 10`: the preset's kit (harness_boot.gd KITS) dresses every role alike.
- Where it fell short:
  - It still left observations in its summaries. The menu tester listed six as "too weak for a finding", and two of them may cost a player (see below).
  - Its French findings bundle several nits each, which triage had to split and narrow.
- **Verdict:** fighter, french and menus stay on Fable. The newcomer and the explorer have only played on Sonnet, so the next run compares the newcomer on Fable and on Sonnet.

**Seen but not sent (a look next run):**
- The E that ends Odo's talk opens his counter on Buy, and the next E buys a Bread Loaf (menus). The French reader's E loop bought things the same way. Two players saw a player's gold spent without asking.
- Vex's quest is accepted even when her talk is left with Esc on line 1 of 3 (menus).
- Odo's list doesn't wrap at the bottom, while every other list does (menus).
- What's new's date sits flush against the scrollbar. The map legend's "Forgetting" is unexplained for a new hero. "Junk: 4 past what crafting keeps." reads awkwardly (all menus).
- The first run's look-next items:
  - the hero over the river is now PIX-467;
  - "skill 2 showed no cost and no effect" is likely this run's lost skill press (PIX-484);
  - the two stacked boxes came back as the journal hint behind the talk (PIX-484).

**Tool (one play.py ticket):**
- `foes[].mode` should name a wind-up (a shooter's glow, the elite's cleave band).
- The state should list ailments (poison, burn, stun) on the hero and on each foe.
- `look`'s state can be one frame behind its picture.
- `keys` answers before a fade or a reload ends. It should wait for the screen to settle, or say that one is running.

**Rules changed:**
- SKILL.md:
  - the players run on Fable;
  - `wait:0.5` after a key that starts a fade;
  - stop an E loop once the talk has closed;
  - wait out a typing caption before pressing E;
  - a row's … is by design, a line cut with no … is a bug;
  - not findings: a footer key that says where to go, a choice that can be undone, heroes dressed alike by the `--level` kit;
  - the summary holds no observations.
- players/fighter.md:
  - Fable;
  - one role at level 20, for keys 5 and 6;
  - an elite for a ranged role too;
  - the cleave measured;
  - a ranged shot at four cells;
  - the shooters' cadence;
  - loot goes in when walked over.
- players/french.md:
  - Fable;
  - release.md's house style is the rule set: straight apostrophe, « 0,5 % », the spaced hyphen as the dash, a neutral player;
  - typography by script, looks spent on line breaks;
  - `--at` beside the night's steps;
  - captions waited out;
  - the bank and the ledgers with large text.
- players/menus.md:
  - Fable;
  - `--flags stats` and `--flags skills`;
  - Hilda's and Vex's counters;
  - the dock out of the route;
  - Large reading text on every screen;
  - a list whose focus doesn't wrap is a finding.
- triage.md: triage reads each player's summary too. An observation left there that can cost gold, progress or a choice gets one replay.
- pixelheim-playtest.js:
  - fighter, french and menus on Fable;
  - `args.model` folded in;
  - the comparison moves to the newcomer (Fable against Sonnet);
  - the merge agent gets the players' summaries.

### 2026-11-12, v0.352.0 (the second run)

**Players:** newcomer and explorer on Sonnet. This entry was written on 2026-11-13, from that run's workflow result.

**Filed:**
- S2: PIX-458, three yetis pin the hero in the ice cave's corner.
- S3: PIX-459, spearmen are drawn over the hero by a wall.
- S3: PIX-460, no E prompt at the well and the fires on the Night of Ash.
- S3: PIX-461, the arrow ignores a full bucket.
- S4: PIX-462 lists the nits.

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
- The comparison run moves to the newcomer, Fable against Sonnet: folded into `.claude/workflows/pixelheim-playtest.js`.
- The players run on Fable, the newcomer and explorer on Sonnet until compared: folded into `SKILL.md` and `.claude/workflows/pixelheim-playtest.js`.
- `wait:0.5` after a key that starts a fade, stop an E loop once the talk has closed, and wait out a typing caption: folded into `SKILL.md`.
- A row's … with its words elsewhere, a footer key that says where, an undoable choice and the `--level` kit's look are not findings: folded into `SKILL.md`.
- The summary holds no observations, and triage replays any left there that can cost the player: folded into `SKILL.md` and `triage.md`.
- The fighter plays one role at level 20, an elite with a ranged role, a measured cleave and a shot at four cells: folded into `players/fighter.md`.
- The French reader judges typography against release.md's house style only, and starts the night's steps beside their place: folded into `players/french.md`.
- The menu tester spends points from `--flags stats` and `--flags skills`, visits every counter, and leaves the dock alone: folded into `players/menus.md`.
