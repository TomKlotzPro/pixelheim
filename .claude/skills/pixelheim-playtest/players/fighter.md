# The fighter

**Goal:** find what's wrong or unfair in combat, role by role. Hits that land from too far or not at all, foes' attacks you can't read, numbers that lie.

**Start:** one session per fight, each with a hero of a given role and level next to a foe. Stop it before starting the next. For example:
* `--role warrior --level 5 --flags "fight --foe orc"`: an orc beside the hero;
* `--role ranger --level 5 --flags "fight --foe orc --foe-distance 3"`: the orc three cells off;
* `--role mage --level 10 --flags "fight pack --foe goblin"`: a goblin and its pack;
* `--role warrior --level 8 --flags "fight --foe turncoat_bowman --foe-distance 3"`: a shooter;
* `--role warrior --level 10 --flags "fight elite --foe orc"`: an elite, for its cleave.

The trick foes' ids are their kinds' names: `--foe slime`, `wolf`, `goblin`, `skeleton`, `ghost`, `crab` (combat.json `tricks`), beside `orc`, `pirate_gunner` and `turncoat_bowman`. A foe six or more levels below the hero runs from it (combat.json `packs.fleeLevels` 6; an elite counts two levels more) and fights only when cornered or struck. Read its "Lv N" at the first look. The wolves (Lv 4), the slimes, the crab (Lv 3) and the sea cave's skeletons run from a level-10 hero, so fight them at level 5.

The `fight` preset hands the fight over before its first swing (PIX-435): at the first look the foe is whole and where the flags put it, `--foe-distance 3` three cells off. Read `foes` at the first look: the first blow is yours. The `fight` foe takes its region's level (its plate's "Lv N"), so a foe above your level is meant to be hard.

play.py makes every such fight real: the foe can hurt you. Never pass `kill` or `slay`.

**Model:** Fable (`lessons.md`, 2026-11-13).

## Route

The 2026-11-27 run played the paladin and the necromancer (a first on record), the mage and the rogue against a pack and a shooter, the ranger against an elite, crits, the rim and the fall at night. Start with what it left: a ghost that fades (`--foe ghost`) and a skill on it, the wolves' and goblins' tricks at level 5, the paladin against a shooter, and one role at level 20 (keys 5 and 6).

Play four roles, about 15 looks each: **warrior**, **ranger**, **mage**, **rogue**. If looks are left, add the cleric, paladin or necromancer. Use level 5 or 10 for each, so you have skills, and play one role at level 20: keys 5 and 6 hold the skills of levels 11 and 14, so a level 10 hero has nothing there. A melee role and the ranger each fight an elite: watch its cleave and roll through it once.

For each role:
1. **One plain foe**, such as an orc or a goblin: fight it close, then from as far as your weapon should reach.
2. **A pack** (`fight pack --foe goblin`): do the foes spread round you, and can you get out?
3. **A foe that shoots**: the Smuggler Gunner (`--foe pirate_gunner`) or the Turncoat Bowman (`--foe turncoat_bowman`). Does it keep its distance? Does it glow before it fires? Can you see its shot fly, and dodge it?
4. **Your skills**: each one by its number key, at least once. Does it reach where it should, and cost what it says? And one skill against a trick: a faded ghost, a guarding crab's front, a bone pile.

A small script that sends `keys` and prints the state (as fighter-fable's brawl.py, until.py and mode.py did on 2026-11-15) measures timings without spending looks.

## Check

- **Reach.** A sword, axe, hammer, dagger or fist lands on the cell in front and its two front corners (combat.json `reach`, a 90° arc), never two cells off. One swing striking two foes, or a foe on a front diagonal, is by design. A bow or a staff reaches three cells, with its arrow or bolt flying. A hit from further than that, or a miss at the right distance, is a bug. Try a ranged basic attack at four cells: `--role ranger --level 5 --flags "fight --foe orc --foe-distance 4"`, then shoot at the first look, before the orc closes.
- **Numbers.** Does the damage that floats up match the foe's health in the state? Does your health bar match your health in the state?
- **Reading a foe.** Is every big attack told before it lands (a glow, a band or a circle on the ground)? An elite's cleave should reach about one cell and a quarter. Measure it: stand still one cell off once, and step back to two cells once when the band shows; `hp` says which it reached. `foes[].mode` names the wind-up (PIX-485): `bite`, a shooter's `aim` (the bowman fires about every 3.15 s, the gunner about every 3.6 s), an elite's move by its name (`cleave`, `stamp`...). Send short `wait`s until the mode shows, then look for its picture.
- **Tricks (PIX-489).** The slime splits. The Dire Wolf bites and runs, and a pack takes turns. The goblin snatches gold. The skeleton rises once from its bone pile unless struck. The ghost fades when struck twice. The crab guards its front. Each trick rests between uses: a ghost fades at most every 5 s, and a crab lifts its claws every 4 s for about 1.6 s. The Bestiary (B) lists a foe from its first kill, with its trick's line once seen. `foes[].mode` names a trick at work (PIX-485): the wolf's `crouch`, `dart`, `back` and `away`, the goblin's `run`, the ghost's `shimmer` and `faded`, the crab's `raise` and `guard`, the skeleton's `pile`. Time with the mode and `played` (`seconds` runs on under a menu), and judge with the pictures. The state lists `ailments` on you and on each foe.
- **Dodging.** Roll (Shift) when the warning shows: being hit through a roll started then is a finding. How long the warning lasts is not.
- **Skills.** Number keys 1 to 6. Does each one fire, and does the dock show its turn coming back? Does one fire with nothing to hit and waste its energy? A skill that costs nothing and shows nothing is a finding: the state shows no effects of skills, so compare the dock and the picture before and after. Skills share a 1 s turn (PIX-484). A skill pressed with more than 0.5 s of it left is refused at once, its slot flashing with a click and no words. One pressed in the last 0.5 s fires as the turn ends. A skill that also costs HP (the warrior's Berserk: 8 HP) greys out when the hero's HP can't pay it. "Interrupted!" floats when a stun takes hold during a foe's tell: the warrior's Shield Slam stuns about one time in two (0.55), and an elite resists more than one a window.
- **The fall.** Let one fight go badly once. Where do you wake, and what did you lose?
- **Loot.** What drops goes in when you walk over it: check the pack and the gold count. Does the gold go up by what floated?

Gold and XP numbers floating up are wanted. Don't report the weapons' reach above as a bug when it works as described.
